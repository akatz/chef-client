#
# Author:: Joshua Timberman (<joshua@opscode.com>)
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Cookbook Name:: chef-client
# Recipe:: service
#
# Copyright 2009-2011, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class ::Chef::Recipe
  include ::Opscode::ChefClient::Helpers
end

require 'chef/version_constraint'
require 'chef/exceptions'

root_group = value_for_platform_family(
  ["openbsd", "freebsd", "mac_os_x"] => "wheel",
  "default" => "root"
)

if node["platform"] == "windows"
    existence_check = :exists?
# Where will also return files that have extensions matching PATHEXT (e.g.
# *.bat). We don't want the batch file wrapper, but the actual script.
    which = 'set PATHEXT=.exe & where'
    Chef::Log.debug "Using exists? and 'where', since we're on Windows"
else
    existence_check = :executable?
    which = 'which'
    Chef::Log.debug "Using executable? and 'which' since we're on Linux"
    user "chef" do
      system true
      shell "/bin/false"
      home "/var/lib/chef"
    end
end

# COOK-635 account for alternate gem paths
# try to use the bin provided by the node attribute
if ::File.send(existence_check, node["chef_client"]["bin"])
  client_bin = node["chef_client"]["bin"]
  Chef::Log.debug "Using chef-client bin from node attributes: #{client_bin}"
# search for the bin in some sane paths
elsif Chef::Client.const_defined?('SANE_PATHS') && (chef_in_sane_path=Chef::Client::SANE_PATHS.map{|p| p="#{p}/chef-client";p if ::File.send(existence_check, p)}.compact.first) && chef_in_sane_path
  client_bin = chef_in_sane_path
  Chef::Log.debug "Using chef-client bin from sane path: #{client_bin}"
