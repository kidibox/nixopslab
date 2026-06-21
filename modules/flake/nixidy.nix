# nixidy environment definitions per cluster.
#
# Each cluster gets its own nixidy environment built from:
#   1. Shared nixidy app modules (apps/)
#   2. Cluster config (clusters/<name>.nix)
#
# Cluster context (domain, networks, storage) flows into app modules
# via nixidy module options (config.cluster.*) defined in clusters/.
{ inputs, config, self, ... }:
let
  clusterNames = [ "prod" ];
in
{
  flake.nixidyEnvs = builtins.listToAttrs (
    map (system: {
      name = system;
      value = builtins.listToAttrs (
        map (clusterName: {
          name = clusterName;
          value = inputs.nixidy.lib.mkEnv {
            pkgs = import inputs.nixpkgs { inherit system; };
            charts = inputs.nixhelm.chartsDerivations.${system};
            modules = [
              "${self}/apps"
              "${self}/clusters/${clusterName}.nix"
            ];
          };
        }) clusterNames
      );
    }) config.systems
  );
}