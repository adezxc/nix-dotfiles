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
    kubelogin
    kubelogin-oidc

    wezterm

    redis

    claude-code-bin
    codex

    obs-studio
    playwright
    playwright-driver
  ];
}
