{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.jellystat;
in {
  options.services.jellystat = {
    enable = mkEnableOption "Jellystat Service";
    package = mkOption {
      type = types.package;
      default = pkgs.jellystat;
    };

    secretEnvFile = mkOption {
      type = types.path;
      description = "Path to a file containing the JWT_SECRET";
    };
    timezone = mkOption {
      type = types.str;
      default = "Etc/UTC";
    };
    listenIp = mkOption {
      type = types.str;
      default = "0.0.0.0";
    };
    port = mkOption {
      type = types.port;
      default = 3000;
    };

    # Optional SSL/Override settings
    sslEnabled = mkOption {
      type = types.bool;
      default = true;
    };
    sslRejectUnauthorized = mkOption {
      type = types.bool;
      default = false;
    };
  };

  config = mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      ensureDatabases = ["jellystat"];
      ensureUsers = [
        {
          name = "jellystat";
          ensureDBOwnership = true;
        }
      ];
    };

    # 2. Configure the systemd service
    systemd.services.jellystat = {
      description = "Jellystat - Jellyfin Statistics";
      after = ["network.target" "postgresql.service"];
      requires = ["postgresql.service"];
      wantedBy = ["multi-user.target"];


      serviceConfig = {
        # Run node directly on the entrypoint in the writable directory
        PermissionsStartOnly = true; 

        ExecStartPre = pkgs.writeShellScript "jellystat-setup" ''
          # 1. Clean up everything except the database or persistent logs
          # (Using a cleaner wipe to ensure no stale symlinks)
          rm -rf /var/lib/jellystat/backend /var/lib/jellystat/frontend /var/lib/jellystat/node_modules /var/lib/jellystat/package.json

          # 2. Copy the WHOLE package root to /var/lib/jellystat
          # This ensures 'backend/server.js' finds '../../package.json' correctly.
          cp -rp ${cfg.package}/lib/node_modules/jellystat/. /var/lib/jellystat/

          # 3. Use a symlink for the heavy node_modules to save disk space
          rm -rf /var/lib/jellystat/node_modules
          ln -s ${cfg.package}/lib/node_modules/jellystat/node_modules /var/lib/jellystat/node_modules

          # 4. Give the jellystat user ownership
          chown -R jellystat:jellystat /var/lib/jellystat
          chmod -R u+w /var/lib/jellystat
        '';

        # 5. Run node on the server.js inside the backend folder
        ExecStart = "${pkgs.nodejs_22}/bin/node /var/lib/jellystat/backend/server.js";
        Restart = "always";
        User = "jellystat";
        Group = "jellystat";
        EnvironmentFile = [cfg.secretEnvFile];
        StateDirectory = "jellystat";
        WorkingDirectory = "/var/lib/jellystat";

        # Hardening: prevent it from trying to write anywhere else
        ReadWritePaths = ["/var/lib/jellystat"];
      };

      environment = {
        # Match these to your ensureUsers/ensureDatabases
        POSTGRES_USER = "jellystat";
        POSTGRES_DB = "jellystat";
        POSTGRES_IP = "/run/postgresql"; # Use localhost for peer/ident auth
        POSTGRES_PASSWORD = "peer_authentication";
        POSTGRES_PORT = "5432";
        NODE_ENV = "production";
        PORT = "${toString cfg.port}";
      };
    };

    users.users.jellystat = {
      isSystemUser = true;
      group = "jellystat";
      home = "/var/lib/jellystat";
    };
    users.groups.jellystat = {};
  };
}
