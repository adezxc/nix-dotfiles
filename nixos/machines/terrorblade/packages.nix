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

    openvpn3
    slack
    spotify
    
    pandoc

    kubectl
    k9s
    kubectx

    claude-code-bin
    codex
  ];
}
