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

    # agent-shell
    imagemagick
    wl-clipboard # safe to
    xclip # have both
  ];

  # Accept null/empty paths safely.
  pathHasElFiles =
    path:
    if path == null || path == "" || !builtins.pathExists path then
      false
    else
      let
        allFiles = builtins.attrNames (builtins.readDir path);
        elFiles = builtins.filter (f: lib.hasSuffix ".el" f) allFiles;
      in
      builtins.length elFiles != 0;

  # Check if a work config path is empty (no .el files)
  isWorkConfigEmpty = work-config-path: !(pathHasElFiles work-config-path);

  # Build an Emacs package using use-package declarations from config-path.
  #
  # Notes:
  # - Each call to `buildEmacsWithPackages` returns a distinct Emacs derivation.
  #   If you need separate Emacs builds (for example a stable build and a git/nightly
  #   build), call `buildEmacsWithPackages` twice with different `emacsBuild`
  #   values. The derivations will be separate and will not reuse each other's
  #   build outputs.
  #
  # - `emacsBuild` is intentionally pluggable so callers can pass any Emacs
  #   derivation from `pkgs` (for example `pkgs.emacs-pgtk`, `pkgs.emacsGit`,
  #   or a locally overridden `pkgs.emacs` derivation). The default remains
  #   `pkgs.emacs-pgtk`.
  #
  # - We expect the passed `emacsBuild` derivation to exist in the `pkgs`
  #   you supply. Document that callers are responsible for ensuring the Emacs
  #   derivations they reference are available in their evaluation environment.
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

  # Canonical attribute name used by the flake to expose the
  # per-system test package
  localTestAttr = "emacs-local-test";

  # Convenience wrapper that returns the test package derivation.
  # This function is intended to be called after importing this lib with a system-specific `pkgs`.
  # Example usage in a per-system packages block:
  #   mylib = import ./lib/emacs.nix { inherit lib pkgs emacs-overlay; };
  #   mylib.mkLocalTestPackage { config-variables = cfg; emacsBuild = pkgs.emacs-gtk; }
  mkLocalTestPackage =
    {
      config-variables,
      emacsBuild ? pkgs.emacs-pgtk,
      extraEmacsPackages ? defaultExtraEmacsPackages,
    }:
    buildEmacsWithPackages {
      inherit config-variables extraEmacsPackages emacsBuild;
    };

  # mkLocalTestLauncher: builds a small script that:
  #  - optionally rebuilds the flake package at "${flakeDir}#${packageTarget}"
  #    using --override-input emacs-config/emacs-work-config (if provided),
  #  - materialises the *same* config into a temp init-directory (merging work/),
  #  - runs the resulting Emacs binary with --init-directory "$CONFIG_DIR".
  #
  # Behaviour changes:
  #  - `packageTarget` is optional. When omitted we use the canonical per-system
  #    target "packages.<system>.emacs-local-test".
  #
  # Required inputs:
  #  - config-variables
  #  - flakeDir -- path to the flake root (string)
  #
  # Optional inputs:
  #  - packageTarget            -- flake output attribute path (string); e.g. "packages.x86_64-linux.emacs-local-test"
  #  - emacsConfigOverride      -- local path to override emacs-config input (null = don't override)
  #  - emacsWorkConfigOverride  -- local path to override emacs-work-config input (null = don't override)
  mkLocalTestLauncher =
    {
      config-variables,
      flakeDir,
      packageTarget ? null,
      emacsConfigOverride ? null,
      emacsWorkConfigOverride ? null,
    }:
    let
      # default packageTarget uses the flake packages.<system>.emacs-local-test convention
      inferredPackageTarget =
        if packageTarget != null then
          packageTarget
        else
          "packages.${config-variables.system}.emacs-local-test";

      effectiveConfigPath =
        if emacsConfigOverride != null then emacsConfigOverride else config-variables.emacs-config;

      effectiveWorkConfigPath =
        if emacsWorkConfigOverride != null then
          emacsWorkConfigOverride
        else
          config-variables.emacs-work-config;

      hasConfigOverride = emacsConfigOverride != null;
      hasWorkConfigOverride = emacsWorkConfigOverride != null;

      hasWorkConfig = !isWorkConfigEmpty effectiveWorkConfigPath;

      cfgPathString = toString effectiveConfigPath;
      workPathString = toString effectiveWorkConfigPath;
      targetString = toString inferredPackageTarget;
    in
    pkgs.writeShellScriptBin "test-emacs" ''
            set -euo pipefail

            CONFIG_PATH="${cfgPathString}"
            WORK_CONFIG_PATH="${workPathString}"

            if [[ -n "$CONFIG_PATH" && ! -d "$CONFIG_PATH" ]]; then
              echo "ERROR: emacs-config source does not exist: $CONFIG_PATH" >&2
              exit 1
            fi

            if [[ -n "$WORK_CONFIG_PATH" && ! -d "$WORK_CONFIG_PATH" ]]; then
              echo "ERROR: emacs-work-config source does not exist: $WORK_CONFIG_PATH" >&2
              exit 1
            fi

      # Rebuild the flake package target with overrides if requested.  We intentionally
      # use --impure because the override-input path is typically a local workspace path.
      # --log-format to avoid the spinner making noise.
      STORE_PATH=$(NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link --print-out-paths --log-format raw \
        ${lib.optionalString hasConfigOverride " --override-input emacs-config \"path:$CONFIG_PATH\""} \
        ${lib.optionalString hasWorkConfigOverride " --override-input emacs-work-config \"path:$WORK_CONFIG_PATH\""} \
        "${flakeDir}#${targetString}")

      EMACS_BIN="$STORE_PATH/bin/emacs"
      if [[ ! -x "$EMACS_BIN" ]]; then
        echo "ERROR: built Emacs binary is not executable: $EMACS_BIN" >&2
        exit 1
      fi
            # Create a runtime init directory that mirrors the source used for the build.
            CONFIG_DIR="$(mktemp -d)"
            trap 'rm -rf "$CONFIG_DIR"' EXIT

            cp -a "$CONFIG_PATH"/. "$CONFIG_DIR"/

            ${lib.optionalString hasWorkConfig ''
              mkdir -p "$CONFIG_DIR/work"
              cp -a "$WORK_CONFIG_PATH"/. "$CONFIG_DIR/work"/
            ''}

            echo "Launching Emacs: $EMACS_BIN"
            echo "  init directory: $CONFIG_DIR"

            "$EMACS_BIN" \
              --init-directory "$CONFIG_DIR" \
              "$@"
    '';

in
{
  inherit
    buildEmacsWithPackages
    defaultExtraEmacsPackages
    defaultEmacsToolingPackages
    isWorkConfigEmpty
    localTestAttr
    mkLocalTestPackage
    mkLocalTestLauncher
    ;
}
