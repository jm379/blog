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
        pkgs.libyaml
        pkgs.libffi
        pkgs.openssl
        pkgs.autoconf
        pkgs.automake
        pkgs.gcc
        pkgs.pkg-config
        pkgs.git
        pkgs.ruby_3_4
        pkgs.caddy
      ];
    };
  };
}
