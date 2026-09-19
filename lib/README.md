# Shared library helpers

## `emacs.nix`

Exports:

- `buildEmacsWithPackages`
- `defaultExtraEmacsPackages`
- `defaultEmacsToolingPackages`: non-Emacs binaries expected by config
  intended for HM `home.packages`, system packages, or dev shells.

### Import

```nix
let
  emacsLib = import ./lib/emacs.nix {
    inherit lib pkgs emacs-overlay;
  };
in
```

### `buildEmacsWithPackages` API

```nix
emacsLib.buildEmacsWithPackages {
  configPath = ...;                           # required
  emacsConfigIsPath = false;                  # optional, default false
  emacsWorkConfigPath = null;                 # optional, default null
  emacsWorkConfigIsPath = emacsConfigIsPath;  # optional
  extraEmacsPackages = epkgs: [ ... ];        # optional
}
```

#### Arguments

- `configPath` (required): main Emacs config root.
  - Expected: `init.el`, `early-init.el`, optional `extras/*.el`.
- `emacsConfigIsPath`:
  - `true` if `configPath` is a local filesystem path string.
  - `false` if `configPath` is a Nix/store path.
- `emacsWorkConfigPath`:
  - Optional separate path for work `*.el` files.
  - If `null`, defaults to `${configPath}/work` (backward compatible).
- `emacsWorkConfigIsPath`:
  - `true` if `emacsWorkConfigPath` is a local filesystem path string.
  - `false` if it is a Nix/store path.
  - Defaults to `emacsConfigIsPath`.
- `extraEmacsPackages`:
  - Function of shape `epkgs: [ ... ]` for additional Emacs packages.

## Source mode rules (important)

`configPath` and `emacsWorkConfigPath` are independent.

- If a source is a local path string, set the corresponding `*IsPath = true`.
- If a source is a Nix/store path, set the corresponding `*IsPath = false`.
- In mixed mode (one local, one store), set both flags explicitly.

Examples:

- Base store path + work store path:
  - `emacsConfigIsPath = false`
  - `emacsWorkConfigIsPath = false`
- Base local path + work local path:
  - `emacsConfigIsPath = true`
  - `emacsWorkConfigIsPath = true`
- Base store path + work local path:
  - `emacsConfigIsPath = false`
  - `emacsWorkConfigIsPath = true`
- Base local path + work store path:
  - `emacsConfigIsPath = true`
  - `emacsWorkConfigIsPath = false`

## Home Manager usage

In your HM module args:

```nix
{
  emacsConfigSource,
  emacsConfigIsPath,
  emacsWorkConfigPath ? null,
  emacsWorkConfigIsPath ? emacsConfigIsPath,
  ...
}:
```

Then:

```nix
programs.emacs.package = emacsLib.buildEmacsWithPackages {
  configPath =
    if emacsConfigIsPath then
      "${config.home.homeDirectory}/${emacsConfigSource}"
    else
      emacsConfigSource;

  emacsWorkConfigPath =
    if emacsWorkConfigPath == null then
      null
    else if emacsWorkConfigIsPath then
      "${config.home.homeDirectory}/${emacsWorkConfigPath}"
    else
      emacsWorkConfigPath;

  inherit emacsConfigIsPath emacsWorkConfigIsPath;
};
```

Optional runtime symlink of full work directory (including non-`.el` files):

```nix
xdg.configFile."emacs/work" = mkIf (emacsWorkConfigPath != null) {
  source =
    if emacsWorkConfigIsPath then
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${emacsWorkConfigPath}"
    else
      emacsWorkConfigPath;
  recursive = true;
};
```

## Plain flake usage (no Home Manager)

You can consume the helper directly from `packages`/`devShells`:

```nix
{
  outputs = { self, nixpkgs, emacs-overlay, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      lib = nixpkgs.lib;
      emacsLib = import ./lib/emacs.nix {
        inherit lib pkgs emacs-overlay;
      };
    in
    {
      packages.${system}.emacs-custom = emacsLib.buildEmacsWithPackages {
        configPath = ./emacs;                  # store path
        emacsConfigIsPath = false;

        emacsWorkConfigPath = /home/user/emacs-work;  # local path string
        emacsWorkConfigIsPath = true;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [ self.packages.${system}.emacs-custom ];
      };
    };
}
```

For fully reproducible builds, prefer store paths for both base and work config.
