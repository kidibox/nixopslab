{ inputs, config, lib, ... }:
{
  # Expose helm chart derivations as a flake output — mirrors the
  # chartsDerivations pattern from sini/nix-config. Aspects reference
  # charts via self.chartsDerivations rather than nixhelm directly,
  # keeping nixhelm an implementation detail.
  flake.chartsDerivations = lib.genAttrs config.systems (system:
    inputs.nixhelm.chartsDerivations.${system}
  );

  # perSystem =
  #   { system, ... }:
  #   let
  #     charts = inputs.nixhelm.chartsDerivations.${system};
  #   in
  #   {
  #     # Charts used in this flake, visible as packages in nix flake show.
  #     # Add entries here when new helm releases are introduced in aspects.
  #     packages = {
  #       helm-argo-cd = charts.argoproj.argo-cd;
  #     };
  #   };
}
