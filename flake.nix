{
  description = "Kubernetes cluster manifests managed with nixidy";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
    };

    nixidy = {
      url = "github:arnarg/nixidy";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixhelm = {
      url = "github:farcaller/nixhelm";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    files = {
      url = "github:sini/files";
    };
  };

  outputs =
    inputs@{
      self,
      flake-parts,
      nixpkgs,
      nixidy,
      nixhelm,
      ...
    }:
    let
      # Each cluster gets its own nixidy environment.
      # Add new clusters here and create a corresponding file in clusters/.
      clusterNames = [ "prod" ];

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      # Recursively walk a derivation output, following symlinks.
      # Returns a list of relative paths to all regular files.
      walkDir = root:
        let
          go = dir:
            builtins.concatLists (
              builtins.attrValues (
                builtins.mapAttrs (name: type:
                  let
                    full = "${dir}/${name}";
                  in
                  if type == "directory" || (type == "symlink" && builtins.pathExists (full + "/.")) then
                    go full
                  else if type == "regular" then
                    [ full ]
                  else
                    []  # skip unknown types
                ) (builtins.readDir dir)
              )
            );
          absPaths = go root;
          prefixLen = builtins.stringLength (root + "/");
        in
        map (p: builtins.substring prefixLen (builtins.stringLength p) p) absPaths;
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = supportedSystems;

      imports = [ inputs.files.flakeModule ];

      flake = {
        # nixidyEnvs.<system>.<cluster> — the canonical nixidy output format.
        # Build: nix build .#nixidyEnvs.x86_64-linux.prod.environmentPackage
        # Or:    nixidy build .#prod
        # Also:  nixidy switch .#prod  (sync manifests to repo)
        nixidyEnvs = builtins.listToAttrs (
          map (system: {
            name = system;
            value = builtins.listToAttrs (
              map (clusterName: {
                name = clusterName;
                value = nixidy.lib.mkEnv {
                  pkgs = import nixpkgs { inherit system; };
                  charts = nixhelm.chartsDerivations.${system};
                  modules = [
                    ./modules
                    ./clusters/${clusterName}.nix
                  ];
                };
              }) clusterNames
            );
          }) supportedSystems
        );
      };

      perSystem =
        {
          system,
          pkgs,
          config,
          ...
        }:
        let
          envs = self.nixidyEnvs.${system};
        in
        {
          packages.nixidy = nixidy.packages.${system}.cli;

          devShells.default = pkgs.mkShell {
            buildInputs = [ nixidy.packages.${system}.default ];
          };

          # -- sini/files: declarative generated manifests -------------------
          # nix run .#write-files   → write manifests into the repo
          # nix run .#diff-files     → preview what would change
          # nix flake check          → verify manifests are in sync
          files.generateApp = true;

          files.file =
            builtins.foldl' (acc: envName:
              let
                env = envs.${envName};
                pkg = env.environmentPackage;
                targetDir = builtins.unsafeDiscardStringContext env.config.nixidy.target.rootPath;
              in
              acc // builtins.listToAttrs (
                builtins.map
                  (relPath: {
                    name = builtins.unsafeDiscardStringContext "${targetDir}/${relPath}";
                    # Use .text to read file content from the store path.
                    # This forces evaluation of each file but produces
                    # individual derivations that sini/files can verify.
                    value.text = builtins.readFile "${pkg}/${relPath}";
                  })
                  (walkDir pkg)
              )
            ) {} (builtins.attrNames envs);
        };
    };
}