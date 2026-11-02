{
  agenix,
  config,
  pkgs,
  ...
}:
let
  # Estimated energy comes from average wall power, avoiding brittle
  # differentiation of a cumulative counter.
  energyDashboard = builtins.fromJSON ''
    {
      "annotations": {
        "list": [
          {
            "builtIn": 1,
            "datasource": {
              "type": "datasource",
              "uid": "grafana"
            },
            "enable": true,
            "hide": true,
            "iconColor": "rgba(0, 211, 255, 1)",
            "name": "Annotations & Alerts",
            "target": {
              "limit": 100,
              "matchAny": false,
              "tags": [],
              "type": "dashboard"
            },
            "type": "dashboard"
          }
        ]
      },
      "description": "Estimated energy use for a selected Home Assistant smart plug. Energy is calculated from average wall power, not by differentiating a cumulative counter.",
      "editable": true,
      "fiscalYearStartMonth": 0,
      "graphTooltip": 1,
      "id": null,
      "links": [],
      "panels": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "cf6h66x67ka9sf"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "decimals": 1,
              "unit": "watt"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 5,
            "w": 6,
            "x": 0,
            "y": 0
          },
          "id": 1,
          "options": {
            "colorMode": "value",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "auto",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "textMode": "auto"
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "cf6h66x67ka9sf"
              },
              "expr": "homeassistant_sensor_power_w{entity=~\"$device\"}",
              "refId": "A",
              "instant": true,
              "range": false
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          },
          "title": "Current power",
          "type": "stat",
          "description": "Latest wall-plug reading for the selected device."
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "cf6h66x67ka9sf"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "decimals": 1,
              "unit": "watt"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 5,
            "w": 6,
            "x": 6,
            "y": 0
          },
          "id": 2,
          "options": {
            "colorMode": "value",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "auto",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "textMode": "auto"
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "cf6h66x67ka9sf"
              },
              "expr": "avg_over_time(homeassistant_sensor_power_w{entity=~\"$device\"}[$__range])",
              "refId": "A",
              "instant": true,
              "range": false
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          },
          "title": "Average power",
          "type": "stat",
          "description": "Average wall power over the dashboard time range."
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "cf6h66x67ka9sf"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "decimals": 1,
              "unit": "kwatth"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 5,
            "w": 6,
            "x": 12,
            "y": 0
          },
          "id": 3,
          "options": {
            "colorMode": "value",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "auto",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "textMode": "auto"
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "cf6h66x67ka9sf"
              },
              "expr": "avg_over_time(homeassistant_sensor_power_w{entity=~\"$device\"}[$__range]) * $__range_ms / 3600000000",
              "refId": "A",
              "instant": true,
              "range": false
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          },
          "title": "Estimated energy",
          "type": "stat",
          "description": "Estimated from average power over the selected range. Missing power samples are not interpolated."
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "cf6h66x67ka9sf"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "decimals": 1,
              "unit": "watt"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 5,
            "w": 6,
            "x": 18,
            "y": 0
          },
          "id": 4,
          "options": {
            "colorMode": "value",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "auto",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "textMode": "auto"
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "cf6h66x67ka9sf"
              },
              "expr": "max_over_time(homeassistant_sensor_power_w{entity=~\"$device\"}[$__range])",
              "refId": "A",
              "instant": true,
              "range": false
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          },
          "title": "Peak power",
          "type": "stat",
          "description": "Highest recorded wall power in the selected range."
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "cf6h66x67ka9sf"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "decimals": 1,
              "unit": "kwatth"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 4,
            "w": 8,
            "x": 0,
            "y": 5
          },
          "id": 5,
          "options": {
            "colorMode": "value",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "auto",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "textMode": "auto"
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "cf6h66x67ka9sf"
              },
              "expr": "avg_over_time(homeassistant_sensor_power_w{entity=~\"$device\"}[24h]) * 24 / 1000",
              "refId": "A",
              "instant": true,
              "range": false
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          },
          "title": "Last 24 hours",
          "type": "stat",
          "description": "Estimated energy from average power over the last 24 hours."
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "cf6h66x67ka9sf"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "decimals": 1,
              "unit": "kwatth"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 4,
            "w": 8,
            "x": 8,
            "y": 5
          },
          "id": 6,
          "options": {
            "colorMode": "value",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "auto",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "textMode": "auto"
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "cf6h66x67ka9sf"
              },
              "expr": "avg_over_time(homeassistant_sensor_power_w{entity=~\"$device\"}[7d]) * 7 * 24 / 1000",
              "refId": "A",
              "instant": true,
              "range": false
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          },
          "title": "Last 7 days",
          "type": "stat",
          "description": "Estimated energy from average power over the last 7 days."
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "cf6h66x67ka9sf"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "decimals": 1,
              "unit": "kwatth"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 4,
            "w": 8,
            "x": 16,
            "y": 5
          },
          "id": 7,
          "options": {
            "colorMode": "value",
            "graphMode": "area",
            "justifyMode": "auto",
            "orientation": "auto",
            "reduceOptions": {
              "calcs": [
                "lastNotNull"
              ],
              "fields": "",
              "values": false
            },
            "textMode": "auto"
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "cf6h66x67ka9sf"
              },
              "expr": "avg_over_time(homeassistant_sensor_power_w{entity=~\"$device\"}[30d]) * 30 * 24 / 1000",
              "refId": "A",
              "instant": true,
              "range": false
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              }
            ]
          },
          "title": "Last 30 days",
          "type": "stat",
          "description": "Estimated energy from average power over the last 30 days."
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "cf6h66x67ka9sf"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 18,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "unit": "watt"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 9,
            "w": 24,
            "x": 0,
            "y": 9
          },
          "id": 8,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "cf6h66x67ka9sf"
              },
              "expr": "homeassistant_sensor_power_w{entity=~\"$device\"}",
              "refId": "A",
              "legendFormat": "{{friendly_name}}"
            }
          ],
          "title": "Power history",
          "type": "timeseries",
          "description": "Wall power over the selected time range."
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "cf6h66x67ka9sf"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "bars",
                "fillOpacity": 70,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "unit": "kwatth"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 9,
            "w": 12,
            "x": 0,
            "y": 18
          },
          "id": 9,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "cf6h66x67ka9sf"
              },
              "expr": "avg_over_time(homeassistant_sensor_power_w{entity=~\"$device\"}[$__interval]) * $__interval_ms / 3600000000",
              "refId": "A",
              "legendFormat": "{{friendly_name}}"
            }
          ],
          "title": "Estimated daily energy",
          "type": "timeseries",
          "interval": "1d",
          "description": "Energy per one-day bucket, estimated from average power. Buckets are rolling and may not align exactly to midnight."
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "cf6h66x67ka9sf"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "bars",
                "fillOpacity": 70,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "lineInterpolation": "smooth",
                "lineWidth": 1,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": true,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "unit": "kwatth"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 9,
            "w": 12,
            "x": 12,
            "y": 18
          },
          "id": 10,
          "options": {
            "legend": {
              "calcs": [],
              "displayMode": "list",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "mode": "single",
              "sort": "none"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "cf6h66x67ka9sf"
              },
              "expr": "avg_over_time(homeassistant_sensor_power_w{entity=~\"$device\"}[$__interval]) * $__interval_ms / 3600000000",
              "refId": "A",
              "legendFormat": "{{friendly_name}}"
            }
          ],
          "title": "Estimated weekly energy",
          "type": "timeseries",
          "interval": "7d",
          "description": "Energy per seven-day bucket, estimated from average power."
        }
      ],
      "refresh": "30s",
      "schemaVersion": 39,
      "tags": [
        "energy",
        "home-assistant",
        "power"
      ],
      "templating": {
        "list": [
          {
            "current": {
              "selected": true,
              "text": "Fridge & Dishwasher",
              "value": "sensor.sonoff_s60zbtpf_power"
            },
            "hide": 0,
            "includeAll": false,
            "label": "Device",
            "multi": false,
            "name": "device",
            "options": [
              {
                "selected": true,
                "text": "Fridge & Dishwasher",
                "value": "sensor.sonoff_s60zbtpf_power"
              },
              {
                "selected": false,
                "text": "Home Server",
                "value": "sensor.sonoff_s60zbtpf_power_3"
              }
            ],
            "query": "Fridge & Dishwasher : sensor.sonoff_s60zbtpf_power,Home Server : sensor.sonoff_s60zbtpf_power_3",
            "type": "custom"
          }
        ]
      },
      "time": {
        "from": "now-30d",
        "to": "now"
      },
      "timepicker": {},
      "timezone": "browser",
      "title": "Energy Usage",
      "uid": "energy-usage",
      "version": 1,
      "weekStart": ""
    }
  '';
in {
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
    # Keep enough history for daily/weekly/monthly energy views.
    retentionTime = "90d";
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
    provision.dashboards.settings.providers = [
      {
        name = "energy";
        type = "file";
        options.path = pkgs.writeTextDir "energy-usage.json" (builtins.toJSON energyDashboard);
      }
    ];
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
