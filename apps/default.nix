# Shared nixidy application module options.
# This module is imported into each nixidy environment (not flake-parts).
# It provides shared options that all application modules can read.
#
# Application modules are collected from den aspects via k8s-manifests
# (see modules/flake/nixidy.nix). The apps/ directory contains those
# k8s-manifests functions.
{ lib, ... }:
{
  options = with lib; {
    networking.domain = mkOption {
      type = types.str;
      default = "home.arpa";
      description = "Base domain for ingress and services";
    };
  };
}