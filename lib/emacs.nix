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
    github-copilot-cli # Would rather not have this, but seems to be launched.
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

  # Canonical suffix used by the flake to expose per-host local test packages.
  localTestAttr = "emacs-local-test";

  # Host-specific package attr name under `packages.<system>`.
  mkLocalTestAttrName = hostId: "${hostId}-${localTestAttr}";

  # Full flake target path for local test package.
  mkLocalTestPackageTarget =
    config-variables:
    "packages.${config-variables.system}.${mkLocalTestAttrName config-variables.hostId}";

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

  # Shared shell fragment:
  # expects CONFIG_PATH, WORK_CONFIG_PATH, CONFIG_DIR to be set.
  mkInitDirectoryShell = ''
    mkdir -p "$CONFIG_DIR"
    ln -s "$CONFIG_PATH"/* "$CONFIG_DIR"/

    if [[ -d "$WORK_CONFIG_PATH" ]]; then
      shopt -s nullglob
      work_el_files=("$WORK_CONFIG_PATH"/*.el)
      if (( ''${#work_el_files[@]} > 0 )); then
        mkdir -p "$CONFIG_DIR/work"
        ln -s "$WORK_CONFIG_PATH"/* "$CONFIG_DIR/work"/
      fi
    fi
  '';

  # Build an Emacs init directory by symlinking config files and optional work config.
  # This is the single source of truth for init-directory materialization.
  mkInitDirectory =
    {
      emacsConfigPath,
      emacsWorkConfigPath,
      name ? "emacs-init-directory",
    }:
    pkgs.runCommandLocal name { } ''
      CONFIG_PATH="${toString emacsConfigPath}"
      WORK_CONFIG_PATH="${toString emacsWorkConfigPath}"
      CONFIG_DIR="$out"

      ${mkInitDirectoryShell}
    '';

  # Shared Launcher script:
  # - optional prelude to compute EMACS_BIN dynamically
  # - common validation/logging/exec path
  # - prelude may set CONFIG_DIR; otherwise initDirectory is used
  mkEmacsLauncher =
    {
      name,
      initDirectory,
      emacsBin ? null,
      prelude ? "",
      useExec ? true,
    }:
    let
      emacsBinLine = if emacsBin != null then ''EMACS_BIN="${toString emacsBin}"'' else "";
      execPrefix = if useExec then "exec" else "";
    in
    pkgs.writeShellScriptBin name ''
      set -euo pipefail

      # This may be overridden by the prelude, but defaults to the initDirectory.
      CONFIG_DIR="${toString initDirectory}"
      ${prelude}
      CONFIG_DIR="''${CONFIG_DIR:-${toString initDirectory}}"
      ${emacsBinLine}

      # Validate required launcher inputs.
      if [ -z "''${EMACS_BIN:-}" ] || [ ! -x "$EMACS_BIN" ]; then
        echo "ERROR: Emacs binary is missing or not executable: ''${EMACS_BIN:-<unset>}" >&2
        exit 1
      fi

      if [ ! -d "$CONFIG_DIR" ]; then
        echo "ERROR: init directory does not exist: $CONFIG_DIR" >&2
        exit 1
      fi

      # `--init-directory` expects init.el in this directory.
      if [ ! -r "$CONFIG_DIR/init.el" ]; then
        echo "ERROR: missing readable init.el in init directory: $CONFIG_DIR/init.el" >&2
        exit 1
      fi

      # On non-NixOS hosts, avoid inheriting GTK/GI module paths that can
      # pull in incompatible host libs (e.g. old RHEL GLib/GIO).
      if [ ! -e /etc/NIXOS ]; then
        unset GIO_EXTRA_MODULES
        unset GI_TYPELIB_PATH
        unset GSETTINGS_SCHEMA_DIR
      fi

      ${execPrefix}"$EMACS_BIN" \
        --init-directory "$CONFIG_DIR" \
        --debug-init \
        "$@"
    '';

  # Stable runtime launcher to run a specific Emacs package with a specific init directory.
  mkWrappedEmacsLauncher =
    {
      emacsPackage,
      config-variables,
      name ? "emacs",
    }:
    let
      emacsInitDirectory = mkInitDirectory {
        emacsConfigPath = config-variables.emacs-config;
        emacsWorkConfigPath = config-variables.emacs-work-config;
        name = "emacs-init-directory";
      };
    in
    mkEmacsLauncher {
      inherit name;
      initDirectory = emacsInitDirectory;
      emacsBin = "${emacsPackage}/bin/emacs";
    };

  # mkLocalTestLauncher: builds a small script that:
  # - optionally rebuilds the flake package at "${flakeDir}#${packageTarget}"
  #   using --override-input emacs-config ... --override-input emacs-work-config
  #   materialises the "same" script into a Nix-built init-directory derivation (merging work/),
  #   runs the resulting Emacs binary with --init-directory "$CONFIG_DIR".
  #
  # Required inputs:
  # - flakeDir
  # - packageTarget
  # Optional inputs:
  # - emacsConfigOverride
  # - emacsWorkConfigOverride
  mkLocalTestLauncher =
    {
      config-variables,
      flakeDir ? "/home/${config-variables.username}/${config-variables.repoRoot}",
      packageTarget ? mkLocalTestPackageTarget config-variables,
      emacsConfigOverride ? null,
      emacsWorkConfigOverride ? null,
    }:
    let
      effectiveConfigPath =
        if emacsConfigOverride != null then emacsConfigOverride else config-variables.emacs-config;
      effectiveWorkConfigPath =
        if emacsWorkConfigOverride != null then
          emacsWorkConfigOverride
        else
          config-variables.emacs-work-config;

      hasConfigOverride = emacsConfigOverride != null;
      hasWorkConfigOverride = emacsWorkConfigOverride != null;

      cfgPathString = toString effectiveConfigPath;
      workPathString = toString effectiveWorkConfigPath;
      targetString = toString packageTarget;
    in
    mkEmacsLauncher {
      name = "test-emacs";
      initDirectory = config-variables.emacs-config;
      useExec = false;
      prelude = ''
        CONFIG_PATH="${cfgPathString}"
        WORK_CONFIG_PATH="${workPathString}"

        if [[ -z "$CONFIG_PATH" || ! -d "$CONFIG_PATH" ]]; then
          echo "ERROR: missing or invalid emacs-config path: $CONFIG_PATH" >&2
          exit 1
        fi

        STORE_PATH=$(NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link --print-out-paths --log-format raw \
          ${lib.optionalString hasConfigOverride "--override-input emacs-config \"path:$CONFIG_PATH\""} \
          ${lib.optionalString hasWorkConfigOverride "--override-input emacs-work-config \"path:$WORK_CONFIG_PATH\""} \
          "${flakeDir}#${targetString}")

        EMACS_BIN="$STORE_PATH/bin/emacs"

        CONFIG_DIR="$(mktemp -d -t test-emacs-init-XXXXXX)"
        trap 'rm -rf "$CONFIG_DIR"' EXIT

        ${mkInitDirectoryShell}
      '';
    };
in
{
  inherit
    defaultExtraEmacsPackages
    defaultEmacsToolingPackages
    buildEmacsWithPackages
    isWorkConfigEmpty
    mkWrappedEmacsLauncher
    localTestAttr
    mkLocalTestAttrName
    mkLocalTestPackageTarget
    mkLocalTestPackage
    mkLocalTestLauncher
    ;
}
