{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  xsession.windowManager.i3 = {
    enable = true;
    package = pkgs.i3-gaps;
    config = {
      modifier = "Mod4";
      gaps = {
        inner = 10;
        outer = 5;
      };
      bars = [
        #{
        #  statusCommand = "killall -q polybar; ${pkgs.polybar}/bin/polybar top &";
        #  position = "bottom";
        #  workspaceNumbers = true;
        #}
      ];
      startup = [
        {
          command = "systemctl --user restart polybar";
          always = true;
          notification = false;
        }
        {
          command = "source ~/.fehbg";
          notification = false;
        }
      ];
      keybindings = let
        modifier = config.xsession.windowManager.i3.config.modifier;
      in
        lib.mkOptionDefault {
          "${modifier}+Return" = "exec wezterm";
          "${modifier}+Shift+q" = "kill";
          "${modifier}+d" = "exec ${pkgs.dmenu}/bin/dmenu_run";
          "${modifier}+l" = "exec ${pkgs.betterlockscreen}/bin/betterlockscreen --lock";
          "XF86MonBrightnessUp" = "exec --no-startup-id brightnessctl set 5%+";
          "XF86MonBrightnessDown" = "exec --no-startup-id brightnessctl set 5%-";
        };
      window.commands = [
        {
          command = "border pixel 0";
          criteria = {
            class = "wezterm";
          };
        }
      ];
    };
  };

  services.screen-locker = {
    enable = true;
  };

  services.betterlockscreen = {
    enable = true;
  };

  services.polybar = {
    enable = true;
    package = pkgs.polybar.override {
      i3Support = true;
      alsaSupport = true;
      #iwSupport = true;
      #githubSupport = true;
    };
    script = "polybar top &";
    config = {
      "bar/top" = {
        monitor = "\${env:MONITOR:eDP-1}";
        width = "100%";
        height = "3%";
        bottom = true;
        radius = 0;
        modules-center = "date";
        modules-left = "i3";
        modules-right = "xkeyboard battery temperature";

        separator = "|";

        font-0 = "FiraCode Nerd Font:pixelsize=12;0";
        font-2 = "Siji:pixelsize=12;0";
      };

      "module/i3" = {
        type = "internal/i3";
        pin-workspaces = true;
        index-sort = true;

        label-focused = "%index%";
        label-focused-foreground = "#ffffff";
        label-focused-background = "#3f3f3f";
        label-focused-underline = "#fba922";
        label-focused-padding = 1;

        label-unfocused = "%index%";
        label-unfocused-padding = 1;

        label-visible = "%index%";
        label-visible-underline = "#555555";
        label-visible-padding = 1;

        label-urgent = "%index%";
        label-urgent-foreground = "#000000";
        label-urgent-background = "#bd2c40";
        label-urgent-padding = 4;

        label-separator = "|";
        label-separator-padding = 0;
        label-separator-foreground = "#ffb52a";
      };

      "module/temperature" = {
        type = "internal/temperature";

        interval = "0.5";

        thermal_zone = 5;
        zone-type = "x86_pkg_temp";

        base-temperature = 30;
        warn-temperature = 60;
      };

      "module/xkeyboard" = {
        type = "internal/xkeyboard";

        blacklist-0 = "num lock";
        blacklist-1 = "scroll lock";
      };

      "module/battery" = {
        type = "internal/battery";
        full-at = 98;

        format-charging = "<animation-charging> <label-charging>";
        format-discharging = "<ramp-capacity> <label-discharging>";
        format-full = "<ramp-capacity> <label-full>";

        time-format = "%H:%M";

        label-charging = "%percentage%% %time%h";
        label-discharging = "%percentage%% %time%h";
        ramp-capacity-0 = "";
        ramp-capacity-0-foreground = "#f53c3c";
        ramp-capacity-1 = "";
        ramp-capacity-1-foreground = "#ffa900";
        ramp-capacity-2 = "";
        ramp-capacity-3 = "";
        ramp-capacity-4 = "";

        bar-capacity-width = "10";
        bar-capacity-format = "%{+u}%{+o}%fill%%empty%%{-u}%{-o}";
        bar-capacity-fill = "█";
        bar-capacity-fill-foreground = "#ddffffff";
        bar-capacity-fill-font = "3";
        bar-capacity-empty = "█";
        bar-capacity-empty-font = "3";
        bar-capacity-empty-foreground = "#44ffffff";

        animation-charging-0 = "";
        animation-charging-1 = "";
        animation-charging-2 = "";
        animation-charging-3 = "";
        animation-charging-4 = "";
        animation-charging-framerate = "750";
      };

      "module/date" = {
        type = "internal/date";
        internal = 5;
        date = "%d.%m.%y";
        time = "%H:%M:%S";
        label = "%time%  %date%";
      };
    };
  };

  programs.feh.enable = true;
}
