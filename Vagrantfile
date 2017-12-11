# -*- mode: ruby -*-
# vi: set ft=ruby :

commands = [
  # hack for https://github.com/mitchellh/vagrant/issues/1303
  "echo 'Defaults env_keep += \"SSH_AUTH_SOCK\"' | " +
  'sudo tee /etc/sudoers.d/agent',
  # ensure we use the local copy of chefctl_hooks.rb
  "echo 'chefctl_hooks_url=file:///vagrant/chefctl_hooks.rb' | " +
  'sudo tee /etc/chef-bootstrap-config',
  # bootstrap chef
  '[ -f /etc/chef/client.rb ] || sudo /vagrant/chef_bootstrap.sh',
  # run chef
  'sudo /usr/local/sbin/chefctl.rb -i',
]
provisioning_script = commands.join('; ')

Vagrant.configure('2') do |config|
  config.ssh.forward_agent = true

  config.vm.box = 'bento/debian-9.2'

  config.vm.define 'test1' do |v|
    v.vm.hostname = 'test1'
    v.vm.provision 'shell', :inline => provisioning_script, :privileged => false
  end
end
