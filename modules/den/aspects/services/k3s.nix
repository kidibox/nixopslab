# k3s server aspect.
#
# Provides a nixos module that configures k3s as a single-node
# server (clusterInit enables embedded datastore).
#
# Include this aspect in any host that should run k3s:
#   den.aspects.myhost.includes = [ den.aspects.k3s-server ];
{ den, ... }:

{
  den.classes.nixos = {
    description = "NixOS system configuration modules";
  };

  den.aspects.k3s-server = {
    nixos = { config, lib, ... }: {
      # k3s — single-node server (clusterInit enables embedded datastore)
      # Flannel and kube-proxy are disabled; Cilium handles both.
      services.k3s = {
        enable = true;
        role = "server";
        clusterInit = true;
        extraFlags = lib.concatStringsSep " " [
          "--flannel-backend=none"
          "--disable-network-policy"
          "--disable-kube-proxy"
        ];
      };

      # Allow k3s API port through firewall
      networking.firewall.allowedTCPPorts = [ 6443 ];
    };
  };
}
