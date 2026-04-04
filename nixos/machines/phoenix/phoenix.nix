{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  flakeDir,
  ...
}: {
  # Bootloader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # You can import other NixOS modules here
  imports = [
    ./hardware-configuration.nix
    ./media.nix
    ./packages.nix
    ./backups.nix
    ./audioteka-abs.nix
    ./home-assistant.nix
    ./metrics.nix
    ./jellystat.nix
  ];

  networking.hostName = "phoenix";
  services.tailscale = {
    enable = true;
    extraUpFlags = [ "--accept-dns=false" ];
    useRoutingFeatures = "server";
  };

  security.sudo.wheelNeedsPassword = false;

  networking.firewall = {
    enable = true;
    trustedInterfaces = [
      "tailscale0"
    ];
  };

  system.stateVersion = "24.05";
}
