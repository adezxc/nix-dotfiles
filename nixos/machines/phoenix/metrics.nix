{
  agenix,
  config,
  pkgs,
  ...
}: {
  age.secrets = {
    home-assistant.file = ../../../secrets/home-assistant.age;

    home-assistant.owner = "prometheus";
  };
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
      "rapl"
      "softirqs"
      "systemd"
      "tcpstat"
      "wifi"
    ];
    # You can pass extra options to the exporter using `extraFlags`, e.g.
    # to configure collectors or disable those enabled by default.
    # Enabling a collector is also possible using "--collector.[name]",
    # but is otherwise equivalent to using `enabledCollectors` above.
    extraFlags = ["--collector.ntp.protocol-version=4" "--no-collector.mdadm"];
  };

  services.prometheus.exporters.process = {
    enable = true;
    settings.process_names = [
      {
        name = "{{.Comm}}";
        cmdline = [".*"];
      }
    ];
  };

  # RAPL energy counters are root-only by default. Grant read access to the
  # node-exporter group without running the exporter itself as root.
  systemd.services.prometheus-node-exporter-rapl = {
    description = "Grant node_exporter read access to RAPL energy counters";
    wantedBy = ["prometheus-node-exporter.service"];
    before = ["prometheus-node-exporter.service"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${pkgs.coreutils}/bin/chgrp node-exporter \
        /sys/class/powercap/intel-rapl:0/energy_uj \
        /sys/class/powercap/intel-rapl:0:0/energy_uj \
        /sys/class/powercap/intel-rapl:0:1/energy_uj \
        /sys/class/powercap/intel-rapl:0:2/energy_uj
      ${pkgs.coreutils}/bin/chmod 0440 \
        /sys/class/powercap/intel-rapl:0/energy_uj \
        /sys/class/powercap/intel-rapl:0:0/energy_uj \
        /sys/class/powercap/intel-rapl:0:1/energy_uj \
        /sys/class/powercap/intel-rapl:0:2/energy_uj
    '';
  };

  services.prometheus = {
    enable = true;
    globalConfig.scrape_interval = "30s"; # "1m"
    checkConfig = false;
    scrapeConfigs = [
      {
        job_name = "node_exporter";
        static_configs = [
          {
            targets = [
              "localhost:${toString config.services.prometheus.exporters.node.port}"
            ];
          }
        ];
      }
      {
        job_name = "process_exporter";
        static_configs = [
          {
            targets = [
              "localhost:${toString config.services.prometheus.exporters.process.port}"
            ];
          }
        ];
      }
      {
        job_name = "home_assistant";
        static_configs = [
          {
            targets = [
              "localhost:${toString config.services.home-assistant.config.http.server_port}"
            ];
          }
        ];
        metrics_path = "/api/prometheus";
        bearer_token_file = "${config.age.secrets.home-assistant.path}";
      }
    ];
  };

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "0.0.0.0";
        http_port = 3001;
        enable_gzip = true;
      };
      "auth.anonymous" = {
        enabled = true;
        # Optional: You can also define the role here
        # org_role = "Viewer";
      };
      security.secret_key = "abc";

      "auth.basic" = {
        enabled = false;
        # Optional: You can also define the role here
        # org_role = "Viewer";
      };
      analytics.reporting_enabled = false;
    };
  };
}
