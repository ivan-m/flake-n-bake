# Source from ~/.bashrc to link Nix-profile-managed agent skills into
# ~/.agents/skills (override with AGENT_SKILLS_DIR).
#
# Only symlinks pointing into the profile's share/agent-skills are
# managed; other skills in the target directory are left untouched.
_agent_skills_link() {
  local src="${AGENT_SKILLS_PROFILE_DIR:-$HOME/.nix-profile/share/agent-skills}"
  local dest="${AGENT_SKILLS_DIR:-$HOME/.agents/skills}"
  local link target skill name

  [ -d "$dest" ] || mkdir -p "$dest" || return 0

  # Remove stale managed links (skill removed from the profile, or the
  # whole package removed).
  for link in "$dest"/*; do
    [ -L "$link" ] || continue
    target=$(readlink "$link")
    case "$target" in
      "$src"/*) [ -e "$link" ] || rm -f "$link" ;;
    esac
  done

  [ -d "$src" ] || return 0

  for skill in "$src"/*/; do
    [ -d "$skill" ] || continue
    skill=${skill%/}
    name=${skill##*/}
    if [ -L "$dest/$name" ]; then
      [ "$(readlink "$dest/$name")" = "$skill" ] && continue
      case "$(readlink "$dest/$name")" in
        "$src"/*) ln -sfn "$skill" "$dest/$name" ;;
        *) echo "agent-skills: not replacing existing link $dest/$name" >&2 ;;
      esac
    elif [ -e "$dest/$name" ]; then
      echo "agent-skills: not replacing existing $dest/$name" >&2
    else
      ln -s "$skill" "$dest/$name"
    fi
  done
}
_agent_skills_link
unset -f _agent_skills_link
