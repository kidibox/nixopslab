# Core flake setup: imports den, files, and flake-file (dendritic).
# Den provides the aspect-oriented module system and auto-imports.
# sini/files provides declarative file management with flake checks.
# flake-file auto-generates flake.nix from module options.
{ inputs, ... }:
{
  imports = [
    inputs.den.flakeModules.default
    inputs.files.flakeModule
    inputs.flake-file.flakeModules.dendritic
  ];

  # Only evaluate on this platform — cross-compilation is not configured.
  flake.systems = [ "x86_64-linux" ];
}