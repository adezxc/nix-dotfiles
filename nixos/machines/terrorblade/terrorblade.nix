{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./microvm-host.nix
    ./packages.nix
  ];

  # Bootloader
  boot.loader.grub = {
    enable = true;
    device = "nodev";
    efiSupport = true;
    enableCryptodisk = true;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.supportedFilesystems = [ "btrfs" ];
  hardware.enableAllFirmware = true;

  networking.hostName = "terrorblade";
  networking.networkmanager.enable = true;

  # Use systemd-networkd for networking (needed for microvm bridge)
  networking.useNetworkd = true;
  systemd.network.enable = true;

  boot.initrd.luks.devices = {
    cryptroot = {
      device = "/dev/disk/by-uuid/ccd9ffae-429e-4206-9ef5-b20af982ac96";
      preLVM = true;
    };
  };

  time.timeZone = "Europe/Vilnius";

  services.openssh = {
    enable = true;
  };

  # Sway
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  # Autologin to sway via greetd
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.sway}/bin/sway";
      user = "adam";
    };
  };

  # Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # XDG portals
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Fonts
  fonts.packages = with pkgs; [
    meslo-lgs-nf
    hack-font
    noto-fonts
    noto-fonts-color-emoji
  ];

  hardware.graphics.enable = true;

  security.sudo.wheelNeedsPassword = false;
  security.polkit.enable = true;

  system.stateVersion = "25.11";
}
