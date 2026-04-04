{ pkgs, microvm, lib, ... }:

{
  # Bridge network for microVMs
  systemd.network.netdevs."20-microbr" = {
    netdevConfig = {
      Kind = "bridge";
      Name = "microbr";
    };
  };

  systemd.network.networks."20-microbr" = {
    matchConfig.Name = "microbr";
    addresses = [{ Address = "192.168.83.1/24"; }];
    networkConfig.ConfigureWithoutCarrier = true;
  };

  # NAT for microVM internet access
  networking.nat = {
    enable = true;
    internalInterfaces = [ "microbr" ];
    externalInterface = "wlp2s0";  # WiFi interface
  };

  # DNS for microVMs
  services.dnsmasq = {
    enable = true;
    settings = {
      interface = "microbr";
      bind-interfaces = true;
      dhcp-range = "192.168.83.10,192.168.83.254,24h";
      dhcp-option = [
        "option:router,192.168.83.1"
        "option:dns-server,192.168.83.1"
      ];
      server = [ "1.1.1.1" "8.8.8.8" ];
    };
  };

  # Define a microVM for Claude Code
  microvm.vms.claude = {
    specialArgs = { inherit microvm; };
    config = { config, pkgs, ... }: {
      imports = [ microvm.nixosModules.microvm ];

      microvm = {
        hypervisor = "qemu";
        vcpu = 2;
        mem = 2049;

        # Ephemeral overlay for /var
        volumes = [{
          mountPoint = "/var";
          image = "var.img";
          size = 4096;
        }];

        # Share /nix/store from host (read-only)
        shares = [{
          tag = "ro-store";
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
          proto = "virtiofs";
        }];

        interfaces = [{
          type = "tap";
          id = "vm-claude";
          mac = "02:00:00:00:00:01";
        }];
      };

      # Network inside the microVM
      systemd.network.enable = true;
      networking.useNetworkd = true;

      systemd.network.networks."20-eth" = {
        matchConfig.Type = "ether";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = true;
        };
      };

      networking.hostName = "claude-vm";
      networking.firewall.enable = false;

      services.openssh = {
        enable = true;
        settings.PermitRootLogin = "yes";
      };

      users.users.adam = {
        isNormalUser = true;
        initialPassword = "nixos";
        extraGroups = [ "wheel" ];
      };
      users.users.root.initialPassword = "nixos";
      security.sudo.wheelNeedsPassword = false;

      environment.systemPackages = with pkgs; [
        vim
        git
        curl
        htop
        nodejs
      ];

      system.stateVersion = "24.11";
    };
  };

  # Attach microVM tap interfaces to the bridge
  systemd.network.networks."21-microvm" = {
    matchConfig.Name = "vm-*";
    networkConfig.Bridge = "microbr";
  };
}
