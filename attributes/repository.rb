case node['platform_family']
when "debian"
  default["chef_client"]["repository_style"] = "apt"
end
