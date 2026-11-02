# Internal ingress for phoenix.
#
# Everything that must NOT be world-reachable gets a name under
# *.internal.adamjasinski.xyz, served by nginx behind a LAN + tailnet IP
# allowlist (implementation: modules/nixos/internal-ingress.nix).
#
# Public services (jellyfin, music, seerr, immich, vaultwarden) keep their
# hand-written vhosts in media.nix and are deliberately absent below.
{
  config,
  ...
}: {
  # Wildcard *.internal.adamjasinski.xyz certificate, issued over ACME
  # DNS-01 via the Hostinger API. HTTP-01 is impossible here: these names
  # resolve to a private address, so Let's Encrypt cannot reach them.
  # Token: hPanel -> API -> create token. Replace with `agenix -e`.
  age.secrets.hostinger-dns = {
    file = ../../../secrets/hostinger-dns.age;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  services.internalIngress = {
    enable = true;
    domain = "internal.adamjasinski.xyz";

    allowedCidrs = [
      "127.0.0.1"
      "::1"
      "192.168.0.0/24"
      "100.64.0.0/10"
    ];

    acme = {
      enable = true;
      certName = "internal-wildcard";
      dnsProvider = "hostinger";
      environmentFile = config.age.secrets.hostinger-dns.path;
    };

    services = {
      # --- dashboard ----------------------------------------------------
      # Homepage: lists every service below with a live up/down dot.
      start = {port = 8082;};

      # --- *arr stack ---------------------------------------------------
      sonarr = {port = 8989;};
      radarr = {port = 7878;};
      lidarr = {port = 8686;};
      prowlarr = {port = 9696;};
      bazarr = {port = 6767;};

      # --- downloads ----------------------------------------------------
      sabnzbd = {port = 9999;};
      # Transmission's web UI and RPC share 9091 (whitelist already allows
      # 127.0.0.1, which is where nginx connects from).
      transmission = {port = 9091;};
      slskd = {port = 5030;};

      # --- monitoring ---------------------------------------------------
      # NOTE: grafana has auth.anonymous.enabled = true (Viewer), so anyone
      # on the LAN gets read access; set it to false for a real login wall.
      grafana = {port = 3001;};
      prometheus = {port = 9090;};

      # --- home automation ----------------------------------------------
      home-assistant = {
        subdomain = "home";
        port = 8123;
      };

      # --- apps moved off the public internet ---------------------------
      audiobookshelf = {
        subdomain = "audiobooks";
        port = 9292;
      };
      calibre = {
        port = 8083;
        clientMaxBodySize = "300M";
        extraConfig = ''
          client_body_buffer_size 32k;
          sendfile on;
          send_timeout 300s;
        '';
      };

      # The freshrss module builds its own vhost (root + php-fpm locations)
      # at services.freshrss.virtualHost, so only TLS/ACL/logging are added.
      freshrss = {manageVhost = false;};
    };
  };

  # The public vhosts in media.nix write their own access logs; pre-create
  # those files too (same reason as the tmpfiles rule in
  # modules/nixos/internal-ingress.nix: the sandboxed nginx cannot create
  # them on first start). Keep in sync with the access_log lines in media.nix.
  systemd.tmpfiles.rules = [
    "f /var/log/nginx/jellyfin.log 0640 nginx nginx -"
    "f /var/log/nginx/music.log 0640 nginx nginx -"
    "f /var/log/nginx/vaultwarden.log 0640 nginx nginx -"
    "f /var/log/nginx/immich.log 0640 nginx nginx -"
    "f /var/log/nginx/seerr.log 0640 nginx nginx -"
  ];
}
