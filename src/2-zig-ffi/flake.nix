{
  description = "Inotify utility using Zig and Ruby";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [
        pkgs.ruby_3_4
        pkgs.tree
        pkgs.zig
        pkgs.zls
      ];
    };
  };
}

