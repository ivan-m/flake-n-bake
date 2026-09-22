{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  config-variables,
  emacs-overlay,
  emacsConfig,
  emacsWorkConfig,
  ...
}:
let
  mkIf = lib.mkIf;
  emacsLib = import ../../../lib/emacs.nix {
    inherit lib pkgs emacs-overlay;
  };

  resolveEmacsConfigPath =
    resolvedConfig:
    if resolvedConfig == null then
      null
    else if resolvedConfig.isPath then
      "${config.home.homeDirectory}/${resolvedConfig.source}"
    else
      resolvedConfig.source;

  emacsConfigPath = resolveEmacsConfigPath emacsConfig;
  emacsWorkConfigPath = resolveEmacsConfigPath emacsWorkConfig;

  emacsPackageArguments = {
    emacsConfigPath = emacsConfigPath;
    emacsConfigIsPath = emacsConfig.isPath;
  }
  // lib.optionalAttrs (emacsWorkConfig != null) {
    emacsWorkConfigPath = emacsWorkConfigPath;
    emacsWorkConfigIsPath = emacsWorkConfig.isPath;
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
    emacs = mkIf (emacsConfig != null) {
      enable = true;
      package = emacsLib.buildEmacsWithPackages emacsPackageArguments;
    };
  };

  # Instead of ~/.emacs.d
  xdg.configFile."emacs" = mkIf (emacsConfig != null) {
    source =
      if emacsConfig.isPath then
        config.lib.file.mkOutOfStoreSymlink emacsConfigPath
      else
        emacsConfig.source;
  };

  # When work configuration is supplied separately, expose it below the
  # Emacs configuration directory at runtime as well as during packaging.
  xdg.configFile."emacs/work" = mkIf (emacsWorkConfig != null) {
    source =
      if emacsWorkConfig.isPath then
        config.lib.file.mkOutOfStoreSymlink emacsWorkConfigPath
      else
        emacsWorkConfig.source;
    recursive = true;
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
