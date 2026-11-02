{lib, ...}: {
  users.extraGroups.dialout.members = ["homeassistant"];
  services.home-assistant = {
    enable = true;
    extraComponents = [
      "analytics"
      "met"
      "radio_browser"
      "shopping_list"
      # https://www.home-assistant.io/integrations/isal
      "isal"
      "zha"
      "prometheus"
    ];
    config = {
      default_config = {};
      http = {
        server_port = 8123;
        use_x_forwarded_for = true;
        trusted_proxies = ["127.0.0.1" "::1"];
      };
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
