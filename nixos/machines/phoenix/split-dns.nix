# Split-horizon DNS for the internal zone.
#
# Problem: `*.internal.adamjasinski.xyz` is published in public DNS as
# 192.168.0.180 (phoenix on the LAN). That works at home and nowhere else —
# a phone on mobile data has no route to a private address.
#
# Fix: tailnet devices ask *phoenix* for this zone instead of the public
# resolver, and phoenix answers with its own tailnet address. Both worlds then
# get a reachable IP for the same name:
#
#   LAN client   -> router DNS  -> public wildcard -> 192.168.0.180
#   tailnet dev  -> Split DNS   -> this resolver   -> 100.120.185.22
#   internet     -> public DNS  -> 192.168.0.180   (unroutable, as intended)
#
# The one step that cannot live here is the Tailscale side: point Split DNS for
# `internal.adamjasinski.xyz` at 100.120.185.22 in the admin console
# (DNS page -> Nameservers -> Custom -> enable "Use with split DNS").
{
  config,
  lib,
  ...
}: let
  # phoenix's own tailnet address. Stable for the life of the node; if you ever
  # re-register the machine, update this.
  tailnetIp = "100.120.185.22";
in {
  services.dnsmasq = {
    enable = true;

    # Do NOT take over the host's own resolver; phoenix keeps using
    # Tailscale's MagicDNS for its own lookups.
    resolveLocalQueries = false;

    settings = {
      port = 53;

      # Only answer on the tailnet (and loopback, for `dig @127.0.0.1`).
      # bind-dynamic => binds addresses as interfaces appear, so this survives
      # tailscaled starting after dnsmasq.
      bind-dynamic = true;
      interface = ["tailscale0" "lo"];

      # The whole zone (and any subdomain) resolves to phoenix's tailnet IP.
      address = ["/internal.adamjasinski.xyz/${tailnetIp}"];

      # No upstream: Split DNS only ever sends this one domain here, and
      # anything else must not be answered (or leaked) by this daemon.
      no-resolv = true;
      no-hosts = true;
      domain-needed = true;
      cache-size = 0;

      # Keep the log readable but useful.
      log-queries = false;
      log-facility = "-";
    };
  };

  # tailscale0 and lo are trusted interfaces already (networking.firewall.
  # trustedInterfaces in phoenix.nix), so 53 needs no explicit opening.
  assertions = [
    {
      assertion = builtins.elem "tailscale0" config.networking.firewall.trustedInterfaces;
      message = "split-dns: tailscale0 must stay a trusted interface or DNS over the tailnet will be firewalled.";
    }
  ];
}
