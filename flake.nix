{
  description = "Shellcode execution capabilities with memflow";

  inputs = {
    flake.url = github:numtide/flake-utils;
    memflow.url = github:memflow/memflow-nixos;
    nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;
    zig-overlay.url = github:arqv/zig-overlay;
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay, ... } @ inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShell = pkgs.mkShell {
          nativeBuildInputs = with pkgs; [
            pkg-config
            zig-overlay.packages.${system}.master.latest
          ];

          buildInputs = with pkgs; with inputs.memflow.packages.${system}; [
            memflow
            memflow-kvm
          ];
        };
      }
    );
}
