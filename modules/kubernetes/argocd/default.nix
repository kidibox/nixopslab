# ArgoCD — den aspect with k8s-manifests content.
#
# Declares the den aspect metadata (service-domains quirk,
# k8s-manifests class) and provides k8s-manifests module
# content directly on the aspect.
#
# The nixidy env assembler collects k8s-manifests modules
# from the cluster aspect tree via den.lib.aspects.resolve.
# Cluster context (domain, etc.) is available via
# config.cluster.* (set by clusters/<name>.nix).
{ lib, ... }:
let
  inherit (lib) types mkOption mkIf;
in
{
  den.classes.k8s-manifests.description = "Kubernetes manifests collected for nixidy";

  den.aspects.argocd = {
    service-domains = [ "argocd" ];

    # k8s-manifests module for nixidy: receives nixidy module args
    # (config, charts, lib, ...) — cluster context via config.cluster.*
    k8s-manifests = { config, charts, lib, ... }:
    let
      domain = "argocd.${config.cluster.domain}";
    in
    {
      options.services.argocd = with lib; {
        enable = mkOption {
          type = types.bool;
          default = true;
        };

        values = mkOption {
          type = types.attrsOf types.anything;
          default = { };
        };
      };

      config = mkIf config.services.argocd.enable {
        applications.argocd = {
          namespace = "argocd";

          helm.releases.argocd = {
            chart = charts.argoproj.argo-cd;

            values = lib.attrsets.recursiveUpdate {
              server = {
                insecure = true;

                dnsConfig.options = [
                  {
                    name = "ndots";
                    value = "1";
                  }
                ];
              };

              repoServer = {
                dnsConfig.options = [
                  {
                    name = "ndots";
                    value = "1";
                  }
                ];
              };

              redis.enabled = true;
              redis-ha.enabled = false;

              controller.replicas = 1;
              applicationSet.replicas = 1;
              notifications.enabled = false;
              dex.enabled = false;

              configs = {
                params."server.insecure" = true;
              };

              global.networkPolicy.create = true;
            } config.services.argocd.values;
          };

          resources = {
            # Allow ingress traffic to argocd-server.
            networkPolicies.allow-ingress.spec = {
              podSelector.matchLabels."app.kubernetes.io/name" = "argocd-server";
              policyTypes = [ "Ingress" ];
              ingress = [
                {
                  from = [
                    {
                      namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "argocd";
                      podSelector.matchLabels."app.kubernetes.io/name" = "argocd-server";
                    }
                  ];
                  ports = [
                    {
                      protocol = "TCP";
                      port = 8080;
                    }
                  ];
                }
              ];
            };
          };
        };
      };
    };
  };
}
