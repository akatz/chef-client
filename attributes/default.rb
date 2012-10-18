#
# Author:: Joshua Timberman (<joshua@opscode.com>)
# Author:: Seth Chisamore (<schisamo@opscode.com>)
# Cookbook Name:: chef
# Attributes:: default
#
# Copyright 2008-2011, Opscode, Inc
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

require 'rbconfig'

default["chef_client"]["interval"]    = "1800"
default["chef_client"]["splay"]       = "20"
default["chef_client"]["log_dir"]     = "/var/log/chef"
default["chef_client"]["log_file"]    = nil
default["chef_client"]["log_level"]   = :info
default["chef_client"]["verbose_logging"] = true
default["chef_client"]["conf_dir"]    = "/etc/chef"
default["chef_client"]["bin"]         = "/usr/bin/chef-client"
default["chef_client"]["server_url"]  = "http://localhost:4000"
default["chef_client"]["validation_client_name"] = "chef-validator"
default["chef_client"]["cron"] = { "minute" => "0", "hour" => "*/4", "path" => nil}
default["chef_client"]["environment"] = nil
default["chef_client"]["load_gems"] = {}

case platform
when "arch"
  default["chef_client"]["init_style"]  = "arch"
  default["chef_client"]["run_path"]    = "/var/run/chef"
  default["chef_client"]["cache_path"]  = "/var/cache/chef"
  default["chef_client"]["backup_path"] = "/var/lib/chef"
when "debian","ubuntu","redhat","centos","fedora","suse","scientific","amazon"
  default["chef_client"]["init_style"]  = "init"
  default["chef_client"]["run_path"]    = "/var/run/chef"
  default["chef_client"]["cache_path"]  = "/var/cache/chef"
  default["chef_client"]["backup_path"] = "/var/lib/chef"
when "openbsd","freebsd"
  default["chef_client"]["init_style"]  = "bsd"
  default["chef_client"]["run_path"]    = "/var/run"
  default["chef_client"]["cache_path"]  = "/var/chef/cache"
  default["chef_client"]["backup_path"] = "/var/chef/backup"
when "mac_os_x","mac_os_x_server"
  default["chef_client"]["init_style"]  = "launchd"
  default["chef_client"]["log_dir"]     = "/Library/Logs/Chef"
  # Launchd doesn't use pid files
  default["chef_client"]["run_path"]    = nil
  default["chef_client"]["cache_path"]  = "/Library/Caches/Chef"
  default["chef_client"]["backup_path"] = "/Library/Caches/Chef/Backup"
  # Set to "daemon" if you want chef-client to run
  # continuously with the -d and -s options, or leave
  # as "interval" if you want chef-client to be run
  # periodically by launchd
  default["chef_client"]["launchd_mode"] = "interval"
when "openindiana","opensolaris","nexentacore","solaris2"
  default["chef_client"]["init_style"]  = "smf"
  default["chef_client"]["run_path"]    = "/var/run/chef"
  default["chef_client"]["cache_path"]  = "/var/chef/cache"
  default["chef_client"]["backup_path"] = "/var/chef/backup"
  default["chef_client"]["method_dir"] = "/lib/svc/method"
  default["chef_client"]["bin_dir"] = "/usr/bin"
when "smartos"
  default["chef_client"]["init_style"]  = "smf"
  default["chef_client"]["run_path"]    = "/var/run/chef"
  default["chef_client"]["cache_path"]  = "/var/chef/cache"
  default["chef_client"]["backup_path"] = "/var/chef/backup"
  default["chef_client"]["method_dir"] = "/opt/local/lib/svc/method"
  default["chef_client"]["bin_dir"] = "/opt/local/bin"
when "windows"
  default["chef_client"]["init_style"]  = "win-service"
  default["chef_client"]["conf_dir"]    = "C:/chef"
  default["chef_client"]["run_path"]    = File.join(node["chef_client"]["conf_dir"], "run")
  default["chef_client"]["cache_path"]  = File.join(node["chef_client"]["conf_dir"], "cache")
  default["chef_client"]["backup_path"] = File.join(node["chef_client"]["conf_dir"], "backup")
  default["chef_client"]["log_dir"]     = File.join(node["chef_client"]["conf_dir"], "log")
  default["chef_client"]["bin"]         = "C:/opscode/chef/bin/chef-client"
  #Required for service_manager.rb
  default["chef_client"]["ruby_bin"]    = File.join(RbConfig::CONFIG['bindir'], "ruby.exe")
else
  default["chef_client"]["init_style"]  = "none"
  default["chef_client"]["run_path"]    = "/var/run"
  default["chef_client"]["cache_path"]  = "/var/chef/cache"
  default["chef_client"]["backup_path"] = "/var/chef/backup"
end

if node['chef_packages']['chef'] >= 10.14
  default['chef-client']['fork'] = true
else
  default['chef-client']['fork'] = false
end
