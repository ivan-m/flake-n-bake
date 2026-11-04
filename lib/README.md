# Shared library helpers

High-level overview only; see the source files for parameters and details.

| File                       | Purpose                             | Standalone (no Home Manager) use   |
|----------------------------|-------------------------------------|------------------------------------|
| `emacs.nix`                | Build Emacs from a config directory | –                                  |
| `emacs-overlay-mirror.nix` | Mirror ELPA sources                 | –                                  |
| `nix-bash-aliases.nix`     | Nix/HM/NixOS Bash aliases           | Yes, via `render-bash-aliases.nix` |
| `render-bash-aliases.nix`  | Render aliases to a sourceable file | Yes                                |
| `agent-skills.nix`         | Install agent skills                | Yes, via `agent-skills-link.sh`    |

## `emacs.nix`

Builds an Emacs derivation from a checked-in config directory (`init.el`,
`early-init.el`, `extras/*.el`, plus an optional separate work config). The
files are combined only so `use-package` declarations can be discovered and the
packages installed automatically.

Also provides default extra Emacs packages, a list of tooling packages the
config expects, and helpers for per-host local test packages and launchers.

## `emacs-overlay-mirror.nix`

Wraps `nix-community/emacs-overlay` so ELPA packages whose homepage matches a
configured domain are fetched from a GitHub mirror instead, keeping the
original version and hash.

## `nix-bash-aliases.nix`

Attribute set of Bash aliases for flake-based Home Manager, NixOS and
`nix profile` workflows (switch, build, update, install, ...). Each group can
be enabled independently. Assumes a local checkout of this flake
(`config-variables.repoRoot`).

## `render-bash-aliases.nix`

Renders an alias attribute set to a Bash snippet, for systems where
Home Manager can't manage `.bashrc`.

## `agent-skills.nix`

Discovers agent skills (directories containing `SKILL.md`) in one or more
source directories (e.g. non-flake flake inputs) and installs them to
`~/.agents/skills`.

- `mkHomeFiles`: for Home Manager (`home.file`).
- `mkPackage`: for standalone installs; builds `share/agent-skills/<name>`
  symlinks plus `link-skills.sh` (from `agent-skills-link.sh`).

Home Manager's per-tool `skills` options only target each tool's own config
directory, hence this helper.

## Standalone single-user Nix installs

No Home Manager, so everything goes into a single `buildEnv` that is
installed into the user profile, with one-time `.bashrc` lines to source the
generated scripts from `~/.nix-profile`.

```nix
# hosts/$hostId/standalone/configuration.nix
{ pkgs, inputs, config-variables, ... }:
let
  lib = pkgs.lib;
  self = inputs.self.outPath;

  aliases = import "${self}/lib/nix-bash-aliases.nix" {
    inherit lib inputs config-variables;
    includeSystemCommands = false;
    includeHomeManagerCommands = false;
    includeProfileCommands = true;
  };

  aliasesFile = import "${self}/lib/render-bash-aliases.nix" {
    inherit pkgs aliases;
    fileName = "generated-aliases.sh";
  };

  aliasesPackage = pkgs.runCommand "bash-aliases-${config-variables.hostId}" { } ''
    mkdir -p "$out/share"
    cp "${aliasesFile}" "$out/share/generated-aliases.sh"
  '';

  agentSkills = import "${self}/lib/agent-skills.nix" { inherit lib; };

  skillsPackage = agentSkills.mkPackage {
    inherit pkgs;
    sources = [
      "${inputs.mattpocock-skills}/skills/engineering"
      "${inputs.mattpocock-skills}/skills/productivity"
    ];
  };
in
pkgs.buildEnv {
  name = config-variables.hostId;
  paths = [
    aliasesPackage
    skillsPackage
    # other packages ...
  ];
}
```

Add to `~/.bashrc`:

```bash
for f in generated-aliases.sh agent-skills/link-skills.sh; do
  [ -f "$HOME/.nix-profile/share/$f" ] && . "$HOME/.nix-profile/share/$f"
done
```

Notes:

- `link-skills.sh` symlinks skills via the stable `~/.nix-profile` path, so
  profile upgrades take effect immediately. Added/removed skills are
  (un)linked the next time it is sourced (e.g. a new shell).
- It only manages links it created and never overwrites your own skills.
- `AGENT_SKILLS_DIR` overrides the target directory.
