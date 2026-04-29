{pkgs, lib, ...}: {
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    curl
    wget
    broot
    firefox
    chromium

    networkmanagerapplet

    jujutsu

    easyeffects
    lsp-plugins


    openvpn3
    slack
    spotify
    vesktop
    
    pandoc

    s3cmd
    kubectl
    k9s
    kubectx

    wezterm

    redis

    claude-code-bin
    codex
  ];
}
