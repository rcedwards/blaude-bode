#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_ROOTS=("$REPO_ROOT/skills" "$REPO_ROOT/private/skills")
AGENTS_ROOTS=("$REPO_ROOT/agents" "$REPO_ROOT/private/agents")
DIST_CODEX="$REPO_ROOT/dist/codex"

source "$REPO_ROOT/bin/lib/frontmatter.sh"

mkdir -p "$DIST_CODEX/agents" "$DIST_CODEX/skills"

escape_toml_multiline() {
  sed -e 's/\\/\\\\/g' -e 's/"""/\\"""/g'
}

escape_toml_basic() {
  local text
  text="$(cat)"
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  text="${text//$'\b'/\\b}"
  text="${text//$'\t'/\\t}"
  text="${text//$'\n'/\\n}"
  text="${text//$'\f'/\\f}"
  text="${text//$'\r'/\\r}"
  printf '%s' "$text"
}

escape_yaml_double_quoted() {
  local text
  text="$(cat)"
  text="${text//\\/\\\\}"
  text="${text//\"/\\\"}"
  printf '%s' "$text"
}

validate_source_dirname() {
  local dir="$1" expected_name="$2" kind="$3"
  local actual_name
  actual_name="$(basename "$dir")"

  if [[ "$actual_name" != "$expected_name" ]]; then
    echo "ERROR: $kind source directory name must match frontmatter name in $dir (expected '$expected_name')" >&2
    exit 1
  fi
}

validate_agent_name() {
  local file="$1" name="$2"

  if [[ "$name" != *-agent ]]; then
    echo "ERROR: agent names must end with '-agent' in $file" >&2
    exit 1
  fi
}

emit_toml_string_array() {
  local values=("$@")
  local index escaped

  printf '['
  for index in "${!values[@]}"; do
    (( index > 0 )) && printf ', '
    escaped="$(printf '%s' "${values[$index]}" | escape_toml_basic)"
    printf '"%s"' "$escaped"
  done
  printf ']'
}

append_hook_note() {
  local out="$1" label="$2" block="$3"
  [[ -n "$block" ]] || return 0

  {
    echo "> Claude hook parity for Codex: $label"
    echo ">"
    echo "> \`\`\`bash"
    while IFS= read -r line; do
      echo "> $line"
    done <<< "$block"
    echo "> \`\`\`"
    echo ""
  } >> "$out"
}

copy_supporting_files() {
  local src_dir="$1" out_dir="$2" entry_name="$3"
  local file rel target

  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    rel="${file#"$src_dir"/}"
    target="$out_dir/$rel"
    mkdir -p "$(dirname "$target")"
    cp "$file" "$target"
  done < <(find "$src_dir" -type f -not -name '.DS_Store' -not -name "$entry_name" | LC_ALL=C sort)
}

