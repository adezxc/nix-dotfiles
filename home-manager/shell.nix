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
      settings = {
        "*" = {
          AddKeysToAgent = "yes";
          SetEnv.TERM = "xterm-256color";
        };
        "pi-coding-agent" = {
          HostName = "192.168.83.10";
          User = "adam";
          IdentityFile = "~/.ssh/id_ed25519";
          StrictHostKeyChecking = "no";
          UserKnownHostsFile = "/dev/null";
        };
        "*.vinted.infra *.vinted.net" = {
          User = "ajasinski";
          AddKeysToAgent = "yes";
          ForwardAgent = true;
          IdentityFile = "~/.ssh/vinted_ed25519";
          SetEnv.LC_CTYPE = "en_US.UTF-8";
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
        push.autoSetupRemote = true;
      };
      includes = [
        {
          condition = "gitdir:~/git/vinted/";
          contents.user.email = "adam.jasinski@vinted.com";
        }
      ];

      maintenance.enable = true;
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
        knife-dal() { knife $@ --profile dal1 }

        vpn() {
          local sessions_output=$(openvpn3 sessions-list)
          local active_session=$(echo "$sessions_output" | grep "Path:" | awk '{print $2}')
          local session_status=$(echo "$sessions_output" | grep "Status:" | sed 's/^[[:space:]]*Status:[[:space:]]*//')

          # Quick subcommands: vpn off|d (disconnect), vpn s (status)
          case "$1" in
            off|down|d)
              if [[ -n "$active_session" ]]; then
                openvpn3 session-manage --session-path "$active_session" --disconnect
                notify-send "VPN" "Disconnected"
              else
                echo "No active VPN session."
              fi
              return ;;
            status|s)
              if [[ -n "$active_session" ]]; then
                echo "Status: $session_status"
                openvpn3 session-stats --session-path "$active_session"
              else
                echo "No active VPN session."
              fi
              return ;;
          esac

          # Handle unhealthy sessions left over after suspend/sleep
          if [[ -n "$active_session" ]]; then
            if [[ "$session_status" == *"paused"* ]]; then
              echo "VPN session is paused (probably after sleep), resuming..."
              if openvpn3 session-manage --session-path "$active_session" --resume; then
                notify-send "VPN" "Session resumed"
                return
              fi
              echo "Resume failed, cleaning up stale session..."
              openvpn3 session-manage --session-path "$active_session" --disconnect 2>/dev/null
              active_session=""
            elif [[ "$session_status" != *"Client connected"* ]]; then
              echo "Stale VPN session detected ($session_status), cleaning up..."
              openvpn3 session-manage --session-path "$active_session" --disconnect 2>/dev/null
              active_session=""
            fi
          fi

          if [[ -n "$active_session" ]]; then
            local action=$(echo -e "Keep Running\nStatus\nRestart\nDisconnect" | fzf --header "VPN is ACTIVE ($session_status)")

            case "$action" in
              "Disconnect")
                openvpn3 session-manage --session-path "$active_session" --disconnect
                notify-send "VPN" "Disconnected" ;;
              "Restart")
                openvpn3 session-manage --session-path "$active_session" --restart
                notify-send "VPN" "Session restarted" ;;
              "Status")
                openvpn3 session-stats --session-path "$active_session" ;;
            esac
            return
          fi

          # No (healthy) session: connect
          local vpn_config=$(openvpn3 configs-list | grep -vE '^(Configuration|---|$)' | awk '{print $1}' | fzf --header "Select Vinted Profile")

          if [[ -n "$vpn_config" ]]; then
            echo "Starting $vpn_config..."
            if openvpn3 session-start --config "$vpn_config"; then
              notify-send "VPN Connected" "Profile: $vpn_config"
              echo "--- Current DNS Domains ---"
              resolvectl domain | grep -A 1 "tun0"
            else
              notify-send -u critical "VPN" "Failed to connect to $vpn_config"
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
