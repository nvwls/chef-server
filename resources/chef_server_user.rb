#
# Author:: Nathan Cerny <ncerny@chef.io>
# Author:: Joseph J. Nuspl Jr. <nuspl@nvwls.com>
#
# Cookbook:: chef-server
# Resource:: chef_server_user
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

# Derived from the chef_user resource in chef-ingredient

provides :chef_server_user
resource_name :chef_server_user

property :username, String, name_property: true
property :first_name, String
property :last_name, String
property :email, String
property :password, String
property :key_path, String
property :serveradmin, [true, false], default: false

action_class do
  def check_resource_semantics!
    if action == :create
      %i(first_name last_name email).each do |prop|
        next if property_is_set?(prop)
        raise Chef::Exceptions::ValidationFailed, "#{prop} is required"
      end
    end
  end
end

load_current_value do
  node.run_state['chef-server'] ||= ChefServerCookbook.run_state
  current_value_does_not_exist! unless node.run_state['chef-server']['users'].include?(username)
end

action :create do
  directory '/etc/opscode/users' do
    owner 'root'
    group 'root'
    mode '0700'
    recursive true
  end

  usr = new_resource.username
  key = (property_is_set?(:key_path) ? new_resource.key_path : "/etc/opscode/users/#{usr}.pem")
  password = (property_is_set?(:password) ? new_resource.password : SecureRandom.base64(36))

  execute "user-create #{usr}" do
    sensitive true
    retries 3
    command "chef-server-ctl user-create #{usr} #{new_resource.first_name} #{new_resource.last_name} #{new_resource.email} #{password} -f #{key}"
    not_if { node.run_state['chef-server']['users'].include?(usr) }
  end

  ruby_block "user-created #{usr}" do
    block do
      node.run_state['chef-server']['users'][usr] = ChefServerCookbook.load_user(usr)
    end
    not_if { node.run_state['chef-server']['users'].include?(usr) }
  end

  serveradmin = node.run_state['chef-server']['server-admins'].include?(usr)
  if new_resource.serveradmin
    execute "grant-server-admin #{usr}" do
      command "chef-server-ctl grant-server-admin-permissions #{usr}"
      not_if { serveradmin }
    end

    ruby_block "granted-server-admin #{usr}" do
      block do
        node.run_state['chef-server']['server-admins'] << usr
      end
      not_if { serveradmin }
    end
  else
    execute "remove-server-admin #{usr}" do
      command "chef-server-ctl remove-server-admin-permissions #{usr}"
      only_if { serveradmin }
    end

    ruby_block "removed-server-admin #{usr}" do
      block do
        node.run_state['chef-server']['server-admins'].delete(usr)
      end
      only_if { serveradmin }
    end
  end
end

action :delete do
  usr = new_resource.username

  execute "user-delete #{usr}" do
    retries 3
    command "chef-server-ctl user-delete #{usr} --yes --remove-from-admin-groups"
    only_if { node.run_state['chef-server']['users'].include?(usr) }
  end

  ruby_block "user-deleted #{usr}" do
    block do
      node.run_state['chef-server']['users'].delete(usr)
      node.run_state['chef-server']['server-admins'].delete(usr)
    end
    only_if { node.run_state['chef-server']['users'].include?(usr) }
  end
end
