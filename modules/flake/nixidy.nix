# Nixidy environment assembly from den cluster entities.
#
# Iterates over den.clusters to build one nixidy environment per cluster
# per system. All nixidy modules are collected from the cluster's aspect
# tree using den.lib.aspects.resolve — den's scope engine walks the
# includes chain and collects all k8s-manifests class content.
#
# The cluster data bridge (mapping den.clusters.<name> into nixidy config)
# lives on the cluster aspect itself as a k8s-manifests module, so there
# is zero cluster-specific logic in this file.
#
# Data flow:
#   den.aspects.<name>.k8s-manifests  →  den.lib.aspects.resolve  →  mkEnv
{ inputs, config, lib, self, den, ... }:
let
  clusterNames = builtins.attrNames config.den.clusters;

  # Collect all k8s-manifests modules for a cluster via den's pipeline.
  k8sManifestsFor = clusterName:
    let
      clusterAspect = config.den.aspects.${clusterName} or null;
    in
    if clusterAspect != null then
      (den.lib.aspects.resolve "k8s-manifests" clusterAspect).imports or [ ]
    else
      [ ];
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
            charts = self.chartsDerivations.${system};
            modules = k8sManifestsFor clusterName;
          };
        }) clusterNames
      );
    }) config.systems
  );
}