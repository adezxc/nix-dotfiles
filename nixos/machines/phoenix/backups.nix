{lib, ...}: {
  services.restic.backups."default" = {
    rcloneConfig = {
      type = "sftp";
      host = "u404718.your-storagebox.de";
      user = "u404718";
      port = "23";
      key = "4xy1LB5tZb-plOVJFumt78gKRQT0tcOEbdv3eyxrRaw";
    };
    initialize = true;
    passwordFile = "/etc/nixos/restic-password";
    repository = "sftp:u404718@u404718.your-storagebox.de:/home/resticbackups";
    paths = [
      "/var/backup/vaultwarden"
      "/data/media/photos"
      "/data/media/.state/nixarr"
    ];
  };
}
