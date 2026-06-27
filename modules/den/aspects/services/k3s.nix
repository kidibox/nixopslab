# k3s server aspect.
#
# Provides a nixos module that configures k3s as a single-node
# server (clusterInit enables embedded datastore). CIDRs are read
# from den.clusters.<clusterName>.networks.{pods,services}.cidr so the
# cluster entity is the single source of truth.
#
# Emits k3s-nodes quirk for BGP peer discovery.
{ den, config, lib, ... }:
let
  clusters = config.den.clusters or { };
in
{
  den.classes.nixos = {
    description = "NixOS system configuration modules";
  };

  den.aspects.k3s-server = {
    # Emit k3s-nodes quirk for each host running k3s.
    # Collected cluster-wide by cluster-collect-k3s-nodes policy.
    k3s-nodes = { host, ... }: {
      hostname = host.name;
      localASN = host.bgp.localAsn or null;
    };

    nixos = { host, ... }:
    let
      clusterName = host.k3s.clusterName or "k3s-prod";
      cluster = clusters.${clusterName};
      podCIDR = cluster.networks.pods.cidr;
      serviceCIDR = cluster.networks.services.cidr;
    in
    {
      # k3s — single-node server (clusterInit enables embedded datastore)
      # Flannel and kube-proxy are disabled; Cilium handles both.
      services.k3s = {
        enable = true;
        role = "server";
        clusterInit = true;
        extraFlags = lib.concatStringsSep " " [
          "--flannel-backend=none"
          "--disable-network-policy"
          "--disable-kube-proxy"
          "--cluster-cidr=${podCIDR}"
          "--service-cidr=${serviceCIDR}"
        ];
      };

      # Allow k3s API port through firewall
      networking.firewall.allowedTCPPorts = [ 6443 ];
    };
  };
}
