# k3s-prod cluster entity and aspect.
#
# Registers the k3s-prod cluster in den.clusters (entity data) and
# den.aspects.k3s-prod (bridge module + app includes).
#
# Domain TLD is sourced from den.environments.${c.environment} so that
# the environment entity is the single source of truth.
#
# The bridge aspect (den.aspects.k3s-prod) provides:
# - A k8s-manifests module that maps cluster and environment data into
#   nixidy config (config.cluster.*, config.environment.*, config.nixidy.target)
# - includes listing the k8s service aspects to deploy
{ den, ... }:
let
  c = den.clusters.k3s-prod;
  e = den.environments.${c.environment};
in
{
  den.clusters.k3s-prod = {
    environment = "prod";

    networks = {
      pods = {
        cidr = "10.42.0.0/16";
        description = "Pod CIDR (k3s default)";
      };

      services = {
        cidr = "10.43.0.0/16";
        description = "Service CIDR (k3s default)";
      };
    };

    nixidy = {
      repository = "https://github.com/kid/nixopslab.git";
      branch = "main";
      rootPath = "manifests/prod";
    };

    storage = {
      nfs = {
        server = null;
        share = null;
      };
    };
  };

  # Cluster aspect — bridge module + app includes.
  #
  # The k8s-manifests bridge maps environment domain and cluster networks
  # into nixidy's config. Collected by den.lib.aspects.resolve alongside
  # application modules via the includes chain.
  den.aspects.k3s-prod = {
    k8s-manifests = { ... }: {
      config = {
        cluster = {
          domain = e.domain;
          networks = {
            podCIDR = c.networks.pods.cidr;
            serviceCIDR = c.networks.services.cidr;
          };
        };

        environment.domain = e.domain;

        nixidy.target = {
          inherit (c.nixidy) repository branch rootPath;
        };

        networking.domain = e.domain;
      };
    };

    includes = with den.aspects; [
      nixidy
      cilium
      argocd
    ];
  };
}
