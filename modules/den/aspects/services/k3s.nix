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

    nixos = { host, pkgs, ... }:
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
          "--disable=coredns"
          "--cluster-cidr=${podCIDR}"
          "--service-cidr=${serviceCIDR}"
        ];
      };

      # Cilium owns all pod/node firewalling; the NixOS host firewall conflicts
      # with Cilium's BPF datapath (outgoing traffic bypasses iptables OUTPUT so
      # conntrack never records it, then incoming replies hit nixos-fw with no
      # RELATED/ESTABLISHED entry and are refused).
      networking.firewall.enable = lib.mkForce false;

      # Keep the kernel on the nftables backend. Without this, k3s's bundled
      # iptables binary writes legacy-backend tables; Cilium's iptables-nft
      # wrapper then rejects them ("table mangle is incompatible, use nft tool")
      # and crashes the agent.
      networking.nftables.enable = true;

      boot.kernelModules = [
        "br_netfilter" # bridge → iptables/nftables visibility (required by Cilium)
        "overlay"      # overlayfs for containerd image layers
        "ip_vs"        # IPVS modules for kube-proxy replacement
        "ip_vs_rr"
        "ip_vs_wrr"
        "ip_vs_sh"
      ];

      boot.kernel.sysctl = {
        "net.bridge.bridge-nf-call-iptables" = 1;
        "net.bridge.bridge-nf-call-ip6tables" = 1;
        "net.core.bpf_jit_enable" = 1;
        "net.core.bpf_jit_harden" = 0;
      };

      # Provide the host iptables-nft + nft on PATH so k3s, kubelet, and
      # Cilium all use the same nft backend for iptables canaries.
      environment.systemPackages = [ pkgs.iptables pkgs.nftables ];
    };
  };
}
