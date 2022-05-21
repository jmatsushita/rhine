{
  description = "rhine";
  nixConfig.bash-prompt = "\[rhine\]$ ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    haskell-flake-utils.url = "github:ivanovs-4/haskell-flake-utils";
    haskell-flake-utils.inputs.nixpkgs.follows = "nixpkgs";
    haskell-flake-utils.inputs.flake-utils.follows = "flake-utils";

  };

outputs = { self, nixpkgs, flake-utils, haskell-flake-utils, ... }@inputs:
  flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-darwin" ] (system:
    inputs.haskell-flake-utils.lib.simpleCabalProject2flake {
      inherit self nixpkgs system;

      name = "rhine";
      packageNames = ["rhine-gloss" "rhine-examples"];

    }
  );
}
