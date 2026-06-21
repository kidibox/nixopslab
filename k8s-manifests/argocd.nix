# ArgoCD — k8s-manifests factory.
#
# Returns a nixidy module that configures ArgoCD.
# Called with cluster context: { domain, networks, name, ... }
#
# This is the k8s-manifests quirk for den.aspects.argocd.
# Cluster context is passed by the nixidy env assembler
# (modules/flake/nixidy.nix) from den.clusters.<name>.
{ cluster, ... }:
let
  domain = "argocd.${cluster.domain}";
in
{ config, charts, lib, ... }:
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

    networking.domain = cluster.domain;
  };
}