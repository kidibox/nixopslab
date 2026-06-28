# Cilium CNI — kube-proxy replacement, VXLAN tunnel, cluster-pool IPAM.
{ ... }:
{
  den.aspects.cilium = {
    k8s-manifests = { cluster, charts, ... }:
      let
        podCIDR = cluster.networks.pods.cidr;
      in
      {
        applications.cilium = {
          namespace = "kube-system";

          annotations."argocd.argoproj.io/sync-wave" = "-2";

          syncPolicy = {
            syncOptions = {
              serverSideApply = true;
              applyOutOfSyncOnly = true;
            };
          };

          compareOptions.serverSideDiff = true;

          helm.releases.cilium = {
            chart = charts.cilium.cilium;

            values = {
              namespaceOverride = "kube-system";

              kubeProxyReplacement = true;
              k8sServiceHost = "localhost";
              k8sServicePort = 6443;

              # Excludes pod CIDR from iptables masquerade even in tunnel mode,
              # and anchors BPF routing decisions to the correct range.
              ipv4NativeRoutingCIDR = podCIDR;

              # cluster-pool: Cilium owns the CIDR allocation, no race with
              # k3s's node IPAM controller setting spec.podCIDR.
              ipam = {
                mode = "cluster-pool";
                operator = {
                  clusterPoolIPv4PodCIDRList = [ podCIDR ];
                  clusterPoolIPv4MaskSize = 24;
                };
              };

              bgpControlPlane.enabled = true;

              # BPF-based masquerade — more reliable than iptables in a
              # kube-proxy-free environment.
              bpf.masquerade = true;

              hubble = {
                enabled = false;
                relay.enabled = false;
                ui.enabled = false;
              };

              operator = {
                enabled = true;
                replicas = 1;
              };
            };
          };
        };
      };
  };
}
