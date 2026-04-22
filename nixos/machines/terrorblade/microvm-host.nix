{ pkgs, microvm, lib, inputs, ... }:

let
  pkgsStable = import inputs.nixpkgs-stable {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in
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

  # Allow forwarded traffic from the VM bridge
  networking.firewall.trustedInterfaces = [ "microbr" ];

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
      # Reserve .10 for the claude VM by MAC address
      dhcp-host = "02:00:00:00:00:01,192.168.83.10,claude-vm";
      server = [ "1.1.1.1" "8.8.8.8" ];
    };
  };

  # Define a microVM for Claude Code
  microvm.autostart = lib.mkForce [];
  microvm.vms.claude = {
    specialArgs = { inherit microvm; };
    config = { config, pkgs, ... }: {
      imports = [ microvm.nixosModules.microvm ];

      microvm = {
        hypervisor = "cloud-hypervisor";
        vcpu = 4;
        mem = 4096;

        # Persistent overlay for /var
        volumes = [{
          mountPoint = "/var";
          image = "var.img";
          size = 4096;
        }];

        shares = [
          # Share /nix/store from host (read-only)
          {
            tag = "ro-store";
            source = "/nix/store";
            mountPoint = "/nix/.ro-store";
            proto = "virtiofs";
          }
          # Claude credentials/state directory
          {
            tag = "claude-state";
            source = "/home/adam/claude-microvm";
            mountPoint = "/home/adam/claude-microvm";
            proto = "virtiofs";
          }
          # Stable SSH host keys (pre-generated on host)
          {
            tag = "ssh-host-keys";
            source = "/var/lib/microvm/claude/ssh-host-keys";
            mountPoint = "/etc/ssh/host-keys";
            proto = "virtiofs";
          }
        ];

        interfaces = [{
          type = "tap";
          id = "vm-claude";
          mac = "02:00:00:00:00:01";
        }];
      };

      systemd.network.enable = true;
      networking.useNetworkd = true;

      systemd.network.networks."20-eth" = {
        # Match any Ethernet-type interface (eth0, enp*, ens*, etc.)
        matchConfig.Name = "e*";
        networkConfig = {
          DHCP = "yes";
          IPv6AcceptRA = true;
        };
      };

      networking.hostName = "claude-vm";
      networking.firewall.enable = false;

      services.openssh = {
        enable = true;
        # Use pre-generated stable host keys shared from host
        hostKeys = [
          { type = "ed25519"; path = "/etc/ssh/host-keys/ssh_host_ed25519_key"; }
        ];
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };

      users.users.adam = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILB1AzLhbytJCN8V6o/BxnJ7hka4J8GoZWRR9lwvELKr adam@alchemist"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK1KUerwqjiAYOBOX9EsPjs0WUi+I1M5Qi0CHzo3ZmZq adam@terrorblade"
        ];
      };
      security.sudo.wheelNeedsPassword = false;

      environment.systemPackages = (with pkgs; [
        vim
        git
        curl
        htop
        nodejs
      ]) ++ [ pkgsStable.claude-code ];

      system.stateVersion = "24.11";
    };
  };

  # Attach microVM tap interfaces to the bridge
  systemd.network.networks."21-microvm" = {
    matchConfig.Name = "vm-*";
    networkConfig.Bridge = "microbr";
  };
}
