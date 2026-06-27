{ den, ... }:
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

  den.aspects.k3s-prod = {
    includes = with den.aspects; [
      cilium
      cilium-bgp
      argocd
    ];
  };
}
