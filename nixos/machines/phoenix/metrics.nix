{ config, pkgs, ... }:
{
  # https://nixos.org/manual/nixos/stable/#module-services-prometheus-exporters
  # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/nixos/modules/services/monitoring/prometheus/exporters.nix
  services.prometheus.exporters.node = {
    enable = true;
    port = 9000;
    # For the list of available collectors, run, depending on your install:
    # - Flake-based: nix run nixpkgs#prometheus-node-exporter -- --help
    # - Classic: nix-shell -p prometheus-node-exporter --run "node_exporter --help"
    enabledCollectors = [
      "ethtool"   
      "softirqs"
      "systemd"
      "tcpstat"
      "wifi"
    ];
    # You can pass extra options to the exporter using `extraFlags`, e.g.
    # to configure collectors or disable those enabled by default.
    # Enabling a collector is also possible using "--collector.[name]",
    # but is otherwise equivalent to using `enabledCollectors` above.
    extraFlags = [ "--collector.ntp.protocol-version=4" "--no-collector.mdadm" ];
  };

  services.prometheus = {
    enable = true;
    globalConfig.scrape_interval = "30s"; # "1m"
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [{
          targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ];
        }];
      }
    ];
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3000;
        enable_gzip = true;

        # Alternatively, if you want to serve Grafana from a subpath:
        # domain = "your.domain";
        # root_url = "https://your.domain/grafana/";
        # serve_from_sub_path = true;
      };

      # Prevents Grafana from phoning home
      analytics.reporting_enabled = false;
    };
  };
}
