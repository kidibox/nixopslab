# k3s bootstrap aspect — oneshot systemd service that applies ArgoCD on first boot.
#
# Bakes the generated manifests into the NixOS image via `self` (the flake
# source is a store path), so no git clone is needed on the node.
#
# Wave ordering:
#   1. Apply ArgoCD manifests (creates namespace + workloads)
#   2. Wait for argocd-server rollout
#   3. Apply Application-argocd.yaml so ArgoCD becomes self-managing from git
#
# Idempotent: exits early if argocd-server already exists.
{ den, self, ... }:
{
  den.aspects.k3s-bootstrap = {
    nixos =
      { pkgs, lib, ... }:
      let
        inherit (lib) getExe;

        argocdManifests = builtins.path {
          path = self + "/manifests/prod/argocd";
          name = "k3s-prod-argocd-manifests";
        };

        argocdApp = builtins.path {
          path = self + "/manifests/prod/apps/Application-argocd.yaml";
          name = "k3s-prod-argocd-application";
        };
      in
      {
        systemd.services.k3s-bootstrap-argocd = {
          description = "Bootstrap ArgoCD and hand off to GitOps";
          after = [ "k3s.service" ];
          requires = [ "k3s.service" ];
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

              echo "Applying ArgoCD manifests..."
              kubectl apply \
                --server-side --force-conflicts --field-manager=argocd-controller \
                -f ${argocdManifests}

              echo "Waiting for argocd-server rollout..."
              kubectl rollout status -n argocd deployment/argocd-server --timeout=300s

              echo "Applying self-managing Application..."
              kubectl apply \
                --server-side --force-conflicts --field-manager=argocd-controller \
                -f ${argocdApp}

              echo "Bootstrap complete — ArgoCD is now managing itself from git."
            '';
          };
          wantedBy = [ "multi-user.target" ];
        };
      };
  };
}
