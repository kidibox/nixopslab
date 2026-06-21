# nixopslab

Kubernetes cluster manifests managed with [nixidy](https://nixidy.dev/), inspired by the [fleet pattern](https://den.denful.dev/) from [sini/nix-config](https://github.com/sini/nix-config).

## Structure

```
.
├── flake.nix              # Flake entry: nixidy env per cluster + sini/files integration
├── clusters/               # Per-cluster configuration
│   └── prod.nix            # Production cluster (domain, networks, storage, nixidy target)
├── modules/                # Shared application modules
│   ├── default.nix         # Imports all submodules, shared options
│   └── argocd/             # ArgoCD application module
│       └── default.nix
└── manifests/               # Generated output (committed for Argo CD)
    └── prod/                # Built by: nix run .#write-files
```

## Commands

| Command | Description |
|---|---|
| `nix run .#write-files` | Write manifests into the repo |
| `nix run .#diff-files` | Preview what would change (no writes) |
| `nix flake check` | Verify manifests are in sync |
| `nixidy build .#prod` | Build manifests to `./result` |
| `nixidy switch .#prod` | Sync manifests (alternative to write-files) |
| `nixidy info .#prod` | Show environment info |

## Adding a new cluster

1. Create `clusters/<name>.nix` — set `nixidy.target.*`, `cluster.domain`, etc.
2. Add the name to `clusterNames` in `flake.nix`.
3. Run `nix run .#write-files` and commit the generated manifests.

## Adding a new application

1. Create `modules/<app>/default.nix` — define `applications.<app>` and `options.services.<app>`.
2. Import it in `modules/default.nix`.
3. Run `nix run .#write-files` and commit.

## Design notes

- **One nixidy env per cluster** — `clusters/<name>.nix` configures the target repo/branch/path and cluster-specific options.
- **Application modules read `config.cluster.*`** — no hardcoding domains, CIDRs, or storage backends.
- **Helm charts via nixhelm** — all charts are pinned in the flake lock for reproducibility.
- **`sini/files` for manifest sync** — generated manifests are declared as file entries. `nix run .#write-files` updates them; `nix flake check` verifies they're in sync. This replaces the manual `nixidy switch` workflow with a checked, declarative approach.
- **Host definitions and cluster creation** are out of scope for this iteration and will be added later.