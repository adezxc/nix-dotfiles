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
  ];

  networking.hostName = "phoenix";
  services.tailscale = {
    enable = true;
    extraUpFlags = ["--accept-dns=false"];
    useRoutingFeatures = "server";
  };

  security.sudo.wheelNeedsPassword = false;

  # With 15GB RAM there is no reason to swap out warm pages: swapping caused
  # latency spikes during media I/O (Jellyfin streaming/transcoding).
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
  };

  networking.firewall = {
    enable = true;
    trustedInterfaces = [
      "tailscale0"
    ];
  };

  system.stateVersion = "24.05";
}
