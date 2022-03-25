{
  description = "Shellcode execution capabilities with memflow";

  inputs = {
    flake-utils.url = github:numtide/flake-utils;
    memflow.url = github:memflow/memflow-nixos;
    nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;
    zig-overlay.url = github:arqv/zig-overlay;
  };

  nixConfig = {
    extra-substituters = [ https://memflow.cachix.org ];
    extra-trusted-public-keys = [ memflow.cachix.org-1:t4ufU/+o8xtYpZQc9/AyzII/sohwMKGYNIMgT56CgXA= ];
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay, ... } @ inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;
      in
      {
        packages = {
          memflow-shell = pkgs.stdenv.mkDerivation {
            name = "memflow-shell";

            nativeBuildInputs = with pkgs; with inputs.memflow.packages.${system}; [
              pkg-config
              zig-overlay.packages.${system}.master.latest
              memflow
            ];

            src = ./.;

            buildPhase = ''
              # Set Zig global cache directory
              export XDG_CACHE_HOME="$TMPDIR/zig-cache/"
              zig build
            '';
            installPhase = ''
              zig build install --prefix $out
            '';

            meta = { };
          };
          default = self.packages.${system}.memflow-shell;
        };
        defaultPackage = self.packages.${system}.default;
      }
    );
}
