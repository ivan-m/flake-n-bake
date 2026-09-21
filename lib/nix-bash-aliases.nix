{
  lib,
  inputs,
  config-variables,
  includeSystemCommands ? true,
  includeHomeManagerCommands ? true,
}:
let
  hostName = config-variables.hostname;
  userName = config-variables.username;
  # Uses $HOME evaluated at runtime in bash when the aliases are
  # executed, since Nix can't derive it at build time.
  flakeRoot = "\${HOME}/${config-variables.repoRoot}";

  hmTarget = "${userName}@${hostName}";
  nixosTarget = hostName;
in
assert includeSystemCommands || includeHomeManagerCommands;
{
  # Assumption:
  # These commands are intended for a machine managed from a checked-out local
  # flake repository. This is a day-to-day management workflow, not a
  # bootstrap/install-only environment.
  nix-flake-update = "nix flake update --flake ${flakeRoot}";
}
// lib.optionalAttrs includeHomeManagerCommands {
  nix-home-news = "home-manager news --flake ${flakeRoot}#${hmTarget}";
  nix-home-switch = "home-manager switch --flake ${flakeRoot}#${hmTarget}";
  nix-home-build = "home-manager build --flake ${flakeRoot}#${hmTarget}";
}
// lib.optionalAttrs includeSystemCommands {
  nix-system-switch = "sudo nixos-rebuild switch --flake ${flakeRoot}#${nixosTarget}";
  nix-system-test = "sudo nixos-rebuild test --flake ${flakeRoot}#${nixosTarget}";
  nix-system-build = "sudo nixos-rebuild build --flake ${flakeRoot}#${nixosTarget}";
  nix-system-boot = "sudo nixos-rebuild boot --flake ${flakeRoot}#${nixosTarget}";
}
