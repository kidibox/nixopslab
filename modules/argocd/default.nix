# ArgoCD — den aspect for the ArgoCD GitOps controller.
#
# Declares the k8s-manifests class for this aspect and registers
# the nixidy module path. The actual manifest content lives in the
# nixidy module at apps/argocd/default.nix, which reads cluster
# context (config.cluster.domain) from the nixidy module system.
#
# This file is a flake-parts module (auto-imported by import-tree).
# It does NOT contain nixidy module content itself — it only
# registers the den aspect metadata.
{ ... }:
{
  den.classes.k8s-manifests.description = "Kubernetes manifests collected for nixidy";
}