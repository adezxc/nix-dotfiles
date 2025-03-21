# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./packages.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "antimage"; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Enable networking
  networking.networkmanager.enable = true;

  systemd.services.NetworkManager-wait-online.enable = false;

  # Configure keymap in X11
  services.xserver = {
    layout = "us,lt,ru";
    xkbVariant = " ,us,phonetic";
    xkbOptions = "caps:swapescape,grp:alt_shift_toggle";
    enable = true;
    desktopManager = {
      xterm.enable = false;
    };
    displayManager = {
      defaultSession = "none+i3";
      lightdm.background = "/etc/nixos/background/landscape.jpg";
    };
    windowManager.i3 = {
      enable = true;
    };
  };

  users.users.adam.extraGroups = ["networkmanager" "wheel"];

  system.stateVersion = "24.05"; # Did you read the comment?
}
