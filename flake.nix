{
  description = "Shellcode execution capabilities with memflow";

  inputs = {
    flake-utils.url = github:numtide/flake-utils;
    memflow.url = github:memflow/memflow-nixos;
    nixpkgs.url = github:nixos/nixpkgs/nixos-unstable;
    zig-overlay.url = github:arqv/zig-overlay;

    zig-win32 = {
      url = github:marlersoft/zigwin32/032a1b51b83b8fe64e0a97d7fe5da802065244c6;
      flake = false;
    };
    zig-clap = {
      flake = false;
      url = github:Hejsil/zig-clap/0970eb827fe53ad7a6c6744019707190d7b9bb32;
    };
    zig-args = {
      flake = false;
      url = github:MasterQ32/zig-args/1ff417ac1f31f8dbee3a31e5973b46286d42e71d;
    };
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
        memflowPkgs = builtins.mapAttrs
          (name: package:
            (package.overrideAttrs
              (super: {
                # dontStrip = true;
                # buildType = "debug";
              })
            )
          )
          inputs.memflow.packages.${system};
      in
      {
        packages = {
          memflow-shell = pkgs.stdenv.mkDerivation {
            name = "memflow-shell";

            nativeBuildInputs = with pkgs; with memflowPkgs; [
              pkg-config
              zig-overlay.packages.${system}.master.latest
              memflow
              # glibc
              breakpointHook
            ];

            src = ./.;

            dontInstall = true;

            postUnpack = ''
              rm -rf $sourceRoot/libs/
              mkdir -vp $sourceRoot/libs/{zigwin32,zig-clap,zig-args}/
              cp -a ${inputs.zig-win32}/* $sourceRoot/libs/zigwin32/
              cp -a ${inputs.zig-clap}/* $sourceRoot/libs/zig-clap/
              cp -a ${inputs.zig-args}/* $sourceRoot/libs/zig-args/
              chmod a+r+w $sourceRoot/libs/*
            '';
            buildPhase = ''
              test
              # Set Zig global cache directory
              export XDG_CACHE_HOME="$TMPDIR/zig-cache/"
              zig build install -Dtarget=native-native-musl --prefix $out
            '';

            meta = { };
          };
          default = self.packages.${system}.memflow-shell;
        };
        defaultPackage = self.packages.${system}.default;
      }
    );
}
