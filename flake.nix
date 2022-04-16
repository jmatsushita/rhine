{
  description = "iios";
  nixConfig.bash-prompt = "\[iios\]$ ";
  inputs = {
    # nixpkgs.url = "github:NixOS/nixpkgs/21.11";
    nixpkgs.url = "github:NixOS/nixpkgs/5181d5945eda382ff6a9ca3e072ed6ea9b547fee";
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.nixpkgs.follows = "nixpkgs";

    hls.url = "github:haskell/haskell-language-server";
    hls.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, flake-utils, hls }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = { allowBroken = true; };
          overlays = [];
        };
        # Change GHC version here. To get the appropriate value, run:
        #   nix-env -f "<nixpkgs>" -qaP -A haskell.compiler
        # hp = pkgs.haskellPackages;
        hp = pkgs.haskell.packages.ghc922;

        # https://github.com/NixOS/nixpkgs/issues/140774#issuecomment-976899227
        m1MacHsBuildTools =
          hp.override {
            overrides = self: super:
              let
                workaround140774 = hpkg: with pkgs.haskell.lib;
                  overrideCabal hpkg (drv: {
                    enableSeparateBinOutput = false;
                  });
              in
              {
                ghcid = workaround140774 super.ghcid;
                ormolu = workaround140774 super.ormolu;
                time-domain = pkgs.haskell.lib.dontCheck (self.callHackage "time-domain" "0.1.0.0" {});
              };
          };
        # haskellPackages = pkgs.haskell.packages.ghc921.override  {
        haskellPackages = pkgs.haskell.packages.ghc922.override  {
          overrides = self: super: {
            # In case you need them
            network = pkgs.haskell.lib.dontCheck (self.callHackage "network" "3.1.2.5" {});
            time-domain = pkgs.haskell.lib.dontCheck (self.callHackage "time-domain" "0.1.0.0" {});
          };
        };
        packageName ="rhine";
      in {

        packages.${packageName} =
          haskellPackages.callCabal2nix packageName ./rhine rec {
            # Link cabal extra-librarires to nix system packages
            # zlib = pkgs.zlib;
          };

        defaultPackage = self.packages.${system}.${packageName};

        devShell = haskellPackages.shellFor {
          packages = p: [];

          buildInputs =
            (with (if system == "aarch64-darwin"
            then m1MacHsBuildTools
            else haskellPackages); [
            pkgs.zlib
            pkgs.zlib.dev

            time-domain

            cabal-install
            ghcid
            haskell-language-server
            hls
            # hlint
            ormolu
          ]);
          # withHoogle = true;
        };
      }
    );
}
