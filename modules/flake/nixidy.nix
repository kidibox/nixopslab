# Nixidy environment assembly from den cluster entities.
#
# Iterates over den.clusters to build one nixidy environment per cluster
# per system. Cluster context flows from den.clusters into nixidy modules
# via the `cluster` specialArg.
#
# k8s-manifests factories are registered in config.k8s.manifests (a plain
# flake-parts option) and selected per-cluster by the cluster's aspect
# includes chain (den.aspects.<clusterName>.includes).
#
# The aspect includes chain walks den.aspects entries to find which
# k8s-manifests factories to include for each cluster. Factory files
# export curried functions:
#   { cluster, ... }: { config, charts, lib, ... }: { ... }
#
# Data flow:
#   den.clusters.<name>  →  extraSpecialArgs.cluster  →  config.cluster.*
#   den.aspects.<name>   →  includes chain  →  k8s.manifests  →  nixidy modules
{ inputs, config, self, lib, ... }:
let
  clusterNames = builtins.attrNames config.den.clusters;

  # Walk a den aspect's includes chain depth-first to collect
  # k8s-manifests factory names. Returns a list of attribute names
  # from config.k8s.manifests that should be included for this cluster.
  collectAspectNames =
    seen: aspect:
    let
      name = aspect.name or "";
    in
    if name != "" && seen ? ${name} then [ ]
    else
      let
        seen' = seen // lib.optionalAttrs (name != "") { ${name} = true; };
        # Check if this aspect has a k8s-manifests factory registered
        own = if config.k8s.manifests ? ${name} then [ name ] else [ ];
        # Recurse into includes
        fromIncludes = builtins.concatMap (collectAspectNames seen') (aspect.includes or [ ]);
      in
      own ++ fromIncludes;

  # Build the nixidy module list for a cluster.
  # Base modules + k8s-manifests factories called with cluster context.
  mkClusterModules = clusterName:
    let
      cluster = config.den.clusters.${clusterName};
      clusterAspect = config.den.aspects.${clusterName} or null;
      aspectNames = if clusterAspect != null then collectAspectNames {} clusterAspect else [];
      # Import each factory file and call the outer function with cluster context
      ctx = { inherit (cluster) domain networks; name = clusterName; inherit (cluster.nixidy) repository branch rootPath; };
      calledManifests = map (name: (import config.k8s.manifests.${name}) { cluster = ctx; }) aspectNames;
    in
    [ "${self}/apps" "${self}/clusters/${clusterName}.nix" ] ++ calledManifests;
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