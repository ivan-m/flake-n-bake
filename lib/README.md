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

## `nix-bash-aliases.nix`

Reusable Home Manager module providing Bash aliases for common flake-based
Home Manager and NixOS workflows.

### Assumptions

This module assumes the system is managed from a checked-out local flake
repository. It uses `inputs.self.outPath` for all generated commands,
including `nix flake update`.

This is intended for normal day-to-day use on a machine already managed by
the flake. It is not intended for bootstrap/install-only environments where
there may be no meaningful local checkout.

### Parameters

- `config-variables`: attribute set containing at least:
  - `username`
  - `hostname`
- `includeSystemCommands` (default: `true`)
- `includeHomeManagerCommands` (default: `true`)

At least one of `includeSystemCommands` or `includeHomeManagerCommands` must be
`true`.

### Aliases

Always included:
- `nix-flake-update`

Home Manager aliases (when enabled):
- `nix-home-news`
- `nix-home-switch`
- `nix-home-build`

NixOS aliases (when enabled):
- `nix-system-switch`
- `nix-system-test`
- `nix-system-build`
- `nix-system-boot`

## `render-bash-aliases.nix`

Renders an attribute set of aliases into a Bash-compatible shell snippet.

### Purpose

This helper is intended primarily for **standalone systems without Home Manager**.

It is useful when you want to reuse the alias definitions produced by
`nix-bash-aliases.nix`, but still keep your existing `~/.bashrc` in charge of
loading the aliases.

Typical workflow:

1. Generate the alias definitions with `nix-bash-aliases.nix`
2. Render them to a Bash snippet with `render-bash-aliases.nix`
3. Install the rendered file into the user profile under `share/`
4. Source that file from `~/.bashrc`

### Input

An attribute set mapping alias names to shell command strings.

Example:

```nix
{
  ll = "ls -l";
  gs = "git status";
}
```

### Output

Bash alias lines, for example:

```bash
alias gs='git status'
alias ll='ls -l'
```

### Example using `nix-bash-aliases.nix`

```nix
let
  lib = import <nixpkgs/lib>;
  flake = builtins.getFlake (toString ./.);

  aliases = import ./lib/nix-bash-aliases.nix {
    inherit lib;
    inputs = flake.inputs // { self = flake; };
    config-variables = {
      username = "ivan";
      hostname = "zolotiy";
      repoRoot = "/home/ivan/flakes";
    };
    includeSystemCommands = true;
    includeHomeManagerCommands = false;
  };

  renderShellAliases = import ./lib/render-bash-aliases.nix;
  aliasesFile = renderShellAliases {
    pkgs = nixpkgs.legacyPackages.${system};
    aliases = aliases // {
      cfg = "cd \"${config-variables.repoRoot}\"";
    };
    fileName = "generated-aliases.sh";
  };
in
# Create a derivation whose output contains the generated Bash script,
# so it can be installed into the user profile under a stable path and
# sourced from ~/.bashrc.
pkgs.runCommand "bash-aliases" { } ''
  mkdir -p $out/share
  cp ${aliasesFile} $out/share/generated-aliases.sh
''
```

### `.bashrc` integration

Add the following to `~/.bashrc`:

```bash
if [ -f "$HOME/.nix-profile/share/generated-aliases.sh" ]; then
  . "$HOME/.nix-profile/share/generated-aliases.sh"
fi
```

This lets you keep your shell startup file unchanged except for a single source
line, while Nix still manages the alias contents.

### Notes

- Output is deterministic: aliases are sorted by name.
- Single quotes in alias commands are escaped appropriately for Bash.
- Keep the checkout path in `config-variables.repoRoot`.
- This helper renders aliases only; it is not a general-purpose shell script generator.
- The returned store path can be copied into a profile-installed output under `share/`.
