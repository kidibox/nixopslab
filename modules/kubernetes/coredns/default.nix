# CoreDNS — deployed as a GitOps app instead of the k3s built-in addon.
#
# k3s is started with --disable=coredns so it skips its bundled deployment
# but still configures kubelet with --cluster-dns pointing to the 10th address
# in the service CIDR (172.42.0.10 for 172.42.0.0/16). This aspect deploys
# the helm chart with service.clusterIP pinned to that same address via the
# cluster's services.assignments.coredns entry.
{ ... }:
{
  den.aspects.coredns = {
    k8s-manifests = { cluster, charts, ... }:
    let
      dnsIP = cluster.networks.services.assignments.coredns;
    in
    {
      applications.coredns = {
        namespace = "kube-system";

        # Deploy after Cilium (wave -2) but before ArgoCD apps (wave 0).
        annotations."argocd.argoproj.io/sync-wave" = "-1";

        syncPolicy.syncOptions = {
          serverSideApply = true;
          applyOutOfSyncOnly = true;
        };

        helm.releases.coredns = {
          chart = charts.coredns.coredns;

          values = {
            replicaCount = 1;

            service = {
              # kube-dns label makes this service discoverable as the cluster
              # DNS resolver by standard tooling (e.g. ndots search path).
              k8sAppLabelOverride = "kube-dns";
              clusterIP = dnsIP;
            };

            servers = [
              {
                zones = [
                  {
                    zone = ".";
                    # use_tcp causes the chart to emit a TCP/53 port alongside
                    # UDP/53, required for RFC 7766 TCP fallback on large answers.
                    use_tcp = true;
                  }
                ];
                port = 53;
                plugins = [
                  { name = "errors"; }
                  { name = "health"; config.lameduck = "5s"; }
                  { name = "ready"; }
                  {
                    name = "kubernetes";
                    parameters = "cluster.local in-addr.arpa ip6.arpa";
                    config = {
                      pods = "insecure";
                      fallthrough = "in-addr.arpa ip6.arpa";
                      ttl = 30;
                    };
                  }
                  { name = "prometheus"; parameters = "0.0.0.0:9153"; }
                  { name = "forward"; parameters = ". 1.1.1.1 8.8.8.8"; }
                  { name = "cache"; parameters = "30"; }
                  { name = "loop"; }
                  { name = "reload"; }
                  { name = "loadbalance"; }
                ];
              }
            ];
          };
        };
      };
    };
  };
}
