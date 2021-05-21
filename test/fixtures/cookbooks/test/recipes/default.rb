node.default['chef-server']['api_fqdn'] = 'chef-server-tk.example.com'

apt_update 'update'

include_recipe 'chef-server::default' if node.read('packages', 'chef-server-core').nil?
include_recipe 'test::post-install'
