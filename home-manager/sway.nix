{ pkgs, ... }:

{
  # Ghostty terminal configuration
  xdg.configFile."ghostty/config".text = ''
    quit-after-last-window-closed = true
    quit-after-last-window-closed-delay = 5m
    window-inherit-working-directory = false
    shell-integration = zsh
    mouse-hide-while-typing = false
    scrollback-limit = 2147483648

    keybind = ctrl+n=new_window

    keybind = ctrl+h=goto_split:left
    keybind = ctrl+j=goto_split:bottom
    keybind = ctrl+k=goto_split:top
    keybind = ctrl+l=goto_split:right

    keybind = ctrl+b>h=new_split:left
    keybind = ctrl+b>j=new_split:down
    keybind = ctrl+b>k=new_split:up
    keybind = ctrl+b>l=new_split:right
    keybind = ctrl+b>f=toggle_split_zoom

    keybind = ctrl+b>n=next_tab
    keybind = ctrl+b>p=previous_tab

    keybind = ctrl+shift+r=reload_config

    window-save-state = always
    clipboard-read = allow
    clipboard-write = allow
    copy-on-select = clipboard
  '';

  # Wofi launcher configuration
  xdg.configFile."wofi/config".text = ''
    mode=drun
    allow_images=true
    image_size=24
    hide_scroll=true
    no_actions=true
    insensitive=true
    prompt=
    term=ghostty
    width=500
    height=360
    lines=8
    matching=fuzzy
    sort_order=default
  '';

  xdg.configFile."wofi/style.css".text = ''
    * {
        font-family: "Hack", monospace;
        font-size: 14px;
    }

    window {
        background-color: transparent;
        border-radius: 12px;
    }

    #outer-box {
        margin: 0px;
        padding: 12px;
        background-color: #2E3440;
        border-radius: 12px;
        border: 2px solid #4C566A;
    }

    #input {
        margin-bottom: 8px;
        padding: 8px 12px;
        border: none;
        border-bottom: 2px solid #4C566A;
        border-radius: 0px;
        background-color: transparent;
        color: #ECEFF4;
        font-size: 15px;
    }

    #input:focus {
        border-bottom: 2px solid #88C0D0;
    }

    #inner-box {
        background-color: transparent;
    }

    #scroll {
        margin: 0px;
    }

    #text {
        padding: 6px 8px;
        color: #D8DEE9;
    }

    #img {
        padding: 4px 8px 4px 4px;
    }

    #entry {
        border-radius: 8px;
        margin: 2px 0px;
    }

    #entry:selected {
        background-color: #3B4252;
        border: none;
        outline: none;
    }

    #text:selected {
        color: #88C0D0;
        background: transparent;
    }
  '';

  # Swaylock configuration
  xdg.configFile."swaylock/config".text = ''
    color=2E3440

    indicator-radius=120
    indicator-thickness=12

    ring-color=4C566A
    key-hl-color=88C0D0

    inside-color=2E3440
    inside-clear-color=81A1C1
    inside-ver-color=5E81AC
    inside-wrong-color=BF616A

    line-color=00000000

    ring-clear-color=81A1C1
    ring-ver-color=5E81AC
    ring-wrong-color=BF616A

    separator-color=00000000

    text-color=ECEFF4
    text-clear-color=2E3440
    text-ver-color=2E3440
    text-wrong-color=ECEFF4

    bs-hl-color=BF616A

    show-failed-attempts
    indicator-caps-lock
  '';

  home.packages = with pkgs; [
    wofi
    swaylock
    swayidle
    swaybg
    grim
    slurp
    swappy
    wl-clipboard
    brightnessctl
    playerctl
    pavucontrol
    pulseaudio
    foot
    ghostty
    blueman
    solaar
    uv
  ];

  wayland.windowManager.sway = {
    enable = true;
    config = {
      modifier = "Mod4";
      terminal = "${pkgs.ghostty}/bin/ghostty";
      menu = "wofi --show drun";

      gaps.inner = 10;
      workspaceLayout = "tabbed";

      fonts = {
        names = [ "MesloLGS Nerd Font" "Hack" ];
        size = 11.0;
      };

      colors = {
        focused = {
          border = "#88C0D0";
          background = "#3B4252";
          text = "#ECEFF4";
          indicator = "#88C0D0";
          childBorder = "#88C0D0";
        };
        focusedInactive = {
          border = "#4C566A";
          background = "#2E3440";
          text = "#D8DEE9";
          indicator = "#4C566A";
          childBorder = "#4C566A";
        };
        unfocused = {
          border = "#3B4252";
          background = "#2E3440";
          text = "#4C566A";
          indicator = "#3B4252";
          childBorder = "#3B4252";
        };
      };

      bars = [{
        command = "${pkgs.waybar}/bin/waybar";
      }];

      output."*" = {
        bg = "#2E3440 solid_color";
      };

      input = {
        "1:1:AT_Translated_Set_2_keyboard" = {
          xkb_layout = "pl,lt,ru";
          xkb_variant = ",us,phonetic";
          xkb_options = "grp:alt_shift_toggle,caps:swapescape";
        };
        "13364:643:Keychron_Keychron_K8_Pro" = {
          xkb_layout = "pl,lt,ru";
          xkb_variant = ",us,phonetic";
          xkb_options = "grp:alt_shift_toggle,caps:swapescape";
        };
        "10730:864:Kinesis_Kinesis_Adv360" = {
          xkb_layout = "pl,lt,ru";
          xkb_variant = ",us,phonetic";
          xkb_options = "grp:ctrls_toggle";
        };
        "7504:24926:Adv360_Pro_Keyboard" = {
          xkb_layout = "pl,lt,ru";
          xkb_variant = ",us,phonetic";
          xkb_options = "grp:ctrls_toggle";
        };
        "1739:52839:SYNA8018:00_06CB:CE67_Touchpad" = {
          tap = "enabled";
          tap_button_map = "lrm";
          natural_scroll = "disabled";
        };
      };

      keybindings = let
        mod = "Mod4";
      in {
        "${mod}+Return" = "exec ${pkgs.ghostty}/bin/ghostty";
        "${mod}+Shift+q" = "kill";
        "${mod}+d" = "exec wofi --show drun";
        "${mod}+Shift+c" = "reload";
        "${mod}+Shift+e" = "exec swaynag -t warning -m 'Exit sway?' -B 'Yes' 'swaymsg exit'";
        "${mod}+Escape" = "exec swaylock -f";

        # Focus
        "${mod}+h" = "focus left";
        "${mod}+j" = "focus down";
        "${mod}+k" = "focus up";
        "${mod}+l" = "focus right";
        "${mod}+Left" = "focus left";
        "${mod}+Down" = "focus down";
        "${mod}+Up" = "focus up";
        "${mod}+Right" = "focus right";

        # Move
        "${mod}+Shift+h" = "move left";
        "${mod}+Shift+j" = "move down";
        "${mod}+Shift+k" = "move up";
        "${mod}+Shift+l" = "move right";
        "${mod}+Shift+Left" = "move left";
        "${mod}+Shift+Down" = "move down";
        "${mod}+Shift+Up" = "move up";
        "${mod}+Shift+Right" = "move right";

        # Workspaces
        "${mod}+1" = "workspace number 1";
        "${mod}+2" = "workspace number 2";
        "${mod}+3" = "workspace number 3";
        "${mod}+4" = "workspace number 4";
        "${mod}+5" = "workspace number 5";
        "${mod}+6" = "workspace number 6";
        "${mod}+7" = "workspace number 7";
        "${mod}+8" = "workspace number 8";
        "${mod}+9" = "workspace number 9";
        "${mod}+0" = "workspace number 10";
        "${mod}+Shift+1" = "move container to workspace number 1";
        "${mod}+Shift+2" = "move container to workspace number 2";
        "${mod}+Shift+3" = "move container to workspace number 3";
        "${mod}+Shift+4" = "move container to workspace number 4";
        "${mod}+Shift+5" = "move container to workspace number 5";
        "${mod}+Shift+6" = "move container to workspace number 6";
        "${mod}+Shift+7" = "move container to workspace number 7";
        "${mod}+Shift+8" = "move container to workspace number 8";
        "${mod}+Shift+9" = "move container to workspace number 9";
        "${mod}+Shift+0" = "move container to workspace number 10";

        # Layout
        "${mod}+b" = "splith";
        "${mod}+v" = "splitv";
        "${mod}+s" = "layout stacking";
        "${mod}+w" = "layout tabbed";
        "${mod}+e" = "layout toggle split";
        "${mod}+f" = "fullscreen";
        "${mod}+Shift+space" = "floating toggle";
        "${mod}+space" = "focus mode_toggle";
        "${mod}+a" = "focus parent";

        # Scratchpad
        "${mod}+Shift+minus" = "move scratchpad";
        "${mod}+minus" = "scratchpad show";

        # Resize mode
        "${mod}+r" = "mode resize";

        # Media
        "--locked XF86AudioMute" = "exec pactl set-sink-mute @DEFAULT_SINK@ toggle";
        "--locked XF86AudioLowerVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ -5%";
        "--locked XF86AudioRaiseVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ +5%";
        "--locked XF86AudioMicMute" = "exec pactl set-source-mute @DEFAULT_SOURCE@ toggle";
        "--locked XF86MonBrightnessDown" = "exec brightnessctl set 5%-";
        "--locked XF86MonBrightnessUp" = "exec brightnessctl set 5%+";

        # Screenshots
        "Print" = "exec grim - | wl-copy";
        "${mod}+Shift+s" = ''exec grim -g "$(slurp)" - | tee /tmp/screenshot.png | wl-copy && swappy -f /tmp/screenshot.png'';
      };

      modes.resize = {
        "h" = "resize shrink width 10px";
        "j" = "resize grow height 10px";
        "k" = "resize shrink height 10px";
        "l" = "resize grow width 10px";
        "Left" = "resize shrink width 10px";
        "Down" = "resize grow height 10px";
        "Up" = "resize shrink height 10px";
        "Right" = "resize grow width 10px";
        "Return" = "mode default";
        "Escape" = "mode default";
      };

      startup = [
        { command = "swayidle -w timeout 900 'swaylock -f' timeout 1800 'systemctl suspend' before-sleep 'swaylock -f'"; }
        { command = "sleep 2 && nm-applet --indicator"; }
        { command = "sleep 2 && blueman-applet"; }
        { command = "sleep 2 && solaar -w hide"; }
      ];
    };
  };

  programs.waybar = {
    enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 30;
      modules-left = [ "sway/workspaces" "sway/mode" ];
      modules-center = [ "sway/window" ];
      modules-right = [ "sway/language" "idle_inhibitor" "cpu" "memory" "network" "bluetooth" "pulseaudio" "battery" "tray" "clock" ];

      "sway/workspaces" = {
        disable-scroll = true;
        format = "{name}";
      };
      "sway/mode" = { format = " {}"; };
      "sway/language" = { format = " {short}"; };
      battery = {
        states = { warning = 30; critical = 15; };
        format = "{icon} {capacity}%";
        format-charging = "󰂄 {capacity}%";
        format-icons = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
      };
      "sway/window" = { max-length = 50; };
      idle_inhibitor = {
        format = "{icon}";
        format-icons = {
          activated = "󰅶";
          deactivated = "󰾪";
        };
      };
      cpu = { format = "󰻠 {usage}%"; interval = 5; };
      memory = { format = "󰍛 {}%"; interval = 10; };
      bluetooth = {
        format = "󰂯 {status}";
        format-connected = "󰂱 {device_alias}";
        format-connected-battery = "󰂱 {device_alias} {device_battery_percentage}%";
        tooltip-format = "{controller_alias}\t{controller_address}";
        tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{device_enumerate}";
        tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
        on-click = "blueman-manager";
      };
      network = {
        format-ethernet = "󰈀 {ifname}";
        format-disconnected = "󰤭 Disconnected";
        tooltip-format = "󰈀 {ifname} via {gwaddr}";
        format-alt = "󰈀 {ipaddr}/{cidr}";
      };
      pulseaudio = {
        scroll-step = 5;
        format = "{icon} {volume}% {format_source}";
        format-muted = "󰖁 {format_source}";
        format-source = "󰍬 {volume}%";
        format-source-muted = "󰍭";
        format-icons.default = [ "󰕿" "󰖀" "󰕾" ];
        on-click = "pavucontrol";
      };
      tray = { spacing = 10; };
      clock = {
        format = "󰥔 {:%a %b %d  %H:%M}";
        tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
      };
    };
    style = builtins.readFile ./waybar-style.css;
  };

  # Open all xdg-open links in Firefox Work profile.
  # Desktop entries are managed manually in ~/.local/share/applications/ — do not
  # add xdg.desktopEntries.firefox-work here or home-manager will overwrite them.
  # For conditional routing (some domains → Personal profile), ask Claude for the router setup.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = [ "firefox-work.desktop" ];
      "x-scheme-handler/https" = [ "firefox-work.desktop" ];
      "text/html" = [ "firefox-work.desktop" ];
      "application/xhtml+xml" = [ "firefox-work.desktop" ];
    };
  };

  services.mako = {
    enable = true;
    defaultTimeout = 5000;
    ignoreTimeout = false;
  };

  services.kanshi = {
    enable = true;
    settings = [
      {
        output = {
          criteria = "LG Electronics LG Ultra HD 0x00092091";
          mode = "3840x2160@59.997Hz";
          position = "0,1086";
          scale = 1.5;
        };
      }
      {
        output = {
          criteria = "Lenovo Group Limited P27h-20 V905YGRW";
          mode = "2560x1440@59.951Hz";
          position = "0,0";
        };
      }
      {
        output = {
          criteria = "Dell Inc. DELL S2721DGF 77SGR83";
          mode = "2560x1440@143.912Hz";
          scale = 1.0;
          position = "0,593";
          transform = "normal";
        };
      }
      {
        output = {
          criteria = "Dell Inc. DELL U2722DE BH169H3";
          mode = "2560x1440";
          scale = 1.0;
          position = "2560,0";
          transform = "90";
        };
      }
      {
        output.criteria = "Lenovo Group Limited 0x403D Unknown";
      }
      {
        profile = {
          name = "laptop";
          outputs = [{
            criteria = "Lenovo Group Limited 0x403D Unknown";
            status = "enable";
            scale = 1.0;
          }];
        };
      }
      {
        profile = {
          name = "home";
          outputs = [
            { criteria = "Lenovo Group Limited 0x403D Unknown"; status = "disable"; }
            { criteria = "Dell Inc. DELL S2721DGF 77SGR83"; status = "enable"; }
            { criteria = "Dell Inc. DELL U2722DE BH169H3"; status = "enable"; }
          ];
          exec = let sm = "${pkgs.sway}/bin/swaymsg"; in [
            "${sm} workspace 1"
            "${sm} move workspace to HDMI-A-1 number 1"
            "${sm} workspace 2"
            "${sm} move workspace to HDMI-A-1 number 2"
            "${sm} workspace 3"
            "${sm} move workspace to HDMI-A-1 number 3"
            "${sm} workspace 4"
            "${sm} move workspace to HDMI-A-1 number 4"
            "${sm} workspace 5"
            "${sm} move workspace to HDMI-A-1 number 5"
            "${sm} workspace 6"
            "${sm} move workspace to DP-2 number 6"
            "${sm} workspace 7"
            "${sm} move workspace to DP-2 number 7"
            "${sm} workspace 8"
            "${sm} move workspace to DP-2 number 8"
            "${sm} workspace 9"
            "${sm} move workspace to DP-2 number 9"
            "${sm} workspace 10"
            "${sm} move workspace to DP-2 number 10"
            "${sm} workspace number 1 output HDMI-A-1"
            "${sm} workspace number 2 output HDMI-A-1"
            "${sm} workspace number 3 output HDMI-A-1"
            "${sm} workspace number 4 output HDMI-A-1"
            "${sm} workspace number 5 output HDMI-A-1"
            "${sm} workspace number 6 output DP-2"
            "${sm} workspace number 7 output DP-2"
            "${sm} workspace number 8 output DP-2"
            "${sm} workspace number 9 output DP-2"
            "${sm} workspace number 10 output DP-2"
          ];
        };
      }
      {
        profile = {
          name = "work2";
          outputs = [
            { criteria = "Lenovo Group Limited 0x403D Unknown"; status = "disable"; }
            { criteria = "Lenovo Group Limited P27h-20 V905YGRW"; status = "enable"; }
          ];
        };
      }
    ];
  };
}
