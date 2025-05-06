{lib, ...}: {
  services.wakapi = {
    enable = true;
    passwordSaltFile = /etc/nixos/wakapi_salt;
    settings = {
      server = {
        port = 7788;
        public_url = "https://wakapi.adamjasinski.xyz";
      };

      mail = {
        enabled = false;
      };
    };
  };

  services.nginx = {
    virtualHosts."wakapi.adamjasinski.xyz" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:7788";
      };
    };
  };
}
