{
  description = "rhine";
  nixConfig.bash-prompt = "\[rhine\]$ ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";

    flake-modules-core.url = "github:hercules-ci/flake-modules-core";
    flake-modules-core.inputs.nixpkgs.follows = "nixpkgs";

    # haskell-flake-utils.url = "path:/Users/jun/dev/workshop/haskell-flake-utils";
    # haskell-flake-utils.url = "github:jmatsushita/haskell-flake-utils/systems";
    haskell-flake-utils.url = "github:ivanovs-4/haskell-flake-utils";
    haskell-flake-utils.inputs.nixpkgs.follows = "nixpkgs";
    haskell-flake-utils.inputs.flake-utils.follows = "flake-utils";

    hls.url = "github:haskell/haskell-language-server";
    hls.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs = { self, nixpkgs, flake-utils, haskell-flake-utils, flake-modules-core, ... }:
    flake-modules-core.lib.mkFlake { inherit self; } {
      imports = [
        # To import a flake module
        # 1. Add foo to inputs
        # 2. Add foo as a parameter to the outputs function
        # 3. Add here: foo.flakeModule

      ];
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      perSystem = system: { config, self', inputs', pkgs, ... }:
        let
        # pkgs = import nixpkgs {
        #   inherit system;
        #   config = { allowBroken = true; };
        #   overlays = [];
        # };
        hp = pkgs.haskell.packages.ghc902;
        project = devTools :
          hp.developPackage {
            returnShellEnv = !(devTools == [ ]);
            name = "rhine";
            root = ./rhine;
            # Use source-overrides instead https://github.com/NixOS/cabal2nix/blob/master/doc/frequently-asked-questions.rst#how-to-specify-source-overrides-for-your-haskell-package
            overrides = self: super: {
              # Use callCabal2nix to override Haskell dependencies here
              rhine = self.callCabal2nix "rhine" ./rhine {};
              rhine-examples = self.callCabal2nix "rhine-examples" ./rhine-examples {};
              rhine-gloss = self.callCabal2nix "rhine-gloss" ./rhine-gloss {};
            };
            modifier = drv: pkgs.haskell.lib.addBuildTools drv devTools;
          };
        shell = pkgs.haskellPackages.shellFor {
          packages = p: [
            # p.rhine
            # p.rhine-gloss
            # p.rhine-examples
          ];
        };

      in
      {
        # Per-system attributes can be defined here. The self' and inputs'
        # module parameters provide easy access to attributes of the same
        # system.

        # Equivalent to  inputs'.nixpkgs.legacyPackages.hello;
        # packages.hello = pkgs.hello;
        # packages = (haskell-flake-utils.lib.simpleCabalProject2flake {
        #   inherit self nixpkgs system;

        #   name = "rhine";
        #   packageNames = ["rhine-gloss" "rhine-terminal" "rhine-examples"];
        #   compiler = "ghc902";
        #   # shellExtBuildInputs = [ hls ];
        #   # shellWithHoogle = true;
        # }).packages;

        packages.rhine = hp.callPackage ./rhine/package.nix { };
        # packages.rhine = hp.callCabal2nix "rhine" ./rhine {};
        # packages.rhine-examples = hp.callCabal2nix "rhine-examples" ./rhine-examples {};
        # packages.rhine-gloss = hp.callCabal2nix "rhine-gloss" ./rhine-gloss {};

        # checks = {
        #   x86_64-linux = pkgs.lib.mkForce {};
        # } // pkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
        #   test = pkgs.runCommand "cabal test all" {};
        # };

        devShells.default = shell;
        # devShell = shell;

        # packages = project [];
        # Used by `nix develop` (dev shell)
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
      };
      flake = {

        # for repl exploration / debug
        # config.config = config;

      };
        # The usual flake attributes can be defined here, including system-
        # agnostic ones like nixosModule and system-enumerating ones, although
        # those are more easily expressed in perSystem.
    };


  # outputs = { self, nixpkgs, flake-utils, haskell-flake-utils, flake-modules-core, ... }:
  #   flake-modules-core.lib.mkFlake { inherit self; } {
  #     imports = [
  #       # To import a flake module
  #       # 1. Add foo to inputs
  #       # 2. Add foo as a parameter to the outputs function
  #       # 3. Add here: foo.flakeModule

  #     ];
  #     systems = [ "x86_64-linux" "aarch64-darwin" ];
  #     perSystem = system: { config, self', inputs', pkgs, ... }: {
  #       # Per-system attributes can be defined here. The self' and inputs'
  #       # module parameters provide easy access to attributes of the same
  #       # system.

  #       # Equivalent to  inputs'.nixpkgs.legacyPackages.hello;
  #       # packages.hello = pkgs.hello;
  #       packages = (haskell-flake-utils.lib.simpleCabalProject2flake {
  #         inherit self nixpkgs system;

  #         name = "rhine";
  #         packageNames = ["rhine-gloss" "rhine-terminal" "rhine-examples"];
  #         compiler = "ghc902";
  #         # shellExtBuildInputs = [ hls ];
  #         # shellWithHoogle = true;
  #       }).packages;
  #     };
  #     flake = {};
  #       # The usual flake attributes can be defined here, including system-
  #       # agnostic ones like nixosModule and system-enumerating ones, although
  #       # those are more easily expressed in perSystem.
  #   };

  # outputs = { self, nixpkgs, flake-utils, haskell-flake-utils, hls,... }@inputs:
  #   flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-darwin" ] (system:
  #     haskell-flake-utils.lib.simpleCabalProject2flake {
  #       inherit self nixpkgs system;

  #       name = "rhine";
  #       packageNames = ["rhine-gloss" "rhine-terminal" "rhine-examples"];
  #       compiler = "ghc902";
  #       # shellExtBuildInputs = [ hls ];
  #       # shellWithHoogle = true;
  #     });
}
