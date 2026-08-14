{
  config,
  lib,
  pkgs,
  ...
}: let
  jellyfinConfigDir = "${config.nixarr.jellyfin.stateDir}/config";
  reclaimerrStateDir = "${config.nixarr.stateDir}/reclaimerr";
  reclaimerrPort = 8000;

  # Upper bound (bits/s) for clients that are *not* on the local network.
  # Keeps the web client's auto-quality picker from choosing a bitrate that the
  # real-world peering between ISPs cannot sustain (-> endless buffering).
  # 20 Mbit/s is plenty for 1080p remuxes; raise it if remote users complain
  # about quality instead of buffering.
  jellyfinRemoteBitrateLimit = 20000000;

  # Addresses nginx talks to Jellyfin from. Without these in KnownProxies,
  # Jellyfin sees every remote user as 127.0.0.1 (a "local" client) and skips
  # all remote bandwidth management.
  jellyfinKnownProxies = ["127.0.0.1" "::1"];
in {
  nixarr = {
    enable = true;
    mediaDir = "/data/media";
    stateDir = "/data/media/.state/nixarr";

    vpn = {
      enable = false;
      wgConf = "/data/.secret/wg.conf";
    };

    jellyfin = {
      enable = true;
      # Do NOT open 8096/8920 to the world: everything goes through nginx + TLS.
      # Tailscale still reaches Jellyfin directly (tailscale0 is a trusted iface).
      openFirewall = false;
      expose.https = {
        enable = true;
        domainName = "jellyfin.adamjasinski.xyz";
        acmeMail = "adam@jasinski.lt";
      };
    };

    seerr = {
      enable = true;
      openFirewall = true;
      expose.https = {
        enable = true;
        domainName = "seerr.adamjasinski.xyz";
        acmeMail = "adam@jasinski.lt";
      };
    };

    transmission = {
      enable = true;
      vpn.enable = false;
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

    lidarr = {
      enable = true;
    };

    sabnzbd = {
      openFirewall = true;
      vpn.enable = false;
      enable = true;
      guiPort = 9999;
    };

    audiobookshelf = {
      enable = true;
      openFirewall = true;
      expose.https = {
        enable = true;
        domainName = "audiobooks.adamjasinski.xyz";
        acmeMail = "adam@jasinski.lt";
      };
    };
    bazarr.enable = true;
    prowlarr.enable = true;
    radarr.enable = true;
    sonarr.enable = true;
  };

  # Reclaimerr is not supported by nixarr yet, but follows its state and media
  # ownership conventions. It needs media-group access to remove sidecar files
  # itself when it deletes or moves a library item.
  users.groups.reclaimerr = {};
  users.users.reclaimerr = {
    isSystemUser = true;
    group = "reclaimerr";
    extraGroups = ["media"];
  };

  systemd.tmpfiles.rules = [
    "d '${reclaimerrStateDir}' 0750 reclaimerr reclaimerr - -"
  ];

  systemd.services.reclaimerr = {
    description = "Reclaimerr media-library cleanup service";
    after = ["network-online.target" "systemd-tmpfiles-setup.service"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    environment = {
      DATA_DIR = reclaimerrStateDir;
      STATIC_DIR = "${reclaimerrStateDir}/static";
      AVATARS_DIR = "${reclaimerrStateDir}/static/avatars";
      FRONTEND_DIST = "${pkgs.reclaimerr}/share/reclaimerr/frontend";
      API_HOST = "0.0.0.0";
      API_PORT = toString reclaimerrPort;
      GRANIAN_HOST = "0.0.0.0";
      GRANIAN_PORT = toString reclaimerrPort;
      TZ = config.time.timeZone;
      COOKIE_SECURE = "false";
    };

    serviceConfig = {
      User = "reclaimerr";
      Group = "reclaimerr";
      WorkingDirectory = reclaimerrStateDir;
      ExecStart = "${pkgs.reclaimerr}/bin/reclaimerr";
      Restart = "on-failure";
      RestartSec = "5s";
      UMask = "0077";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [reclaimerrStateDir config.nixarr.mediaDir];
    };
  };

  networking.firewall.allowedTCPPorts = [reclaimerrPort];

  # Jellyfin keeps its settings in mutable XML files, so patch the two values
  # that matter for remote playback on every service start. Everything else in
  # those files (hardware acceleration, libraries, ...) is left untouched.
  systemd.services.jellyfin.preStart = lib.mkAfter ''
    set -euo pipefail

    xml='${pkgs.xmlstarlet}/bin/xmlstarlet'
    network_xml='${jellyfinConfigDir}/network.xml'
    encoding_xml='${jellyfinConfigDir}/encoding.xml'

    # KnownProxies: make Jellyfin trust X-Forwarded-For coming from nginx, so
    # remote clients stop being reported (and treated) as local 127.0.0.1 ones.
    if [ -f "$network_xml" ]; then
      "$xml" ed -L \
        -d '/NetworkConfiguration/KnownProxies' \
        -s '/NetworkConfiguration' -t elem -n KnownProxies -v "" \
    ${lib.concatMapStringsSep "\n" (proxy: "        -s '/NetworkConfiguration/KnownProxies' -t elem -n string -v '${proxy}' \\") jellyfinKnownProxies}
        "$network_xml"
    fi

    # RemoteClientBitrateLimit: cap the bitrate offered to non-local clients.
    if [ -f "$encoding_xml" ]; then
      if [ "$("$xml" sel -t -v 'count(/EncodingOptions/RemoteClientBitrateLimit)' "$encoding_xml")" = "0" ]; then
        "$xml" ed -L \
          -s '/EncodingOptions' -t elem -n RemoteClientBitrateLimit \
          -v '${toString jellyfinRemoteBitrateLimit}' \
          "$encoding_xml"
      else
        "$xml" ed -L \
          -u '/EncodingOptions/RemoteClientBitrateLimit' \
          -v '${toString jellyfinRemoteBitrateLimit}' \
          "$encoding_xml"
      fi
    fi
  '';

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

    virtualHosts."jellyfin.adamjasinski.xyz" = {
      enableACME = true;
      forceSSL = true;

      extraConfig = ''
        client_max_body_size 20M;
      '';

      locations."/" = {
        proxyPass = "http://127.0.0.1:8096";
        proxyWebsockets = true;
        recommendedProxySettings = true;

        # Video streaming needs long lived, *unbuffered* connections:
        #  - services.nginx.recommendedProxySettings sets 60s send/read
        #    timeouts in the http block. A client whose buffer is full stops
        #    reading, nginx hits the timeout and kills the stream -> the
        #    infamous spinning buffer icon. Override them here.
        #  - proxy_buffering must be off so chunks are passed straight through
        #    instead of being accumulated by nginx first.
        extraConfig = ''
          proxy_buffering off;
          proxy_request_buffering off;
          proxy_connect_timeout 10s;
          proxy_send_timeout 12h;
          proxy_read_timeout 12h;
          send_timeout 12h;
        '';
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
