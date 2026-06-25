# nixopslab — operating instructions for coding agents

## Architecture

**Everything comes from den aspects.** `modules/flake/nixidy.nix` only assembles: it iterates `config.den.clusters`, calls `den.lib.aspects.resolve "k8s-manifests"` on each cluster's aspect, and passes the collected modules to `nixidy.lib.mkEnv`. No hardcoded module paths, no bridges.

There is no `apps/` or `clusters/` directory. All nixidy module content lives on den aspects.

## The three module sources collected per cluster

1. **Cluster bridge** (on `den.aspects.<name>.k8s-manifests`) — maps `den.clusters.<name>` entity data into nixidy config (`config.cluster.*`, `config.nixidy.target`, `config.networking.domain`). Uses `let c = den.clusters.<name>` at module evaluation time, captured into the k8s-manifests module function. Nix's laziness handles the timing.

2. **Nixidy base** (`den.aspects.nixidy.k8s-manifests` from `modules/nixidy/default.nix`) — shared option definitions (`cluster.domain`, `cluster.networks.podCIDR`, `networking.domain`), nixidy defaults (syncPolicy, helm transformer), and extraFiles (README.md). Every cluster includes this via `den.aspects.<name>.includes = [ den.aspects.nixidy ... ]`.

3. **Application modules** (e.g. `den.aspects.argocd.k8s-manifests`) — the actual k8s manifests. Each aspect declares its own k8s-manifests module function directly as a freeform key.

## Key rules

- **Don't put nixidy modules in `apps/` or `clusters/`.** They go on den aspects as k8s-manifests content.
- **nixidy.nix must have zero cluster-specific logic.** No bridges, no special cases per cluster name.
- **The cluster bridge belongs in the entity file** (`modules/flake/entities/<name>.nix`), not in nixidy.nix. It's just another k8s-manifests module on the cluster aspect.
- **`aspectContentType` wraps freeform keys in `__contentValues`.** Don't read aspect content from config directly — go through `den.lib.aspects.resolve` which calls `unwrapContentValuesList`.
- **Module functions** like `{ config, charts, lib, ... }: { ... }` survive den's pipeline as-is because `cluster`/`charts` aren't den context args. The function is not called by den — it's passed through to nixidy's `mkEnv`.

## Adding a new cluster

1. Create `modules/flake/entities/<name>.nix`
2. Define `den.clusters.<name>` with domain, networks, nixidy target, storage
3. Capture `c = den.clusters.<name>` in a let binding
4. Define `den.aspects.<name>` with:
   - `k8s-manifests = { ... }: { ... }` — the bridge (maps `c` to `config.cluster.*`, `config.nixidy.target`, `config.networking.domain`)
   - `includes = with den.aspects; [ nixidy ... ]` — the nixidy base + app aspects

## Adding a new k8s-manifests aspect

1. Create `modules/<name>/default.nix` (auto-imported via import-tree)
2. Define `den.aspects.<name>` with:
   - Any metadata quirks (e.g. `service-domains`)
   - `k8s-manifests = { config, charts, lib, ... }: { ... }` — the nixidy module function
3. Add `<name>` to `den.aspects.<cluster>.includes` in the cluster entity file
4. Run `nix run .#write-files` to generate manifests, then `nix run .#sync-manifests` if removing an app

## Verification

- `nix flake check` — content correctness + stale files detection
- `nix run .#write-files` — writes declared manifests
- `nix run .#sync-manifests` — writes manifests + removes stale files
- `nix run .#write-flake` — regenerates `flake.nix` from `flake-file.nix`
