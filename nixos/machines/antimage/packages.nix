{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    firefox
    brightnessctl
  ];
}
