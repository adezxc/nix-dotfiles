# mediastack: a hand-rolled replacement for the parts of nixarr that this
# repo's machines actually use. It wires up the stock nixpkgs NixOS modules
# (services.sonarr, services.jellyfin, ...) with:
#
#   - the same fixed UIDs/GIDs nixarr assigned (so file ownership on disk
#     never changes — every value below matches nixarr's defaults, meaning
#     both modules can even be enabled for the same service while migrating)
#   - the same state directory layout (default stateDir is deliberately
#     nixarr's `/data/media/.state/nixarr`, so existing service state —
#     arr databases, Jellyfin config, seerr settings — is picked up as-is)
#   - the media group + UMask 0002 so every service can read/write the
#     shared library tree
#
# Migrating off nixarr, one service at a time:
#
#   1. `services.mediastack.enable = true;`
#   2. for the service you are moving: `nixarr.<svc>.enable = false;` and
#      `services.mediastack.<svc>.enable = true;`
#   3. `nixos-rebuild test`, check the service comes up and sees its state,
#      then `nixos-rebuild switch`. Repeat for the next service.
#
# Deliberately NOT replicated from nixarr (unused here):
#   - vpnConfinement (vpn is disabled everywhere on these machines)
#   - the `*-api` users/groups and `settings-sync` machinery (no
#     nixarr.*.settings-sync options were used)
#   - jellyfin/seerr nginx vhosts are only created for services with a
#     `domain` set; the jellyfin vhost is hand-written in media.nix, so
#     jellyfin only gets the 80/443 firewall opening (exposeHttps).
#
# When every service has moved over, set `nixarr.enable = false` (or drop the
# module from the flake imports) and delete the nixarr input.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.mediastack;

  inherit
    (lib)
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    mkForce
    types
    ;

  mediaDir = cfg.mediaDir;
  stateDir = cfg.stateDir;

  # Fixed IDs, matching `id <user>` on the machines that ran nixarr.
  # sonarr/radarr/lidarr/transmission already match nixpkgs' static ids.nix;
  # the rest are nixarr's own assignments.
  fixedUids = {
    jellyfin = 146;
    seerr = 262;
    transmission = 70;
    recyclarr = 269;
    lidarr = 306;
    sabnzbd = 38;
    audiobookshelf = 980;
    bazarr = 232;
    prowlarr = 293;
    radarr = 275;
    sonarr = 274;
  };
  fixedGids = {
    media = 169;
    seerr = 250;
    prowlarr = 287;
    recyclarr = 269;
  };

  # A system user with a pinned uid, primary group `media` (nixarr's
  # convention for services that share the library tree).
  mediaUser = name: {
    users.users.${name} = {
      isSystemUser = true;
      group = "media";
      uid = fixedUids.${name};
    };
  };
