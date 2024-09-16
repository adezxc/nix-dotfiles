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
      keybindings = let
        modifier = config.xsession.windowManager.i3.config.modifier;
      in
        lib.mkOptionDefault {
          "${modifier}+Return" = "exec wezterm";
          "${modifier}+Shift+q" = "kill";
          "${modifier}+d" = "exec ${pkgs.dmenu}/bin/dmenu_run";
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
}
