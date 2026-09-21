{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  config-variables,
  emacs-overlay,
  emacsConfigSource,
  emacsConfigIsPath,
  ...
}:
let
  mkIf = lib.mkIf;
  emacsLib = import ../../../lib/emacs.nix {
    inherit lib pkgs emacs-overlay;
  };

  nixShellAliases = import ../../../lib/nix-bash-aliases.nix {
    inherit
      lib
      inputs
      config-variables
      ;
    includeSystemCommands = true;
    includeHomeManagerCommands = true;
  };
in
{
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "steam"
      "steam-run"
      "steam-original"
      "copilot-language-server"
    ];

  programs = {
    home-manager.enable = true;
    command-not-found.enable = false;
    nix-index = {
      # Doesn't actually seem to be working.
      enable = true;
      enableBashIntegration = true;
    };
    bash = {
      enable = true;
      shellAliases = nixShellAliases // {
        # Add any additional shell aliases here
      };
    };
    emacs = mkIf (emacsConfigSource != null) {
      enable = true;
      package = emacsLib.buildEmacsWithPackages {
        emacsConfigPath =
          if emacsConfigIsPath then
            "${config.home.homeDirectory}/${emacsConfigSource}"
          else
            emacsConfigSource;
        inherit emacsConfigIsPath;
      };
    };
  };

  # Instead of ~/.emacs.d
  xdg.configFile."emacs" = mkIf (emacsConfigSource != null) {
    source =
      if emacsConfigIsPath then
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${emacsConfigSource}"
      else
        emacsConfigSource;
  };

  home = {
    username = config-variables.username;
    homeDirectory = "/home/${config-variables.username}";
    stateVersion = config-variables.stateVersion;
    packages =
      with pkgs;
      [
        atool
        chromium
        solaar
      ]
      ++ emacsLib.defaultEmacsToolingPackages;
  };
}
