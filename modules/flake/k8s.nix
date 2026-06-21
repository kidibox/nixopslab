# k8s-manifests registry for nixidy.
#
# Registers k8s-manifests factory paths as a flake-parts option.
# Each factory file exports a curried function:
#   { cluster, ... }: { config, charts, lib, ... }: { ... }
#
# This is separate from den.aspects because den's aspectContentType
# wraps freeform keys in __contentValues/__functor, making it
# impossible to store paths or curried functions directly.
#
# Corresponds to den.classes.k8s-manifests — aspects that declare
# k8s-manifests register their factory here.
{ lib, ... }:
{
  options.k8s = {
    manifests = lib.mkOption {
      type = lib.types.attrsOf lib.types.path;
      default = { };
      description = "k8s-manifests factory paths, keyed by aspect name. Each file is imported and called with cluster context.";
    };
  };
}