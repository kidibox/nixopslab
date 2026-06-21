# Cluster entity schema and instance registry.
#
# Defines the cluster entity type (den.schema.cluster) with
# isEntity = true and declares its properties. Each cluster
# instance is registered in den.clusters (e.g. den.clusters.prod).
#
# The cluster schema integrates with den's entity system so that
# future policy routing can resolve clusters into scope branches.
{ lib, ... }:
{
  # Declare the cluster entity type.
  # isEntity = true tells den's pipeline this is a first-class entity.
  config.den.schema.cluster.isEntity = true;

  # Cluster instance registry.
  # Each cluster has: domain, networks, nixidy target, and optional storage.
  options.den.clusters = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        domain = lib.mkOption {
          type = lib.types.str;
          default = "home.arpa";
          description = "Base domain for this cluster";
        };

        networks = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              cidr = lib.mkOption {
                type = lib.types.str;
                description = "Network CIDR (e.g., 172.20.0.0/16)";
              };

              description = lib.mkOption {
                type = lib.types.str;
                default = "";
                description = "Human-readable description";
              };

              assignments = lib.mkOption {
                type = lib.types.attrsOf lib.types.str;
                default = { };
                description = "Static IP assignments within this network";
              };
            };
          });
          default = { };
          description = "Cluster network definitions";
        };

        nixidy = lib.mkOption {
          type = lib.types.submodule {
            options = {
              repository = lib.mkOption {
                type = lib.types.str;
                description = "Git repository URL for nixidy target";
              };

              branch = lib.mkOption {
                type = lib.types.str;
                default = "main";
                description = "Git branch for nixidy target";
              };

              rootPath = lib.mkOption {
                type = lib.types.str;
                description = "Directory path within the repo for manifests";
              };
            };
          };
          description = "Nixidy sync target for this cluster";
        };

        storage = lib.mkOption {
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              server = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Storage server address";
              };

              share = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Storage share path";
              };
            };
          });
          default = { };
          description = "Cluster storage definitions";
        };
      };
    });
    default = { };
    description = "Cluster entity registry for den";
  };
}