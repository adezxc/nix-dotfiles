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

  # Kernel from a pinned nixpkgs so the patched kernel isn't rebuilt on
  # every `nix flake update`. Bump the `nixpkgs-kernel` rev in flake.nix
  # to update the kernel.
  boot.kernelPackages = inputs.nixpkgs-kernel.legacyPackages.${pkgs.stdenv.hostPlatform.system}.linuxPackages_latest;
  boot.supportedFilesystems = ["btrfs"];
  hardware.enableAllFirmware = true;

  virtualisation.docker.enable = true;

  networking.hostName = "terrorblade";
  networking.networkmanager.enable = true;

  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.wait-online.enable = false;

  programs.openvpn3.enable = true;

  boot.initrd.luks.devices = {
    cryptroot = {
      device = "/dev/disk/by-uuid/ccd9ffae-429e-4206-9ef5-b20af982ac96";
      preLVM = true;
    };
  };

  time.timeZone = "Europe/Vilnius";

  # Swap Caps Lock <-> Escape on the built-in laptop keyboard only, at the
  # kernel/evdev level (udev hwdb), so it works independently of niri's
  # single global xkb config. External USB keyboards are unaffected.
  # `atkbd` matches the internal "AT Translated Set 2 keyboard".
  # Scancodes (from `evtest`, MSC_SCAN): 0x3a = Caps Lock, 0x01 = Escape.
  services.udev.extraHwdb = ''
    evdev:atkbd:*
     KEYBOARD_KEY_3a=esc
     KEYBOARD_KEY_01=capslock
  '';

  services.openssh = {
    enable = true;
  };

  # Niri. The compositor itself is configured via home-manager
  # (wayland.windowManager.niri in home-manager/niri.nix).
  #
  # Binary cache for the noctalia flake input (see flake.nix).
  nix.settings = {
    extra-substituters = ["https://noctalia.cachix.org"];
    extra-trusted-public-keys = ["noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="];
  };

  # Autologin to niri via greetd. niri-session starts niri through the
  # user's systemd manager (units are installed by home-manager), which
  # imports the environment for spawned commands.
  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.niri}/bin/niri-session";
      user = "adam";
    };
  };

  # Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # XDG portals — niri uses the GNOME portal for screencasting and the
  # GTK portal for file dialogs.
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.xdg-desktop-portal-gtk pkgs.xdg-desktop-portal-gnome];
  };

  # Fonts
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
  ];

  programs.chromium = {
    enable = true;
    extraOpts = {
      "OzonePlatform" = "wayland";
    };
  };

  # Use the NixOS Steam module so 32-bit GL/Vulkan drivers are available.
  programs.steam.enable = true;

  hardware.graphics.enable = true;

  hardware.logitech.wireless.enable = true;

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # Expose battery status over D-Bus for Noctalia and other desktop apps.
  services.upower.enable = true;

  services.tlp = {
    enable = true;
    settings = {
      START_CHARGE_THRESH_BAT0 = 50;
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

  programs.nix-ld.enable = true;

  security.pam.loginLimits = [
    {
      domain = "*";
      type = "soft";
      item = "nofile";
      value = "655350";
    }
    {
      domain = "*";
      type = "hard";
      item = "nofile";
      value = "655350";
    }
  ];

  security.sudo.wheelNeedsPassword = false;
  security.polkit.enable = true;

  system.stateVersion = "25.11";
}
