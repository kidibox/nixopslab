# Nixidy environment assembly from den cluster entities.
#
# Iterates over den.clusters to build one nixidy environment per cluster
# per system. Cluster context (domain, networks, nixidy target, storage)
# flows from den.clusters into nixidy modules via the `cluster`
# specialArg, which is then set as config.cluster in the cluster config
# module (clusters/<name>.nix).
#
# Each nixidy env includes:
#   1. Shared nixidy app modules (apps/)
#   2. Cluster config module (clusters/<name>.nix) — reads cluster
#     specialArg, sets nixidy.target and networking.domain
{ inputs, config, self, ... }:
let
  clusterNames = builtins.attrNames config.den.clusters;
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
            extraSpecialArgs = {
              cluster = config.den.clusters.${clusterName};
            };
          };
        }) clusterNames
      );
    }) config.systems
  );
}