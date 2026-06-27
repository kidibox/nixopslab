{ inputs, ... }:
{
  imports = [ inputs.devshell.flakeModule ];

  perSystem =
    { system, pkgs, ... }:
    {
      packages.nixidy = inputs.nixidy.packages.${system}.cli;

      devshells.default = {
        packages = [
          inputs.nixidy.packages.${system}.cli
          pkgs.qemu-utils
        ];

        commands = [
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
            help = "Build image, define in libvirt, and start <node>";
            command = ''
              set -euo pipefail
              node=$1
              mkdir -p disks
              nix build .#nixosConfigurations.$node.config.system.build.qcow \
                -o disks/$node-base.qcow2
              if [ ! -f disks/$node.qcow2 ]; then
                qemu-img create -f qcow2 \
                  -b "$(readlink -f disks/$node-base.qcow2/nixos.qcow2)" \
                  -F qcow2 disks/$node.qcow2
              fi
              idx=$(grep -oP '\d+$' <<< "$node")
              mac=$(printf "02:00:00:00:01:%02x" "$idx")
              virsh undefine "$node" 2>/dev/null || true
              virt-install \
                --name "$node" --memory 2048 --vcpus 2 \
                --disk "$(pwd)/disks/$node.qcow2,bus=virtio,format=qcow2" \
                --network type=direct,source=adm,source_mode=bridge,model=virtio,mac="$mac" \
                --osinfo linux2024 --import --noautoconsole \
                --print-xml | virsh define /dev/stdin
              virsh start "$node"
            '';
          }
          {
            name = "vm-rebuild";
            help = "Rebuild base image and rebase overlay for <node>";
            command = ''
              set -euo pipefail
              node=$1
              nix build .#nixosConfigurations.$node.config.system.build.qcow \
                -o disks/$node-base.qcow2
              qemu-img rebase -u -f qcow2 \
                -b "$(readlink -f disks/$node-base.qcow2/nixos.qcow2)" \
                -F qcow2 disks/$node.qcow2
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
              virsh undefine "$1"
            '';
          }
          {
            name = "vm-ssh";
            help = "SSH into a node";
            command = ''ssh kid@$(virsh domifaddr "$1" | grep -oP '(\d+\.){3}\d+(?=/)')'';
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
