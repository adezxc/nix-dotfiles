{pkgs, lib, ...}: {
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    curl
    wget
    firefox

    networkmanagerapplet

    openvpn3
    slack
    spotify
    
    kubectl
    k9s
    kubectx
  ];
}
