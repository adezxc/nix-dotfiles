{
  pkgs,
  config,
  ...
}: let
  # fn+F4 (XF86AudioMicMute) handler. Toggles the default microphone via
  # Noctalia (so its OSD shows) and then syncs the ThinkPad hardware
  # mic-mute LED with the actual PipeWire mute state. The LED is purely
  # cosmetic — the EC does not mute the DMIC in hardware — but it stays
  # lit otherwise, which looks like the mic is dead. The sysfs file is
  # made user-writable via a tmpfiles rule in the NixOS config.
  # Call with "sync" to only update the LED (used at session startup).
  micMuteToggle = pkgs.writeShellScript "mic-mute-toggle" ''
    LED=/sys/class/leds/platform::micmute/brightness

    if [ "''${1:-}" != "sync" ]; then
      noctalia msg mic-mute
    fi

    # Give the daemon a moment to apply the new state, then read it back.
    sleep 0.4
    if ${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null \
      | ${pkgs.gnugrep}/bin/grep -q MUTED; then
      echo 1 > "$LED"
    else
      echo 0 > "$LED"
    fi
  '';
in {
  wayland.windowManager.niri = {
    enable = true;

    # Raw KDL config: supports comments and is validated by niri on build.
    extraConfig = ''
      input {
          keyboard {
              xkb {
                  layout "pl,lt,ru"
                  variant ",us,phonetic"
                  // NOTE: niri does not support per-device xkb configuration
                  // (unlike sway's `input "vendor:product:name" { xkb_* }`);
                  // there is a single global keymap (per-device input config
                  // is planned upstream). Both Ctrl keys together toggle
                  // between the declared layouts; Caps Lock is left as-is.
                  options "grp:ctrls_toggle"
              }
          }

          // Equivalent of the sway touchpad config
          // (tap enabled, tap_button_map lrm, natural_scroll disabled):
          // tap-to-click with two-finger tap = right button and
          // three-finger tap = middle button. natural-scroll is off by
          // default in niri.
          touchpad {
              tap
              tap-button-map "left-right-middle"
          }
      }

      cursor {
          xcursor-theme "phinger-cursors-light"
          xcursor-size 36
      }

      environment {
          // Electron apps (Slack, Discord, ...) on native Wayland instead
          // of XWayland, which renders blurry on fractionally scaled outputs.
          ELECTRON_OZONE_PLATFORM_HINT "wayland"
      }

      layout {
          // Same inner gap as the old sway config.
          gaps 10

          // Transparent so Noctalia's stationary wallpaper layer (see the
          // layer-rule below) is visible at all times; niri's own background
          // only shows if the wallpaper layer is missing.
          background-color "transparent"

          // Nord-ish focus indication, matching the old sway colors.
          focus-ring {
              width 2
              active-color "#88C0D0"
              inactive-color "#4C566A"
          }
          border {
              width 2
              active-color "#88C0D0"
              inactive-color "#3B4252"
          }
      }

      // Instant workspace switching. To disable all animations, put
      // `off` directly on the `animations` section; individual ones can
      // be turned off the same way (e.g. `horizontal-view-movement` for
      // the camera scrolling to a focused off-screen window).
      animations {
          workspace-switch {
              off
          }
      }

      // Monitor setup, translated from the old kanshi profiles.
      //
      // Monitors are matched by make/model/serial (from `niri msg outputs`)
      // rather than connector name where possible, because the same
      // connector (DP-2) carries different monitors on the home and office
      // docks. Unlike kanshi, niri has no dynamic profiles: each block
      // applies whenever that monitor is connected, and positions are
      // static. (The old kanshi profiles also disabled the internal
      // display when docked; use `niri msg output eDP-1 off` for that.)

      // Laptop internal display
      output "eDP-1" {
          scale 1.0
      }

      // Home: Dell S2721DGF (main, 144 Hz) — HDMI-A-1
      output "Dell Inc. DELL S2721DGF 77SGR83" {
          mode "2560x1440@143.912"
          position x=0 y=593
      }

      // Home: Dell U2722DE (side, rotated) — DP-2
      output "Dell Inc. DELL U2722DE BH169H3" {
          mode "2560x1440"
          position x=2560 y=0
          transform "90"
      }

      // Office: LG UltraFine 4K — also DP-2, hence matched by EDID
      output "LG Electronics LG ULTRAFINE 109NTQDQC932" {
          mode "3840x2160@59.997"
          scale 1.5
          position x=0 y=0
      }

      // Work: Samsung LS34A650U ultrawide
      output "Samsung Electric Company LS34A650U HNTR302475" {
          mode "3440x1440@99.982"
          position x=0 y=0
      }

      // Other monitors from the old kanshi config:

      // LG Ultra HD 4K
      output "LG Electronics LG Ultra HD 0x00092091" {
          mode "3840x2160@59.997"
          scale 1.5
          position x=0 y=1086
      }

      // Lenovo P27h-20
      output "Lenovo Group Limited P27h-20 V905YGRW" {
          mode "2560x1440@59.951"
          position x=0 y=0
      }

      // Stationary wallpaper (per Noctalia docs, "Option 2"): the
      // wallpaper layer is placed on niri's backdrop, so it does not
      // scroll with the workspace strip — like sway/swaybg.
      layer-rule {
          match namespace="^noctalia-wallpaper"
          place-within-backdrop true
      }

      // No workspace shadows in the overview, so the stationary wallpaper
      // looks clean behind the workspace cards.
      overview {
          workspace-shadow {
              off
          }
      }

      // Noctalia shell + tray applets
      // (the sleep mirrors the old sway startup commands).
      spawn-at-startup "noctalia"
      // Clear a stale mic-mute LED left on by the firmware (see
      // micMuteToggle above).
      spawn-sh-at-startup "sleep 3 && ${micMuteToggle} sync"
      spawn-sh-at-startup "sleep 2 && nm-applet --indicator"
      spawn-sh-at-startup "sleep 2 && blueman-applet"
      spawn-sh-at-startup "sleep 2 && solaar -w hide"

      // Rounded corners (per Noctalia docs).
      window-rule {
          geometry-corner-radius 12
          clip-to-geometry true
      }

      // Noctalia settings window floats.
      window-rule {
          match app-id="dev.noctalia.Noctalia"
          open-floating true
          default-column-width { fixed 1080; }
          default-window-height { fixed 920; }
      }

      // Allows notification actions and window activation from Noctalia.
      debug {
          honor-xdg-activation-with-invalid-serial
      }

      binds {
          Mod+Return { spawn "${pkgs.ghostty}/bin/ghostty"; }
          Mod+Shift+Q { close-window; }
          // Noctalia launcher (replaces wofi)
          Mod+D { spawn "noctalia" "msg" "panel-toggle" "launcher"; }
          // Noctalia lock screen (replaces swaylock)
          Mod+Escape { spawn "noctalia" "msg" "session" "lock"; }
          Mod+Shift+E { quit; }

          // Noctalia caffeine — replaces the old Waybar sleep-inhibitor
          // toggle (Mod+Shift+C used to reload sway; niri live-reloads
          // its config on save).
          Mod+Shift+C { spawn "noctalia" "msg" "caffeine-toggle"; }

          // Focus
          Mod+H { focus-column-left; }
          Mod+J { focus-window-or-workspace-down; }
          Mod+K { focus-window-or-workspace-up; }
          Mod+L { focus-column-right; }
          Mod+Left { focus-column-left; }
          Mod+Down { focus-window-or-workspace-down; }
          Mod+Up { focus-window-or-workspace-up; }
          Mod+Right { focus-column-right; }

          // Move
          Mod+Shift+H { move-column-left; }
          Mod+Shift+J { move-window-down-or-to-workspace-down; }
          Mod+Shift+K { move-window-up-or-to-workspace-up; }
          Mod+Shift+L { move-column-right; }
          Mod+Shift+Left { move-column-left; }
          Mod+Shift+Down { move-window-down-or-to-workspace-down; }
          Mod+Shift+Up { move-window-up-or-to-workspace-up; }
          Mod+Shift+Right { move-column-right; }

          // Workspaces
          Mod+1 { focus-workspace 1; }
          Mod+2 { focus-workspace 2; }
          Mod+3 { focus-workspace 3; }
          Mod+4 { focus-workspace 4; }
          Mod+5 { focus-workspace 5; }
          Mod+6 { focus-workspace 6; }
          Mod+7 { focus-workspace 7; }
          Mod+8 { focus-workspace 8; }
          Mod+9 { focus-workspace 9; }
          Mod+0 { focus-workspace 10; }
          Mod+Shift+1 { move-column-to-workspace 1; }
          Mod+Shift+2 { move-column-to-workspace 2; }
          Mod+Shift+3 { move-column-to-workspace 3; }
          Mod+Shift+4 { move-column-to-workspace 4; }
          Mod+Shift+5 { move-column-to-workspace 5; }
          Mod+Shift+6 { move-column-to-workspace 6; }
          Mod+Shift+7 { move-column-to-workspace 7; }
          Mod+Shift+8 { move-column-to-workspace 8; }
          Mod+Shift+9 { move-column-to-workspace 9; }
          Mod+Shift+0 { move-column-to-workspace 10; }

          // Columns: stack the focused window below the column to its
          // left (vertical split — e.g. two terminals top/bottom), or
          // expel the bottom window back out to its own column.
          Mod+Comma { consume-window-into-column; }
          Mod+Period { expel-window-from-column; }

          // Consume/expel in one bind, depending on which side the
          // neighbouring column is on.
          Mod+BracketLeft { consume-or-expel-window-left; }
          Mod+BracketRight { consume-or-expel-window-right; }

          // Layout
          // (sway's manual splith/splitv have no niri equivalent — columns
          // split automatically; sway's "layout stacking" has none either.)
          Mod+W { toggle-column-tabbed-display; }
          Mod+F { fullscreen-window; }
          Mod+Shift+Space { toggle-window-floating; }
          Mod+Space { switch-focus-between-floating-and-tiling; }

          // Resizing (sway had a Mod+R "resize" mode; niri has no modes)
          Mod+R { switch-preset-column-width; }
          Mod+Shift+R { switch-preset-window-height; }
          Mod+Ctrl+H { set-column-width "-10"; }
          Mod+Ctrl+L { set-column-width "+10"; }
          Mod+Ctrl+K { set-window-height "-10"; }
          Mod+Ctrl+J { set-window-height "+10"; }
          Mod+M { maximize-column; }

          // Media & brightness — via Noctalia so its OSDs show
          // (volume step is 5%, same as the old pactl binds).
          XF86AudioMute allow-when-locked=true { spawn "noctalia" "msg" "volume-mute"; }
          XF86AudioLowerVolume allow-when-locked=true { spawn "noctalia" "msg" "volume-down"; }
          XF86AudioRaiseVolume allow-when-locked=true { spawn "noctalia" "msg" "volume-up"; }
          XF86AudioMicMute allow-when-locked=true { spawn-sh "${micMuteToggle}"; }
          XF86MonBrightnessDown allow-when-locked=true { spawn "noctalia" "msg" "brightness-down"; }
          XF86MonBrightnessUp allow-when-locked=true { spawn "noctalia" "msg" "brightness-up"; }

          // Screenshots (niri's built-in UI; saves to ~/Pictures/Screenshots
          // and copies to the clipboard, replacing the old grim/slurp/swappy
          // flow)
          Print { screenshot-screen; }
          Mod+Shift+S { screenshot; }
      }
    '';
  };

  # Noctalia desktop shell: bar, launcher, notifications, lock screen,
  # OSDs, control center (replaces waybar, wofi, mako, swaylock, swayidle,
  # swaybg).
  programs.noctalia = {
    enable = true;
    settings = {
      # Wallpaper (replaces swaybg + the old solid sway background).
      # The picker browses ~/Pictures/Wallpapers (the NASA dailies); the
      # default is the newest one present. Picking a wallpaper from the UI
      # overrides this in Noctalia's own settings.toml.
      wallpaper = {
        directory = "${config.home.homeDirectory}/Pictures/Wallpapers";
        default.path = "${config.home.homeDirectory}/Pictures/Wallpapers/nasa-2026-04-29.jpg";
      };

      # Idle behaviour, replacing swayidle (previously: `swayidle -w
      # timeout 900 'swaylock -f' timeout 1800 'systemctl suspend'
      # before-sleep 'swaylock -f'`).
      idle = {
        behavior = {
          lock = {
            timeout = 900;
            action = "lock";
            enabled = true;
          };
          suspend = {
            timeout = 1800;
            action = "lock_and_suspend";
            enabled = true;
          };
        };
      };
    };
  };

  # Ghostty terminal configuration
  xdg.configFile."ghostty/config".text = ''
    font-family = Iosevka
    quit-after-last-window-closed = true
    quit-after-last-window-closed-delay = 5m
    window-inherit-working-directory = false
    shell-integration = zsh
    mouse-hide-while-typing = false
    scrollback-limit = 2147483648

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
    keybind = ctrl+n=unbind

    window-save-state = always
    clipboard-read = allow
    clipboard-write = allow
    copy-on-select = clipboard
  '';

  # Cursor theme (phinger-cursors). Handles installing the theme,
  # ~/.icons/default/index.theme (Inherits=), GTK2/GTK3 cursor settings,
  # and XCURSOR_THEME/XCURSOR_SIZE session variables.
  home.pointerCursor = {
    package = pkgs.phinger-cursors;
    name = "phinger-cursors-light";
    size = 36;
    gtk.enable = true;
  };

  home.packages = with pkgs; [
    ghostty
    wl-clipboard
    brightnessctl
    playerctl
    pavucontrol
    uv
    blueman
    solaar
  ];

  xdg.desktopEntries.firefox-work = {
    name = "Firefox Work";
    genericName = "Web Browser";
    exec = "firefox --profile ${config.home.homeDirectory}/.mozilla/firefox/98rkkzfh.Work-new --name firefox-work %U";
    icon = "firefox";
    terminal = false;
    categories = ["Network" "WebBrowser"];
    mimeType = [
      "text/html"
      "text/xml"
      "application/xhtml+xml"
      "application/vnd.mozilla.xul+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
    settings = {
      StartupWMClass = "firefox-work";
    };
    actions = {
      new-window = {
        name = "New Window";
        exec = "firefox --profile ${config.home.homeDirectory}/.mozilla/firefox/98rkkzfh.Work-new --new-window %U";
      };
      new-private-window = {
        name = "New Private Window";
        exec = "firefox --profile ${config.home.homeDirectory}/.mozilla/firefox/98rkkzfh.Work-new --private-window %U";
      };
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = ["firefox-work.desktop"];
      "x-scheme-handler/https" = ["firefox-work.desktop"];
      "text/html" = ["firefox-work.desktop"];
      "application/xhtml+xml" = ["firefox-work.desktop"];
    };
  };
}
