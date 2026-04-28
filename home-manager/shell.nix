{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  home.sessionPath = [
    "/home/adam/bin"
  ];

  services.ssh-agent.enable = true;

  programs = {
    ssh = {
      enable = true;
      enableDefaultConfig = false;
      matchBlocks = {
        "*" = {
          addKeysToAgent = "yes";
        };
        "claude-vm" = {
          hostname = "192.168.83.10";
          user = "adam";
          extraOptions.StrictHostKeyChecking = "accept-new";
        };
        "*.vinted.infra *.vinted.net" = {
          user = "ajasinski";
          addKeysToAgent = "yes";
          forwardAgent = true;
          identityFile = "~/.ssh/vinted_ed25519";
          extraOptions.SetEnv = ''LC_CTYPE="en_US.UTF-8"'';
        };
      };
    };

    jujutsu = {
      enable = true;
      settings = {
        user = {
          name = "Adam Jasinski";
          email = "adam.jasinski@vinted.com";
        };
        templates = {
          commit_trailers = "\n  format_signed_off_by_trailer(self)\n";
        };
      };
    };

    git = {
      enable = true;
      signing.format = null;
      ignores = [
        "CLAUDE.md"
        ".codex"
        ".claude"
        ".envrc"
        ".direnv"
      ];
      settings = {
        alias.s = "status";
        user.email = "adam@jasinski.lt";
        user.name = "Adam Jasinski";
      };
      includes = [
        {
          condition = "gitdir:~/git/vinted/";
          contents.user.email = "adam.jasinski@vinted.com";
        }
      ];
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      shellAliases = {
        ll = "ls -l";
        update = "sudo nixos-rebuild switch";
        k = "kubectl";
        today = "date '+%Y-%m-%d'";
      };

      envExtra = ''
        [ -f ~/.zshenv.local ] && source ~/.zshenv.local
      '';

      sessionVariables = {
        KITCHEN_DRIVER = "digitalocean";
        FZF_ALT_C_COMMAND = "";
      };

      history = {
        size = 10000;
        path = "${config.xdg.dataHome}/zsh/history";
      };

      initContent = ''
        autoload edit-command-line
        zle -N edit-command-line
        bindkey '^Xe' edit-command-line
        bindkey '^W' vi-backward-kill-word

        if [[ -n $SSH_CONNECTION ]]; then
          export EDITOR='vim'
        else
          export EDITOR='nvim'
        fi

        eval "$(kubectl completion zsh)"

        knife-a() { knife $@ --profile ams1 }
        knife-b() { knife $@ --profile bru1 }
        knife-d() { knife $@ --profile dus1 }
        knife-dedge() { knife $@ --profile dus2 }

        vm-claude() {
          local action="''${1:-ssh}"
          case "$action" in
            start) sudo systemctl start microvm@claude ;;
            stop)  sudo systemctl stop microvm@claude ;;
            ssh)   ssh claude-vm ;;
            *)     echo "Usage: vm-claude [start|stop|ssh]" ;;
          esac
        }

        vpn() {
          local active_session=$(openvpn3 sessions-list | grep "Path:" | awk '{print $2}')

          if [[ -n "$active_session" ]]; then
            local action=$(echo -e "Disconnect\nStatus\nKeep Running" | fzf --header "VPN is ACTIVE ($active_session)")

            case "$action" in
              "Disconnect")
                openvpn3 session-manage --session-path "$active_session" --disconnect
                notify-send "VPN" "Disconnected" ;;
              "Status")
                openvpn3 session-stats --session-path "$active_session" ;;
            esac
          else
            local vpn_config=$(openvpn3 configs-list | grep -vE '^(Configuration|---|$)' | awk '{print $1}' | fzf --header "Select Vinted Profile")

            if [[ -n "$vpn_config" ]]; then
              echo "Starting $vpn_config..."
              openvpn3 session-start --config "$vpn_config"
              sleep 2
              notify-send "VPN Connected" "Profile: $vpn_config"
              echo "--- Current DNS Domains ---"
              resolvectl domain | grep -A 1 "tun0"
            fi
          fi
        }

      '';
    };

    fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    atuin = {
      enable = true;
      enableZshIntegration = true;
      flags = [
        "--disable-up-arrow"
      ];
    };

    starship = {
      enable = true;
      enableZshIntegration = true;
      settings = {
        format = lib.concatStrings [
          "$username"
          "$directory"
          "$status"
          "$shell"
          "$character"
        ];
      };
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
    };

    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
