chef_server_user 'test' do
  node['test'].each do |config, value|
    send(config.to_sym, value) unless value.nil?
  end
end
