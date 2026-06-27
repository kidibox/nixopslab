# k3s bootstrap aspect — oneshot systemd services that apply manifests on first boot.
#
# Bakes the generated manifests into the NixOS image via `self` (the flake
# source is a store path), so no git clone is needed on the node.
#
# Wave ordering:
#   1. k3s-bootstrap-cilium  — Cilium CNI (networking must come first)
#   2. k3s-bootstrap-argocd  — ArgoCD + self-managing Application
#
# Each service is idempotent: exits early if already installed.
{ den, self, ... }:
{
  den.aspects.k3s-bootstrap = {
    nixos =
      { pkgs, lib, ... }:
      let
        manifestPath = name: builtins.path {
          path = self + "/manifests/prod/${name}";
          name = "k3s-prod-${builtins.replaceStrings [ "/" "." ] [ "-" "-" ] name}";
        };
      in
      {
        systemd.services = {
          # Wave 1: Cilium CNI — pods can't start without networking
          k3s-bootstrap-cilium = {
            description = "Bootstrap Cilium CNI";
            after = [ "k3s.service" ];
            requires = [ "k3s.service" ];
            path = [ pkgs.kubectl ];
            environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = pkgs.writeShellScript "k3s-bootstrap-cilium" ''
                set -e

                echo "Waiting for k3s API server..."
                until kubectl get nodes >/dev/null 2>&1; do
                  sleep 5
                done

                if kubectl get daemonset -n kube-system cilium >/dev/null 2>&1; then
                  echo "Cilium already installed, skipping bootstrap."
                  exit 0
                fi

                echo "Applying Cilium manifests..."
                kubectl apply \
                  --server-side --force-conflicts --field-manager=argocd-controller \
                  -f ${manifestPath "cilium"}

                echo "Waiting for Cilium to be ready..."
                kubectl rollout status -n kube-system daemonset/cilium --timeout=300s
              '';
            };
            wantedBy = [ "multi-user.target" ];
          };

          # Wave 2: ArgoCD — depends on Cilium for pod networking
          k3s-bootstrap-argocd = {
            description = "Bootstrap ArgoCD and hand off to GitOps";
            after = [ "k3s.service" "k3s-bootstrap-cilium.service" ];
            requires = [ "k3s.service" "k3s-bootstrap-cilium.service" ];
            path = [ pkgs.kubectl ];
            environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = pkgs.writeShellScript "k3s-bootstrap-argocd" ''
                set -e

                echo "Waiting for k3s API server..."
                until kubectl get nodes >/dev/null 2>&1; do
                  sleep 5
                done

                if kubectl get deployment -n argocd argocd-server >/dev/null 2>&1; then
                  echo "ArgoCD already installed, skipping bootstrap."
                  exit 0
                fi

                echo "Creating argocd namespace..."
                kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

                echo "Applying ArgoCD manifests..."
                kubectl apply \
                  --server-side --force-conflicts --field-manager=argocd-controller \
                  -f ${manifestPath "argocd"}

                echo "Waiting for argocd-server rollout..."
                kubectl rollout status -n argocd deployment/argocd-server --timeout=300s

                echo "Applying self-managing Application..."
                kubectl apply \
                  --server-side --force-conflicts --field-manager=argocd-controller \
                  -f ${manifestPath "apps/Application-argocd.yaml"}

                echo "Bootstrap complete — ArgoCD is now managing itself from git."
              '';
            };
            wantedBy = [ "multi-user.target" ];
          };
        };
      };
  };
}
