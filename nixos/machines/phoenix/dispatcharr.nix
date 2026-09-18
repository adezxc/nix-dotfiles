# Dispatcharr (IPTV / stream management) via the official all-in-one OCI
# image. The container bundles everything — nginx, uwsgi, celery, daphne,
# redis and postgres — so the host only provides the state directory and
# the reverse proxy. Podman itself is enabled in audioteka-abs.nix.
#
# The registry publishes only `latest`, `dev` and per-commit tags, so the
# image is pinned by digest (below: 0.31.0, build 20260913174850). To
# upgrade, fetch the new digest and update it here:
#   $ token=$(curl -s 'https://ghcr.io/token?scope=repository:dispatcharr/dispatcharr:pull' | jq -r .token)
#   $ curl -sI -H "Authorization: Bearer $token" \
#       -H "Accept: application/vnd.oci.image.index.v1+json" \
#       https://ghcr.io/v2/dispatcharr/dispatcharr/manifests/latest | grep -i digest
# then `podman image prune` on the host once the new one is running.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # The container's /data tree: m3u/EPG uploads, logos, DVR recordings,
  # plugins, in-app backups, and its internal postgres. Kept in the
  # mediastack state dir so the existing restic backup covers it (see
  # backups.nix for the churny exclusions).
  stateDir = "${config.services.mediastack.stateDir}/dispatcharr";
  # Port of the nginx bundled inside the container
  port = 9191;
in {
  virtualisation.oci-containers.backend = "podman";

  virtualisation.oci-containers.containers."dispatcharr" = {
    # digest-pinned 0.31.0 (see header)
    image = "ghcr.io/dispatcharr/dispatcharr:latest@sha256:f81924fa3dbfeb463b3908be7e086bf58aacbd2ba56062bfb555ee3a471acf8f";

    # Run the container's processes (nginx/uwsgi/celery/postgres) as this
    # user instead of the default 1000 (= adam on this machine), so files
    # in the state dir get a stable, dedicated owner.
    environment = {
      PUID = "271";
      PGID = "271";
      TZ = config.time.timeZone;
    };

    # localhost only — clients go through the iptv.adamjasinski.xyz vhost
    # below (TLS + ACME). Drop the 127.0.0.1 prefix + open the firewall in
    # the ports entry instead for direct LAN/tailscale access.
    ports = [
      "127.0.0.1:${toString port}:${toString port}/tcp"
    ];

    volumes = [
      "${stateDir}:/data"
    ];

    log-driver = "journald";
  };

  systemd.services."podman-dispatcharr" = {
    serviceConfig.Restart = lib.mkOverride 90 "always";
    wantedBy = ["multi-user.target"];
  };

  users.groups.dispatcharr = {
    gid = 271;
  };
  users.users.dispatcharr = {
    isSystemUser = true;
    group = "dispatcharr";
    uid = 271;
  };

  systemd.tmpfiles.rules = [
    "d '${stateDir}' 0750 dispatcharr dispatcharr - -"
    "d '${stateDir}/recordings' 0770 dispatcharr dispatcharr - -"
  ];

  services.nginx.virtualHosts."iptv.adamjasinski.xyz" = {
    enableACME = true;
    forceSSL = true;

    # m3u/EPG and logo uploads go through the proxy
    extraConfig = ''
      client_max_body_size 0;

      proxy_connect_timeout 75;
      proxy_send_timeout 300;
      proxy_read_timeout 300;
    '';

    # The bundled nginx inside the container serves static files, the app
    # and the /ws/ websockets itself — plain reverse proxy is enough.
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      # Live streams are long-lived chunked responses: pass them straight
      # through instead of buffering (same reasoning as the Jellyfin vhost).
      extraConfig = ''
        proxy_buffering off;
        proxy_request_buffering off;
      '';
    };
  };
}
