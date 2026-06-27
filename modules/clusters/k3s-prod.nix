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
        cidr = "172.40.0.0/16";
        description = "Pod CIDR (k3s --cluster-cidr)";
      };

      services = {
        cidr = "172.42.0.0/16";
        description = "Service CIDR (k3s --service-cidr)";
      };

      loadbalancers = {
        cidr = "10.0.42.0/24";
        description = "LoadBalancer IP pool (BGP-advertised)";
      };
    };

    bgp.peers = [
      {
        name = "router";
        ip = "10.0.40.1";
        asn = 64512;
      }
    ];

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
  # into nixidy's config. Collected by the cluster-to-nixidy policy alongside
  # application modules via the includes chain.
  den.aspects.k3s-prod = {
    k8s-manifests = { ... }: {
      config = {
        cluster = {
          domain = e.domain;
          networks = {
            podCIDR = c.networks.pods.cidr;
            serviceCIDR = c.networks.services.cidr;
            lbCIDR = c.networks.loadbalancers.cidr;
          };
          bgp.peers = c.bgp.peers;
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
      cilium-bgp
      argocd
    ];
  };
}
