{
  config,
  lib,
  pkgs,
  ...
}:
let
  jellyfinConfigDir = "${config.services.mediastack.stateDir}/jellyfin/config";
  reclaimerrStateDir = "${config.services.mediastack.stateDir}/reclaimerr";
  reclaimerrPort = 8000;

  # --- Music stack (slskd + navidrome + explo; lidarr via mediastack) ---
  slskdStateDir = "${config.services.mediastack.stateDir}/slskd";
  # Completed slskd downloads land here (in `lidarr/<download id>/...` when
  # grabbed through the Lidarr slskd plugin); Lidarr imports them from this
  # dir into its library tree and the plugin deletes the leftovers. Kept
  # OUTSIDE the music library so Navidrome never sees partial downloads.
  slskdDownloadsDir = "${config.services.mediastack.mediaDir}/downloads/slskd";
  exploStateDir = "${config.services.mediastack.stateDir}/explo";
  exploPort = 7288;
  navidromePort = 4533;
  musicDir = "${config.services.mediastack.mediaDir}/library/music";

  # Upper bound (bits/s) for clients that are *not* on the local network.
  # Keeps the web client's auto-quality picker from choosing a bitrate that the
  # real-world peering between ISPs cannot sustain (-> endless buffering).
  # 20 Mbit/s is plenty for 1080p remuxes; raise it if remote users complain
  # about quality instead of buffering.
  jellyfinRemoteBitrateLimit = 20000000;

  # Addresses nginx talks to Jellyfin from. Without these in KnownProxies,
  # Jellyfin sees every remote user as 127.0.0.1 (a "local" client) and skips
  # all remote bandwidth management.
  jellyfinKnownProxies = [
    "127.0.0.1"
    "::1"
  ];
