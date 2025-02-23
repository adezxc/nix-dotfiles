{
  nixarr,
  lib,
  ...
}: {
  nixarr = {
    enable = true;
    mediaDir = "/data/media";
    stateDir = "/data/media/.state/nixarr";

    vpn = {
      enable = true;
      wgConf = "/data/.secret/wg.conf";
    };

    jellyfin = {
      enable = true;
      openFirewall = true;
      expose.https = {
        enable = true;
        domainName = "jellyfin.adamjasinski.xyz";
        acmeMail = "adam@jasinski.lt";
      };
    };

    transmission = {
      enable = true;
      vpn.enable = true;
      peerPort = 34497; # Set this to the port forwarded by your VPN
      extraSettings = {
        ratio-limit-enabled = true;
        ratio-limit = 2.5;
      };
    };

    bazarr.enable = true;
    prowlarr.enable = true;
    radarr.enable = true;
    sonarr.enable = true;
  };

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;

    virtualHosts."adamjasinski.xyz" = {
      enableACME = true;
      forceSSL = true;
      root = "/var/www/blog/public";
    };

    virtualHosts."jasinski.lt" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "https://adamjasinski.xyz";
      };
    };

    virtualHosts."linkding.adamjasinski.xyz" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:9090";
      };

      extraConfig = ''
               client_body_in_file_only clean;
               client_body_buffer_size 32k;
               client_max_body_size 300M;
               sendfile on;
               send_timeout 300s;

        proxy_http_version 1.1;
               proxy_set_header   Upgrade    $http_upgrade;
               proxy_set_header   Connection "upgrade";
               proxy_redirect     off;
        proxy_read_timeout 3600;
      '';
    };

    # other Nginx options
    virtualHosts."jellyfin.adamjasinski.xyz" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8096";
      };
    };

    virtualHosts."vaultwarden.adamjasinski.xyz" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8222";
      };
    };

    virtualHosts."calibre.adamjasinski.xyz" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8083";
      };

      extraConfig = ''
        client_body_in_file_only clean;
        client_body_buffer_size 32k;
        client_max_body_size 300M;
        sendfile on;
        send_timeout 300s;


      '';
    };

    virtualHosts."immich.adamjasinski.xyz" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:3001";
      };

      extraConfig = ''
               client_body_in_file_only clean;
               client_body_buffer_size 32k;
               client_max_body_size 300M;
               sendfile on;
               send_timeout 300s;

        proxy_http_version 1.1;
               proxy_set_header   Upgrade    $http_upgrade;
               proxy_set_header   Connection "upgrade";
               proxy_redirect     off;
      '';
    };

    #virtualHosts."youtube.adamjasinski.xyz" = {
    #  enableACME = true;
    #  forceSSL = true;
    #  locations."/" = {
    #    proxyPass = "http://127.0.0.1:8111";
    #  };
    #};
  };

  services.vaultwarden = {
    enable = true;
    config = {
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      DOMAIN = "https://vaultwarden.adamjasinski.xyz";
      SIGNUPS_ALLOWED = false;
    };
  };

  services.calibre-web = {
    listen.ip = "127.0.0.1";
    enable = true;
    options = {
      enableBookUploading = true;
      enableBookConversion = true;
      calibreLibrary = "/data/media/books";
    };
    openFirewall = true;
  };

  services.invidious = {
    enable = false;
    port = 8111;
    domain = "youtube.adamjasinski.xyz";
    settings = lib.mkForce {
      db = {
        dbname = "invidious";
        host = "";
        password = "";
        port = 5432;
        user = "invidious";
      };
      admins = [
        "adezxc"
      ];
      https_only = true;
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = "adam@jasinski.lt";
  };

  services.immich = {
    enable = true;
    mediaLocation = "/data/media/photos";
    openFirewall = true;
    port = 3001;
    host = "127.0.0.1";
    machine-learning.enable = false;
    environment = {
      IMMICH_MACHINE_LEARNING_URL = lib.mkForce "http://alchemist:3003";
    };
  };
}
