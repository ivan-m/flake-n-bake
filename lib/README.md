# Shared library helpers

## `emacs.nix`

Builds an Emacs derivation from a source tree of Emacs Lisp config files, with support for both a shared config and an optional separate work config.

### Purpose

This helper is intended for Home Manager and NixOS configuration where Emacs is built from a checked-in config directory instead of a monolithic package definition.

It:

- loads `init.el` and `early-init.el` from the main Emacs config root
- loads any `extras/*.el` files from the same root
- optionally loads `work/*.el` files from a separate work config path
- concatenates them into one temporary file
- invokes `emacsWithPackagesFromUsePackage` so `use-package` declarations are discovered and the required packages are installed automatically

This keeps your Emacs config in a normal directory layout while still letting Nix manage package installation.

### Inputs

- `config-variables` that contains:
  - `emacs-config`: path to the main Emacs config root
      - expected files:
        - `init.el`
        - `early-init.el`
        - `extras/*.el` (optional)
  - `emacs-work-config`: path to a work-specific config
    - if empty, or if it contains no `.el` files in the top level, it is skipped
- `extraEmacsPackages` (default: `defaultExtraEmacsPackages`): a function such as:
  - `epkgs: [ ... ]`
- `emacsBuild` (default: `pkgs.emacs-pgtk`): the Emacs derivation to use

### Provided values

The module exports:

- `buildEmacsWithPackages`
- `defaultExtraEmacsPackages`
- `defaultEmacsToolingPackages`
- `isWorkConfigEmpty`

### Default extra packages

These are installed automatically unless overridden:

- `jinx`
- `tree-sitter-langs`
- `treesit-grammars.with-all-grammars`

### Default tooling packages

Packages the emacs configuration is known to depend upon.

- `ripgrep`
- `fd`
- `git`
- `copilot-language-server`
- `nodejs`
- `pandoc`
- `jq`
- `dhall`
- `nerd-fonts.symbols-only`
- `nixfmt`
- `hunspell`
- `hunspellDicts.en_AU`

### Example: Home Manager integration

This is the pattern used in `hosts/zolotiy/home-manager/home.nix`:

```nix
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
in
{
  programs = {
    emacs = {
      enable = true;
      package = emacsLib.buildEmacsWithPackages emacsPackageArguments;
    };
  };

  xdg.configFile."emacs" = {
    source = emacs-config;
  };

  xdg.configFile."emacs/work" = mkIf (!emacsLib.isWorkConfigEmpty emacs-work-config) {
    source = emacs-work-config;
    recursive = true;
  };

  home.packages =
    [
      # Other packages you want installed
    ]
    ++ emacsLib.defaultEmacsToolingPackages;
}
```

### Notes

- `isWorkConfigEmpty` checks whether the work config path exists and contains any `.el` files.
- The helper follows a “config directory plus optional work directory” layout; it is not intended for arbitrary Emacs package assembly.
- The resulting package is suitable for `programs.emacs.package` in Home Manager or as a system package in NixOS configuration.
- The temporary combined config file is used only for detecting `use-package` declarations; it is not intended to be the actual runtime `init.el`.

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

- `config-variables`: attribute set containing:
  - `hostId`
  - `repoRoot`
  - `username` when Home Manager commands are enabled
- `includeSystemCommands` (default: `true`)
- `includeHomeManagerCommands` (default: `true`)
- `includeProfileCommands` (default: `false`)

At least one of the `include*Commands` must be `true`.

### Aliases

Always included:

- `nix-flake-update`

Home Manager aliases, when enabled:

- `nix-home-news`
- `nix-home-switch`
- `nix-home-build`

NixOS aliases, when enabled:

- `nix-system-switch`
- `nix-system-test`
- `nix-system-build`
- `nix-system-boot`

Nix profile aliases, when enabled:

- `nix-profile-install`
- `nix-profile-list`
- `nix-profile-upgrade`

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
# hosts/$hostId/standalone/configuration.nix
{
  pkgs,
  inputs,
  config-variables,
  ...
}:

let
  lib = pkgs.lib;

  aliases = import "${inputs.self.outPath}/lib/nix-bash-aliases.nix" {
    inherit
      lib
      inputs
      config-variables
      ;

    includeSystemCommands = false;
    includeHomeManagerCommands = false;
    includeProfileCommands = true;
  };

  renderShellAliases =
    import "${inputs.self.outPath}/lib/render-bash-aliases.nix";

  aliasesFile = renderShellAliases {
    inherit pkgs aliases;

    fileName = "generated-aliases.sh";
  };

  aliasesPackage = pkgs.runCommand "bash-aliases-${config-variables.hostId}" { } ''
    mkdir -p "$out/share"
    cp "${aliasesFile}" "$out/share/generated-aliases.sh"
  '';
in
pkgs.buildEnv {
  name = config-variables.hostId;

  paths = [
    aliasesPackage

    pkgs.fd
    pkgs.jq
    pkgs.ripgrep
    pkgs.tmux
  ];
}
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

## `emacs-overlay-mirror.nix`

This helper wraps a `nix-community/emacs-overlay` and re-points ELPA package
sources at a GitHub mirror when the package homepage matches a configured ELPA
domain.

### Purpose

Some Emacs packages are delivered from ELPA repositories whose package metadata
points at upstream ELPA hosts. In locked-down or slow environments, fetching the
tarballs directly from those hosts can be unreliable. This helper inspects each
package's `meta.homepage`, finds the matching mirror domain, and overrides the
package source URL so it is fetched from a mirror instead.

This keeps the main Emacs overlay intact, while preserving the original package
version and hash checks.

### Inputs

The module exports:

- `mkMirroredEmacsOverlay`
- `defaultMirrorByDomain`

`mkMirroredEmacsOverlay` accepts:

- `emacs-overlay`: the overlay value from `nix-community/emacs-overlay`
- `mirrorByDomain` (optional): a domain-to-URL mapping; defaults to
  `defaultMirrorByDomain`

The default mapping is:

```nix
{
  "elpa.gnu.org" = "https://raw.githubusercontent.com/d12frosted/elpa-mirror/refs/heads/master/gnu";
  "elpa.nongnu.org" = "https://raw.githubusercontent.com/d12frosted/elpa-mirror/refs/heads/master/nongnu";
}
```

### How it works

The helper wraps the overlay's `overlays.default` function and patches the
`emacsPackagesFor` scope:

- it scans each package in the generated Emacs package set
- it checks whether the package is overrideable and has a `meta.homepage`
- it compares the homepage against the configured mirror domains
- if a matching domain is found, it rebuilds the package source URL using the
  mirror base URL and the package version
- it keeps the original `outputHash` so the package remains reproducible

If no mirror matches, the package is returned unchanged.

### Example

```nix
let
  emacsMirror = import ./lib/emacs-overlay-mirror.nix {
    inherit lib pkgs;
  };
in
{
  nixpkgs.overlays = [
    emacsMirror.mkMirroredEmacsOverlay {
      emacs-overlay = inputs.emacs-overlay;
    }
  ];
}
```

### Notes

- This only rewrites packages whose homepage matches one of the configured
  domains.
- It relies on the package being overrideable via `overrideAttrs`.
- It does not rewrite arbitrary package URLs; it only handles those that map to
  known ELPA mirror domains.
- The original package integrity is preserved by reusing the existing source
  hash.
