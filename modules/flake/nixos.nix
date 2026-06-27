# NixOS configuration assembly from den host entities.
#
# Iterates over den.hosts to build one nixosConfiguration per host.
# All nixos modules are collected from the host's aspect tree using
# den.lib.aspects.resolve — the same mechanism nixidy.nix uses for
# k8s-manifests.
#
# Data flow:
#   den.aspects.<name>.nixos  →  den.lib.aspects.resolve  →  nixosSystem
{ inputs, config, lib, den, ... }:
let
  hosts = config.den.hosts or { };

  nixosModulesFor = hostName:
    let
      hostAspect = config.den.aspects.${hostName} or null;
    in
    if hostAspect != null then
      (den.lib.aspects.resolve "nixos" hostAspect).imports or [ ]
    else
      [ ];
in
{
  flake.nixosConfigurations = lib.concatMapAttrs (
    system: hostsBySystem:
    lib.mapAttrs (hostName: _:
      inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = nixosModulesFor hostName;
      }
    ) hostsBySystem
  ) hosts;
}
