{
  description = "rhine";
  nixConfig.bash-prompt = "\[rhine\]$ ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    haskell-flake-utils.url = "path:/Users/jun/dev/workshop/haskell-flake-utils";
    # haskell-flake-utils.url = "github:jmatsushita/haskell-flake-utils/systems";
    haskell-flake-utils.inputs.nixpkgs.follows = "nixpkgs";
    haskell-flake-utils.inputs.flake-utils.follows = "flake-utils";

    hls.url = "github:haskell/haskell-language-server";
    hls.inputs.nixpkgs.follows = "nixpkgs";

  };

outputs = { self, nixpkgs, flake-utils, haskell-flake-utils, hls,... }@inputs:
  # flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-darwin" ] (system:
    inputs.haskell-flake-utils.lib.simpleCabalProject2flake {
      inherit self nixpkgs;

      name = "rhine";
      packageNames = ["rhine-gloss" "rhine-terminal" "rhine-examples"];
      compiler = "ghc902";
      # shellExtBuildInputs = [ hls ];
      # shellWithHoogle = true;
    };
  # );
}