in {
  options.services.mediastack = {
    enable = mkEnableOption "the mediastack module (nixarr replacement)";

    mediaDir = mkOption {
      type = types.str;
      default = "/data/media";
      description = "Root of the media tree (library, torrents, usenet).";
    };

    stateDir = mkOption {
      type = types.str;
      default = "/data/media/.state/nixarr";
      description = ''
        Root of the service state directories. Defaults to nixarr's state
        directory on purpose, so existing state is reused without migration.
        Changing this requires manually moving the per-service directories.
      '';
    };

    jellyfin = {
      enable = mkEnableOption "Jellyfin";
      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open the Jellyfin port (8096) in the firewall.";
      };
      exposeHttps = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Open ports 80/443 for the (hand-written) nginx vhost + ACME. The
          vhost itself lives in machines/phoenix/media.nix.
        '';
      };
    };

    sonarr.enable = mkEnableOption "Sonarr";
    radarr.enable = mkEnableOption "Radarr";

    lidarr = {
      enable = mkEnableOption "Lidarr";
      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open the Lidarr port (8686) in the firewall.";
      };
    };

    prowlarr = {
      enable = mkEnableOption "Prowlarr";
      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open the Prowlarr port (9696) in the firewall.";
      };
    };

    bazarr = {
      enable = mkEnableOption "Bazarr";
      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open the Bazarr port (6767) in the firewall.";
      };
    };

    sabnzbd = {
      enable = mkEnableOption "SABnzbd";
      guiPort = mkOption {
        type = types.port;
        default = 9999;
        description = "SABnzbd web UI port.";
      };
      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open the SABnzbd web UI port in the firewall (and bind to 0.0.0.0).";
      };
    };

    transmission = {
      enable = mkEnableOption "Transmission";
      peerPort = mkOption {
        type = types.nullOr types.port;
        default = null;
        description = "Peer traffic port; also opens it in the firewall when set.";
      };
      settings = mkOption {
        type = types.attrs;
        default = {};
        description = "Extra services.transmission.settings to merge (e.g. ratio limits).";
      };
    };

    seerr = {
      enable = mkEnableOption "Seerr";
      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open the Seerr port (5055) in the firewall.";
      };
      domain = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Domain to expose Seerr on via nginx + ACME (null = no vhost).";
      };
    };

    audiobookshelf = {
      enable = mkEnableOption "Audiobookshelf";
      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open the Audiobookshelf port (9292) in the firewall.";
      };
      domain = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Domain to expose Audiobookshelf on via nginx + ACME (null = no vhost).";
      };
    };

    recyclarr = {
      enable = mkEnableOption "Recyclarr";
      configFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = ''
          Path to the recyclarr YAML config. API keys are injected via the
          SONARR_API_KEY / RADARR_API_KEY environment variables, extracted
          from the arrs' config.xml on each run (recyclarr's !env_var yaml
          tag picks them up).
        '';
      };
      schedule = mkOption {
        type = types.str;
        default = "daily";
        description = "When to run recyclarr sync (systemd calendar format).";
      };
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # === shared: media group + directory layout ===
    {
      users.groups.media.gid = fixedGids.media;

      systemd.tmpfiles.rules = [
        "d '${mediaDir}/library'             0775 root media - -"
        "d '${mediaDir}/library/movies'      0775 root media - -"
        "d '${mediaDir}/library/tv'          0775 root media - -"
        "d '${mediaDir}/library/music'       0775 root media - -"
        "d '${mediaDir}/library/audiobooks'  0775 root media - -"
        "d '${mediaDir}/library/podcasts'    0775 root media - -"
        "d '${mediaDir}/torrents'            0775 root media - -"
        "d '${mediaDir}/usenet/manual'       0775 root media - -"
        "d '${mediaDir}/usenet/watch'        0775 root media - -"
        "d '${mediaDir}/usenet/.incomplete'  0775 root media - -"
      ];
    }

    # === jellyfin (uid 146, group media) ===
    (mkIf cfg.jellyfin.enable (mkMerge [
      (mediaUser "jellyfin")
      {
        services.jellyfin = {
          enable = true;
          user = "jellyfin";
          group = "media";
          openFirewall = cfg.jellyfin.openFirewall;
          logDir = "${stateDir}/jellyfin/log";
          cacheDir = "${stateDir}/jellyfin/cache";
          dataDir = "${stateDir}/jellyfin/data";
          configDir = "${stateDir}/jellyfin/config";
        };
        # keep the nixarr tmpfiles layout (0700, jellyfin:root)
        systemd.tmpfiles.rules = [
          "d '${stateDir}/jellyfin'        0700 jellyfin root - -"
          "d '${stateDir}/jellyfin/log'    0700 jellyfin root - -"
          "d '${stateDir}/jellyfin/cache'  0700 jellyfin root - -"
          "d '${stateDir}/jellyfin/data'   0700 jellyfin root - -"
          "d '${stateDir}/jellyfin/config' 0700 jellyfin root - -"
        ];
        # nixarr ran jellyfin at normal I/O priority (nixpkgs' module
        # defaults to best-effort/idle for its cache churn)
        systemd.services.jellyfin.serviceConfig.IOSchedulingPriority = mkForce 0;
        networking.firewall.allowedTCPPorts =
          mkIf cfg.jellyfin.exposeHttps [80 443];
      }
    ]))

    # === sonarr (uid 274) / radarr (uid 275) — group media, UMask 0002 ===
    (mkIf cfg.sonarr.enable (mkMerge [
      (mediaUser "sonarr")
      {
        services.sonarr = {
          enable = true;
          user = "sonarr";
          group = "media";
          dataDir = "${stateDir}/sonarr";
        };
        systemd.services.sonarr.serviceConfig.UMask = mkForce "0002";
      }
    ]))
    (mkIf cfg.radarr.enable (mkMerge [
      (mediaUser "radarr")
      {
        services.radarr = {
          enable = true;
          user = "radarr";
          group = "media";
          dataDir = "${stateDir}/radarr";
        };
        systemd.services.radarr.serviceConfig.UMask = mkForce "0002";
      }
    ]))

    # === lidarr (uid 306, group media) ===
    # Set services.lidarr.package yourself (e.g. pkgs.lidarr-nightly) — this
    # module deliberately does not pick a package.
    (mkIf cfg.lidarr.enable (mkMerge [
      (mediaUser "lidarr")
      {
        services.lidarr = {
          enable = true;
          user = "lidarr";
          group = "media";
          dataDir = "${stateDir}/lidarr";
          openFirewall = cfg.lidarr.openFirewall;
        };
        systemd.services.lidarr.serviceConfig.UMask = mkForce "0002";
      }
    ]))

    # === prowlarr (uid 293, group prowlarr gid 287) ===
    # The nixpkgs prowlarr module uses DynamicUser; override it to a real
    # user + point -data at the existing state dir, like nixarr did.
    (mkIf cfg.prowlarr.enable (mkMerge [
      {
        users.groups.prowlarr.gid = fixedGids.prowlarr;
        users.users.prowlarr = {
          isSystemUser = true;
          group = "prowlarr";
          uid = fixedUids.prowlarr;
        };
      }
      {
        services.prowlarr = {
          enable = true;
          dataDir = "${stateDir}/prowlarr";
          openFirewall = cfg.prowlarr.openFirewall;
        };
        systemd.services.prowlarr.serviceConfig = {
          User = "prowlarr";
          Group = "prowlarr";
          ExecStart = mkForce "${pkgs.prowlarr}/bin/Prowlarr -nobrowser -data=${stateDir}/prowlarr";
          ReadWritePaths = ["${stateDir}/prowlarr"];
        };
      }
    ]))

    # === bazarr (uid 232, group media) ===
    (mkIf cfg.bazarr.enable (mkMerge [
      (mediaUser "bazarr")
      {
        services.bazarr = {
          enable = true;
          user = "bazarr";
          group = "media";
          dataDir = "${stateDir}/bazarr";
          listenPort = 6767;
          openFirewall = cfg.bazarr.openFirewall;
        };
        systemd.services.bazarr.serviceConfig.UMask = mkForce "0002";
      }
    ]))

    # === sabnzbd (uid 38, group media) ===
    # The ini lives in the nixarr state dir via a bind mount onto
    # /var/lib/sabnzbd (the nixpkgs module's default home for it).
    (mkIf cfg.sabnzbd.enable (mkMerge [
      (mediaUser "sabnzbd")
      {
        services.sabnzbd = {
          enable = true;
          user = "sabnzbd";
          group = "media";
          # configFile = null lets the module merge `settings` into the ini
          # (see the note in machines/phoenix/media.nix)
          configFile = null;
          settings = {
            misc = {
              host =
                if cfg.sabnzbd.openFirewall
                then "0.0.0.0"
                else "127.0.0.1";
              port = cfg.sabnzbd.guiPort;
              download_dir = "${mediaDir}/usenet/.incomplete";
              complete_dir = "${mediaDir}/usenet/manual";
              dirscan_dir = "${mediaDir}/usenet/watch";
              permissions = "775";
            };
          };
        };
        networking.firewall.allowedTCPPorts =
          mkIf cfg.sabnzbd.openFirewall [cfg.sabnzbd.guiPort];
        systemd.services.sabnzbd.serviceConfig = {
          UMask = mkForce "0002";
          BindPaths = ["${stateDir}/sabnzbd:/var/lib/sabnzbd"];
        };
      }
    ]))

    # === transmission (uid 70, group media) ===
    (mkIf cfg.transmission.enable (mkMerge [
      (mediaUser "transmission")
      {
        services.transmission = {
          enable = true;
          # nixpkgs removed transmission_3 and makes the choice explicit;
          # nixarr also ran transmission_4
          package = pkgs.transmission_4;
          user = "transmission";
          group = "media";
          home = "${stateDir}/transmission";
          openPeerPorts = cfg.transmission.peerPort != null;
          settings =
            {
              download-dir = "${mediaDir}/torrents";
              incomplete-dir = "${mediaDir}/torrents/.incomplete";
              incomplete-dir-enabled = true;
              watch-dir-enabled = true;
              watch-dir = "${mediaDir}/torrents/.watch";
              umask = "002";
              rpc-port = 9091;
              rpc-authentication-required = false;
            }
            // (
              if cfg.transmission.peerPort != null
              then {peer-port = cfg.transmission.peerPort;}
              else {}
            )
            // cfg.transmission.settings;
        };
        # deprioritize transmission I/O vs. everything else (nixarr behavior)
        systemd.services.transmission.serviceConfig.IOSchedulingPriority = mkForce 7;
      }
    ]))

    # === seerr (uid 262, group seerr gid 250) ===
    # The nixpkgs seerr module uses DynamicUser; override it to a real user
    # and make the (non-/var/lib) config dir writable.
    (mkIf cfg.seerr.enable (mkMerge [
      {
        users.groups.seerr.gid = fixedGids.seerr;
        users.users.seerr = {
          isSystemUser = true;
          group = "seerr";
          uid = fixedUids.seerr;
        };
      }
      {
        services.seerr = {
          enable = true;
          port = 5055;
          openFirewall = cfg.seerr.openFirewall;
          configDir = "${stateDir}/seerr";
        };
        systemd.services.seerr.serviceConfig = {
          DynamicUser = mkForce false;
          User = "seerr";
          Group = "seerr";
          # configDir is custom, so pin StateDirectory to the plain "seerr"
          # name (the module otherwise derives it from stateRevision)
          StateDirectory = mkForce "seerr";
          ReadWritePaths = ["${stateDir}/seerr"];
        };
        systemd.tmpfiles.rules = [
          "d '${stateDir}/seerr' 0770 seerr seerr - -"
        ];
        services.nginx = mkIf (cfg.seerr.domain != null) {
          enable = true;
          recommendedProxySettings = true;
          virtualHosts."${cfg.seerr.domain}" = {
            enableACME = true;
            forceSSL = true;
            locations."/" = {
              proxyPass = "http://127.0.0.1:5055";
              proxyWebsockets = true;
            };
          };
        };
      }
    ]))

    # === audiobookshelf (uid 980, group media) ===
    # The nixpkgs module keeps everything under /var/lib/<dataDir>; bind
    # mount the nixarr state dir there to reuse config/ and metadata/.
    (mkIf cfg.audiobookshelf.enable (mkMerge [
      (mediaUser "audiobookshelf")
      {
        services.audiobookshelf = {
          enable = true;
          user = "audiobookshelf";
          group = "media";
          port = 9292;
          openFirewall = cfg.audiobookshelf.openFirewall;
        };
        systemd.services.audiobookshelf.serviceConfig = {
          # use the absolute state dir like nixarr did (the nixpkgs module
          # hardcodes /var/lib/<dataDir>)
          StateDirectory = mkForce "${stateDir}/audiobookshelf";
          WorkingDirectory = mkForce "${stateDir}/audiobookshelf";
          # hardening nixarr had that the nixpkgs module lacks
          ProtectSystem = mkForce "strict";
          ReadWritePaths = ["${stateDir}/audiobookshelf"];
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectHome = true;
          ProtectHostname = true;
          ProtectClock = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          NoNewPrivileges = true;
          RestrictRealtime = true;
          RestrictSUIDSGID = true;
          RemoveIPC = true;
          PrivateMounts = true;
          IOSchedulingPriority = mkForce 0;
        };
        systemd.tmpfiles.rules = [
          "d '${stateDir}/audiobookshelf' 0700 audiobookshelf root - -"
        ];
        services.nginx = mkIf (cfg.audiobookshelf.domain != null) {
          enable = true;
          recommendedProxySettings = true;
          virtualHosts."${cfg.audiobookshelf.domain}" = {
            enableACME = true;
            forceSSL = true;
            locations."/" = {
              proxyPass = "http://127.0.0.1:9292";
              proxyWebsockets = true;
            };
          };
        };
      }
    ]))

    # === recyclarr (uid 269, group recyclarr gid 269) ===
    (mkIf cfg.recyclarr.enable (mkMerge [
      {
        users.groups.recyclarr.gid = fixedGids.recyclarr;
        users.users.recyclarr = {
          isSystemUser = true;
          group = "recyclarr";
          uid = fixedUids.recyclarr;
        };
      }
      {
        services.recyclarr = {
          enable = true;
          user = "recyclarr";
          group = "recyclarr";
          schedule = cfg.recyclarr.schedule;
        };
        systemd.tmpfiles.rules = [
          "d '${stateDir}/recyclarr' 0750 recyclarr recyclarr - -"
        ];
        systemd.services.recyclarr =
          mkIf (cfg.recyclarr.configFile != null)
          {
            serviceConfig = {
              ExecStart = mkForce "${pkgs.recyclarr}/bin/recyclarr sync --config ${toString cfg.recyclarr.configFile}";
              Environment = mkForce [
                "RECYCLARR_CONFIG_DIR=${stateDir}/recyclarr"
                "RECYCLARR_DATA_DIR=${stateDir}/recyclarr"
              ];
              EnvironmentFile = "${stateDir}/recyclarr/env";
              # the nixpkgs module only whitelists its own /var/lib state
              # dir — recyclarr writes its cache/logs to ours
              ReadWritePaths = mkForce ["${stateDir}/recyclarr" "/var/lib/recyclarr"];
              # '+' prefix: runs as root — the arrs' config.xml files are
              # 0600 and owned by their respective users
              ExecStartPre = mkForce "+${pkgs.writeShellScript "recyclarr-api-keys" ''
                set -euo pipefail
                umask 077
                envfile='${stateDir}/recyclarr/env'
                : > "$envfile"
                ${lib.optionalString cfg.sonarr.enable ''
                  printf 'SONARR_API_KEY=%s\n' \
                    "$(sed -n 's/.*<ApiKey>\(.*\)<\/ApiKey>.*/\1/p' '${stateDir}/sonarr/config.xml')" \
                    >> "$envfile"
                ''}
                ${lib.optionalString cfg.radarr.enable ''
                  printf 'RADARR_API_KEY=%s\n' \
                    "$(sed -n 's/.*<ApiKey>\(.*\)<\/ApiKey>.*/\1/p' '${stateDir}/radarr/config.xml')" \
                    >> "$envfile"
                ''}
                chown recyclarr:recyclarr "$envfile"
              ''}";
            };
          };
      }
    ]))
  ]);
}
