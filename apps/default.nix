# Shared nixidy application module options.
# This module is imported into each nixidy environment (not flake-parts).
# It provides shared options that all application modules can read.
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