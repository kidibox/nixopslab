# flake-file module: declares all inputs and flake metadata.
# flake-file auto-generates flake.nix from these options.
# Run `nix run .#write-flake` after changing inputs.
{ lib, ... }:
{
  flake-file = {
    description = "Kubernetes cluster manifests managed with nixidy";

    nixConfig = {
      extra-experimental-features = [
        "nix-command"
        "flakes"
      ];
      extra-substituters = [
        "https://nix-community.cachix.org"
      ];
      extra-trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };

    inputs = {
      nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

      den.url = "github:denful/den";

      files.url = "github:sini/files";

      flake-parts = {
        url = "github:hercules-ci/flake-parts";
        inputs.nixpkgs-lib.follows = "nixpkgs";
      };

      # Use sini's fork of flake-file (has improvements over upstream vic/flake-file)
      flake-file.url = "github:sini/flake-file";

      nixidy = {
        url = "github:arnarg/nixidy";
        inputs.nixpkgs.follows = "nixpkgs";
      };

      nixhelm = {
        url = "github:farcaller/nixhelm";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    };
  };
}