# last ditch search for a bin in PATH
elsif (chef_in_path=%x{#{which} chef-client}.chomp) && ::File.send(existence_check, chef_in_path)
  client_bin = chef_in_path
  Chef::Log.debug "Using chef-client bin from system path: #{client_bin}"
else
  raise "Could not locate the chef-client bin in any known path. Please set the proper path by overriding node['chef_client']['bin'] in a role."
end


node.set["chef_client"]["bin"] = client_bin

# libraries/helpers.rb method to DRY directory creation resources
create_directories

case node["chef_client"]["init_style"]
when "init"

  #argh?
  dist_dir, conf_dir = value_for_platform_family(
    ["debian"] => ["debian", "default"],
    ["fedora"] => ["redhat", "sysconfig"],
    ["rhel"] => ["redhat", "sysconfig"],
    ["suse"] => ["suse", "sysconfig"]
  )

  template "/etc/init.d/chef-client" do
    source "#{dist_dir}/init.d/chef-client.erb"
    mode 0755
    variables(
      :client_bin => client_bin,
      :fork => node['chef_client']['fork']
    )
    notifies :restart, "service[chef-client]", :delayed
  end

  template "/etc/#{conf_dir}/chef-client" do
    source "#{dist_dir}/#{conf_dir}/chef-client.erb"
    mode 0644
    notifies :restart, "service[chef-client]", :delayed
  end

  service "chef-client" do
    supports :status => true, :restart => true
    action :enable
  end

when "smf"
  directory node['chef_client']['method_dir'] do
    action :create
    owner "root"
    group "bin"
    mode "0755"
    recursive true
  end

  local_path = ::File.join(Chef::Config[:file_cache_path], "/")
  template "#{node['chef_client']['method_dir']}/chef-client" do
    source "solaris/chef-client.erb"
    owner "root"
    group "root"
    mode "0755"
    notifies :restart, "service[chef-client]"
  end

  template(local_path + "chef-client.xml") do
    source "solaris/manifest.xml.erb"
    owner "root"
    group "root"
    mode "0644"
    notifies :run, "execute[load chef-client manifest]", :immediately
  end

  execute "load chef-client manifest" do
    action :nothing
    command "svccfg import #{local_path}chef-client.xml"
    notifies :restart, "service[chef-client]"
  end

  service "chef-client" do
    action [:enable, :start]
    provider Chef::Provider::Service::Solaris
  end

when "upstart"

  upstart_job_dir = "/etc/init"
  upstart_job_suffix = ".conf"

  case node["platform"]
  when "ubuntu"
    if (8.04..9.04).include?(node["platform_version"].to_f)
      upstart_job_dir = "/etc/event.d"
      upstart_job_suffix = ""
    end
  end

  template "#{upstart_job_dir}/chef-client#{upstart_job_suffix}" do
    source "debian/init/chef-client.conf.erb"
    mode 0644
    variables(
      :client_bin => client_bin,
      :fork => node['chef_client']['fork']
    )
    notifies :restart, "service[chef-client]", :delayed
  end

  service "chef-client" do
    provider Chef::Provider::Service::Upstart
    supports :status => true, :restart => true
    action [ :enable, :start ]
  end

  service "chef-client init" do
    service_name "chef-client"
    provider Chef::Provider::Service::Init::Debian
    supports :status => true
    action [ :stop, :disable ]
  end

when "arch"

  template "/etc/rc.d/chef-client" do
    source "rc.d/chef-client.erb"
    mode 0755
    variables(
      :client_bin => client_bin
    )
    notifies :restart, "service[chef-client]", :delayed
  end

  template "/etc/conf.d/chef-client.conf" do
    source "conf.d/chef-client.conf.erb"
    mode 0644
    notifies :restart, "service[chef-client]", :delayed
  end

  service "chef-client" do
    action [:enable, :start]
  end

when "runit"

  include_recipe "runit"
  runit_service "chef-client"

when "bluepill"

  directory node["chef_client"]["run_path"] do
    recursive true
    owner "root"
    group root_group
    mode 0755
  end

  include_recipe "bluepill"

  template "#{node["bluepill"]["conf_dir"]}/chef-client.pill" do
    source "chef-client.pill.erb"
    mode 0644
    notifies :restart, "bluepill_service[chef-client]", :delayed
  end

  bluepill_service "chef-client" do
    action [:enable,:load,:start]
  end

when "daemontools"

  include_recipe "daemontools"

  directory "/etc/sv/chef-client" do
    recursive true
    owner "root"
    group root_group
    mode 0755
  end

  daemontools_service "chef-client" do
    directory "/etc/sv/chef-client"
    template "chef-client"
    action [:enable,:start]
    log true
  end

when "win-service"
  chef_gems_path = Gem.path.map {|g| g if g =~ /chef\/embedded/ }.compact.first.strip
  win_service_manager = File.join(chef_gems_path,"gems","chef-#{Chef::VERSION}","distro","windows","service_manager.rb")
  windows_service_file = File.join("#{chef_gems_path}","gems","chef-#{Chef::VERSION}","lib","chef","application","windows_service.rb")
  chef_client_conf_file = File.join(node['chef_client']['conf_dir'], "client.rb")
  chef_client_log = File.join(node['chef_client']['log_dir'], "client.log")


  # install a patched windows_service.rb for CHEF-3301 NameError issue. This should get fixed in chef 10.14.0
  cookbook_file windows_service_file do
    source "windows_service.rb"
    inherits true
    only_if { Chef::VERSION <= '10.12.0' }
    notifies :restart, "service[chef-client]"
  end

  execute "install chef-client Windows Service" do
    command "#{node["chef_client"]["ruby_bin"]} \"#{win_service_manager}\" --action install -c #{chef_client_conf_file} -L #{chef_client_log} -i #{node["chef_client"]["interval"]} -s #{node["chef_client"]["splay"]}"
    notifies :restart, "service[chef-client]"
    action :nothing
  end

  execute "uninstall chef-client Windows Service" do
    command "#{node["chef_client"]["ruby_bin"]} \"#{win_service_manager}\" --action uninstall"
    notifies :run, "execute[install chef-client Windows Service]", :immediately
    not_if do
      require 'win32/service'

      actual = {}
      expected_svc_config = {
        :service_type => "own process, interactive",
        :start_type => "auto start",
        :error_control => "normal",
        :binary_path_name => "\"#{node["chef_client"]["ruby_bin"].gsub(File::SEPARATOR, File::ALT_SEPARATOR).gsub(".exe", "")}\" \"#{windows_service_file.gsub(File::SEPARATOR, File::ALT_SEPARATOR)}\"  -c #{chef_client_conf_file.gsub(File::SEPARATOR, File::ALT_SEPARATOR)} -L #{chef_client_log.gsub(File::SEPARATOR, File::ALT_SEPARATOR)} -i #{node["chef_client"]["interval"]} -s #{node["chef_client"]["splay"]} #{node["chef_client"]["fork"] ? "--fork" : ""}",
        :load_order_group => "",
        :tag_id => 0,
        :dependencies => [],
        :service_start_name => "LocalSystem",
        :display_name => "chef-client"
        }

      begin
        # convert the service config_info from a Struct to a Hash so we can compare with our expected config
        actual = Hash[Win32::Service.config_info('chef-client').each_pair.to_a]
      rescue Win32::Service::Error
        # catch the exception and do nothing, since this means the service doesn't exist
      end

      Chef::Log.debug("actual: #{actual}")
      Chef::Log.debug("expected: #{expected_svc_config}")

      expected_svc_config == actual
    end
  end

  service "chef-client" do
    supports :restart => true
    action [ :enable, :start ]
    provider Chef::Provider::Service::Windows
#    start_command "#{node["chef_client"]["ruby_bin"]} \"#{win_service_manager}\" --action start"
#    stop_command "#{node["chef_client"]["ruby_bin"]} \"#{win_service_manager}\" --action stop"
#    restart_command "#{node["chef_client"]["ruby_bin"]} \"#{win_service_manager}\" --action restart"
  end

when "launchd"

  version_checker = Chef::VersionConstraint.new(">= 0.10.10")
  mac_service_supported = version_checker.include?(node['chef_packages']['chef']['version'])

  if mac_service_supported
    template "/Library/LaunchDaemons/com.opscode.chef-client.plist" do
      source "com.opscode.chef-client.plist.erb"
      mode 0644
      variables(
        :launchd_mode => node["chef_client"]["launchd_mode"],
        :client_bin => client_bin
      )
    end

    service "chef-client" do
      service_name "com.opscode.chef-client"
      provider Chef::Provider::Service::Macosx
      action :start
    end
  else
    log("Mac OS X Service provider is only supported in Chef >= 0.10.10") { level :warn }
  end

when "bsd"
  log "You specified service style 'bsd'. You will need to set up your rc.local file."
  log "Hint: chef-client -i #{node["chef_client"]["client_interval"]} -s #{node["chef_client"]["client_splay"]}"
else
  log "Could not determine service init style, manual intervention required to start up the chef-client service."
end
