{
  description = "Nix Flake for ED-UP (ED Unofficial Patch: DLSS/FSR/XeSS for Elite Dangerous: Odyssey)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: nixpkgs.legacyPackages.${system};
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = self.packages.${system}.ed-up;
          ed-up = pkgs.callPackage ./package.nix { };
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/ed-up-install";
          meta.description = "Install ED-UP in the Elite Dangerous game folder (chains another 3DMigoto such as EDCAS)";
        };
      });

      overlays.default = final: prev: {
        ed-up = self.packages.${prev.stdenv.hostPlatform.system}.ed-up;
      };
    };
}
