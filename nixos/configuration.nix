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
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nixpkgs = {
    config = {
      allowUnfree = true;
    };
  };

  nix = let
    flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
  in {
    settings = {
      experimental-features = "nix-command flakes";
      flake-registry = "";
      nix-path = config.nix.nixPath;
    };
    channel.enable = false;

    registry = lib.mapAttrs (_: flake: {inherit flake;}) flakeInputs;
    nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;
  };

  users.users = {
    adam = {
      hashedPassword = "$y$j9T$58X48SD.zSwdh0FbX6MNZ/$U6/ZzqJAmKrvFJ8nKytzXJ4Gn0ZOf7A.0VTSokOB5OD";
      isNormalUser = true;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILB1AzLhbytJCN8V6o/BxnJ7hka4J8GoZWRR9lwvELKr adam@alchemist"
      ];
      extraGroups = ["wheel"];
      shell = pkgs.zsh;
    };
  };

  # This setups a SSH server. Very important if you're setting up a headless system.
  # Feel free to remove if you don't need it.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
  };

  services.mullvad-vpn.enable = true;

  environment.systemPackages = (import ./packages.nix) pkgs;

  programs.neovim.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  programs.zsh.enable = true;

  networking.firewall.allowedTCPPorts = [22 80 443 8222];
  networking.firewall.allowedUDPPorts = [22 80 443 8222];
  networking.firewall.enable = true;

  system.stateVersion = "24.05";
}
