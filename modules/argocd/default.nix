# ArgoCD — GitOps controller.
#
# Provides the core application controller, repo server, and UI.
# All other applications are managed as ArgoCD Applications so
# ArgoCD is the first thing deployed on a fresh cluster.
#
# Bootstrap: `nixidy bootstrap .#prod | kubectl apply -f -`
{
  lib,
  config,
  charts,
  ...
}:
let
  namespace = "argocd";

  domain = "argocd.${config.networking.domain}";
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

  config = lib.mkIf config.services.argocd.enable {
    applications.argocd = {
      inherit namespace;

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
}