build_skills() {
  local skills_dist="$DIST_CODEX/skills"
  rm -f "$DIST_CODEX/AGENTS.md"
  rm -rf "$skills_dist"
  mkdir -p "$skills_dist"

  local count=0
  local skills_root skill_dir skill_file skill_name description pre_hook post_hook out_dir out_file

  for skills_root in "${SKILLS_ROOTS[@]}"; do
    [[ -d "$skills_root" ]] || continue
    for skill_dir in "$skills_root"/*; do
      [[ -d "$skill_dir" ]] || continue
      skill_file="$skill_dir/SKILL.md"
      [[ -f "$skill_file" ]] || continue

      skill_name="$(frontmatter_get "$skill_file" "name")"
      description="$(frontmatter_get "$skill_file" "description")"
      pre_hook="$(frontmatter_get "$skill_file" "hooks.pre-invoke")"
      post_hook="$(frontmatter_get "$skill_file" "hooks.post-invoke")"

      require_field "$skill_file" "name" "$skill_name"
      require_field "$skill_file" "description" "$description"
      validate_source_dirname "$skill_dir" "$skill_name" "skill"
      frontmatter_validate_excluded_hosts "$skill_file"

      if frontmatter_host_is_excluded "$skill_file" "codex"; then
        echo "  skill: $skill_name skipped for codex"
        continue
      fi

      out_dir="$skills_dist/$skill_name"
      out_file="$out_dir/SKILL.md"
      mkdir -p "$out_dir"

      {
        echo "---"
        echo "name: $skill_name"
        printf 'description: "%s"\n' "$(printf '%s' "$description" | escape_yaml_double_quoted)"
        echo "---"
        echo ""
        append_hook_note /dev/stdout "Before running this skill, run:" "$pre_hook"
        frontmatter_body "$skill_file"
        echo ""
        append_hook_note /dev/stdout "After running this skill, run:" "$post_hook"
      } > "$out_file"

      copy_supporting_files "$skill_dir" "$out_dir" "SKILL.md"

      count=$((count + 1))
      echo "  skill: $skill_name -> $out_file"
    done
  done

  echo "  skills: $count directory/directories"
}

build_agents() {
  local count=0
  local agents_root agent_dir agent_file name description body model reasoning sandbox toml_file rel_source
  local nickname_candidates=()
  local escaped_name escaped_description escaped_model escaped_reasoning escaped_sandbox

  rm -f "$DIST_CODEX/agents"/*.toml

  for agents_root in "${AGENTS_ROOTS[@]}"; do
    [[ -d "$agents_root" ]] || continue
    for agent_dir in "$agents_root"/*; do
      [[ -d "$agent_dir" ]] || continue
      agent_file="$agent_dir/AGENT.md"
      [[ -f "$agent_file" ]] || continue

      name="$(frontmatter_get "$agent_file" "name")"
      description="$(frontmatter_get "$agent_file" "description")"
      body="$(frontmatter_body "$agent_file")"
      nickname_candidates=()
      while IFS= read -r nickname_candidate; do
        nickname_candidates+=("$nickname_candidate")
      done < <(frontmatter_get_list "$agent_file" "codex.nickname_candidates")

      require_field "$agent_file" "name" "$name"
      require_field "$agent_file" "description" "$description"
      validate_source_dirname "$agent_dir" "$name" "agent"
      validate_agent_name "$agent_file" "$name"
      frontmatter_validate_excluded_hosts "$agent_file"

      if frontmatter_host_is_excluded "$agent_file" "codex"; then
        echo "  agent: $name skipped for codex"
        continue
      fi

      model="$(frontmatter_get "$agent_file" "codex.model")"
      reasoning="$(frontmatter_get "$agent_file" "codex.model_reasoning_effort")"
      sandbox="$(frontmatter_get "$agent_file" "codex.sandbox_mode")"

      toml_file="$DIST_CODEX/agents/$name.toml"
      rel_source="${agent_file#"$REPO_ROOT/"}"
      escaped_name="$(printf '%s' "$name" | escape_toml_basic)"
      escaped_description="$(printf '%s' "$description" | escape_toml_basic)"
      escaped_model="$(printf '%s' "$model" | escape_toml_basic)"
      escaped_reasoning="$(printf '%s' "$reasoning" | escape_toml_basic)"
      escaped_sandbox="$(printf '%s' "$sandbox" | escape_toml_basic)"

      {
        echo "# Auto-generated by build.sh - do not edit directly"
        echo "# Source: $rel_source"
        echo ""
        echo "name = \"$escaped_name\""
        echo "description = \"$escaped_description\""
        [[ -n "$model" ]] && echo "model = \"$escaped_model\""
        [[ -n "$reasoning" ]] && echo "model_reasoning_effort = \"$escaped_reasoning\""
        [[ -n "$sandbox" ]] && echo "sandbox_mode = \"$escaped_sandbox\""
        if (( ${#nickname_candidates[@]} > 0 )); then
          printf 'nickname_candidates = '
          emit_toml_string_array "${nickname_candidates[@]}"
          printf '\n'
        fi
        echo ""
        echo "developer_instructions = \"\"\""
        printf '%s\n' "$body" | escape_toml_multiline
        echo "\"\"\""
      } > "$toml_file"

      count=$((count + 1))
      echo "  agent: $name -> $toml_file"
    done
  done

  echo "  agents: $count toml file(s)"
}

echo "Building dist/codex..."
build_skills
build_agents
echo "Done."
