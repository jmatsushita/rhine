attrs:

let
  settings = import ./defaults.nix // attrs;
  haskellPackages = settings.pkgs.haskell.packages.${settings.compiler};
in
haskellPackages.override {
  overrides = super: self: {
    rhine = self.callCabal2nix "rhine" ../rhine {};
    rhine-examples = self.callCabal2nix "rhine-examples" ../rhine-examples {};
    rhine-gloss = self.callCabal2nix "rhine-gloss" ../rhine-gloss {};
    monadic-arrow = self.callCabal2nix "monadic-arrow" ../../monadic-arrow {}; # FIXME Replace by a github link soon, and then by a hackage, and then remove
    essence-of-live-coding = self.callCabal2nix "essence-of-live-coding" ../../essence-of-live-coding/essence-of-live-coding {}; # FIXME Replace by a github link soon, and then by a hackage, and then remove
    dunai-live = self.callCabal2nix "dunai-live" ../../dunai-live {}; # FIXME Replace by a github link soon, and then by a hackage, and then remove
  };
}
