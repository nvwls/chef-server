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

    def load_org_admins(org)
      res = {}

      obj = pivotal.get("organizations/#{org}/groups/admins")
      obj['users'].each do |id|
        next if id == 'pivotal'
        res[id] = :user
      end

      obj['clients'].each do |id|
        res[id] = :client
      end

      res
    end

    def load_org_users(org)
      res = {}

      all = pivotal.get("organizations/#{org}/users")
      all.each do |it|
        usr = it['user']['username']
        res[usr] = :user
      end

      res
    end

    def load_org(org)
      obj = pivotal.get("organizations/#{org}")

      {
        'full_name' => obj['full_name'],
        'admins' => load_org_admins(org),
        'users' => load_org_users(org),
      }
    end

    def load_orgs
      res = {}

      all = pivotal.get('organizations').keys.sort
      all.each do |org|
        res[org] = load_org(org)
      end

      res
    end

    def load_user(usr)
      obj = pivotal.get("users/#{usr}")
      res = {
        'first_name' => obj['first_name'],
        'last_name' => obj['last_name'],
        'email' => obj['email'],
        'keys' => {},
      }

      pub = obj['public_key']
      if pub.nil?
        all = pivotal.get("users/#{usr}/keys")
        all.each do |it|
          key = it['name']
          obj = pivotal.get("users/#{usr}/keys/#{key}")

          res['keys'][key] = obj['public_key'].strip
        end
      else
        res['keys']['default'] = pub.strip
      end

      res
    end

    def load_users
      res = {}

      all = pivotal.get('users').keys.sort
      all.each do |usr|
        res[usr] = load_user(usr)
      end

      res
    end

    def load_server_admins
      shell_out('chef-server-ctl list-server-admins')
        .stdout
        .split
        .reject { |it| it == 'pivotal' }
    end
  end
end
