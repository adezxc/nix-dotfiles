{
  pkgs,
  lib,
  config,
  ...
}: {
  services.adguardhome = {
    enable = true;
    openFirewall = false;
  };
}
