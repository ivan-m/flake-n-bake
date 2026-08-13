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

  buildEmacsWithPackages = configPath:
    if configPath == null then
      null
    else
      let
        # If we can read the local config directory then we must be running with --impure
        isImpureMode = emacsConfigIsPath && builtins.pathExists configPath;

	extraPackages = epkgs: with epkgs; [
	  tree-sitter-langs
	  treesit-grammars.with-all-grammars
	  ];
      in
        if !emacsConfigIsPath || isImpureMode then
          let
            pkgsWithOverlay = pkgs.extend emacs-overlay.overlays.default;

            loadDir = dir:
              if builtins.pathExists dir then
                let
                  allFiles = builtins.attrNames (builtins.readDir dir);
                in
                  map (f: dir + "/${f}")
                    (builtins.filter (f: lib.hasSuffix ".el" f) allFiles)
              else
                [];

            allConfigFiles =
              [ (configPath + "/init.el") (configPath + "/early-init.el") ] ++
              lib.concatMap (dir: loadDir (configPath + "/${dir}"))
                [ "extras" "work" ];
          in
            pkgsWithOverlay.emacsWithPackagesFromUsePackage {
              config = allConfigFiles;
              package = pkgsWithOverlay.emacs-pgtk;
	      extraEmacsPackages = extraPackages;
            }
        else
          # Don't bother with the overlay, as it may require us to build too many things.
          pkgs.emacs-pgtk.pkgs.withPackages extraPackages;
in
{
  nixpkgs.config.allowUnfreePredicate = pkg:
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
    emacs = mkIf (emacsConfigSource != null) {
      enable = true;
      package = buildEmacsWithPackages (
        if emacsConfigIsPath then
          "${config.home.homeDirectory}/${emacsConfigSource}"
        else
          emacsConfigSource
      );
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
    packages = with pkgs; [
      atool
      chromium
      solaar

      # Additional helpful tools
      copilot-language-server
      nodejs # For copilot-language-server
      git # probably already have
      ripgrep
      fd
    ];
  };
}
