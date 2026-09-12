# Custom packages, that can be defined similarly to ones from nixpkgs
# You can build them using 'nix build .#example'
pkgs: {
  reclaimerr = pkgs.callPackage ./reclaimerr.nix {};
  lidarr-nightly = pkgs.callPackage ./lidarr-nightly.nix {};
}
