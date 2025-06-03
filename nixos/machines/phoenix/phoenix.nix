{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  # You can import other NixOS modules here
  imports = [
    ./hardware-configuration.nix
    ./media.nix
    ./packages.nix
    ./backups.nix
    ./wakapi.nix
    ./audioteka-abs.nix
  ];

  networking.hostName = "phoenix";
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };
}
