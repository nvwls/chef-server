execute 'setup' do
  command <<EOF
rm -f /tmp/run_state.json

chef-server-ctl user-delete now -y || true
chef-server-ctl user-create now now now now@example.com dontusethisforreal --filename /dev/null

chef-server-ctl user-delete was -y || true
chef-server-ctl user-create was was was was@example.com dontusethisforreal --filename /dev/null
chef-server-ctl grant-server-admin-permissions was

chef-server-ctl user-delete del -y || true
chef-server-ctl user-create del del del del@example.com dontusethisforreal --filename /dev/null
chef-server-ctl grant-server-admin-permissions del
EOF
end

chef_server_user 'now' do
  serveradmin true
  first_name 'Example'
  last_name 'User'
  email "#{name}@example.com"
end

chef_server_user 'was' do
  serveradmin false
  first_name name
  last_name name
  email "#{name}@example.com"
end

chef_server_user 'del' do
  action :delete
end

chef_server_user 'exemplar' do
  first_name 'Example'
  last_name 'User'
  email "#{name}@example.com"
  password 'dontusethisforreal'
  key_path '/tmp/exemplar.key'
end

chef_server_org 'sample' do
  org_full_name 'Sample Size'
  admins []
  # --association_user exemplar
  # --filename /tmp/exemplar.key'
  # not_if 'chef-server-ctl org-list | grep "sample"'
end

file '/tmp/run_state.json' do
  content lazy { JSON.pretty_generate(node.run_state['chef-server']) + "\n" }
end
