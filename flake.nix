{
  description = "spimdisasm";
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "nixos-26.05";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spimdisasm = {
      url = "github:Decompollaborate/spimdisasm";
      flake = false;
    };
    # spimdisasm's one compiled dependency; it is not packaged in nixpkgs,
    # so we build it from source and track it alongside spimdisasm itself.
    rabbitizer = {
      url = "github:Decompollaborate/rabbitizer";
      flake = false;
    };
  };

  outputs =
    inputs@{ self
    , nixpkgs
    , flake-utils
    , flake-compat
    , spimdisasm
    , pyproject-nix
    , rabbitizer
    }:
    let
      outputs = flake-utils.lib.eachDefaultSystem
        (system:
          let
            pkgs = import nixpkgs {
              inherit system;
            };

            python = pkgs.python3.override {
              packageOverrides = self: _super: {
                rabbitizer = self.buildPythonPackage {
                  pname = "rabbitizer";
                  version = (builtins.fromTOML
                    (builtins.readFile "${inputs.rabbitizer}/pyproject.toml")).project.version;
                  pyproject = true;
                  src = inputs.rabbitizer;
                  build-system = [ self.setuptools self.wheel ];
                };
              };
            };

            # The python application itself. Exposed as `spimdisasm-python` for
            # consumers that genuinely want the library on their PYTHONPATH.
            spimdisasm-python =
              let
                # spimdisasm declares its dependencies dynamically via
                # requirements.txt; pyproject.nix parses it at eval time and
                # resolves the names from the python package set, so
                # dependency changes upstream are picked up automatically.
                deps = pyproject-nix.lib.project.loadRequirementsTxt {
                  requirements = "${inputs.spimdisasm}/requirements.txt";
                };
              in
              python.pkgs.buildPythonApplication {
                pname = "spimdisasm";
                version = (builtins.fromTOML
                  (builtins.readFile "${inputs.spimdisasm}/pyproject.toml")).project.version;
                pyproject = true;
                src = inputs.spimdisasm;
                build-system = [ python.pkgs.setuptools python.pkgs.wheel ];
                # Upstream lists twine (a release tool) in build-system
                # requires; skip the check instead of pulling it into the
                # build.
                pypaBuildFlags = [ "--skip-dependency-check" ];
                dependencies =
                  (deps.renderers.withPackages { inherit python; }) python.pkgs;
                pythonImportsCheck = [ "spimdisasm" ];
              };

            # What consumers actually get: the executables, and nothing else.
            #
            # A buildPythonApplication placed in a devShell's inputs drags its
            # own site-packages and every propagated dependency onto PYTHONPATH.
            # PYTHONPATH is honoured by *every* interpreter on the shell, not
            # just this one — so it silently hijacks unrelated tools that vendor
            # their own, incompatible spimdisasm. splat is exactly that: it runs
            # its own python 3.10 env pinning spimdisasm ~1.13, and picking up a
            # newer 1.42 (built for python 3.13) from PYTHONPATH made it call a
            # rabbitizer API its bundled rabbitizer 1.7 does not implement,
            # dying with `SystemError: PY_SSIZE_T_CLEAN macro must be defined
            # for '#' formats` deep inside splat's data disassembly.
            #
            # Symlinking just $out/bin gives a derivation with no python setup
            # hooks and no propagated python deps, so nothing is exported. The
            # scripts in $out/bin are already wrapped with their own PYTHONPATH,
            # so they keep working regardless of the caller's environment.
            spimdisasm = pkgs.runCommandLocal "spimdisasm-${spimdisasm-python.version}" { } ''
              mkdir -p "$out/bin"
              for f in ${spimdisasm-python}/bin/*; do
                ln -s "$f" "$out/bin/$(basename "$f")"
              done
            '';

            # Update script for this repo.
            update-spimdisasm = pkgs.writeShellScriptBin "update-spimdisasm" ''
              ${pkgs.nix}/bin/nix flake update spimdisasm rabbitizer \
                  --extra-experimental-features nix-command \
                  --extra-experimental-features flakes
            '';
          in
          rec
          {
            legacyPackages = { };

            packages = flake-utils.lib.flattenTree
              {
                inherit spimdisasm spimdisasm-python update-spimdisasm;
              };
            checks = {
              # Actually run spimdisasm so updates that break it (new
              # dependencies, python incompatibilities, ...) fail the check.
              spimdisasm-runs = pkgs.runCommand "spimdisasm-runs" { } ''
                ${packages.spimdisasm}/bin/spimdisasm --help > $out
              '';

              # The exposed package must not leak its library onto PYTHONPATH:
              # doing so hijacks other tools' vendored spimdisasm (see the note
              # on the `spimdisasm` derivation). A devShell that includes it must
              # come out with an empty PYTHONPATH.
              spimdisasm-does-not-leak-pythonpath =
                pkgs.runCommand "spimdisasm-does-not-leak-pythonpath"
                  { nativeBuildInputs = [ packages.spimdisasm ]; } ''
                  if [ -n "''${PYTHONPATH:-}" ]; then
                    echo "spimdisasm leaked PYTHONPATH=$PYTHONPATH" >&2
                    exit 1
                  fi
                  spimdisasm --help > /dev/null
                  touch "$out"
                '';
            };
          });
    in
    outputs //
    {
      overlays.default = final: _prev: {
        spimdisasm = outputs.packages.${final.system}.spimdisasm;
      };
    };
}
