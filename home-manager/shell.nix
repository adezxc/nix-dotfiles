{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
  programs = {
    git = {
      enable = true;
      aliases = {
        s = "status";
      };
      userEmail = "adam@jasinski.lt";
      userName = "Adam Jasinski";
    };

    zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestion.enable = true;
      syntaxHighlighting.enable = true;

      shellAliases = {
        ll = "ls -l";
        update = "sudo nixos-rebuild switch";
      };

      history = {
        size = 10000;
        path = "${config.xdg.dataHome}/zsh/history";
      };
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
          "$git_branch"
          "$git_commit"
          "$git_status"
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
  };
}
