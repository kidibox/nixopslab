{ lib, self, ... }:
{
  perSystem =
    { system, pkgs, ... }:
    let
      envs = self.nixidyEnvs.${system};
    in
    {
      # One check for all manifests: diffs the entire nixidy environment package
      # against committed manifests. Detects content drift and stale/missing files.
      # nix flake show: no IFD — derivation hash is computable from store paths.
      # nix flake check: builds env.environmentPackage (helm charts built here).
      checks.manifests = pkgs.runCommandLocal "manifests-check"
        { nativeBuildInputs = [ pkgs.diffutils ]; }
        (lib.concatStringsSep "\n" (
          lib.mapAttrsToList (envName: env:
            let
              pkg = env.environmentPackage;
              targetDir = builtins.unsafeDiscardStringContext env.config.nixidy.target.rootPath;
            in
            ''
              if ! diff -rq "${self}/${targetDir}" "${pkg}"; then
                echo "Manifests are stale for ${envName} — run: nix run .#write-manifests" >&2
                exit 1
              fi
            ''
          ) envs
        ) + "\ntouch $out");

      # Write all nixidy manifests into the repo, replacing stale files.
      apps.write-manifests = {
        type = "app";
        program = "${pkgs.writeShellApplication {
          name = "write-manifests";
          runtimeInputs = [ pkgs.rsync ];
          text = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (envName: env:
              let
                pkg = env.environmentPackage;
                targetDir = builtins.unsafeDiscardStringContext env.config.nixidy.target.rootPath;
              in
              ''
                echo "==> Writing ${envName} manifests..."
                mkdir -p "${targetDir}"
                rsync -av --delete "${pkg}/" "${targetDir}/"
              ''
            ) envs
          );
        }}/bin/write-manifests";
      };
    };
}
