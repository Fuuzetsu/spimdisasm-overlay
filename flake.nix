{
  description = "spimdisasm";
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs = {
      type = "github";
      owner = "NixOS";
      repo = "nixpkgs";
      ref = "22.11";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    pip2nix = {
      url = "github:nix-community/pip2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spimdisasm = {
      url = "github:Decompollaborate/spimdisasm";
      flake = false;
    };
  };

  outputs =
    inputs@{ self
    , nixpkgs
    , flake-utils
    , flake-compat
    , spimdisasm
    , pip2nix
    }:
    let
      outputs = flake-utils.lib.eachDefaultSystem
        (system:
          let
            pkgs = import nixpkgs {
              inherit system;
              overlays = [

              ];
            };

            spimdisasm =
              let
                packageOverrides = pkgs.callPackage ./python-packages.nix { };
                python = pkgs.python3.override { inherit packageOverrides; };
                dependencyNames = pkgs.lib.attrsets.attrNames (packageOverrides null null);
                spimdisasmPython = python.withPackages (ps: builtins.map (n: ps."${n}") dependencyNames);
              in
              pkgs.writeShellScriptBin "spimdisasm" ''
                ${spimdisasmPython}/bin/python ${inputs.spimdisasm}/spimdisasm "$@"
              '';

            # Update script for this repo.
            #
            # I thought I was supposed to be able to do
            # inputs.pip2nix.defaultPackages.${system} and get pip2nix via flake but
            # it's crying about something I don't understand so we're doing this weird
            # thing...

            update-spimdisasm = pkgs.writeShellScriptBin "update-spimdisasm" ''
              ${pkgs.nix}/bin/nix flake lock --update-input spimdisasm \
                  --extra-experimental-features nix-command \
                  --extra-experimental-features flakes
              nix run \
                  --extra-experimental-features nix-command \
                  --extra-experimental-features flakes \
                  ${inputs.pip2nix}# -- \
                  generate -r ${inputs.spimdisasm}/requirements.txt \
                  -e spimdisasm
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
              spimdisasm-builds = packages.spimdisasm;
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
