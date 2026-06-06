{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  config-variables,
  ...
}: {
  programs = {
    home-manager.enable = true;
    command-not-found.enable = false;
    nix-index = {
      # Doesn't actually seem to be working.
      enable = true;
      enableBashIntegration = true;
    };
  };
  home.username = config-variables.username;
  home.homeDirectory = "/home/" + config-variables.username;
  home.stateVersion = config-variables.stateVersion;
  home.packages = with pkgs; [
    chromium
    solaar
  ];
}
