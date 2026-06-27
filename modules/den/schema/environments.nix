# Environment entity schema and instance registry.
#
# Defines the environment entity type (den.schema.environment) with
# isEntity = true and declares its properties. Each environment instance
# is registered in den.environments (e.g. den.environments.prod).
#
# Environments hold cross-cluster configuration: the base domain TLD
# that clusters in this environment inherit.
{ lib, ... }:
{
  config.den.schema.environment.isEntity = true;

  options.den.environments = lib.mkOption {
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        domain = lib.mkOption {
          type = lib.types.str;
          description = "Base domain TLD for this environment (e.g. home.arpa)";
        };
      };
    });
    default = { };
    description = "Environment entity registry for den";
  };
}
