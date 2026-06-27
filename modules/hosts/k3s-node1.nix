# k3s-node1 — libvirt VM on the adm VLAN.
#
# Build disk image:
#   just build k3s-node1
#
# First-time setup and launch:
#   just up k3s-node1 02:00:00:00:01:01
#
# Subsequent launches (after define):
#   just start k3s-node1
#
# See the justfile for the full workflow.
{ den, inputs, ... }:
{
  den.hosts.x86_64-linux.k3s-node1 = { };

  den.aspects.k3s-node1.nixos = { ... }: {
    imports = [
      inputs.nixos-generators.nixosModules.qcow
    ];

    networking.hostName = "k3s-node1";
    networking.useDHCP = true;

    time.timeZone = "UTC";
    i18n.defaultLocale = "en_US.UTF-8";

    users.mutableUsers = false;
    security.sudo.enable = true;

    services.openssh.enable = true;

    system.stateVersion = "25.05";
  };

  den.aspects.k3s-node1.includes = [
    den.aspects.k3s-server
    den.aspects.kid
  ];
}
