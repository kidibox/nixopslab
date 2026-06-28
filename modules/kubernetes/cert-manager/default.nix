{ ... }:
{
  den.aspects.cert-manager = {
    k8s-manifests = { charts, ... }: {
      applications.cert-manager = {
        namespace = "cert-manager";
        createNamespace = true;

        annotations."argocd.argoproj.io/sync-wave" = "-1";

        syncPolicy.syncOptions = {
          serverSideApply = true;
          applyOutOfSyncOnly = true;
        };

        helm.releases.cert-manager = {
          chart = charts.jetstack.cert-manager;

          values = {
            crds.enabled = true;
            replicaCount = 1;
          };
        };
      };
    };
  };
}
