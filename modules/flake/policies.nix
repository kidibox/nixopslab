# Den policies for cluster-to-nixidy routing.
#
# Defines policy wiring for den cluster entities:
# - cluster-aspect: auto-includes the entity-named aspect for each cluster
#   (so den.aspects.argocd is included for a cluster with argocd aspect)
#
# Future policies (when den's pipeline is integrated):
# - cluster-to-nixidy: collect k8s-manifests quirks from resolved aspects
#   and build per-cluster nixidy environments
# - env-to-clusters: resolve clusters into environment scope branches
#
# Currently, nixidy env assembly is done directly in modules/flake/nixidy.nix
# rather than through den's policy/instantiate pipeline, because the full
# pipeline requires den's scope walking and resolution engine.
{ lib, den, ... }:
let
  inherit (den.lib.policy) resolve include;
in
{
  # Auto-include the entity-named aspect for each cluster.
  # If den.aspects.<clusterName> exists, include it in the cluster scope.
  # This mirrors sini/nix-config's cluster-aspect policy.
  den.policies.cluster-aspect =
    { cluster, ... }:
    let
      aspect = den.aspects.${cluster.name} or null;
    in
    lib.optionals (aspect != null) [
      (include aspect)
    ];

  # Wire cluster-aspect into the cluster schema.
  den.schema.cluster.includes = [
    den.policies.cluster-aspect
  ];
}