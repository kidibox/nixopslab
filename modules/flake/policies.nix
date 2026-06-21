# Den policies for cluster-to-nixidy routing.
#
# Defines policy wiring for den cluster entities:
# - cluster-aspect: auto-includes the entity-named aspect for each cluster
#   (so den.aspects.prod is auto-included for cluster prod)
#
# nixidy module collection uses den.lib.aspects.resolve in
# modules/flake/nixidy.nix — den's scope engine walks the aspect
# includes chain and collects k8s-manifests class content.
#
# Future when den's full pipeline (instantiate, policy dispatch) is wired:
# - cluster-to-nixidy: use den.lib.policy.instantiate with class k8s-manifests
# - env-to-clusters: resolve clusters into environment scope branches
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