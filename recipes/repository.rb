case node["chef_client"]["repository_style"]
when "apt"
  include_recipe "apt"
  
  apt_repository "opscode" do
    uri "http://apt.opscode.com"
    distribution "#{node['lsb']['codename']}-0.10"
    components ["main"]
    key "http://apt.opscode.com/packages@opscode.com.gpg.key"
  end
end

