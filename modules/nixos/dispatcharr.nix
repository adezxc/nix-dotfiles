# dispatcharr: native (no containers) NixOS deployment of Dispatcharr, the
# IPTV/stream management app — think "*arr for live TV".
#
# The application itself is packaged in pkgs/dispatcharr.nix (Django +
# gunicorn/gevent, daphne, celery; React frontend built at build time, static
# files collected at build time). This module wires it up:
#
#   - gunicorn on 127.0.0.1:port (gevent workers, like upstream's uwsgi)
#   - daphne on 127.0.0.1:websocketPort (websockets)
#   - celery worker (default queue), dvr worker (thread pool) and beat
#   - redis (celery broker + channel layer + shared cache — NOT optional:
#     celery, daphne and the web workers are separate processes)
#   - PostgreSQL database (Dispatcharr is Postgres-only; sqlite is broken
#     upstream), unix socket + peer auth, no password
#   - optional nginx vhost when `domain` is set
#
# The first boot generates the Django secret key into `${stateDir}/env` and
# runs migrations (dispatcharr-init.service). All units are sandboxed
# (ProtectSystem=strict, ReadWritePaths limited to the state dir).
#
# Deliberate deviations from upstream (see pkgs/dispatcharr.nix):
#   - gunicorn instead of uwsgi (nixpkgs' uwsgi cannot be built with the
#     gevent plugin; the app explicitly supports gunicorn)
#   - no torch/sentence-transformers (optional ML EPG matching falls back
#     to rapidfuzz)
#   - streamlink/yt-dlp/ffmpeg live on the units' PATH, not in the Python env
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.dispatcharr;

  inherit (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    mkForce
    types
    ;

  # Upstream hardcodes its /data tree; the prefix is baked into the package
  # at build time, so it has to come from cfg.stateDir here.
  dispatcharr = (pkgs.callPackage ../../pkgs/dispatcharr.nix { }) { dataDir = cfg.stateDir; };
  dispatcharrStaticDir = "${dispatcharr}/share/dispatcharr/static";

  # Shared by the web/daphne/celery units. The Django secret lives in
  # ${cfg.stateDir}/env (generated on first boot by dispatcharr-init.service)
  # and is added via EnvironmentFile.
  dispatcharrEnv = {
    # aio = celery reaches the web server directly on 127.0.0.1 (see
    # get_dvr_stream_base_url upstream); trusted proxies default to loopback,
    # so the app sees real client IPs behind nginx.
    DISPATCHARR_ENV = "aio";
    DJANGO_SETTINGS_MODULE = "dispatcharr.settings";
    POSTGRES_DB = "dispatcharr";
    POSTGRES_USER = "dispatcharr";
    # Unix socket + peer auth, no password needed
    POSTGRES_HOST = "/run/postgresql";
    REDIS_HOST = "127.0.0.1";
    REDIS_PORT = "6379";
    TZ = config.time.timeZone;
    DISPATCHARR_TIME_ZONE = config.time.timeZone;
    DISPATCHARR_LOG_LEVEL = "INFO";
    # nginx serves /protected-backups/ for X-Accel-Redirect backup downloads
    USE_NGINX_ACCEL = "true";
    DISPATCHARR_MEDIA_ROOT = "${cfg.stateDir}/media";
  };

  # Stream profiles exec ffmpeg / streamlink / yt-dlp as subprocesses. The
  # systemd module defines its own PATH default, hence mkForce.
  dispatcharrBinPath = mkForce (
    lib.makeBinPath [
      pkgs.ffmpeg
      pkgs.streamlink
      pkgs.yt-dlp
      pkgs.coreutils
    ]
  );

  # Shared service hardening for the long-running units. /run/dispatcharr is
  # created via RuntimeDirectory (gunicorn worker tmp dir + sockets).
  dispatcharrServiceConfig = {
    User = "dispatcharr";
    Group = "dispatcharr";
    UMask = "0007";
    RuntimeDirectory = "dispatcharr";
    RuntimeDirectoryMode = "0750";
    EnvironmentFile = "${cfg.stateDir}/env";
    KillMode = "mixed";
    Restart = "on-failure";
    RestartSec = "5s";
    NoNewPrivileges = true;
    PrivateTmp = true;
    ProtectHome = true;
    ProtectSystem = "strict";
    ReadWritePaths = [ cfg.stateDir ];
  };
in
{
  options.services.dispatcharr = {
    enable = mkEnableOption "Dispatcharr (IPTV stream management)";

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/dispatcharr";
      description = ''
        State directory. The subdirectory layout matches upstream's /data
        tree (logos, recordings, uploads, m3us, epgs, plugins, backups,
        logs). The prefix is baked into the package at build time; moving it
        means migrating the tree and the PostgreSQL database manually.
      '';
    };

    domain = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Domain for the nginx vhost (TLS via ACME). When null, the services
        keep listening on 127.0.0.1 only and no vhost is created.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 5656;
      description = "Internal gunicorn port. Celery's DVR worker fetches the TS proxy from here (upstream's aio default).";
    };

    websocketPort = mkOption {
      type = types.port;
      default = 8001;
      description = "Internal daphne (websocket) port.";
    };

    webWorkers = mkOption {
      type = types.ints.positive;
      default = 4;
      description = "Number of gunicorn workers (gevent; each handles many concurrent streams).";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      users.groups.dispatcharr = { };
      users.users.dispatcharr = {
        isSystemUser = true;
        group = "dispatcharr";
      };

      systemd.tmpfiles.rules = [
        "d '${cfg.stateDir}' 0750 dispatcharr dispatcharr - -"
        "d '${cfg.stateDir}/logos' 0750 dispatcharr dispatcharr - -"
        "d '${cfg.stateDir}/recordings' 0770 dispatcharr dispatcharr - -"
        "d '${cfg.stateDir}/uploads/m3us' 0750 dispatcharr dispatcharr - -"
        "d '${cfg.stateDir}/uploads/epgs' 0750 dispatcharr dispatcharr - -"
        "d '${cfg.stateDir}/m3us' 0750 dispatcharr dispatcharr - -"
        "d '${cfg.stateDir}/epgs' 0750 dispatcharr dispatcharr - -"
        "d '${cfg.stateDir}/plugins' 0750 dispatcharr dispatcharr - -"
        "d '${cfg.stateDir}/backups' 0750 dispatcharr dispatcharr - -"
        "d '${cfg.stateDir}/logs' 0750 dispatcharr dispatcharr - -"
        "d '${cfg.stateDir}/media' 0750 dispatcharr dispatcharr - -"
      ];

      # Redis: celery broker + channels layer + django-redis cache.
      services.redis.servers.dispatcharr = {
        enable = true;
        bind = "127.0.0.1";
        port = 6379;
      };

      # PostgreSQL: Dispatcharr is Postgres-only. Peer auth over the unix
      # socket, so no password is involved.
      services.postgresql = {
        enable = true;
        ensureDatabases = [ "dispatcharr" ];
        ensureUsers = [
          {
            name = "dispatcharr";
            ensureDBOwnership = true;
          }
        ];
      };

      systemd.services.dispatcharr-init = {
        description = "Dispatcharr init (Django secret + migrations)";
        after = [
          "network-online.target"
          "postgresql.service"
          "redis-dispatcharr.service"
        ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        environment = dispatcharrEnv;

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "dispatcharr";
          Group = "dispatcharr";
          UMask = "0077";
        };

        script = ''
          set -euo pipefail

          # Generate the Django secret key once; every dispatcharr unit
          # sources it from this file via EnvironmentFile.
          if [ ! -s '${cfg.stateDir}/env' ]; then
            key="$(${pkgs.openssl}/bin/openssl rand -hex 32)"
            printf 'DJANGO_SECRET_KEY=%s\n' "$key" > '${cfg.stateDir}/env'
            chmod 600 '${cfg.stateDir}/env'
          fi

          set -a
          . '${cfg.stateDir}/env'
          set +a

          ${dispatcharr}/bin/dispatcharr-manage migrate --noinput
        '';
      };

      systemd.services.dispatcharr-web = {
        description = "Dispatcharr web (gunicorn, gevent workers)";
        after = [ "dispatcharr-init.service" ];
        requires = [ "dispatcharr-init.service" ];
        wantedBy = [ "multi-user.target" ];

        environment = dispatcharrEnv // {
          PATH = dispatcharrBinPath;
        };

        serviceConfig = dispatcharrServiceConfig // {
          # NO --preload: the gevent worker monkey-patches the interpreter
          # in init_process, which must happen before the Django app is
          # imported.
          ExecStart =
            "${dispatcharr}/bin/dispatcharr-gunicorn dispatcharr.wsgi:application"
            + " --worker-class gevent --workers ${toString cfg.webWorkers}"
            + " --bind 127.0.0.1:${toString cfg.port}"
            + " --timeout 120 --graceful-timeout 30"
            + " --worker-tmp-dir /run/dispatcharr";
        };
      };

      systemd.services.dispatcharr-daphne = {
        description = "Dispatcharr websockets (daphne ASGI)";
        after = [ "dispatcharr-init.service" ];
        requires = [ "dispatcharr-init.service" ];
        wantedBy = [ "multi-user.target" ];

        environment = dispatcharrEnv;

        serviceConfig = dispatcharrServiceConfig // {
          ExecStart =
            "${dispatcharr}/bin/dispatcharr-daphne"
            + " -b 127.0.0.1 -p ${toString cfg.websocketPort}"
            + " dispatcharr.asgi:application";
        };
      };

      systemd.services.dispatcharr-worker = {
        description = "Dispatcharr celery worker (default queue)";
        after = [
          "dispatcharr-init.service"
          "redis-dispatcharr.service"
        ];
        requires = [ "dispatcharr-init.service" ];
        wantedBy = [ "multi-user.target" ];

        environment = dispatcharrEnv // {
          PATH = dispatcharrBinPath;
        };

        serviceConfig = dispatcharrServiceConfig // {
          ExecStart =
            "${dispatcharr}/bin/dispatcharr-celery"
            + " -A dispatcharr worker -Q celery -n default@${config.networking.hostName} --autoscale=4,1";
          Nice = 5;
        };
      };

      systemd.services.dispatcharr-dvr = {
        description = "Dispatcharr celery worker (dvr queue)";
        after = [
          "dispatcharr-init.service"
          "redis-dispatcharr.service"
          "dispatcharr-web.service"
        ];
        requires = [ "dispatcharr-init.service" ];
        wantedBy = [ "multi-user.target" ];

        environment = dispatcharrEnv // {
          PATH = dispatcharrBinPath;
        };

        serviceConfig = dispatcharrServiceConfig // {
          # Thread pool: the run_recording task is long-running and I/O
          # bound (it drives ffmpeg against the TS proxy served by
          # dispatcharr-web).
          ExecStart =
            "${dispatcharr}/bin/dispatcharr-celery"
            + " -A dispatcharr worker -Q dvr -n dvr@${config.networking.hostName} --pool=threads --concurrency=20";
          Nice = 5;
        };
      };

      systemd.services.dispatcharr-beat = {
        description = "Dispatcharr celery beat scheduler";
        after = [
          "dispatcharr-init.service"
          "redis-dispatcharr.service"
        ];
        requires = [ "dispatcharr-init.service" ];
        wantedBy = [ "multi-user.target" ];

        environment = dispatcharrEnv;

        serviceConfig = dispatcharrServiceConfig // {
          ExecStart = "${dispatcharr}/bin/dispatcharr-celery -A dispatcharr beat -l info";
          Nice = 5;
        };
      };
    }

    (mkIf (cfg.domain != null) {
      # nginx serves ${cfg.stateDir}/media and the internal
      # /protected-backups/ location straight from disk (0750 dirs).
      users.users.nginx.extraGroups = [ "dispatcharr" ];

      services.nginx.virtualHosts.${cfg.domain} = {
        enableACME = true;
        forceSSL = true;

        # m3u/EPG uploads and logo uploads go through the proxy
        extraConfig = ''
          client_max_body_size 0;

          proxy_connect_timeout 75;
          proxy_send_timeout 300;
          proxy_read_timeout 300;
        '';

        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
          # Live streams are long-lived chunked responses: pass them
          # straight through instead of buffering.
          extraConfig = ''
            proxy_buffering off;
            proxy_request_buffering off;
          '';
        };

        # WebSockets (live stats, notifications)
        locations."/ws/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.websocketPort}";
          proxyWebsockets = true;
        };

        # Collected at build time by the package — immutable, cacheable
        locations."/static/" = {
          alias = "${dispatcharrStaticDir}/";
          extraConfig = ''
            expires 7d;
          '';
        };

        locations."/assets/" = {
          alias = "${dispatcharrStaticDir}/assets/";
          extraConfig = ''
            expires 7d;
          '';
        };

        locations."/media/" = {
          alias = "${cfg.stateDir}/media/";
        };

        # Internal: Django authorizes backup downloads and redirects here
        # (USE_NGINX_ACCEL=true), nginx serves the file directly.
        locations."/protected-backups/" = {
          alias = "${cfg.stateDir}/backups/";
          extraConfig = ''
            internal;
          '';
        };
      };
    })
  ]);
}
