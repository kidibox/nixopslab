{
  description = "Kubernetes cluster manifests managed with nixidy";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    nixidy = {
      url = "github:arnarg/nixidy";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixhelm = {
      url = "github:farcaller/nixhelm";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixidy,
      nixhelm,
    }:
    let
      # Each cluster gets its own nixidy environment.
      # Add new clusters here and create a corresponding file in clusters/.
      clusterNames = [
        "prod"
      ];

      mkClusterEnv =
        system: clusterName:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        nixidy.lib.mkEnv {
          inherit pkgs;

          charts = nixhelm.chartsDerivations.${system};

          modules = [
            ./modules
            ./clusters/${clusterName}.nix
          ];
        };

      # Generate nixidyEnvs for all clusters across all systems.
      mkAllEnvs = system: builtins.listToAttrs (
        map (name: {
          name = name;
          value = mkClusterEnv system name;
        }) clusterNames
      );

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
    in
    {
      # nixidyEnvs.<system>.<clusterName> — build with:
      #   nixidy build .#prod
      #   nix build .#nixidyEnvs.x86_64-linux.prod.environmentPackage
      nixidyEnvs = builtins.listToAttrs (
        map (system: {
          name = system;
          value = mkAllEnvs system;
        }) supportedSystems
      );
    }
    // (builtins.listToAttrs (
      map (system: {
        name = system;
        value =
          let
            pkgs = import nixpkgs { inherit system; };
          in
          {
            packages.nixidy = nixidy.packages.${system}.cli;

            devShells.default = pkgs.mkShell {
              buildInputs = [
                nixidy.packages.${system}.default
              ];
            };
          };
      }) supportedSystems
    ));
}