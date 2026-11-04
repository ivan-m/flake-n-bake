{ lib }:
let
  hasSkillFile = dir: builtins.pathExists "${dir}/SKILL.md";

  # Source can be a path/string to a directory containing one folder
  # per skill.  Only folders containing a SKILL.md are considered
  # skills.
  discoverSkills =
    src:
    let
      contents = builtins.readDir src;
      names = builtins.filter (n: contents.${n} == "directory" && hasSkillFile "${src}/${n}") (
        builtins.attrNames contents
      );
    in
    map (name: {
      inherit name;
      path = "${src}/${name}";
    }) names;

  # Later sources override earlier ones on name clashes.
  skillsFromSources =
    sources:
    lib.attrValues (
      lib.listToAttrs (
        map (s: lib.nameValuePair s.name s) (lib.concatMap discoverSkills sources)
      )
    );

  # Home Manager: `home.file = agentSkills.mkHomeFiles { sources = [ ... ]; };`
  mkHomeFiles =
    {
      sources,
      targetDir ? ".agents/skills",
    }:
    lib.listToAttrs (
      map (skill: lib.nameValuePair "${targetDir}/${skill.name}" { source = skill.path; }) (
        skillsFromSources sources
      )
    );

  # Standalone Nix: a package for the user profile with
  #   share/agent-skills/<name>       (symlinks to the skills)
  #   share/agent-skills/link-skills.sh  (script to source from ~/.bashrc)
  mkPackage =
    {
      pkgs,
      sources,
      name ? "agent-skills",
    }:
    let
      skills = skillsFromSources sources;
    in
    pkgs.runCommandLocal name { } ''
      mkdir -p "$out/share/agent-skills"
      ${lib.concatMapStringsSep "\n" (
        s: "ln -s ${lib.escapeShellArg s.path} \"$out/share/agent-skills/\"${lib.escapeShellArg s.name}"
      ) skills}
      cp ${./agent-skills-link.sh} "$out/share/agent-skills/link-skills.sh"
    '';
in
{
  inherit
    discoverSkills
    skillsFromSources
    mkHomeFiles
    mkPackage
    ;
}
