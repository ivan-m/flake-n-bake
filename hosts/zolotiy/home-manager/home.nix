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
    emacs = {
      enable = true;
      # Pure GTK version for Wayland
      package = pkgs.emacs-pgtk;
    };
  };

  home = {
    username = config-variables.username;
    homeDirectory = "/home/" + config-variables.username;
    stateVersion = config-variables.stateVersion;
    packages = with pkgs; [
      atool
      chromium
      solaar
    ];
  };
}
