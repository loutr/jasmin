{
  description = "Jasmin";

  inputs.nixpkgs.url = "nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;

      rocqOverlay = self: super: {
        coq-elpi = super.coq-elpi.override {
          version = "2.5.2";
          elpi-version = "2.0.7";
        };
        hierarchy-builder = super.hierarchy-builder.override { version = "1.9.1"; };
        mathcomp = super.mathcomp.override { version = "2.4.0"; };
        mathcomp-word = self.callPackage scripts/mathcomp-word.nix { inherit super; };
      };

      overlays = [
        (final: super: {
          coqPackages = super.coqPackages_9_0.overrideScope rocqOverlay;
          inherit (final.coqPackages.coq) ocamlPackages;
        })
      ];

      options = with lib; genAttrs systems.flakeExposed (system: rec {
        inherit system; selfPackages = self.packages.${system};
        pkgs = import nixpkgs { inherit system overlays; };
      });

      genOut = _: f: builtins.mapAttrs (_: f) options;
    in
    builtins.mapAttrs genOut {
      packages = { selfPackages, pkgs, ... }: {
        default = selfPackages.jasmin;

        rocq-mcp = pkgs.callPackage scripts/rocq-mcp.nix { };

        jasmin = pkgs.stdenv.mkDerivation {
          name = "jasmin";
          src = ./.;

          nativeBuildInputs =
            (with pkgs.coqPackages; [
              ITree
              coq
              mathcomp-word
            ]) ++
            (with pkgs.ocamlPackages; [
              camlidl
              cmdliner
              dune_3
              findlib
              menhir
              ocaml
            ]);

          buildInputs =
            (with pkgs; [
              # selfPackages.mathcomp-word # includes ppx_deriving for some reason
              mpfr
              ppl
              # easycrypt
              # z3.out
            ])
            ++ (with pkgs.ocamlPackages; [
              apron
              yojson
            ]);

          propagatedNativeBuildInputs =
            (with pkgs.ocamlPackages; [
              angstrom
              batteries
              menhirLib
              zarith
            ]);

          checkInputs = (with pkgs; [
            curl.bin
            llvmPackages.bintools-unwrapped
            ocamlPackages.apron.out
          ]) ++ (with pkgs.python3Packages; [ python pyyaml ]);

          enableParallelBuilding = true;

          installPhase = ''
            make -C compiler install PREFIX=$out
          '';
        };
      };

      devShells = { selfPackages, pkgs, ... }: {
        default = pkgs.mkShell {
          dontDetectOcamlConflicts = true;

          inherit (selfPackages.default) name;
          inputsFrom = [ selfPackages.default ];
          packages = (with pkgs.ocamlPackages; [ merlin ocaml-lsp ocamlformat ])
            ++ [ selfPackages.rocq-mcp ];

          # The proofs are large; rocq-mcp's 30s default expires while pet is
          # still replaying a file's dependencies.
          ROCQ_PET_TIMEOUT = "300";

          # rocq-mcp constrains every path it resolves to this root, and pet
          # needs it to pick up proofs/_CoqProject. It is the checkout, not a
          # store path, so it cannot be a plain attribute.
          shellHook = ''
            export ROCQ_WORKSPACE="$(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD")/proofs"
          '';
        };
      };
    };
}
