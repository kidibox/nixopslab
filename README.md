# nixopslab

Kubernetes cluster manifests managed with [nixidy](https://nixidy.dev/), inspired by the [fleet pattern](https://den.denful.dev/) from [sini/nix-config](https://github.com/sini/nix-config).

## Structure

```
.
├── flake.nix              # Flake entry: nixidy env per cluster
├── clusters/               # Per-cluster configuration
│   └── prod.nix            # Production cluster (domain, networks, storage, nixidy target)
├── modules/                # Shared application modules
│   ├── default.nix         # Imports all submodules, shared options
│   └── argocd/             # ArgoCD application module
│       └── default.nix
└── manifests/              # Generated output (committed for Argo CD)
    └── prod/               # Built by: nixidy build .#prod
```

## Adding a new cluster

1. Create `clusters/<name>.nix` — set `nixidy.target.*`, `cluster.domain`, etc.
2. Add the name to `clusterNames` in `flake.nix`.
3. Build: `nixidy build .#<name>`

## Adding a new application

1. Create `modules/<app>/default.nix` — define `applications.<app>` and `options.services.<app>`.
2. Import it in `modules/default.nix`.
3. Rebuild: `nixidy build .#prod`

## Commands

| Command | Description |
|---|---|
| `nixidy build .#prod` | Build manifests to `./result` |
| `nixidy switch .#prod` | Sync manifests to `manifests/prod/` |
| `nixidy bootstrap .#prod` | Output bootstrap Application YAML |
| `nixidy info .#prod` | Show environment info |

## Design notes

- **One nixidy env per cluster** — `clusters/<name>.nix` configures the target repo/branch/path and cluster-specific options.
- **Application modules read `config.cluster.*`** — no hardcoding domains, CIDRs, or storage backends.
- **Helm charts via nixhelm** — all charts are pinned in the flake lock for reproducibility.
- **Host definitions and cluster creation** are out of scope for this iteration and will be added later.