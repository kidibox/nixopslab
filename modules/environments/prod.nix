# Production cluster entity and aspect.
#
# Registers the prod cluster in den.clusters (entity data) and
# den.aspects.prod (which k8s services to include, plus the bridge
# module that maps cluster data into nixidy config).
#
# The cluster entity (den.clusters.prod) is the single source of truth
# for domain, networks, nixidy target, and storage config.
#
# The cluster aspect (den.aspects.prod) provides:
# - A k8s-manifests bridge module that maps den.clusters.prod data
#   into nixidy config (config.cluster.*, config.nixidy.target)
# - includes listing the k8s service aspects to include
#
# This way nixidy.nix needs no hardcoded bridge — the bridge is just
# another k8s-manifests module collected by den.lib.aspects.resolve.
{ den, lib, ... }:
let
  # Capture this cluster's entity data for the bridge module below.
  # Nix's laziness handles this correctly: the thunk is forced only
  # when the k8s-manifests module function evaluates inside nixidy.
  c = den.clusters.prod;
in
{
  den.clusters.prod = {
    domain = "home.arpa";

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
  # The k8s-manifests bridge maps this cluster's domain/networks/nixidy
  # target into nixidy's config. It's collected by den.lib.aspects.resolve
  # alongside the base module (den.aspects.nixidy) and application modules.
  den.aspects.prod = {
    k8s-manifests = { ... }: {
      config = {
        cluster = {
          inherit (c) domain;
          networks = {
            podCIDR = c.networks.pods.cidr;
            serviceCIDR = c.networks.services.cidr;
          };
        };

        nixidy.target = {
          inherit (c.nixidy) repository branch rootPath;
        };

        networking.domain = c.domain;
      };
    };

    includes = with den.aspects; [
      nixidy
      argocd
    ];
  };
}
