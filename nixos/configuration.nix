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

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "aspnetcore-runtime-6.0.36"
    "aspnetcore-runtime-wrapped-6.0.36"
    "dotnet-sdk-6.0.428"
    "dotnet-sdk-wrapped-6.0.428"
  ];
  time.timeZone = "Europe/Vilnius";

  i18n.defaultLocale = "en_US.UTF-8";

  nix = let
    flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
  in {
    settings = {
      experimental-features = "nix-command flakes";
      flake-registry = "";
      nix-path = config.nix.nixPath;
      trusted-users = [
        "adam"
      ];
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
	"ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK1KUerwqjiAYOBOX9EsPjs0WUi+I1M5Qi0CHzo3ZmZq adam@terrorblade"
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

  fonts.packages = with pkgs; [
    font-awesome
    siji
    pango
  ] ++ builtins.filter lib.attrsets.isDerivation (builtins.attrValues pkgs.nerd-fonts);

  services.mullvad-vpn.enable = true;

  services.tailscale.enable = true;

  environment.systemPackages = (import ./packages.nix) pkgs;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings = {
  data-root = "/data/media/docker";
  };

  virtualisation.oci-containers = {
  backend = "docker";
  containers = {
    linkding = {
      image = "sissbruecker/linkding:latest";
      ports = ["127.0.0.1:9090:9090"];
      volumes = [
	"/data/media/linkding:/etc/linkding/data"
      ];
    };
  };
};


  programs.zsh.enable = true;

  networking.firewall.allowedTCPPorts = [22];
  networking.firewall.allowedUDPPorts = [22];
  networking.firewall.enable = true;

  system.stateVersion = "24.05";
}
