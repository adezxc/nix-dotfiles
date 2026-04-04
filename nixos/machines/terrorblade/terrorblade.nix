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

  programs.openvpn3.enable = true;

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

  services.tlp = {
    enable = true;
    settings = {
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0 = 80;

      # WiFi powersave off (unreliable, causes latency spikes)
      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "off";

      # CPU
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_BOOST_ON_AC = 1;
      CPU_BOOST_ON_BAT = 0;

      # Runtime power management for PCI/USB
      RUNTIME_PM_ON_AC = "on";
      RUNTIME_PM_ON_BAT = "auto";
    };
  };

  security.sudo.wheelNeedsPassword = false;
  security.polkit.enable = true;

  system.stateVersion = "25.11";
}
