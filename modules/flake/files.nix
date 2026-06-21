# sini/files integration: register nixidy manifest outputs as managed files.
# nix run .#write-files  → write manifests into the repo
# nix run .#diff-files    → preview what would change
# nix flake check         → verify manifests are in sync
{ lib, self, ... }:
let
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
                []
            ) (builtins.readDir dir)
          )
        );
      absPaths = go root;
      prefixLen = builtins.stringLength (root + "/");
    in
    map (p: builtins.substring prefixLen (builtins.stringLength p) p) absPaths;
in
{
  perSystem =
    { system, ... }:
    let
      envs = self.nixidyEnvs.${system};
    in
    {
      files.generateApp = true;

      files.file =
        builtins.foldl' (acc: envName:
          let
            env = envs.${envName};
            pkg = env.environmentPackage;
            # target.rootPath may carry store context — strip it so the
            # attrset name stays clean (sini/files rejects store refs in keys).
            targetDir = builtins.unsafeDiscardStringContext env.config.nixidy.target.rootPath;
          in
          acc // builtins.listToAttrs (
            builtins.map
              (relPath: {
                name = builtins.unsafeDiscardStringContext "${targetDir}/${relPath}";
                # Use .text to read file content from the store path — this
                # produces individual derivations that sini/files can verify.
                value.text = builtins.readFile "${pkg}/${relPath}";
              })
              (walkDir pkg)
          )
        ) {} (builtins.attrNames envs);
    };
}