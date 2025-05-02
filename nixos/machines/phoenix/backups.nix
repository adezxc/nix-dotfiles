{lib, ...}: {
  services.restic.backups."default" = {
    rcloneConfigFile = "/etc/nixos/rclone.conf";
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
