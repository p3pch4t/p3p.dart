{ pkgs ? import <nixpkgs> {}}:
pkgs.mkShell {
  packages = with pkgs; [ 
    dart
    gnumake42
    sqlite
  ];
}
