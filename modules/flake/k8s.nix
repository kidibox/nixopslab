# k8s-manifests den class declaration.
#
# Registers "k8s-manifests" as a den class so the pipeline recognizes
# it as a class key on aspects. The den pipeline's scope engine collects
# k8s-manifests class content when walking aspect includes chains, and
# delivers them to the nixidy environment assembler.
{ lib, ... }:
{
  config.den.classes.k8s-manifests = {
    description = "Kubernetes manifest nixidy modules — collected via den's pipeline";
  };
}
