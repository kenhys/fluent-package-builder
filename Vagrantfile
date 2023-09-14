# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  vms = [
    {
      :id => "debian-bullseye",
      :box => "debian/bullseye64",
    },
    {
      :id => "ubuntu-focal",
      :box => "generic/ubuntu2004",
    },
    {
      :id => "ubuntu-jammy",
      :box => "generic/ubuntu2204",
    },
    {
      :id => "centos-7",
      :box => "centos/7",
    },
    {
      :id => "rockylinux-8",
      :box => "rockylinux/8",
    },
    {
      :id => "almalinux-9",
      :box => "almalinux/9",
    },
    {
      :id => "amazonlinux-2",
      :box => "bento/amazonlinux-2",
    },
  ]

  n_cpus = ENV["BOX_N_CPUS"]&.to_i || 2
  memory = ENV["BOX_MEMORY"]&.to_i || 2048
  vms.each_with_index do |vm, idx|
    id = vm[:id]
    box = vm[:box] || id
    config.vm.define(id) do |node|
      node.vm.box = box
      node.vm.provider("virtualbox") do |virtual_box|
        virtual_box.cpus = n_cpus if n_cpus
        virtual_box.memory = memory if memory
      end
      node.vm.provider("libvirt") do |libvirt|
        libvirt.cpus = n_cpus if n_cpus
        libvirt.memory = memory if memory
      end
    end
    config.vm.synced_folder "./", "/vagrant", type: "rsync"
  end
end
