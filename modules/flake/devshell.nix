{ inputs, ... }:
{
  imports = [ inputs.devshell.flakeModule ];

  perSystem =
    { system, pkgs, ... }:
    let
      ovmf = pkgs.OVMF.fd;
    in
    {
      packages.nixidy = inputs.nixidy.packages.${system}.cli;

      devshells.default = {
        packages = [
          inputs.nixidy.packages.${system}.cli
          pkgs.qemu-utils
          pkgs.OVMF.fd
        ];

        commands =
          let
            # Resolve <node> IP via qemu guest agent only. Filters out loopback
            # (127.), link-local (169.), and pod-network (172.4x.) addresses.
            # Aborts if the agent is not reachable or returns no usable IP.
            nodeIp = ''
              node_ip() {
                local node=$1
                local ip
                ip=$(virsh domifaddr "$node" --source agent 2>/dev/null \
                  | grep -oP '(\d+\.){3}\d+(?=/)' \
                  | grep -vE '^(127\.|169\.|172\.4)' | head -1)
                if [[ -z "$ip" ]]; then
                  echo "error: guest agent on $node returned no usable IP (is qemuGuest running?)" >&2
                  return 1
                fi
                echo "$ip"
              }
            '';
          in
          [
          {
            name = "vm-build";
            help = "Build the qcow2 base image for <node>";
            command = ''
              nix build .#nixosConfigurations.$1.config.system.build.qcow \
                -o disks/$1-base.qcow2
            '';
          }
          {
            name = "vm-up";
            help = "Build image, define in libvirt with EFI, and start <node>";
            command = ''
              set -euo pipefail
              node=$1
              mkdir -p disks
              nix build .#nixosConfigurations.$node.config.system.build.qcow \
                -o disks/$node-base.qcow2
              rm -f disks/$node.qcow2
              qemu-img create -f qcow2 \
                -b "$(readlink -f disks/$node-base.qcow2/nixos.qcow2)" \
                -F qcow2 disks/$node.qcow2
              cp ${ovmf}/FV/OVMF_VARS.fd disks/$node-efi-vars.fd
              chmod +w disks/$node-efi-vars.fd
              virsh undefine "$node" --nvram 2>/dev/null || true
              virt-install \
                --name "$node" --memory 4096 --vcpus 2 \
                --disk "$(pwd)/disks/$node.qcow2,bus=virtio,format=qcow2" \
                --network bridge=br-k8s,model=virtio \
                --boot loader=${ovmf}/FV/OVMF_CODE.fd,loader.readonly=yes,loader.type=pflash,nvram.template=${ovmf}/FV/OVMF_VARS.fd,nvram=$(pwd)/disks/$node-efi-vars.fd \
                --channel unix,target.type=virtio,target.name=org.qemu.guest_agent.0 \
                --serial pty \
                --console pty,target_type=serial \
                --osinfo linux2024 --import --noautoconsole \
                --print-xml | virsh define /dev/stdin
              virsh start "$node"
            '';
          }
          {
            name = "vm-switch";
            help = "Apply NixOS config to a running <node> without rebooting";
            command = ''
              set -euo pipefail
              ${nodeIp}
              node=$1
              ip=$(node_ip "$node")
              [[ -n "$ip" ]] || { echo "cannot resolve IP for $node"; exit 1; }
              nixos-rebuild switch \
                --flake ".#$node" \
                --target-host "kid@$ip" \
                --use-remote-sudo
            '';
          }
          {
            name = "vm-rebuild";
            help = "Rebuild base image, rebase overlay, reset EFI nvram, and restart <node>";
            command = ''
              set -euo pipefail
              node=$1
              nix build .#nixosConfigurations.$node.config.system.build.qcow \
                -o disks/$node-base.qcow2
              if virsh domstate "$node" 2>/dev/null | grep -q running; then
                echo "Shutting down $node..."
                virsh shutdown "$node"
                while virsh domstate "$node" 2>/dev/null | grep -qv "shut off"; do sleep 1; done
              fi
              qemu-img rebase -u -f qcow2 \
                -b "$(readlink -f disks/$node-base.qcow2/nixos.qcow2)" \
                -F qcow2 disks/$node.qcow2
              cp ${ovmf}/FV/OVMF_VARS.fd disks/$node-efi-vars.fd
              chmod +w disks/$node-efi-vars.fd
              virsh start "$node"
            '';
          }
          {
            name = "vm-start";
            help = "Start a defined VM";
            command = ''virsh start "$1"'';
          }
          {
            name = "vm-stop";
            help = "Gracefully shut down a VM";
            command = ''virsh shutdown "$1"'';
          }
          {
            name = "vm-kill";
            help = "Force-stop a VM";
            command = ''virsh destroy "$1"'';
          }
          {
            name = "vm-undefine";
            help = "Remove a VM from libvirt (keeps disk)";
            command = ''
              virsh destroy "$1" 2>/dev/null || true
              virsh undefine "$1" --nvram
            '';
          }
          {
            name = "vm-console";
            help = "Attach to the serial console of a running VM (Ctrl+] to detach)";
            command = ''virsh console "$1"'';
          }
          {
            name = "vm-ssh";
            help = "SSH into a node";
            command = ''
              ${nodeIp}
              ip=$(node_ip "$1")
              [[ -n "$ip" ]] || { echo "cannot resolve IP for $1"; exit 1; }
              ssh "kid@$ip"
            '';
          }
          {
            name = "vm-status";
            help = "Show status of all k3s VMs";
            command = "virsh list --all | grep -E 'Name|k3s'";
          }
        ];
      };
    };
}
