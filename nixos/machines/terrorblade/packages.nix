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

    comma

    networkmanagerapplet

    jujutsu
    ruby

    easyeffects
    lsp-plugins

    openvpn3
    slack
    spotify
    vesktop
    
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
  ];
}
