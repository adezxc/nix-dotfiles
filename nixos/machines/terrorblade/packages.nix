{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    vim
    git
    htop
    curl
    wget
    firefox

    openvpn3
    slack
    spotify
    
    kubectl
    k9s
    kubectx
  ];
}
