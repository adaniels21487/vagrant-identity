# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/xenial64"

  config.vm.hostname = "identity.example.com"
  config.vm.network "private_network", ip: "192.168.174.91"

  config.vm.provider "virtualbox" do |vb|
    vb.customize [ "modifyvm", :id, "--uartmode1", "disconnected" ]
    vb.linked_clone = true
    vb.memory = "1024"
  end

  config.vm.provision "shell", path: "identity.sh"
end
