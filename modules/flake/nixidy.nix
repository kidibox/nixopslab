# Nixidy environment assembly from den cluster entities.
#
# Iterates over den.clusters to build one nixidy environment per cluster
# per system. Cluster context flows from den.clusters into nixidy modules
# via the `cluster` specialArg.
#
# k8s-manifests modules are collected from the cluster's aspect tree
# using den.lib.aspects.resolve — den's scope engine walks the includes
# chain and collects all class content matching "k8s-manifests".
#
# Data flow:
#   den.clusters.<name>  →  extraSpecialArgs.cluster  →  config.cluster.*
#   den.aspects.<name>   →  den.lib.aspects.resolve  →  collected nixidy modules
{ inputs, config, self, lib, den, ... }:
let
  clusterNames = builtins.attrNames config.den.clusters;

  # Collect k8s-manifests modules for a cluster via den's pipeline.
  # Walks the cluster's aspect includes tree depth-first, finds all
  # aspects declaring k8s-manifests content, and returns the merged
  # nixidy module list.
  k8sManifestsFor = clusterName:
    let
      clusterAspect = config.den.aspects.${clusterName} or null;
    in
    if clusterAspect != null then
      (den.lib.aspects.resolve "k8s-manifests" clusterAspect).imports or [ ]
    else
      [ ];

  # Build the complete nixidy module list for a cluster:
  # base modules + collected k8s-manifests modules from den aspects.
  mkClusterModules = clusterName:
    [ "${self}/apps" "${self}/clusters/${clusterName}.nix" ] ++ k8sManifestsFor clusterName;
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
            modules = mkClusterModules clusterName;
            extraSpecialArgs = {
              cluster = config.den.clusters.${clusterName};
            };
          };
        }) clusterNames
      );
    }) config.systems
  );
}