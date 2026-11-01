# Baked flakes, one system at a time.

This aims to provide a holistic and re-usable configuration to deploy
Nix-based configurations on different systems.

## Per-host configuration

To add a new host:

1. Enable Nix flakes accordingly (TODO: document how).

2. Add a high-level representation of the host to the
   `hostDefinitions` list of records in [flake.nix](flake.nix).

   This allows for some high-level overriding of Nix attributes,
   but in general is meant to be a general dispatch.

3. Define the combination of host configurations are covered:

    |                            | `flake.nix` entry | `hosts/${hostname}/` file      |
    |----------------------------|-------------------|--------------------------------|
    | NixOS operating system     | `nixosHosts`      | `nixos/configuration.nix`      |
    | Home Manager configuration | `homeHosts`       | `home-manager/home.nix`        |
    | Standalone Profiles        | `standaloneHosts` | `standalone/configuration.nix` |

Here, "Standalone Profiles" are Nix profiles that are installed and
used on a non-NixOS operating system (e.g. single-user standalone Nix
install on a work machine).

There is a lot of balancing act between what is defined on a per-host
basis and what is defined centrally in `flake.nix`.

## Emacs configuration

A fair amount of the Nix code here deals with Emacs, which is designed
around [my Emacs
configuration](https://github.com/ivan-m/emacs-regolith).  In
particular, it's configured such that I can re-use the whole machinery
I've built here and have a separate Emacs configuration for use at
work that I can't push upstream, hence the `emacs-work-config` flake
input.

## How to activate for the first time:

* NixOS: TODO

* Home Manager: TODO

* Standalone Profiles: `nix profile add ".#${hostname}` (TODO: how to
  handle existing profiles that provide `nix`, etc.?)
