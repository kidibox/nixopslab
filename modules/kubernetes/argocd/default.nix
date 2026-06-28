{ lib, ... }:
let
  inherit (lib) types mkOption mkIf;
in
{
  den.classes.k8s-manifests.description = "Kubernetes manifests collected for nixidy";

  den.aspects.argocd = {
    service-domains = [ "argocd" ];

    k8s-manifests = { environment, config, charts, lib, pkgs, ... }:
    let
      domain = "argocd.${environment.domain}";
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
          createNamespace = true;

          kustomize.applications.argocd = {
            namespace = "argocd";
            kustomization = {
              src = pkgs.fetchFromGitHub {
                owner = "argoproj";
                repo = "argo-cd";
                rev = "v3.4.4";
                hash = "sha256-GaY4Cw/LlSwy35umbB4epXt6ev8ya19UjHRwhDwilqU=";
                # hash = lib.fakeSha256;
              };
              path = "manifests/core-install";
            };
          };

          # helm.releases.argocd = {
          #   chart = charts.argoproj.argo-cd;
          #
          #   values = lib.attrsets.recursiveUpdate {
          #     server = {
          #       insecure = true;
          #
          #       dnsConfig.options = [
          #         {
          #           name = "ndots";
          #           value = "1";
          #         }
          #       ];
          #     };
          #
          #     repoServer = {
          #       dnsConfig.options = [
          #         {
          #           name = "ndots";
          #           value = "1";
          #         }
          #       ];
          #     };
          #
          #     redis.enabled = true;
          #     redis-ha.enabled = false;
          #     redisSecretInit.enabled = false;
          #
          #
          #     controller.replicas = 1;
          #     applicationSet.replicas = 1;
          #     notifications.enabled = false;
          #     dex.enabled = false;
          #
          #     configs = {
          #       params."server.insecure" = true;
          #     };
          #
          #     global.networkPolicy.create = true;
          #   } config.services.argocd.values;
          # };

          # resources = {
          #   # Allow ingress traffic to argocd-server.
          #   networkPolicies.allow-ingress.spec = {
          #     podSelector.matchLabels."app.kubernetes.io/name" = "argocd-server";
          #     policyTypes = [ "Ingress" ];
          #     ingress = [
          #       {
          #         from = [
          #           {
          #             namespaceSelector.matchLabels."kubernetes.io/metadata.name" = "argocd";
          #             podSelector.matchLabels."app.kubernetes.io/name" = "argocd-server";
          #           }
          #         ];
          #         ports = [
          #           {
          #             protocol = "TCP";
          #             port = 8080;
          #           }
          #         ];
          #       }
          #     ];
          #   };
          # };
        };
      };
    };
  };
}
