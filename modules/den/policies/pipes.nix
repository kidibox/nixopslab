{ den, ... }:
let
  inherit (den.lib.policy) pipe;
in
{
  den.policies.cluster-collect-k3s-nodes =
    { cluster, ... }:
    [
      (pipe.from "k3s-nodes" [
        (pipe.collectAll ({ host, ... }: true))
      ])
    ];
}
