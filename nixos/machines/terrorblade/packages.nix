{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
    emacs
    vim
    git
    htop
    curl
    wget
    broot
    firefox
    chromium

    comma

    networkmanagerapplet

    nodejs_latest
    python3

    jujutsu
    sqlite
    ruby

    easyeffects
    lsp-plugins

    openvpn3
    slack
    spotify
    discord

    pandoc

    s3cmd
    kubectl
    istioctl
    k9s
    kubectx
    kubelogin
    kubelogin-oidc

    wezterm

    redis

    claude-code
    codex
    pi-coding-agent

    obs-studio
    playwright
    playwright-driver

    mermaid-cli
  ];
}
