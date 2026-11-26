{
  description = "joy-carousel";

  nixConfig = {
    extra-substituters = [ "https://niclas-ahden.cachix.org" ];
    extra-trusted-public-keys = [ "niclas-ahden.cachix.org-1:FdGli1vBk0cTuVJV27Tau/JvlbW+Ly3pRwFByyqdke0=" ];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # Roc compiler revision, keep the `?dir=src` at the end.
    roc-src.url = "github:roc-lang/roc/ee835686f9eae076bee7422c26e7cf8deb20aa0e?dir=src";
    # roc-nix keeps its own nixpkgs, so the compiler is the one its cache holds
    # for this Roc commit. Everything else in the shell comes from the nixpkgs
    # above.
    roc-nix = {
      url = "github:niclas-ahden/roc-nix";
      inputs.roc-src.follows = "roc-src";
    };
  };

  outputs = { nixpkgs, flake-utils, roc-nix, ... }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Builds Roc using `ReleaseFast`. To chase a suspected compiler fault,
        # build a `ReleaseSafe` variant of the same revision:
        #
        #   roc-nix.lib.${system}.mkRoc { optimize = "ReleaseSafe"; }
        #
        # roc-nix's README lists the rest of the build options, patches
        # included.
        roc = roc-nix.packages.${system}.roc;
      in
      {
        formatter = pkgs.nixpkgs-fmt;

        packages = {
          inherit roc;
          default = roc;
        };

        devShells = {
          default = pkgs.mkShell {
            buildInputs = [
              roc
              pkgs.watchexec
              # The browser suite (tests/*_test.roc) drives Chromium through
              # roc-playwright. Its version comes from the nixpkgs in flake.lock.
              # Keep the npm version in .github/scripts/setup.sh, which the
              # Windows CI legs install, at the same version.
              pkgs.playwright-test
              pkgs.nodejs
            ];

            shellHook = ''
              export ROC_LANGUAGE_SERVER_PATH=${roc}/bin/roc
              export PLAYWRIGHT_BROWSERS_PATH=${pkgs.playwright-driver.browsers}
              export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
            '';
          };
        };
      });
}
