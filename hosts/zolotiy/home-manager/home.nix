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

  emacs-config = config-variables.emacs-config;
  emacs-work-config = config-variables.emacs-work-config;

  emacsPackageArguments = {
    inherit emacs-config emacs-work-config;
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

        # TODO: work out how to just do a "build and run" approach
        # here to test it rather than requiring switching the whole
        # home-manager configuration. Maybe a `home-manager build`
        # with a `--impure` override-input for the emacs config path?
        hm-emacs-local = ''
            home-manager switch \
          --flake "''${HOME}/${config-variables.repoRoot}#${config-variables.username}@${config-variables.hostId}" \
          --override-input emacs-config "path:''${HOME}/code/emacs"
        '';
      };
    };
    emacs = {
      enable = true;
      package = emacsLib.buildEmacsWithPackages emacsPackageArguments;
    };
  };

  # Instead of ~/.emacs.d
  xdg.configFile."emacs" = {
    source = emacs-config;
  };

  # When work configuration is supplied separately, expose it below the
  # Emacs configuration directory at runtime as well as during packaging.
  xdg.configFile."emacs/work" = mkIf (!emacsLib.isWorkConfigEmpty emacs-work-config) {
    source = emacs-work-config;
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
