{lib, ...}: {
  users.extraGroups.dialout.members = ["homeassistant"];
  services.home-assistant = {
    enable = true;
    extraComponents = [
      # Components required to complete the onboarding
      "analytics"
      "met"
      "radio_browser"
      "shopping_list"
      # Recommended for fast zlib compression
      # https://www.home-assistant.io/integrations/isal
      "isal"
      "zha"
      "prometheus"
    ];
    config = {
      default_config = {};
      homeassistant = {
        name = "Home";
        latitude = "54.71";
        longitude = "25.23";
        elevation = "112";
        unit_system = "metric";
        time_zone = "EET";
      };
      prometheus = {};

      "automation" = "!include automations.yaml";
    };
  };
}
