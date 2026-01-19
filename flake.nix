{
  description = "joy-carousel";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    roc.url = "github:roc-lang/roc";
  };

  outputs = { nixpkgs, flake-utils, roc, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        rocPkgs = roc.packages.${system};
        rocFull = rocPkgs.full;
      in
      {
        formatter = pkgs.nixpkgs-fmt;

        devShells = {
          default = pkgs.mkShell {
            buildInputs = [
              rocFull
              pkgs.cargo
              pkgs.lld
              pkgs.rustc
              pkgs.wasm-pack
              pkgs.zig
              pkgs.simple-http-server
              pkgs.watchexec
              pkgs.playwright-test
            ];

            shellHook = ''
              export ROC_LANGUAGE_SERVER_PATH=${rocFull}/bin/roc_language_server
            '';
          };
        };
      });
}
