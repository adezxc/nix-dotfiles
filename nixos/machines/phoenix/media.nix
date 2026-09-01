{
  config,
  lib,
  pkgs,
  ...
}: let
  jellyfinConfigDir = "${config.nixarr.jellyfin.stateDir}/config";
  reclaimerrStateDir = "${config.nixarr.stateDir}/reclaimerr";
  reclaimerrPort = 8000;

  # --- Music stack (slskd + navidrome + explo; lidarr via nixarr) ---
  slskdStateDir = "${config.nixarr.stateDir}/slskd";
  # Downloads go straight into the music library so Navidrome picks them up
  # automatically (slskd only moves *completed* files here; partial files stay
  # in the incomplete dir under the state directory).
  slskdDownloadsDir = "${config.nixarr.mediaDir}/library/music/slskd";
  exploStateDir = "${config.nixarr.stateDir}/explo";
  beetsStateDir = "${config.nixarr.stateDir}/beets";
  exploPort = 7288;
  navidromePort = 4533;
  musicDir = "${config.nixarr.mediaDir}/library/music";

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

  # beets: auto-import of manual slskd downloads. A timer scans the slskd
  # download inbox every few minutes, tags via MusicBrainz (falls back to the
  # existing tags for obscure Soulseek rips), fetches cover art + genre, and
  # moves albums into the standard library structure. explo keeps managing
  # its own downloads under library/music/explo.
  beetsConfig =
    pkgs.writers.writeYAML "beets-config.yaml"
    {
      directory = musicDir;
      library = "${beetsStateDir}/library.db";
      import = {
        move = true;
        write = true;
        quiet = true;
        quiet_fallback = "asis";
        resume = false;
        duplicate_action = "skip";
        log = "${beetsStateDir}/import.log";
      };
      plugins = "fetchart lastgenre";
      # NOTE: no `permissions` plugin — modes are already 664/775 everywhere
      # via the media group + UMask 0002, and the plugin hard-crashes on
      # foreign-owned files whose mode doesn't match (chmod needs ownership).
      paths = {
        default = "$albumartist/$album%aunique{}/$track $title";
        singleton = "Non-Album/$artist/$title";
        comp = "Compilations/$album%aunique{}/$track $title";
      };
      fetchart.cautious = true;
      lastgenre = {
        count = 3;
        separator = "; ";
        # only accept tags from the canonical genre list — Last.fm top tags
        # include junk like "brittanique" or "seen live"
        whitelist = true;
      };
    };

  beetsImportScript = pkgs.writeShellScript "beets-import" ''
    set -uo pipefail
    inbox="${musicDir}/slskd"
    rc=0
    # Import the *children* of the inbox, not the inbox itself: beets prunes
    # directories it empties, and the inbox dir must never disappear —
    # slskd has a read-write bind mount on it (deleting it orphans that mount
    # and downloads start failing with EROFS until slskd is restarted).
    shopt -s nullglob
    entries=("$inbox"/*)
    shopt -u nullglob
    if [ ''${#entries[@]} -gt 0 ]; then
      ${pkgs.beets}/bin/beet --config ${beetsConfig} import "''${entries[@]}" || rc=$?
      # As-is imports (no MusicBrainz match) skip the import-stage art fetch —
      # fetch covers for any album still missing one (idempotent).
      ${pkgs.beets}/bin/beet --config ${beetsConfig} fetchart || true
      ${pkgs.beets}/bin/beet --config ${beetsConfig} lastgenre || true
      # widen albums that arrived with only a single pre-existing genre tag
      ${pkgs.beets}/bin/beet --config ${beetsConfig} lastgenre --force 'genres::^[^;]+$' || true
      ${pkgs.beets}/bin/beet --config ${beetsConfig} write || true
    fi
    find "$inbox" -mindepth 1 -type d -empty -delete 2>/dev/null || true
    exit $rc
  '';

  # beets for the Lidarr subtree: tags in place (genres, covers, tag fixes)
  # but never moves or renames anything — Lidarr owns the layout there.
  # `incremental` skips already-imported directories, so the timer stays
  # cheap. Separate library DB + log from the slskd-inbox beets.
  beetsLidarrConfig =
    pkgs.writers.writeYAML "beets-lidarr-config.yaml"
    {
      directory = musicDir;
      library = "${beetsStateDir}/lidarr-library.db";
      import = {
        copy = false;
        move = false;
        write = true;
        quiet = true;
        quiet_fallback = "asis";
        resume = false;
        incremental = true;
        duplicate_action = "skip";
        log = "${beetsStateDir}/lidarr-import.log";
      };
      plugins = "fetchart lastgenre";
      # NOTE: no `permissions` plugin here — it chmods files, which requires
      # ownership; in the Lidarr tree beets curates other users' files
      # (lidarr/sabnzbd/adam). Modes are already 664/775 via Lidarr's umask.
      lastgenre = {
        count = 3;
        separator = "; ";
        whitelist = true;
      };
      fetchart.cautious = true;
    };

  beetsLidarrScript = pkgs.writeShellScript "beets-lidarr" ''
    set -uo pipefail
    root="${musicDir}/lidarr"
    rc=0
    if [ -d "$root" ]; then
      ${pkgs.beets}/bin/beet --config ${beetsLidarrConfig} import "$root" || rc=$?
      # pick up anything new (e.g. Lidarr quality upgrades) that the
      # incremental log skipped
      ${pkgs.beets}/bin/beet --config ${beetsLidarrConfig} lastgenre || true
      ${pkgs.beets}/bin/beet --config ${beetsLidarrConfig} fetchart || true
    fi
    # Files often arrive pre-tagged with a single genre (e.g. Lidarr writes
    # one on import), which lastgenre then refuses to overwrite — force a
    # re-fetch for albums that have only one genre, and sync tags to files.
    ${pkgs.beets}/bin/beet --config ${beetsLidarrConfig} lastgenre --force 'genres::^[^;]+$' || true
    ${pkgs.beets}/bin/beet --config ${beetsLidarrConfig} write || true
    exit $rc
  '';

  # Manual whole-library metadata fix-up (missing covers + genres):
  #   sudo systemctl start beets-curate
  beetsCurateScript = pkgs.writeShellScript "beets-curate" ''
    set -uo pipefail
    ${pkgs.beets}/bin/beet --config ${beetsConfig} fetchart || true
    ${pkgs.beets}/bin/beet --config ${beetsConfig} lastgenre || true
    ${pkgs.beets}/bin/beet --config ${beetsConfig} lastgenre --force 'genres::^[^;]+$' || true
    ${pkgs.beets}/bin/beet --config ${beetsConfig} write || true
    ${pkgs.beets}/bin/beet --config ${beetsLidarrConfig} fetchart || true
    ${pkgs.beets}/bin/beet --config ${beetsLidarrConfig} lastgenre || true
    ${pkgs.beets}/bin/beet --config ${beetsLidarrConfig} lastgenre --force 'genres::^[^;]+$' || true
    ${pkgs.beets}/bin/beet --config ${beetsLidarrConfig} write || true
    # fetchart downloads via a 0600 temp file and renames it — fix the mode
    find "${musicDir}" -name cover.jpg -user beets -exec chmod 664 {} + 2>/dev/null || true
  '';
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
    "d '${slskdStateDir}' 0770 slskd media - -"
    "d '${slskdStateDir}/incomplete' 0770 slskd media - -"
    # setgid so downloads created by slskd (primary group 'slskd') inherit the
    # media group, letting beets/explo move and retag them
    "d '${slskdDownloadsDir}' 2775 slskd media - -"
    "d '${exploStateDir}' 0770 explo media - -"
    "d '${exploStateDir}/config' 0770 explo media - -"
    "d '${exploStateDir}/cache' 0770 explo media - -"
    "d '${beetsStateDir}' 0770 beets media - -"
    # explo downloads into a subfolder of the music library
    "d '${musicDir}/explo' 0775 explo media - -"
    # Lidarr's own subtree, kept separate from the slskd/beets-managed part
    "d '${musicDir}/lidarr' 0775 lidarr media - -"
    # explo exec's `python3 search_ytmusic.py` from its working directory
    "L+ '${exploStateDir}/search_ytmusic.py' - - - - ${pkgs.explo}/share/explo/search_ytmusic.py"
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

  # ===================================================================
  # Music stack: slskd (Soulseek) + Navidrome + Explo.
  # Lidarr is enabled through nixarr above (port 8686).
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
      shares.directories = [musicDir];
      directories = {
        downloads = slskdDownloadsDir;
        incomplete = "${slskdStateDir}/incomplete";
      };
    };
  };

  # Share read access to the music library; downloads dir is group-writable
  # for the media group so explo can migrate completed files into the library.
  users.users.slskd.extraGroups = ["media"];
  # Group-writable downloads so beets can retag/move them (media group).
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
  users.users.navidrome.extraGroups = ["media"];

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
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    # explo shells out to yt-dlp, ffmpeg and python3 (ytmusicapi fallback for
    # YouTube search when no YOUTUBE_API_KEY is set).
    environment = {
      PATH =
        lib.mkForce
        (lib.makeBinPath [
          pkgs.ffmpeg
          pkgs.yt-dlp
          (pkgs.python3.withPackages (ps: [ps.ytmusicapi]))
        ]);
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

  users.users.beets = {
    isSystemUser = true;
    group = "media";
  };

  systemd.services.beets-import = {
    description = "beets auto-import of slskd downloads into the music library";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    environment.HOME = beetsStateDir;
    serviceConfig = {
      Type = "oneshot";
      User = "beets";
      Group = "media";
      UMask = "0002";
      # beets prunes the emptied inbox, but slskd needs it to exist — recreate
      # it before each run ('+' prefix: this command runs as root)
      ExecStartPre = "+${pkgs.coreutils}/bin/install -d -o slskd -g media -m 2775 ${slskdDownloadsDir}";
      ExecStart = "${beetsImportScript}";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [musicDir beetsStateDir];
    };
  };

  systemd.timers.beets-import = {
    description = "Periodically import slskd downloads with beets";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "10min";
      OnUnitActiveSec = "5min";
      RandomizedDelaySec = "1min";
      Persistent = true;
    };
  };

  systemd.services.beets-lidarr = {
    description = "beets in-place curation of the Lidarr music subtree";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    environment.HOME = beetsStateDir;
    serviceConfig = {
      Type = "oneshot";
      User = "beets";
      Group = "media";
      UMask = "0002";
      ExecStart = "${beetsLidarrScript}";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = ["${musicDir}/lidarr" beetsStateDir];
    };
  };

  systemd.timers.beets-lidarr = {
    description = "Periodically curate the Lidarr subtree with beets";
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "15min";
      OnUnitActiveSec = "15min";
      RandomizedDelaySec = "2min";
      Persistent = true;
    };
  };

  # Manual curation: stable config paths + beet binary + one-shot service.
  # Quick fix for missing covers/genres:
  #   sudo systemctl start beets-curate
  # Full manual control:
  #   sudo -u beets env HOME=/data/media/.state/nixarr/beets \
  #     beet --config /etc/beets/music-library.yaml <command>
  environment.etc."beets/music-library.yaml".source = beetsConfig;
  environment.etc."beets/lidarr-library.yaml".source = beetsLidarrConfig;
  environment.systemPackages = [pkgs.beets];

  systemd.services.beets-curate = {
    description = "beets: fetch missing covers and genres for the whole library";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    environment.HOME = beetsStateDir;
    serviceConfig = {
      Type = "oneshot";
      User = "beets";
      Group = "media";
      UMask = "0002";
      ExecStart = "${beetsCurateScript}";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [musicDir beetsStateDir];
    };
  };

  # nixpkgs' sabnzbd module only merges `settings` into sabnzbd.ini when
  # configFile is null — it defaults to non-null for stateVersion < 26.05,
  # which would silently ignore the category below (and nixarr's settings).
  # The ini still lives at the same place via nixarr's BindPaths.
  services.sabnzbd.configFile = null;

  # Lidarr's downloads would otherwise land in SABnzbd's default complete
  # dir (usenet/manual): the "lidarr" category routes them to their own
  # folder, matching the dirs nixarr creates per *arr service.
  services.sabnzbd.settings.categories.lidarr = {
    name = "lidarr";
    order = 3;
    dir = "${config.nixarr.mediaDir}/usenet/lidarr";
    pp = "";
    script = "";
    newzbin = "";
    priority = -100;
  };

  # Lidarr-managed music lives in its own subtree, separate from the
  # slskd/beets-managed part of the library (everything stays inside
  # musicDir so Navidrome scans it all).
  # NOTE: beets and explo run with primary group "media" (like nixarr's *arr
  # users) so every service in the music pipeline can write into each other's
  # directories — otherwise e.g. beets-created artist folders block Lidarr
  # imports with "Permissions error".

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
