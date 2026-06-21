# Production cluster entity definition.
#
# Registers the prod cluster in den.clusters with its domain,
# networks, and nixidy target configuration. This is the single
# source of truth for cluster properties — nixidy environments
# and policy routing both read from here.
{ ... }:
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
}