# Cilium CNI — kube-proxy replacement, VXLAN tunnel.
{ ... }:
{
  den.aspects.cilium = {
    k8s-manifests = { config, charts, lib, ... }: {
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

            ipam.mode = "kubernetes";

            bgpControlPlane.enabled = true;

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
