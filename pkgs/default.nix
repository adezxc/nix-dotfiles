# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  lidarr-nightly = pkgs.callPackage ./lidarr-nightly.nix { };
}
