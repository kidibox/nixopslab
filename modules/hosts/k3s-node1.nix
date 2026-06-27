# k3s-node1 host — microvm (qemu) with macvtap on adm VLAN.
#
# Before running, create the macvtap interface on the host (once per session):
#   sudo ip link add link adm name vm-k3s-node1 type macvtap mode bridge
#   sudo ip link set vm-k3s-node1 up
#
# Build and launch:
#   nix build .#nixosConfigurations.k3s-node1.config.microvm.runner.qemu
#   sudo ./result
#
# The VM's NIC appears on the adm VLAN with MAC 02:00:00:00:01:01.
# SSH in via DHCP address:  ssh kid@<vm-ip>
#
# Cleanup after session:
#   sudo ip link delete vm-k3s-node1
{ den, inputs, ... }:
{
  den.hosts.x86_64-linux.k3s-node1 = { };

  den.aspects.k3s-node1.nixos = { ... }: {
    imports = [
      # microvm NixOS module — only needed for microvm hosts
      inputs.microvm.nixosModules.microvm
    ];

    networking.hostName = "k3s-node1";
    networking.useNetworkd = true;

    # macvtap NIC — brought up via DHCP on the adm VLAN
    systemd.network.networks."10-adm" = {
      matchConfig.Name = "vm-adm";
      networkConfig.DHCP = "yes";
    };

    time.timeZone = "UTC";
    i18n.defaultLocale = "en_US.UTF-8";

    users.mutableUsers = false;
    security.sudo.enable = true;

    services.openssh.enable = true;

    microvm = {
      hypervisor = "qemu";
      mem = 2048;
      vcpu = 2;

      interfaces = [
        {
          type = "macvtap";
          id = "vm-k3s-node1";   # macvtap interface name on the host
          mac = "02:00:00:00:01:01";
        }
      ];

      volumes = [
        {
          mountPoint = "/";
          image = "k3s-node1-root.img";
          size = 20480;
        }
      ];
    };

    system.stateVersion = "25.05";
  };

  den.aspects.k3s-node1.includes = [
    den.aspects.k3s-server
    den.aspects.kid
  ];
}
