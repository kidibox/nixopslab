# k3s-node1 — libvirt VM on the adm VLAN.
# just up k3s-node1   →  build image, define in libvirt, start
# just rebuild k3s-node1  →  rebuild image, rebase overlay
{ den, ... }:
{
  den.hosts.x86_64-linux.k3s-node1 = { };

  den.aspects.k3s-node1.nixos = { lib, config, pkgs, modulesPath, ... }: {
    imports = [ "${modulesPath}/profiles/qemu-guest.nix" ];

    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      autoResize = true;
      fsType = "ext4";
    };

    boot.growPartition = true;
    boot.kernelParams = [ "console=ttyS0" ];
    boot.loader.grub.device = lib.mkDefault "/dev/vda";
    boot.loader.timeout = 0;

    system.build.qcow = import "${modulesPath}/../lib/make-disk-image.nix" {
      inherit lib config pkgs;
      diskSize = "auto";
      format = "qcow2";
      partitionTableType = "hybrid";
    };

    networking.hostName = "k3s-node1";
    networking.useDHCP = false;
    networking.useNetworkd = true;

    systemd.network.networks."10-eth" = {
      matchConfig.Name = "en*";
      networkConfig.DHCP = "ipv4";
    };

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
