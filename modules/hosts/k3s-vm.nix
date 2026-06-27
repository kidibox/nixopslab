# k3s-vm host entity and aspect.
#
# den.hosts.x86_64-linux.k3s-vm declares the host — den auto-creates
# den.aspects.k3s-vm with the nixos class. We fill in the nixos
# config on the aspect and include the k3s-server aspect.
{ den, lib, ... }:

{
  den.hosts.x86_64-linux.k3s-vm = {};

  # NixOS config on the auto-created aspect.
  den.aspects.k3s-vm.nixos = { pkgs, lib, modulesPath, ... }: {
    imports = [
      (modulesPath + "/profiles/qemu-guest.nix")
    ];

    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;

    fileSystems."/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "ext4";
      autoResize = true;
    };

    networking.hostName = "k3s-vm";
    networking.networkmanager.enable = true;

    time.timeZone = "UTC";
    i18n.defaultLocale = "en_US.UTF-8";

    users.mutableUsers = false;
    security.sudo.enable = true;

    services.openssh.enable = true;

    virtualisation.forwardPorts = [
      { from = "host"; host.port = 2222; guest.port = 22; }
    ];

    system.stateVersion = "25.05";
  };

  den.aspects.k3s-vm.includes = [
    den.aspects.k3s-server
    den.aspects.kid
  ];
}
