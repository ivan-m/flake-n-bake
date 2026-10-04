{
  lib,
  pkgs,
  emacs-overlay,
}:
let
  defaultExtraEmacsPackages =
    epkgs: with epkgs; [
      # Has a binary component, not just pure .el so best to install it here.
      jinx
      tree-sitter-langs
      treesit-grammars.with-all-grammars
    ];

  # Non-Emacs runtime tools commonly expected by the Emacs config.
  # Use this in HM home.packages or flake package lists so binaries are available.
  defaultEmacsToolingPackages = with pkgs; [
    ripgrep
    fd
    git
    copilot-language-server
    nodejs
    pandoc
    jq
    dhall
    nerd-fonts.symbols-only # For Emacs icons
    nixfmt
    hunspell
    hunspellDicts.en_AU # TODO: make lang configurable?
  ];

  # Check if a work config path is empty (no .el files)
  isWorkConfigEmpty =
    work-config-path:
    let
      allFiles = builtins.attrNames (builtins.readDir work-config-path);
      elFiles = builtins.filter (f: lib.hasSuffix ".el" f) allFiles;
    in
    builtins.length elFiles == 0;

  # Build an Emacs package using use-package declarations from config-path.
  #
  # Required args:
  # - emacs-config: Store path to Emacs config root.
  #   Expected files/dirs:
  #   - init.el
  #   - early-init.el
  #   - extras/*.el (optional)
  #   - work/*.el (optional, or from emacs-work-config)
  # - emacs-work-config: path for work config files (defaults to empty sentinel).
  #   When empty (no .el files), work config is skipped.
  #
  # Optional args:
  # - extraEmacsPackages: function (epkgs -> [ ... ]) for extra packages.
  # - emacsBuild: Emacs derivation to use for building the package. Defaults to pkgs.emacs-pgtk.
  #
  # Returns:
  # - Emacs derivation suitable for programs.emacs.package or systemPackages.
  buildEmacsWithPackages =
    {
      config-variables,
      extraEmacsPackages ? defaultExtraEmacsPackages,
      emacsBuild ? pkgs.emacs-pgtk,
    }:
    let
      emacs-config = config-variables.emacs-config;
      emacs-work-config = config-variables.emacs-work-config;
      workConfigIsEmpty = isWorkConfigEmpty emacs-work-config;

      pkgsWithOverlay = pkgs.extend emacs-overlay.overlays.default;

      loadDir =
        dir:
        if builtins.pathExists dir then
          let
            allFiles = builtins.attrNames (builtins.readDir dir);
          in
          map (f: dir + "/${f}") (builtins.filter (f: lib.hasSuffix ".el" f) allFiles)
        else
          [ ];

      allConfigFiles = [
        (emacs-config + "/init.el")
        (emacs-config + "/early-init.el")
      ]
      ++ loadDir (emacs-config + "/extras")
      ++ (if !workConfigIsEmpty then loadDir emacs-work-config else [ ]);

      # Combine all config files into a single file; the Emacs
      # overlay look for all use-package declarations in the
      # combined file (so we don't have to worry about relative
      # imports).
      combinedConfig = pkgs.writeText "emacs-config.el" (
        builtins.concatStringsSep "\n\n" (map builtins.readFile allConfigFiles)
      );
    in
    pkgsWithOverlay.emacsWithPackagesFromUsePackage {
      config = combinedConfig;
      # Don't try and use our combined mega-file as init.el, just use it for parsing use-package declarations.
      defaultInitFile = false;
      package = emacsBuild;
      extraEmacsPackages = extraEmacsPackages;
    };
in
{
  inherit
    buildEmacsWithPackages
    defaultExtraEmacsPackages
    defaultEmacsToolingPackages
    isWorkConfigEmpty
    ;
}
