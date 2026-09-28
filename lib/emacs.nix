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

  # Build an Emacs package using use-package declarations from configPath.
  #
  # Required args:
  # - emacsConfig: Store path to Emacs config root.
  #   Expected files/dirs:
  #   - init.el
  #   - early-init.el
  #   - extras/*.el (optional)
  #   - work/*.el (optional by default, or from emacsWorkConfig)
  #
  # Optional args:
  # - emacsWorkConfig: optional separate path for work config files.
  #   When null, defaults to "${emacsConfig}/work" (backward compatible).
  # - extraEmacsPackages: function (epkgs -> [ ... ]) for extra packages.
  # - emacsBuild: Emacs derivation to use for building the package. Defaults to pkgs.emacs-pgtk.
  #
  # Returns:
  # - Emacs derivation suitable for programs.emacs.package or systemPackages.
  buildEmacsWithPackages =
    {
      emacsConfig,
      emacsWorkConfig ? null,
      extraEmacsPackages ? defaultExtraEmacsPackages,
      emacsBuild ? pkgs.emacs-pgtk,
    }:
    if emacsConfig == null then
      throw "buildEmacsWithPackages: `emacsConfig` is mandatory and cannot be null."
    else
      let
        # Work config defaults to emacsConfig/work when not explicitly set.
        resolvedWorkPath = if emacsWorkConfig != null then emacsWorkConfig else (emacsConfig + "/work");
      in
      let
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
          (emacsConfig + "/init.el")
          (emacsConfig + "/early-init.el")
        ]
        ++ loadDir (emacsConfig + "/extras")
        ++ loadDir resolvedWorkPath;

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
  inherit buildEmacsWithPackages defaultExtraEmacsPackages defaultEmacsToolingPackages;
}