in
{
  # ===================================================================
  # Media stack (formerly the `nixarr` module): stock nixpkgs service
  # modules + the glue in modules/nixos/mediastack.nix. State dirs and uids
  # are identical to what nixarr used, so everything is a drop-in replacement.
  # ===================================================================
  services.mediastack = {
    enable = true;

    jellyfin = {
      enable = true;
      # Do NOT open 8096/8920 to the world: everything goes through nginx +
      # TLS (vhost is hand-written below). Tailscale still reaches Jellyfin
      # directly (tailscale0 is a trusted iface).
      openFirewall = false;
      # opens 80/443 for the nginx vhost + ACME
      exposeHttps = true;
    };

    sonarr.enable = true;
    radarr.enable = true;

    lidarr.enable = true;

    prowlarr.enable = true;
    bazarr.enable = true;

    seerr = {
      enable = true;
      openFirewall = true;
      domain = "seerr.adamjasinski.xyz";
    };

    transmission = {
      enable = true;
      peerPort = 34497; # Set this to the port forwarded by your VPN
      settings = {
        ratio-limit-enabled = true;
        ratio-limit = 2.5;
      };
    };

    sabnzbd = {
      enable = true;
      guiPort = 9999;
      openFirewall = true;
    };

    audiobookshelf = {
      enable = true;
      openFirewall = true;
      domain = "audiobooks.adamjasinski.xyz";
    };

    # Recyclarr gets its SONARR_API_KEY/RADARR_API_KEY env file from the
    # mediastack module, which extracts the keys from the arrs' config.xml.
    recyclarr = {
      enable = true;
      configFile = "/etc/nixos/recyclarr.yaml";
    };
  };

  # Lidarr *nightly*: plugin support (needed for the slskd plugin — Soulseek
  # as indexer + download client) is not in the stable channel.
  services.lidarr.package = pkgs.lidarr-nightly;

  # Reclaimerr follows the mediastack state and media
  # ownership conventions. It needs media-group access to remove sidecar files
  # itself when it deletes or moves a library item.
  users.groups.reclaimerr = { };
  users.users.reclaimerr = {
    isSystemUser = true;
    group = "reclaimerr";
    extraGroups = [ "media" ];
  };

  systemd.tmpfiles.rules = [
    "d '${reclaimerrStateDir}' 0750 reclaimerr reclaimerr - -"
    "d '${slskdStateDir}' 0770 slskd media - -"
    "d '${slskdStateDir}/incomplete' 0770 slskd media - -"
    # setgid so downloads created by slskd (primary group 'slskd') inherit
    # the media group, letting lidarr/explo move and retag them
    "d '${slskdDownloadsDir}' 2775 slskd media - -"
    "d '${exploStateDir}' 0770 explo media - -"
    "d '${exploStateDir}/config' 0770 explo media - -"
    "d '${exploStateDir}/cache' 0770 explo media - -"
    # explo downloads into a subfolder of the music library
    "d '${musicDir}/explo' 0775 explo media - -"
    # Lidarr's own subtree, kept separate from the slskd-managed part
    "d '${musicDir}/lidarr' 0775 lidarr media - -"
    # explo exec's `python3 search_ytmusic.py` from its working directory
    "L+ '${exploStateDir}/search_ytmusic.py' - - - - ${pkgs.explo}/share/explo/search_ytmusic.py"
  ];

  systemd.services.reclaimerr = {
    description = "Reclaimerr media-library cleanup service";
    after = [
      "network-online.target"
      "systemd-tmpfiles-setup.service"
    ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

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
      ReadWritePaths = [
        reclaimerrStateDir
        config.services.mediastack.mediaDir
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [ reclaimerrPort ];

  # ===================================================================
  # Music stack: slskd (Soulseek) + Navidrome + Explo.
  # Lidarr is enabled through mediastack above (port 8686), running the nightly
  # build so the slskd plugin (Soulseek indexer + download client) can be
  # installed from System > Plugins:
  #   https://github.com/allquiet-hub/Lidarr.Plugin.Slskd
  # (add both the indexer and the download client in Lidarr; point them at
  # localhost:5030 with a readwrite slskd API key).
  # ===================================================================

  # slskd: Soulseek daemon with a web UI on port 5030 (tailscale-only).
  # /etc/nixos/slskd.env must provide:
  #   SLSKD_USERNAME / SLSKD_PASSWORD      - web UI login
  #   SLSKD_SLSK_USERNAME / SLSKD_SLSK_PASSWORD - Soulseek network login
  #     (logging in with a fresh username/password registers the account)
  #   SLSKD_API_KEY                        - API key explo uses
  #   SLSKD_JWT_KEY                        - optional, avoids JWT warning
  services.slskd = {
    enable = true;
    environmentFile = "/etc/nixos/slskd.env";
    # Soulseek listen port: incoming peer connections massively improve
    # download speeds, so open it like the torrent peer port.
    openFirewall = true;
    settings = {
      soulseek.description = "phoenix (slskd via NixOS)";
      shares.directories = [ musicDir ];
      directories = {
        downloads = slskdDownloadsDir;
        incomplete = "${slskdStateDir}/incomplete";
      };
    };
  };

  # Share read access to the music library; downloads dir is group-writable
  # for the media group so explo can migrate completed files into the library.
  users.users.slskd.extraGroups = [ "media" ];
  # Group-writable downloads so lidarr/explo can move and retag them.
  systemd.services.slskd.serviceConfig.UMask = "0002";

  # Navidrome: music streaming server (Subsonic API + web UI on 4533).
  # Exposed via nginx at music.adamjasinski.xyz; direct access from LAN and
  # tailscale for mobile Subsonic clients.
  services.navidrome = {
    enable = true;
    openFirewall = true;
    settings = {
      Address = "0.0.0.0";
      Port = navidromePort;
      MusicFolder = musicDir;
      EnableInsightsCollector = false;
      ScanSchedule = "@every 5m";
    };
  };
  users.users.navidrome.extraGroups = [ "media" ];

  # Explo: ListenBrainz-powered music discovery ("Discover Weekly" for
  # Navidrome). Requests missing tracks from slskd (YouTube fallback) and
  # creates playlists in Navidrome. Web UI on port 7288 (tailscale-only).
  # Its entire configuration lives in ${exploStateDir}/.env and is editable
  # from the web UI (WEB_UI=true).
  users.users.explo = {
    isSystemUser = true;
    group = "media";
  };

  systemd.services.explo = {
    description = "Explo music discovery for Navidrome";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    # explo shells out to yt-dlp, ffmpeg and python3 (ytmusicapi fallback for
    # YouTube search when no YOUTUBE_API_KEY is set).
    environment = {
      PATH = lib.mkForce (
        lib.makeBinPath [
          pkgs.ffmpeg
          pkgs.yt-dlp
          (pkgs.python3.withPackages (ps: [ ps.ytmusicapi ]))
        ]
      );
      HOME = exploStateDir;
      XDG_CACHE_HOME = "${exploStateDir}/cache";
      TZ = config.time.timeZone;
    };

    serviceConfig = {
      User = "explo";
      Group = "media";
      WorkingDirectory = exploStateDir;
      ExecStart = "${pkgs.explo}/bin/explo --config ${exploStateDir}/.env";
      Restart = "on-failure";
      RestartSec = "10s";
      UMask = "0002";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [
        exploStateDir
        musicDir
        slskdDownloadsDir
      ];
    };
  };

  # nixpkgs' sabnzbd module only merges `settings` into sabnzbd.ini when
  # configFile is null — it defaults to non-null for stateVersion < 26.05,
  # which would silently ignore the category below (and the mediastack
  # module's settings). The ini still lives at the same place via the
  # mediastack module's BindPaths.
  services.sabnzbd.configFile = null;

  # Lidarr's downloads would otherwise land in SABnzbd's default complete
  # dir (usenet/manual): the "lidarr" category routes them to their own
  # folder, matching the dirs the mediastack module creates per *arr service.
  services.sabnzbd.settings.categories.lidarr = {
    name = "lidarr";
    order = 3;
    dir = "${config.services.mediastack.mediaDir}/usenet/lidarr";
    pp = "";
    script = "";
    newzbin = "";
    priority = -100;
  };

  # Lidarr-managed music lives in its own subtree, separate from the
  # slskd/explo-managed part of the library (everything stays inside
  # musicDir so Navidrome scans it all).
  # NOTE: explo runs with primary group "media" (like the mediastack *arr users,
  # incl. lidarr) so every service in the music pipeline can write into each
  # other's directories — otherwise e.g. explo-created artist folders block
  # Lidarr imports with "Permissions error".

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
    ${lib.concatMapStringsSep "\n" (
      proxy: "        -s '/NetworkConfiguration/KnownProxies' -t elem -n string -v '${proxy}' \\"
    ) jellyfinKnownProxies}
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

    virtualHosts."music.adamjasinski.xyz" = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString navidromePort}";
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
