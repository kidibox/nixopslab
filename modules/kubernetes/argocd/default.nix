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
                hash = "sha256-I3udVhmPpOA2Lf1mkJqG+d+mGpfM16HIKBkEnTiAw0c=";
              };
              path = "manifests/core-install";
            };
          };

          resources.appProjects.default.spec = {
            clusterResourceWhitelist = [{ group = "*"; kind = "*"; }];
            destinations = [{ namespace = "*"; server = "*"; }];
            sourceRepos = [ "*" ];
          };
        };
      };
    };
  };
}
