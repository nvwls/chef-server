require 'resolv'

describe package('chef-server-core') do
  it { should be_installed }
end

describe file('/etc/opscode/chef-server.rb') do
  its(:content) { should match(/^topology "standalone"$/) }
  its(:content) { should match(/^api_fqdn ".+"$/) }
end

describe file('/etc/hosts') do
  its(:content) { should match(/127.0.0.1 chef-server-tk.example.com/) }
end

describe command('chef-server-ctl test') do
  its(:exit_status) { should eq 0 }
end

describe command('chef-server-ctl org-list') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/sample/) }
end

describe command('chef-server-ctl list-user-keys exemplar') do
  its(:exit_status) { should eq 0 }
  its(:stdout) { should match(/name: default\nexpired: false/) }
end

describe command('chef-server-ctl list-server-admins') do
  its(:exit_status) { should eq 0 }
  describe 'stdout' do
    subject { super().stdout.split }
    it { should include 'now' }
    it { should_not include 'was' }
    it { should_not include 'del' }
    it { should_not include 'exemplar' }
  end
end
