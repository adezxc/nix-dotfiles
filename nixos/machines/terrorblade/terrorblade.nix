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
  # upower is read-only with respect to charge thresholds — it never writes
  # /sys/class/power_supply/BAT0/charge_control_*_threshold, so it cannot
  # interfere with TLP's START/STOP_CHARGE_THRESH_BAT0. The daemon that
  # *does* conflict with TLP is power-profiles-daemon, which is not enabled
  # here (TLP would refuse to start / tlp-stat would warn otherwise).
  services.upower.enable = true;

  # This ThinkPad (T14 Gen 5 AMD) only supports s2idle (ACPI: S0 S4 S5, no
  # S3), which drains ~2%/h. On lid close, suspend first, then hibernate to
  # the LUKS-backed vg-swap LV after HibernateDelaySec. On AC just suspend.
  boot.resumeDevice = "/dev/mapper/vg-swap";
  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend";
  };
  systemd.sleep.settings.Sleep.HibernateDelaySec = "2h";

  # Faster hibernate image save/restore: compress with more threads (default
  # 3) and use lz4 instead of lzo (much faster decompression on resume).
  # lz4 is a module (CONFIG_CRYPTO_LZ4=m), so it must be in the initrd for
  # the resuming kernel to decompress the image.
  boot.kernelParams = [
    "hibernate.compressor=lz4"
    "hibernate_compression_threads=8"
  ];
  boot.initrd.kernelModules = ["lz4"];

  # Firmware updates (BIOS/EC, NVMe, etc.) via LVFS: `fwupdmgr refresh &&
  # fwupdmgr get-updates && fwupdmgr update`.
  services.fwupd.enable = true;

  services.tlp = {
    enable = true;
    settings = {
      # Battery care: keep the battery topped up near 80% at all times.
      # With START=75, the battery recharges as soon as it drops below 75%
      # (self-discharge while on AC), so it hovers at ~80% instead of
      # cycling the whole 50-80% band.
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;

      WIFI_PWR_ON_AC = "off";
      WIFI_PWR_ON_BAT = "off";

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

  # Make the ThinkPad mic-mute LED writable by the desktop user so the
  # fn+F4 handler in home-manager (niri.nix: micMuteToggle) can sync it
  # with the real PipeWire mute state. The LED lives in sysfs and has no
  # /dev node, so udev ownership rules don't apply; tmpfiles is the
  # simplest way to relax the mode (and it is re-applied on every
  # nixos-rebuild, not just at boot).
  systemd.tmpfiles.rules = [
    "f /sys/class/leds/platform::micmute/brightness 0666 - - -"
  ];

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

  environment.systemPackages = [
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  system.stateVersion = "25.11";
}
