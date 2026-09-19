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
  ];

  # Build an Emacs package using use-package declarations from configPath.
  #
  # Required args:
  # - configPath: Absolute path or store path to Emacs config root.
  #   Expected files/dirs:
  #   - init.el
  #   - early-init.el
  #   - extras/*.el (optional)
  #   - work/*.el (optional by default, or from emacsWorkConfigPath)
  #
  # Optional args:
  # - emacsConfigIsPath: true when configPath refers to a local filesystem path
  #   that may require --impure to inspect during evaluation.
  # - emacsWorkConfigPath: optional separate path for work config files.
  #   When null, defaults to "${configPath}/work" (backward compatible).
  # - extraEmacsPackages: function (epkgs -> [ ... ]) for extra packages.
  #
  # Returns:
  # - Emacs derivation suitable for programs.emacs.package or systemPackages.
  buildEmacsWithPackages =
    {
      emacsConfigPath,
      emacsConfigIsPath ? false,
      emacsWorkConfigPath ? null,
      emacsWorkConfigIsPath ? emacsConfigIsPath,
      extraEmacsPackages ? defaultExtraEmacsPackages,
    }:
    if emacsConfigPath == null then
      throw "buildEmacsWithPackages: `emacsConfigPath` is mandatory and cannot be null."
    else
      let
        # Base config path visibility in local-path mode.
        isBasePathVisible = (!emacsConfigIsPath) || builtins.pathExists emacsConfigPath;

        # Work config defaults to emacsConfigPath/work when not explicitly set.
        resolvedWorkPath =
          if emacsWorkConfigPath != null then emacsWorkConfigPath else (emacsConfigPath + "/work");

        # Work path visibility depends on its own path-mode flag.
        isWorkPathVisible = (!emacsWorkConfigIsPath) || builtins.pathExists resolvedWorkPath;

        canUseOverlay = isBasePathVisible && isWorkPathVisible;
      in
      if canUseOverlay then
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
            (emacsConfigPath + "/init.el")
            (emacsConfigPath + "/early-init.el")
          ]
          ++ loadDir (emacsConfigPath + "/extras")
          ++ loadDir resolvedWorkPath;
        in
        pkgsWithOverlay.emacsWithPackagesFromUsePackage {
          config = allConfigFiles;
          package = pkgsWithOverlay.emacs-pgtk;
          extraEmacsPackages = extraEmacsPackages;
        }
      else
        # If local paths are not visible in this eval mode, avoid forcing overlay parsing.
        pkgs.emacs-pgtk.pkgs.withPackages extraEmacsPackages;
in
{
  inherit buildEmacsWithPackages defaultExtraEmacsPackages defaultEmacsToolingPackages;
}
