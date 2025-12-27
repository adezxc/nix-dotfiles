{
  lib,
  agenix,
  config,
  ...
}: {
  age.secrets = {
    jellystat.file = ../../../secrets/jellystat.age;

    jellystat.owner = "jellystat";
  };

  services.jellystat = {
    enable = true;
    secretEnvFile = "${config.age.secrets.jellystat.path}";
    timezone = "Europe/Vilnius";
    port = 9595;
  };
}
