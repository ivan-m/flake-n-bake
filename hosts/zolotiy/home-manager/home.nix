{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  config-variables,
  emacs-overlay,
  ...
}:
let
  mkIf = lib.mkIf;

  emacsLib = import ../../../lib/emacs.nix {
    inherit lib pkgs emacs-overlay;
  };

  emacsPackageArguments = {
    inherit config-variables;
    emacsBuild = pkgs.emacs-pgtk;
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
    let
      toolingPkgNames = map (p: pkgs.lib.getName p) emacsLib.defaultEmacsToolingPackages;
      allowedPkgNames = toolingPkgNames ++ [
        "steam"
        "steam-run"
        "steam-original"
      ];
    in
    builtins.elem (pkgs.lib.getName pkg) allowedPkgNames;

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
    emacs = {
      enable = true;
      package = emacsLib.buildEmacsWithPackages emacsPackageArguments;
    };
  };

  # Instead of ~/.emacs.d
  xdg.configFile."emacs" = {
    source = config-variables.emacs-config;
  };

  # When work configuration is supplied separately, expose it below the
  # Emacs configuration directory at runtime as well as during packaging.
  xdg.configFile."emacs/work" =
    mkIf (!emacsLib.isWorkConfigEmpty config-variables.emacs-work-config)
      {
        source = config-variables.emacs-work-config;
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

        (emacsLib.mkLocalTestLauncher {
          inherit config-variables;
          emacsConfigOverride = "${config.home.homeDirectory}/code/emacs";
        })
      ]
      ++ emacsLib.defaultEmacsToolingPackages;
  };
}
