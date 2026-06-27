# kid user aspect.
#
# Provides a nixos module that creates the kid user with wheel access
# and authorized SSH keys. Include this aspect on any host kid should
# be able to log in to.
{ ... }:
{
  den.aspects.kid = {
    nixos = { ... }: {
      users.users.kid = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAcnmLrPeTJeKsasfU0qn4sP4lBNeOUgRG4iZDS8nyEo kid@vulkan"
        ];
      };
    };
  };
}
