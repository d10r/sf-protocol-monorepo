{
  description = "Overlay for working with Superfluid protocol monorepo";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    foundry.url = "github:shazow/foundry.nix/monthly";
    foundry.inputs.nixpkgs.follows = "nixpkgs";
    foundry.inputs.flake-utils.follows = "flake-utils";
    # solc static binary compilers
    solc.url = "github:hellwolf/solc.nix";
    solc.inputs.nixpkgs.follows = "nixpkgs";
    solc.inputs.flake-utils.follows = "flake-utils";
    # certora tools
    certora.url = "github:hellwolf/certora.nix";
    certora.inputs.nixpkgs.follows = "nixpkgs";
    certora.inputs.flake-utils.follows = "flake-utils";
    # TODO use ghc 9.6 when available
    ghc-wasm.url = "gitlab:ghc/ghc-wasm-meta?host=gitlab.haskell.org";
    ghc-wasm.inputs.nixpkgs.follows = "nixpkgs";
    ghc-wasm.inputs.flake-utils.follows = "flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, solc, foundry, certora, ghc-wasm } :
  flake-utils.lib.eachDefaultSystem (system:
  let
    pkgs = import nixpkgs {
      inherit system;
      overlays = [
        solc.overlay
        foundry.overlay
      ];
    };

    # minimem development shell
    minimumEVMDevInputs = with pkgs; [
      # for nodejs ecosystem
      yarn
      nodejs-18_x
      # for solidity development
      solc_0_8_19
      foundry-bin
    ];
    # additional tooling for whitehat hackers
    whitehatInputs = with pkgs; [
      slither-analyzer
      echidna
    ];
    # for developing specification
    ghcVer = "ghc944";
    ghc = pkgs.haskell.compiler.${ghcVer};
    ghcPackages = pkgs.haskell.packages.${ghcVer};
    specInputs = with pkgs; [
      # for nodejs ecosystem
      yarn
      gnumake
      nodePackages.nodemon
      # for haskell spec
      cabal-install
      ghc
      ghc-wasm.packages.${system}.default
      ghcPackages.haskell-language-server
      hlint
      stylish-haskell
      # certora
      python3
      # sage math
      sage
      # testing tooling
      gnuplot
      # yellowpaper pipeline tooling
      ghcPackages.lhs2tex
      python39Packages.pygments
      (texlive.combine {
        inherit (texlive)
        scheme-basic metafont
        collection-latex collection-latexextra
        collection-bibtexextra collection-mathscience
        collection-fontsrecommended collection-fontsextra;
      })
    ] ++ certora.devInputs.${system};
    ci-spec = ghcVer : with pkgs; mkShell {
      buildInputs = [
        gnumake
        cabal-install
        haskell.compiler.${ghcVer}
        hlint
      ];
    };
  in {
    devShells.default = with pkgs; mkShell {
      buildInputs = minimumEVMDevInputs;
    };
    devShells.whitehat = with pkgs; mkShell {
      buildInputs = minimumEVMDevInputs
        ++ whitehatInputs;
    };
    devShells.spec = with pkgs; mkShell {
      buildInputs = minimumEVMDevInputs
        ++ specInputs;
    };
    devShells.full = with pkgs; mkShell {
      buildInputs = minimumEVMDevInputs
      ++ whitehatInputs
      ++ specInputs;
    };
    devShells.ci-spec-ghc925 = ci-spec "ghc925";
    devShells.ci-spec-ghc944 = ci-spec "ghc944";
    devShells.ci-hot-fuzz = with pkgs; mkShell {
      buildInputs = [
        slither-analyzer
        echidna
      ];
    };
  });
}
