# Den policies for cluster-scope routing.
#
# flake-to-clusters:           fan-out from flake entity to each den.clusters entry
# cluster-aspect:              auto-include the entity-named aspect per cluster
# cluster-collect-k3s-nodes:   collect k3s-nodes quirk into cluster scope
# cluster-to-nixidy:           instantiate k8s-manifests modules into nixidyEnvs
#
# All cluster policies are wired into den.schema.cluster.includes so they fire
# for every cluster entity. flake-to-clusters fans out to all clusters.
{ lib, den, config, inputs, self, withSystem, ... }:
let
  inherit (den.lib.policy) include resolve;
  clusters = config.den.clusters;
in
{
  # Fan out from the flake entity to each cluster entity.
  # This causes den to process every cluster via den.schema.cluster.includes.
  den.policies.flake-to-clusters =
    _:
    map (clusterName:
      resolve.to "cluster" {
        cluster = clusters.${clusterName} // { name = clusterName; };
      }
    ) (builtins.attrNames clusters);

  den.policies.cluster-aspect =
    { cluster, ... }:
    let
      aspect = den.aspects.${cluster.name} or null;
    in
    lib.optionals (aspect != null) [
      (include aspect)
    ];

  # Instantiate k8s-manifests modules into flake.nixidyEnvs.<system>.<clusterName>.
  # den prepends "flake" to intoAttr, so intoAttr = ["nixidyEnvs" ...] becomes
  # config.flake.nixidyEnvs.*, i.e. self.nixidyEnvs.*.
  #
  # lib.unique: config.systems carries duplicates inside the den pipeline
  # when hosts append their systems; map must dedupe or den warns on collisions.
  den.policies.cluster-to-nixidy =
    { cluster, ... }:
    map (system:
      den.lib.policy.instantiate {
        inherit (cluster) name;
        class = "k8s-manifests";
        intoAttr = [
          "nixidyEnvs"
          system
          cluster.name
        ];
        instantiate = { modules, ... }:
          withSystem system ({ pkgs, ... }:
            inputs.nixidy.lib.mkEnv {
              pkgs = pkgs;
              charts = self.chartsDerivations.${system};
              inherit modules;
            });
      }
    ) (lib.unique config.systems);

  den.schema.flake.includes = [ den.policies.flake-to-clusters ];

  den.schema.cluster.includes = [
    den.policies.cluster-to-nixidy
    den.policies.cluster-aspect
    den.policies.cluster-collect-k3s-nodes
  ];
}
