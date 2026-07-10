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

            spimdisasm =
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
                inherit spimdisasm update-spimdisasm;
              };
            checks = {
              # Actually run spimdisasm so updates that break it (new
              # dependencies, python incompatibilities, ...) fail the check.
              spimdisasm-runs = pkgs.runCommand "spimdisasm-runs" { } ''
                ${packages.spimdisasm}/bin/spimdisasm --help > $out
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
