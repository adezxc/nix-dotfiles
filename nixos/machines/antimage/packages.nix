{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    firefox
    brightnessctl
    zathura
    feh
    mitscheme
    i3lock
  ];
}
