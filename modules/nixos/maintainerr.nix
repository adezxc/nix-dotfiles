{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.maintainerr;
in {
  options.services.maintainerr = {
    enable = lib.mkEnableOption "Maintainerr Service";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.maintainerr; # Points to the derivation we built earlier
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 6246;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.maintainerr = {
      # 1. Create the user and group
      description = "Maintainerr";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        # This automatically creates /var/lib/maintainerr with correct permissions
        StateDirectory = "maintainerr";

        # Run the binary we created in the derivation
        ExecStart = "${pkgs.maintainerr}/bin/maintainerr";
        WorkingDirectory = "/var/lib/maintainerr";
        # Set the environment variable here instead of the package
        Environment = [
          "DATA_DIR=/var/lib/maintainerr"
          "PORT=6246"
        ];

        User = "maintainerr";
        Group = "maintainerr";
        Restart = "always";
      };
    };

    users.users.maintainerr = {
      isSystemUser = true;
      group = "maintainerr";
    };

    users.groups.maintainerr = {};
  };

  # Define the user if not using DynamicUser
}
