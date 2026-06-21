# Production cluster entity and aspect.
#
# Registers the prod cluster in den.clusters (entity data) and
# den.aspects.prod (which k8s services to include).
#
# The cluster entity (den.clusters.prod) is the single source of truth
# for domain, networks, nixidy target, and storage config.
#
# The cluster aspect (den.aspects.prod) lists the k8s service aspects
# to include via includes. The cluster-aspect policy in modules/flake/policies.nix
# auto-includes den.aspects.<clusterName> when a cluster entity exists.
{ den, ... }:
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

  # Cluster aspect — which k8s services to include for this cluster.
  # Following the sini/nix-config pattern: den.aspects.<clusterName>
  # with includes listing the k8s service aspects.
  den.aspects.prod = {
    includes = with den.aspects; [
      argocd
    ];
  };
}
