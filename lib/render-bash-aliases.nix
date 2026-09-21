# Write an attrset of aliases to a Bash-compatible shell snippet in the Nix store.
#
# Intended use:
#   Standalone systems without Home Manager, where Nix is used to build a file
#   containing alias definitions that can then be sourced from an existing
#   ~/.bashrc.
#
# Input:
#   {
#     pkgs = <nixpkgs package set>;
#     aliases = {
#       foo = "echo hello";
#       ll = "ls -l";
#     };
#     fileName ? "generated-aliases.sh";
#   }
#
# Output:
#   A store path to a generated shell file, suitable for sourcing from Bash.
{
  pkgs,
  aliases,
  fileName ? "generated-aliases.sh",
}:
let
  escapeSingleQuotes = s: builtins.replaceStrings [ "'" ] [ "'\\''" ] s;

  aliasNames = builtins.sort builtins.lessThan (builtins.attrNames aliases);

  renderAlias = name: "alias ${name}='${escapeSingleQuotes aliases.${name}}'";

  rendered = builtins.concatStringsSep "\n" (map renderAlias aliasNames) + "\n";
in
pkgs.writeText fileName rendered
