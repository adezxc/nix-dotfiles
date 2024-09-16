{...}: {
  programs.wezterm = {
    enable = true;
    enableZshIntegration = true;
    extraConfig = ''
      local wezterm = require 'wezterm'

      local config = wezterm.config_builder()

      config.color_scheme = 'Catppuccin Mocha'

      config.font = wezterm.font 'FiraCode Nerd Font'

      config.front_end = "WebGpu"

      return config
    '';
  };
}
