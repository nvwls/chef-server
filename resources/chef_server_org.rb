#
# Author:: Joseph J. Nuspl Jr. <nuspl@nvwls.com>
# Author:: Nathan Cerny <ncerny@chef.io>
#
# Cookbook:: chef-ingredient
# Resource:: chef_org
#
# Copyright:: 2017-2019, Chef Software, Inc.
# Copyright:: 2020-2021, Joseph J. Nuspl Jr.
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

# Derived from the chef_org resource in chef-ingredient

provides :chef_server_org
resource_name :chef_server_org

property :org, String, name_property: true
property :org_full_name, String
property :admins, Array
property :users, Array, default: []
property :remove_users, Array, default: []
property :key_path, String

load_current_value do
  node.run_state['chef-server'] ||= ChefServerCookbook.run_state
  current_value_does_not_exist! unless node.run_state['chef-server']['orgs'].include?(org)
end

action :create do
  org = new_resource.org

  directory '/etc/opscode/orgs' do
    owner 'root'
    group 'root'
    mode '0700'
    recursive true
  end

  org_full_name = (property_is_set?(:org_full_name) ? new_resource.org_full_name : org)
  key = (property_is_set?(:key_path) ? new_resource.key_path : "/etc/opscode/orgs/#{org}-validation.pem")
  execute "org-create #{org}" do
    retries 10
    command "chef-server-ctl org-create #{org} '#{org_full_name}' -f #{key}"
    not_if { node.run_state['chef-server']['orgs'].include?(org) }
  end

  ruby_block "org-created #{org}" do
    block do
      node.run_state['chef-server']['orgs'][org] = ChefServerCookbook.load_org(org)
    end
    not_if { node.run_state['chef-server']['orgs'].include?(org) }
  end

  new_resource.users.each do |usr|
    execute "org-user-add #{org} #{usr}" do
      command "chef-server-ctl org-user-add #{org} #{usr}"
      only_if { node.run_state['chef-server']['users'].include?(usr) }
      not_if { node.run_state['chef-server']['orgs'][org]['users'].include?(usr) }
      notifies :run, "ruby_block[org-created #{org}", :delayed
    end
  end

  new_resource.admins.each do |user|
    execute "add-admin-#{user}-org-#{new_resource.org}" do
      command "chef-server-ctl org-user-add --admin #{org} #{usr}"
      only_if { node.run_state['chef-server']['users'].include?(usr) }
      not_if { node.run_state['chef-server']['orgs'][org]['users'].include?(usr) }
      notifies :run, "ruby_block[org-created #{org}", :delayed
    end
  end

  new_resource.remove_users.each do |usr|
    execute "org-user-remove #{org} #{usr}" do
      command "chef-server-ctl org-user-remove #{org} #{usr}"
      only_if { node.run_state['chef-server']['orgs'][org]['users'].include?(usr) }
      notifies :run, "ruby_block[org-created #{org}", :delayed
    end
  end
end
