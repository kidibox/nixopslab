# Per-system packages and devshell.
{ inputs, ... }:
{
  perSystem =
    { system, pkgs, ... }:
    {
      packages.nixidy = inputs.nixidy.packages.${system}.cli;

      devShells.default = pkgs.mkShell {
        buildInputs = [
          inputs.nixidy.packages.${system}.cli
          pkgs.just
        ];
      };
    };
}