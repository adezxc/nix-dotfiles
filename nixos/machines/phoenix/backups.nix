{
  services.restic.backups."default" = {
    rcloneConfigFile = "/etc/nixos/rclone.conf";
    initialize = true;
    passwordFile = "/etc/nixos/restic-password";
    repository = "sftp:u404718@u404718.your-storagebox.de:/home/resticbackups";
    paths = [
      "/var/backup/vaultwarden"
      "/var/backup/postgresql" # dumps from services.postgresqlBackup below
      "/data/media/photos" # immich library
      "/data/media/.state/nixarr"
      "/data/media/library/audiobooks"
      "/data/media/library/podcasts"
    ];

    # Jellyfin's cache and logs are pure churn (~180 MB re-read every night,
    # nothing restorable in them). Everything else in the state dir matters.
    exclude = [
      "/data/media/.state/nixarr/jellyfin/cache"
      "/data/media/.state/nixarr/jellyfin/log"
    ];

    # Retention: fine granularity for recent accidents, monthlies for a
    # year back, and one snapshot per calendar year kept indefinitely as
    # an archival copy (each yearly pins its unique data in the repo).
    # Runs as `restic forget --prune` at the end of each nightly backup.
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 12"
      "--keep-yearly 75" # effectively: keep every year-end, forever
    ];
  };

  # Live postgres files are not safely copyable — dump the databases
  # instead. Runs at 23:30, ahead of the 00:00 restic backup, so each
  # nightly snapshot contains the same evening's dumps.
  services.postgresqlBackup = {
    enable = true;
    location = "/var/backup/postgresql";
    databases = ["immich"];
    startAt = "*-*-* 23:30:00";
  };
}
