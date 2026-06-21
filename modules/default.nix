# Shared application modules.
#
# Each submodule defines a nixidy application and any supporting
# resources (network policies, secrets, etc.).
#
# Application modules can read `config.cluster.*` for environment-
# specific values set in clusters/<env>.nix.
{ lib, ... }:
{
  imports = [
    ./argocd
  ];

  options = with lib; {
    networking.domain = mkOption {
      type = types.str;
      default = "home.arpa";
      description = "Base domain for ingress and services";
    };
  };
}