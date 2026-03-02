{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  ...
}: {
programs.beets = {
  enable = true;
  # Use a package override to include necessary dependencies for plugins
  settings = {
    directory = "/data/media/library/music";
    library = "~/.config/beets/musiclibrary.db";
    
    import = {
      move = true;           # Move files to the library dir
      write = true;          # Write tags to the files
      resume = "ask";
    };

    plugins = [
      "fetchart" 
      "musicbrainz"
      "lastgenre" 
      "permissions"          # Vital for your Jellyfin setup
      "info"
    ];

    # This section ensures Jellyfin can always read/write the files Beets touches
    permissions = {
      file = "664";          # -rw-rw-r--
      dir = "775";           # drwxrwxr-x
    };

    # Standard path formatting for Jellyfin compatibility
    paths = {
      default = "$albumartist/$album%aunique{}/$track $title";
      singleton = "Non-Album/$artist/$title";
      comp = "Compilations/$album%aunique{}/$track $title";
    };
  };
};
}
