# Production environment entity.
#
# Registers the prod environment in den.environments with its base
# domain TLD. Clusters that set `environment = "prod"` inherit this
# domain via their bridge aspect.
{ ... }:
{
  den.environments.prod = {
    domain = "home.arpa";
  };
}
