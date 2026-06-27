set shell := ["bash", "-euo", "pipefail", "-c"]

# Build the qcow2 base image for a node.
build node:
    nix build .#nixosConfigurations.{{node}}.config.system.build.qcow -o disks/{{node}}-base.qcow2

# Create writable overlay disk from the nix-built base (no-op if disk exists).
init-disk node: (build node)
    #!/usr/bin/env bash
    mkdir -p disks
    if [ ! -f disks/{{node}}.qcow2 ]; then
      qemu-img create -f qcow2 \
        -b "$(readlink -f disks/{{node}}-base.qcow2/nixos.qcow2)" \
        -F qcow2 \
        disks/{{node}}.qcow2
    fi

# Rebuild base image and rebase overlay onto it (keeps VM state).
rebuild node:
    just build {{node}}
    qemu-img rebase -u -f qcow2 \
      -b "$(readlink -f disks/{{node}}-base.qcow2/nixos.qcow2)" \
      -F qcow2 \
      disks/{{node}}.qcow2

# Derive a stable locally-administered MAC from the trailing node index.
# k3s-node1 → 02:00:00:00:01:01, k3s-node2 → 02:00:00:00:01:02, …
_mac node:
    #!/usr/bin/env bash
    idx=$(grep -oP '\d+$' <<< "{{node}}")
    printf "02:00:00:00:01:%02x\n" "$idx"

# Define (or redefine) a VM in libvirt with a deterministic MAC on the adm VLAN.
define node: (init-disk node)
    #!/usr/bin/env bash
    idx=$(grep -oP '\d+$' <<< "{{node}}")
    mac=$(printf "02:00:00:00:01:%02x" "$idx")
    virsh undefine {{node}} 2>/dev/null || true
    virt-install \
      --name {{node}} \
      --memory 2048 \
      --vcpus 2 \
      --disk "$(pwd)/disks/{{node}}.qcow2,bus=virtio,format=qcow2" \
      --network type=direct,source=adm,source_mode=bridge,model=virtio,mac="$mac" \
      --osinfo linux2024 \
      --import \
      --noautoconsole \
      --print-xml | virsh define /dev/stdin

# Build, define, and start a node in one shot.
up node: (define node)
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
