{
  description = "Ardia browser, tracking upstream Linux releases";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} = {
        ardia = pkgs.callPackage ./package.nix { };
        default = self.packages.${system}.ardia;
      };

      checks.${system}.ardia = self.packages.${system}.ardia;

      overlays.default = final: _prev: {
        ardia = final.callPackage ./package.nix { };
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
