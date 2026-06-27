set shell := ["bash", "-euo", "pipefail", "-c"]

# Build the qcow2 base image for a node.
build node:
    nix build .#nixosConfigurations.{{node}}.config.formats.qcow2 -o disks/{{node}}-base.qcow2

# Create writable overlay disk from the nix-built base (no-op if disk exists).
init-disk node: (build node)
    #!/usr/bin/env bash
    mkdir -p disks
    if [ ! -f disks/{{node}}.qcow2 ]; then
      qemu-img create -f qcow2 \
        -b "$(readlink -f disks/{{node}}-base.qcow2)" \
        -F qcow2 \
        disks/{{node}}.qcow2
    fi

# Rebuild base image and rebase overlay onto it (keeps VM state).
rebuild node:
    just build {{node}}
    qemu-img rebase -u -f qcow2 \
      -b "$(readlink -f disks/{{node}}-base.qcow2)" \
      -F qcow2 \
      disks/{{node}}.qcow2

# Define (or redefine) a VM in libvirt. mac = stable MAC on the adm VLAN.
define node mac: (init-disk node)
    -virsh undefine {{node}} 2>/dev/null
    virt-install \
      --name {{node}} \
      --memory 2048 \
      --vcpus 2 \
      --disk "$(pwd)/disks/{{node}}.qcow2,bus=virtio,format=qcow2" \
      --network type=direct,source=adm,source_mode=bridge,model=virtio,mac={{mac}} \
      --import \
      --noautoconsole \
      --print-xml | virsh define /dev/stdin

# Build, define, and start a node in one shot.
up node mac: (define node mac)
    virsh start {{node}}

# Start a defined VM.
start node:
    virsh start {{node}}

# Gracefully shut down a VM.
stop node:
    virsh shutdown {{node}}

# Force-stop a VM.
kill node:
    virsh destroy {{node}}

# Remove a VM from libvirt (keeps disk).
undefine node:
    -virsh destroy {{node}} 2>/dev/null
    virsh undefine {{node}}

# SSH into a node (uses the first IP libvirt sees on the NIC).
ssh node:
    ssh kid@$(virsh domifaddr {{node}} | grep -oP '(\d+\.){3}\d+(?=/)')

# Show status of all k3s nodes.
status:
    virsh list --all | grep -E 'Name|k3s'
