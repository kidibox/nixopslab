# Nixidy environment assembly from den cluster entities.
#
# Iterates over den.clusters to build one nixidy environment per cluster
# per system. Cluster context flows from den.clusters into nixidy modules
# via the `cluster` specialArg.
#
# All nixidy modules are collected from the cluster's aspect tree using
# den.lib.aspects.resolve — den's scope engine walks the includes chain
# and collects all k8s-manifests class content. This includes both the
# base module (from den.aspects.nixidy) and application modules (from
# aspects like argocd, cilium, etc.).
#
# The only code here that is not aspect-sourced is the cluster bridge:
# it maps den.clusters.<name> data into nixidy's config (config.cluster,
# config.nixidy.target, config.networking.domain). This bridge is the
# essential seam where den entity data enters the nixidy module system.
{ inputs, config, lib, den, ... }:
let
  clusterNames = builtins.attrNames config.den.clusters;

  # Collect all k8s-manifests modules for a cluster via den's pipeline.
  # Walks the cluster's aspect includes tree depth-first.
  k8sManifestsFor = clusterName:
    let
      clusterAspect = config.den.aspects.${clusterName} or null;
    in
    if clusterAspect != null then
      (den.lib.aspects.resolve "k8s-manifests" clusterAspect).imports or [ ]
    else
      [ ];

  # Bridge module: maps den.clusters.<name> into nixidy's module config.
  # This is the only non-aspect module — it feeds cluster-specific data
  # (domain, networks, nixidy target) from den's entity registry into
  # the nixidy module system where aspects can read config.cluster.*.
  clusterBridge = clusterName:
    let
      c = config.den.clusters.${clusterName};
    in
    { lib, ... }: {
      config = {
        cluster = {
          inherit (c) domain;
          networks = {
            podCIDR = c.networks.pods.cidr;
            serviceCIDR = c.networks.services.cidr;
          };
        };

        nixidy.target = {
          inherit (c.nixidy) repository branch rootPath;
        };

        networking.domain = c.domain;
      };
    };
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
              (clusterBridge clusterName)
            ] ++ k8sManifestsFor clusterName;
          };
        }) clusterNames
      );
    }) config.systems
  );
}