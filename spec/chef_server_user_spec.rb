require 'spec_helper'

describe 'test::chef_server_user' do
  {
    'default action' => {
    },
    
    'no params' => {
      'action' => :create,
      'first_name' => nil,
      'last_name' => nil,
      'email' => nil,
    },

    'no first' => {
      'action' => :create,
      'first_name' => nil,
      'last_name' => 'last',
      'email' => 'nobody@example.com',
    },

    'no last' => {
      'action' => :create,
      'first_name' => 'first',
      'last_name' => nil,
      'email' => 'nobody@example.com',
    },

    'no email' => {
      'action' => :create,
      'first_name' => 'first',
      'last_name' => 'last',
      'email' => nil,
    },
  }.each do |desc, attrs|
    context desc do
      cached(:subject) do
        ChefSpec::SoloRunner.new(step_into: :chef_server_user) do |node|
          node.default['test'] = attrs
        end.converge(described_recipe)
      end

      it 'does not converge' do
        expect { subject }.to raise_error(Chef::Exceptions::ValidationFailed)
      end
    end
  end

  {
    ':create' => {
      'action' => :create,
      'first_name' => 'first',
      'last_name' => 'last',
      'email' => 'nobody@example.com',
    },

    ':delete' => {
      'action' => :delete,
    }
  }.each do |desc, attrs|
    context desc do
      cached(:subject) do
        ChefSpec::SoloRunner.new(step_into: :chef_server_user) do |node|
          node.default['test'] = attrs
          node.run_state['chef-server'] = {
            'orgs' => {},
            'users' => {},
            'server-admins' => [],
          }
        end.converge(described_recipe)
      end
    
      it 'converges' do
        expect { subject }.not_to raise_error
      end
    end
  end
end
