{
  lib,
  ...
}:
{
  users.extraGroups.dialout.members = [ "homeassistant" ];
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
    ];
    config = {
      default_config={};
    };
  };
}
