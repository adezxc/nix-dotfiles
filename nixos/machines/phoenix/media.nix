{
  nixarr,
  lib,
  ...
}: let
  karakeepVars = {
    PORT = "1234";
    DISABLE_SIGNUPS = "false";
  };
in {
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

    recyclarr = {
      enable = true;
      configFile = "/etc/nixos/recyclarr.yaml";
    };

    sabnzbd = {
      openFirewall = true;
      vpn.enable = true;
      enable = true;
      guiPort = 9999;
    };

    bazarr.enable = true;
    prowlarr.enable = true;
    radarr.enable = true;
    sonarr.enable = true;
  };

  services.audiobookshelf = {
    enable = true;
    openFirewall = true;
  };

  services.karakeep = {
    enable = true;
    meilisearch.enable = true;
    browser.enable = true;
    environmentFile = "/etc/nixos/karakeep.env";
  };

  services.vaultwarden = {
    enable = true;
    config = {
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      DOMAIN = "https://vaultwarden.adamjasinski.xyz";
      SIGNUPS_ALLOWED = false;
    };
    backupDir = "/var/backup/vaultwarden";
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

  security.acme = {
    acceptTerms = true;
    defaults.email = "adam@jasinski.lt";
  };

  services.freshrss = {
    enable = true;
    baseUrl = "https://freshrss.example.com";
    virtualHost = "freshrss.adamjasinski.xyz";
    passwordFile = "/etc/nixos/freshrss_password";
  };

  services.immich = {
    enable = true;
    mediaLocation = "/data/media/photos";
    openFirewall = true;
    port = 3002;
    host = "127.0.0.1";
    machine-learning.enable = false;
    environment = {
      IMMICH_MACHINE_LEARNING_URL = lib.mkForce "http://alchemist:3003";
    };
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

    virtualHosts."jellyfin.adamjasinski.xyz" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8096";
      };
    };

    virtualHosts."audiobooks.adamjasinski.xyz" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8000";
        proxyWebsockets = true;
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
        proxyPass = "http://127.0.0.1:3002";
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

    virtualHosts."karakeep.adamjasinski.xyz" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:1234";
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

    virtualHosts."freshrss.adamjasinski.xyz" = {
      enableACME = true;
      forceSSL = true;

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
  };
}
