# k3s bootstrap aspect — oneshot systemd services that apply manifests on first boot.
#
# Bakes the generated manifests into the NixOS image via `self` (the flake
# source is a store path), so no git clone is needed on the node.
#
# Wave ordering:
#   0. k3s-bootstrap-namespaces — all Namespace resources from all apps
#   1. k3s-bootstrap-cilium     — Cilium core manifests, wait for operator
#                                  (operator registers Cilium CRDs at startup),
#                                  then apply Cilium custom resources
#   2. k3s-bootstrap-argocd     — ArgoCD + self-managing Application
#
# Cilium does not ship CRDs in its Helm chart; the cilium-operator registers
# them at runtime. Applying Cilium*.yaml CRs before the operator is ready
# causes "no kind is registered" errors, hence the split in wave 1.
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
        ciliumDir = manifestPath "cilium";
        argocdDir = manifestPath "argocd";
        waitForApi = ''
          echo "Waiting for k3s API server..."
          until kubectl get nodes >/dev/null 2>&1; do
            sleep 5
          done
        '';
      in
      {
        systemd.services = {
          # Wave 0: create all Namespace resources before any workloads
          k3s-bootstrap-namespaces = {
            description = "Bootstrap namespaces for all applications";
            after = [ "k3s.service" ];
            requires = [ "k3s.service" ];
            path = [ pkgs.kubectl pkgs.findutils ];
            environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = pkgs.writeShellScript "k3s-bootstrap-namespaces" ''
                set -e
                ${waitForApi}

                echo "Applying all Namespace resources..."
                declare -a files
                while IFS= read -r f; do files+=("-f" "$f"); done < <(
                  find ${ciliumDir} ${argocdDir} -name "Namespace-*.yaml" | sort
                )
                [[ ''${#files[@]} -gt 0 ]] && \
                  kubectl apply --server-side --force-conflicts --field-manager=argocd-controller "''${files[@]}"

                echo "Namespaces ready."
              '';
            };
            wantedBy = [ "multi-user.target" ];
          };

          # Wave 1: Cilium CNI
          #
          # Cilium's Helm chart ships no CRDs — the cilium-operator registers
          # them at startup. We therefore split the apply in two:
          #   a) Core manifests (everything except Cilium* custom resources)
          #   b) Wait for cilium-operator rollout (CRDs now Established)
          #   c) Cilium custom resources (CiliumBGP*, CiliumLoadBalancerIPPool)
          k3s-bootstrap-cilium = {
            description = "Bootstrap Cilium CNI";
            after = [ "k3s.service" "k3s-bootstrap-namespaces.service" ];
            requires = [ "k3s.service" "k3s-bootstrap-namespaces.service" ];
            path = [ pkgs.kubectl pkgs.findutils ];
            environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = pkgs.writeShellScript "k3s-bootstrap-cilium" ''
                set -e

                if kubectl get daemonset -n kube-system cilium >/dev/null 2>&1; then
                  echo "Cilium already installed, skipping bootstrap."
                  exit 0
                fi

                echo "Applying Cilium core manifests..."
                declare -a core_files
                while IFS= read -r f; do core_files+=("-f" "$f"); done < <(
                  find ${ciliumDir} -name "*.yaml" ! -name "Cilium*.yaml" | sort
                )
                [[ ''${#core_files[@]} -gt 0 ]] && \
                  kubectl apply --server-side --force-conflicts --field-manager=argocd-controller "''${core_files[@]}"

                echo "Waiting for Cilium DaemonSet to be ready..."
                kubectl rollout status -n kube-system daemonset/cilium --timeout=300s

                echo "Waiting for Cilium operator to be ready..."
                kubectl rollout status -n kube-system deployment/cilium-operator --timeout=120s

                echo "Waiting for Cilium CRDs to be established..."
                until kubectl get crd ciliumloadbalancerippools.cilium.io >/dev/null 2>&1; do
                  sleep 5
                done
                kubectl wait --for=condition=Established \
                  crd/ciliumloadbalancerippools.cilium.io \
                  crd/ciliumbgpclusterconfigs.cilium.io \
                  crd/ciliumbgppeerconfigs.cilium.io \
                  crd/ciliumbgpadvertisements.cilium.io \
                  --timeout=60s

                echo "Applying Cilium custom resources..."
                declare -a cr_files
                while IFS= read -r f; do cr_files+=("-f" "$f"); done < <(
                  find ${ciliumDir} -name "Cilium*.yaml" | sort
                )
                [[ ''${#cr_files[@]} -gt 0 ]] && \
                  kubectl apply --server-side --force-conflicts --field-manager=argocd-controller "''${cr_files[@]}"

                echo "Cilium bootstrap complete."
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

                if kubectl get statefulset -n argocd argocd-application-controller >/dev/null 2>&1; then
                  echo "ArgoCD already installed, skipping bootstrap."
                  exit 0
                fi

                echo "Applying ArgoCD manifests..."
                kubectl apply \
                  --server-side --force-conflicts --field-manager=argocd-controller \
                  -f ${argocdDir}

                echo "Waiting for argocd-application-controller rollout..."
                kubectl rollout status -n argocd statefulset/argocd-application-controller --timeout=300s

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
