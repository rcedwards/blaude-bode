#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"
AGENTS_DIR="$REPO_ROOT/agents"
BIN_DIR="$REPO_ROOT/bin"

source "$REPO_ROOT/bin/lib/frontmatter.sh"

HOST=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$HOST" ]]; then
  INSTALL_CLAUDE=false
  INSTALL_CODEX=false
  command -v claude &>/dev/null && INSTALL_CLAUDE=true
  command -v codex &>/dev/null && INSTALL_CODEX=true
  if ! $INSTALL_CLAUDE && ! $INSTALL_CODEX; then
    echo "Neither 'claude' nor 'codex' found on PATH. Use --host to specify a target."
    exit 1
  fi
else
  INSTALL_CLAUDE=false
  INSTALL_CODEX=false
  case "$HOST" in
    claude) INSTALL_CLAUDE=true ;;
    codex) INSTALL_CODEX=true ;;
    *) echo "Unknown host: $HOST (valid: claude, codex)"; exit 1 ;;
  esac
fi

symlink_into_place() {
  local source="$1" target="$2" label="$3"

  mkdir -p "$(dirname "$target")"

  if [[ -L "$target" ]]; then
    local resolved
    resolved="$(readlink "$target")"
    if [[ "$resolved" != "$source" && "$resolved" != "$REPO_ROOT"/* ]]; then
      echo "  [$label] WARNING: $target is a symlink to $resolved (not managed by this repo) - skipping"
      return 0
    fi
    rm "$target"
  elif [[ -e "$target" ]]; then
    echo "  [$label] WARNING: $target exists and is not a symlink - backing up to $target.bak"
    mv "$target" "$target.bak"
  fi

  ln -s "$source" "$target"
}

migrate_legacy_blaude_bode_dir() {
  local legacy_dir="$HOME/.claude/skills/blaude-bode"
  [[ -d "$legacy_dir" && ! -L "$legacy_dir" ]] || return 0

  local entry name resolved expected has_unexpected=false
  shopt -s nullglob dotglob
  for entry in "$legacy_dir"/*; do
    name="$(basename "$entry")"

    if [[ "$name" == ".DS_Store" ]]; then
      rm -f "$entry"
      continue
    fi

    expected="$SKILLS_DIR/$name"

    if [[ -L "$entry" ]]; then
      resolved="$(readlink "$entry")"
      if [[ "$resolved" == "$expected" ]]; then
        rm "$entry"
        echo "  [claude/skill] migrated nested symlink blaude-bode/$name"
        continue
      fi
    elif [[ -d "$entry" && -L "$entry/SKILL.md" ]]; then
      resolved="$(readlink "$entry/SKILL.md")"
      if [[ "$resolved" == "$expected/SKILL.md" ]]; then
        rm -rf "$entry"
        echo "  [claude/skill] migrated nested managed directory blaude-bode/$name"
        continue
      fi
    fi

    echo "  [claude/skill] WARNING: unexpected content at blaude-bode/$name - leaving in place"
    has_unexpected=true
  done
  shopt -u nullglob dotglob

  if ! $has_unexpected; then
    if rmdir "$legacy_dir" 2>/dev/null; then
      echo "  [claude/skill] removed empty legacy blaude-bode directory"
    else
      echo "  [claude/skill] WARNING: could not remove legacy blaude-bode directory"
    fi
  fi
}

install_claude() {
  local skills_base="$HOME/.claude/skills"
  local agents_base="$HOME/.claude/agents"
  local skill_dir skill_file skill_name target
  local agent_dir agent_file agent_name

  mkdir -p "$skills_base" "$agents_base"

  migrate_legacy_blaude_bode_dir

  for skill_dir in "$SKILLS_DIR"/*; do
    [[ -d "$skill_dir" ]] || continue
    skill_file="$skill_dir/SKILL.md"
    [[ -f "$skill_file" ]] || continue

    skill_name="$(frontmatter_get "$skill_file" "name")"
    require_field "$skill_file" "name" "$skill_name"
    frontmatter_validate_excluded_hosts "$skill_file"

    if frontmatter_host_is_excluded "$skill_file" "claude"; then
      continue
    fi

    target="$skills_base/$skill_name"

    symlink_into_place "$skill_dir" "$target" "claude/skill"
    echo "  [claude/skill] $skill_name -> $target"
    check_requires "$skill_file"
  done

  for target in "$skills_base"/*; do
    [[ -L "$target" ]] || continue
    local resolved_source
    resolved_source="$(readlink "$target")"
    if [[ "$resolved_source" == "$SKILLS_DIR/"* ]]; then
      if [[ ! -e "$resolved_source" ]]; then
        rm "$target"
        echo "  [claude/skill] removed stale symlink $(basename "$target")"
        continue
      fi

      local resolved_skill_file="$resolved_source/SKILL.md"
      if [[ -f "$resolved_skill_file" ]]; then
        frontmatter_validate_excluded_hosts "$resolved_skill_file"
        if frontmatter_host_is_excluded "$resolved_skill_file" "claude"; then
          rm "$target"
          echo "  [claude/skill] removed host-excluded symlink $(basename "$target")"
        fi
      fi
    fi
  done

  for agent_dir in "$AGENTS_DIR"/*; do
    [[ -d "$agent_dir" ]] || continue
    agent_file="$agent_dir/AGENT.md"
    [[ -f "$agent_file" ]] || continue

    agent_name="$(frontmatter_get "$agent_file" "name")"
    require_field "$agent_file" "name" "$agent_name"
    frontmatter_validate_excluded_hosts "$agent_file"

    if frontmatter_host_is_excluded "$agent_file" "claude"; then
      continue
    fi

    target="$agents_base/$agent_name.md"

    symlink_into_place "$agent_file" "$target" "claude/agent"
    echo "  [claude/agent] $agent_name -> $target"
  done

  for target in "$agents_base"/*.md; do
    [[ -L "$target" ]] || continue
    local resolved_source
    resolved_source="$(readlink "$target")"
    if [[ "$resolved_source" == "$AGENTS_DIR/"* ]]; then
      if [[ ! -e "$resolved_source" ]]; then
        rm "$target"
        echo "  [claude/agent] removed stale symlink $(basename "$target")"
        continue
      fi

      if [[ -f "$resolved_source" ]]; then
        frontmatter_validate_excluded_hosts "$resolved_source"
        if frontmatter_host_is_excluded "$resolved_source" "claude"; then
          rm "$target"
          echo "  [claude/agent] removed host-excluded symlink $(basename "$target")"
        fi
      fi
    fi
  done
}

install_codex() {
  "$REPO_ROOT/build.sh"

  mkdir -p "$HOME/.codex/skills" "$HOME/.codex/agents"

  local skill_dir target toml_file

  for skill_dir in "$REPO_ROOT/dist/codex/skills"/*; do
    [[ -d "$skill_dir" ]] || continue
    target="$HOME/.codex/skills/$(basename "$skill_dir")"
    symlink_into_place "$skill_dir" "$target" "codex/skill"
    echo "  [codex/skill] $(basename "$skill_dir") -> $target"
  done

  for toml_file in "$REPO_ROOT/dist/codex/agents"/*.toml; do
    [[ -f "$toml_file" ]] || continue
    target="$HOME/.codex/agents/$(basename "$toml_file")"
    symlink_into_place "$toml_file" "$target" "codex/agent"
    echo "  [codex/agent] $(basename "$toml_file") -> $target"
  done

  for target in "$HOME/.codex/agents"/*.toml; do
    [[ -L "$target" ]] || continue
    local resolved_source
    resolved_source="$(readlink "$target")"
    if [[ "$resolved_source" == "$REPO_ROOT/dist/codex/agents/"* && ! -e "$resolved_source" ]]; then
      rm "$target"
      echo "  [codex/agent] removed stale symlink $(basename "$target")"
    fi
  done

  for target in "$HOME/.codex/skills"/*; do
    [[ -L "$target" ]] || continue
    local resolved_source
    resolved_source="$(readlink "$target")"
    if [[ "$resolved_source" == "$REPO_ROOT/dist/codex/skills/"* && ! -e "$resolved_source" ]]; then
      rm "$target"
      echo "  [codex/skill] removed stale symlink $(basename "$target")"
    fi
  done

  local stale_agents_md="$HOME/.codex/AGENTS.md"
  if [[ -L "$stale_agents_md" ]]; then
    local resolved_source
    resolved_source="$(readlink "$stale_agents_md")"
    if [[ "$resolved_source" == "$REPO_ROOT/dist/codex/AGENTS.md" ]]; then
      rm "$stale_agents_md"
      echo "  [codex] removed stale AGENTS.md symlink from previous install"
    fi
  fi
}

install_bin() {
  local local_bin="$HOME/.local/bin"
  local bin_file name target

  mkdir -p "$local_bin"

  for bin_file in "$BIN_DIR"/*; do
    [[ -f "$bin_file" ]] || continue
    [[ "$(basename "$bin_file")" == ".gitkeep" ]] && continue

    name="$(basename "$bin_file")"
    target="$local_bin/$name"

    symlink_into_place "$bin_file" "$target" "bin"
    chmod +x "$bin_file"

    echo "  [bin] $name -> $target"
  done
}

check_requires() {
  local skill_file="$1"
  local in_requires=false
  local in_fm=false
  local fm_count=0

  while IFS= read -r line; do
    if [[ "$line" == "---" ]]; then
      fm_count=$((fm_count + 1))
      [[ $fm_count -eq 1 ]] && in_fm=true && continue
      [[ $fm_count -eq 2 ]] && break
    fi
    [[ $fm_count -eq 0 ]] && break

    if $in_fm; then
      if [[ "$line" =~ ^requires: ]]; then
        in_requires=true
        continue
      fi
      if $in_requires; then
        if [[ "$line" =~ ^[[:space:]]+-[[:space:]](.+)$ ]]; then
          local tool="${BASH_REMATCH[1]}"
          if ! command -v "$tool" &>/dev/null; then
            echo "  WARNING: '$(basename "$(dirname "$skill_file")")' requires '$tool' but it was not found on PATH"
          fi
        else
          in_requires=false
        fi
      fi
    fi
  done < "$skill_file"
}

echo "Installing blaude-bode skills..."

if $INSTALL_CLAUDE; then
  echo ""
  echo "Claude Code:"
  install_claude
fi

if $INSTALL_CODEX; then
  echo ""
  echo "Codex:"
  install_codex
fi

echo ""
echo "bin/:"
install_bin

echo ""
echo "Done."
