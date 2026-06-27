# Fleet policy: environment → cluster scope wiring.
#
# env-to-clusters: for each environment entity, resolve all clusters
# whose `environment` field matches the environment name into the
# environment's scope branch.
#
# This mirrors sini/nix-config's fleet.nix env-to-clusters policy and
# enables aspects to receive `environment` and `cluster` as injected
# scope args when den's full pipeline is used.
{ lib, den, config, ... }:
let
  inherit (den.lib.policy) resolve;
in
{
  den.policies.env-to-clusters =
    { environment, ... }:
    builtins.concatLists (
      lib.mapAttrsToList (_: c:
        lib.optionals (c.environment == environment.name) [
          (resolve.to "cluster" { cluster = c; })
        ]
      ) (config.den.clusters or { })
    );

  den.schema.environment.includes = [
    den.policies.env-to-clusters
  ];
}
