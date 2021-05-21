require 'chef/mixin/shell_out'

module ChefServerCookbook
  module Helpers
    def api_fqdn_available?
      return false if node['chef-server'].nil?
      return false if node['chef-server']['api_fqdn'].nil?
      !node['chef-server']['api_fqdn'].empty?
    end

    def api_fqdn_resolves?
      ChefIngredientCookbook::Helpers.fqdn_resolves?(
        node['chef-server']['api_fqdn']
      )
    end

    def repair_api_fqdn
      fe = Chef::Util::FileEdit.new('/etc/hosts')
      fe.insert_line_if_no_match(/#{node['chef-server']['api_fqdn']}/,
        "127.0.0.1 #{node['chef-server']['api_fqdn']}")
      fe.write_file
    end
  end

  class << self
    include Chef::Mixin::ShellOut

    def pivotal
      @pivotal ||= begin
        if ::File.read('/etc/opscode/pivotal.rb') =~ /^chef_server_root \"(.*)\"/
          url = Regexp.last_match(1)
        else
          raise 'Could not determine chef_server_root!'
        end

        options = {
          client_name: 'pivotal',
          raw_key: ::File.read('/etc/opscode/pivotal.pem'),
          ssl_verify_mode: :verify_none,
        }

        ::Chef::ServerAPI.new(url, options)
      end
    end

    def run_state
      {
        'orgs' => load_orgs,
        'users' => load_users,
        'server-admins' => load_server_admins,
      }
    end

    def load_org(org)
      obj = pivotal.get("organizations/#{org}")
      warn obj.inspect
      obj = pivotal.get("organizations/#{org}/groups/users")
    end

    def load_orgs
      all = {}

      list = pivotal.get('organizations').keys.sort
      list.each do |org|
        all[org] = load_org(org)
      end

      all
    end

    def load_user(usr)
      obj = pivotal.get("users/#{usr}")

      pub = obj['public_key']
      pub.strip! if pub.is_a?(String)

      pub
    end

    def load_users
      all = {}

      list = pivotal.get('users').keys.sort
      list.each do |usr|
        all[usr] = load_user(usr)
      end

      all
    end

    def load_server_admins
      shell_out('chef-server-ctl list-server-admins')
        .stdout
        .split
        .reject { |it| it == 'pivotal' }
    end
  end
end
