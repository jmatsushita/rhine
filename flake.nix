{
  description = "rhine";
  nixConfig.bash-prompt = "\[rhine\]$ ";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    flake-utils.inputs.nixpkgs.follows = "nixpkgs";

    # hls.url = "github:haskell/haskell-language-server";
    # hls.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = { allowBroken = true; };
          overlays = [];
        };

        # Using pipe as this how to do function composition in nix
        # https://github.com/NixOS/nixpkgs/commit/8252861507ef85b45f739c63f27d4e9a80b31b31
        pipe = pkgs.lib.trivial.pipe;

        # abstract this pattern https://github.com/NixOS/nixpkgs/issues/26561#issuecomment-397350884
        # in the same spirit as https://github.com/haskell/haskell-language-server/blob/master/configuration-ghc-90.nix#L44 but without using extend
        tweak = hsPkgs : fun :
          hsPkgs.override (old: {
            overrides = pkgs.lib.composeExtensions (old.overrides or (_: _: {})) fun;
          });

        tweakM1 = hsPkgs : tweak hsPkgs (self: super:
          if system == "aarch64-darwin"
            then
              let
                # https://github.com/NixOS/nixpkgs/issues/140774#issuecomment-976899227
                workaround140774 = hpkg: with pkgs.haskell.lib;
                  overrideCabal hpkg (drv: {
                    enableSeparateBinOutput = false;
                  });
              in
                {
                  ghcid = workaround140774 super.ghcid;
                }
            else {});

        tweakGhc922 = hsPkgs : tweak hsPkgs (self: super : {
          network = pkgs.haskell.lib.dontCheck (self.callHackage "network" "3.1.2.5" {});
          retry = pkgs.haskell.lib.dontCheck (self.callHackage "retry" "0.9.2.0" {});
          OpenGL = self.callCabal2nix "OpenGL" (builtins.fetchGit {
            url = "https://github.com/haskell-opengl/OpenGL";
            rev = "f7af8fe04b0f19c260a85c9ebcad612737cd7c8c";
          }) {};
          GLFW-b = pkgs.haskell.lib.dontCheck (self.callHackage "GLFW-b" "1.4.8.4" {});
          gloss = pkgs.haskell.lib.dontCheck (pkgs.haskell.lib.appendConfigureFlags (self.callHackage "gloss" "1.13.2.2" {}) ["-f-GLFW" "-fGLUT" "-fexplicitbackend"]);
          gloss-rendering = pkgs.haskell.lib.dontCheck (self.callHackage "gloss-rendering" "1.13.1.2" {});
          vector-sized = pkgs.haskell.lib.dontCheck (self.callHackage "vector-sized" "1.4.4" {});
        });

        # haskellPackages for different ghc versions with the appropriate overrides
        # by pipe-ing composable tweaks
        ghc884  = pipe pkgs.haskell.packages.ghc884 [ tweakM1 ];
        ghc8107  = pipe pkgs.haskell.packages.ghc8107  [ tweakM1 ];
        ghc922  = pipe pkgs.haskell.packages.ghc922  [ tweakM1 tweakGhc922 ];

        # similar to https://github.com/IHaskell/IHaskell/blob/master/flake.nix#L34
        ghcDefault = ghc8107;

        # Source package names from cabal.project
        # fixed version of https://gist.github.com/codebje/000df013a2a4b7c10d6014d8bf7bccf3
        cabalPackages = with builtins; listToAttrs (if pathExists ./cabal.project
                                        then projectParse
                                        else [ { name = baseNameOf ./.; value = ./.; } ] );

        projectParse = with builtins; let
          contents = readFile ./cabal.project;
          trimmed = replaceStrings ["packages:" " "] ["" ""] contents;
          packages = filter (x: isString x && x != "") (split "\n" trimmed);
          package = p: substring 0 (stringLength p) p;
          paths = map (p: let p' = package p; in { name = p'; value = toPath (./. + "/${p'}"); } ) packages;
        in paths;

        # Using this idiom https://magnus.therning.org/2022-03-13-simple-nix-flake-for-haskell-development.html
        project = packageName: hp : devTools :
          hp.developPackage {
            name = packageName;
            root = ./${packageName};
            overrides = self: super: {
              # Use callCabal2nix to override Haskell dependencies here
              rhine = self.callCabal2nix "rhine" ./rhine {};
            };
            returnShellEnv = !(devTools == [ ]);
            modifier = drv: pkgs.haskell.lib.addBuildTools drv devTools;
          };
      in {

        # similar to https://github.com/IHaskell/IHaskell/blob/master/flake.nix#L70-L83
        packages.ghc8107.rhine = project "rhine" ghc8107 [];
        packages.ghc8107.rhine-examples = project "rhine-examples" ghc8107 [];
        packages.ghc922.rhine = project "rhine" ghc922 [];
        packages.ghc922.rhine-examples = project "rhine-examples" ghc922 [];

        packages.default = project "rhine" ghc8107 [];

        packages.all = cabalPackages;

        devShells.default = project "rhine" ghc922 (with ghc922; [
          # Specify your build/dev dependencies here.
          # cabal-fmt
          cabal-install
          ghcid
          # haskell-language-server
          # hls
          # hlint
          # fourmolu
          # pkgs.nixpkgs-fmt
          # pkgs.glfw
        ]);

        # check.test = pkgs.runCommand "combined-test"
        #     # {
        #     #   checksss = builtins.attrValues self.checks.${system};
        #     # }
        #     { buildInputs = [ hp.cabal-install]; }
        #   ''
        #     cabal test all
        #     touch $out
        #   '';

        # check = perSystem (system:
        #   (nixpkgsFor system).runCommand "combined-test"
        #     {
        #       checksss = builtins.attrValues self.checks.${system};
        #     } ''
        #     echo $checksss
        #     touch $out
        #   ''
        # );
        # # Used by `nix build` & `nix run` (prod exe)
        # defaultPackage = project [];
        # # Used by `nix develop` (dev shell)
        # devShell = project (with hp; [
        #   # Specify your build/dev dependencies here.
        #   # cabal-fmt
        #   cabal-install
        #   ghcid
        #   # haskell-language-server
        #   # hls
        #   # hlint
        #   # fourmolu
        #   # pkgs.nixpkgs-fmt
        #   # pkgs.glfw
        # ]);

      }
    );
}
