{
  description = "A flake with development tools needed to run this project";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs = { self, nixpkgs }: 
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = [
        pkgs.caddy
        pkgs.nssTools
      ];

      shellHook = ''
        export BLOG_DOMAIN=:3000 &&
        export BLOG_ROOT=./
      '';
    };
  };
}
