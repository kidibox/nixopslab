# ArgoCD — den aspect for the ArgoCD GitOps controller.
#
# Declares the k8s-manifests class and a service-domains quirk.
# The actual manifest content lives in apps/argocd/default.nix
# (a nixidy module), which reads cluster context via the `cluster`
# specialArg from den.clusters.
#
# This file is a flake-parts module (auto-imported by import-tree).
# It does NOT contain nixidy module content — only den metadata.
{ ... }:
{
  den.classes.k8s-manifests.description = "Kubernetes manifests collected for nixidy";

  den.aspects.argocd = {
    service-domains = [ "argocd" ];
  };
}