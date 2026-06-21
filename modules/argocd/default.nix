# ArgoCD — den aspect + k8s-manifests factory registration.
#
# Declares the den aspect metadata (service-domains quirk,
# k8s-manifests class) and registers the k8s-manifests factory
# path so the nixidy env assembler can import and call it.
#
# k8s.manifests.argocd is a path to the factory file, stored in
# a plain flake-parts option (not in den.aspects) to avoid den's
# aspectContentType wrapping.
{ ... }:
{
  den.classes.k8s-manifests.description = "Kubernetes manifests collected for nixidy";

  den.aspects.argocd = {
    service-domains = [ "argocd" ];
  };

  k8s.manifests.argocd = ./../../k8s-manifests/argocd.nix;
}