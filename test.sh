#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

source "$REPO_ROOT/bin/lib/frontmatter.sh"

cleanup_paths=()

cleanup() {
  local path
  (( ${#cleanup_paths[@]} == 0 )) && return 0
  for path in "${cleanup_paths[@]}"; do
    [[ -n "$path" ]] && rm -rf "$path"
  done
}

trap cleanup EXIT

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

assert_file_exists() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file to exist: $path"
}

assert_symlink_exists() {
  local path="$1"
  [[ -L "$path" ]] || fail "expected symlink to exist: $path"
}

assert_contains() {
  local path="$1" needle="$2"
  grep -Fq -- "$needle" "$path" || fail "expected '$needle' in $path"
}

assert_not_contains() {
  local path="$1" needle="$2"
  if grep -Fq -- "$needle" "$path"; then
    fail "did not expect '$needle' in $path"
  fi
}

assert_equals() {
  local actual="$1" expected="$2" label="$3"
  [[ "$actual" == "$expected" ]] || fail "$label: expected '$expected' but got '$actual'"
}

assert_valid_toml_basic_escapes() {
  local path="$1"
  local invalid

  invalid="$(perl -ne 'for (my $i = 0; $i < length($_); $i++) { next unless substr($_, $i, 1) eq "\\"; my $next = substr($_, $i + 1, 1); if ($next eq "\\") { $i++; next } if ($next !~ /[btnfr"uU]/) { print "$ARGV:$.: invalid TOML escape \\$next\n" } }' "$path")"
  [[ -z "$invalid" ]] || fail "$invalid"
}

assert_codex_agents_exposed() {
  local home_dir="$1"
  local expected_count=0
  local actual_count agent_dir agent_file agent_name generated_agent installed_agent

  for agent_dir in "$REPO_ROOT/agents"/*; do
    [[ -d "$agent_dir" ]] || continue
    agent_file="$agent_dir/AGENT.md"
    [[ -f "$agent_file" ]] || continue

    agent_name="$(frontmatter_get "$agent_file" "name")"
    require_field "$agent_file" "name" "$agent_name"

    generated_agent="$REPO_ROOT/dist/codex/agents/$agent_name.toml"
    installed_agent="$home_dir/.codex/agents/$agent_name.toml"

    assert_file_exists "$generated_agent"
    assert_valid_toml_basic_escapes "$generated_agent"
    assert_symlink_exists "$installed_agent"
    assert_equals \
      "$(readlink "$installed_agent")" \
      "$generated_agent" \
      "codex $agent_name agent symlink"

    expected_count=$((expected_count + 1))
  done

  actual_count="$(find "$home_dir/.codex/agents" -maxdepth 1 -type l -name '*.toml' | wc -l | tr -d ' ')"
  assert_equals "$actual_count" "$expected_count" "installed codex agent count"
}

./build.sh >/dev/null

mermaid_skill="$REPO_ROOT/dist/codex/skills/mermaid-author/SKILL.md"
assert_file_exists "$mermaid_skill"
assert_contains "$mermaid_skill" "name: mermaid-author"
assert_contains "$mermaid_skill" 'description: "Author correct, rendering-safe mermaid.js diagrams.'
assert_contains "$mermaid_skill" 'For detailed syntax of each diagram type, see `references/diagram-types.md`.'
assert_contains "$REPO_ROOT/dist/codex/skills/mermaid-author/references/diagram-types.md" "# Mermaid Diagram Types - Detailed Reference"
assert_not_contains "$mermaid_skill" "In Codex-generated output"

for agent_file in "$REPO_ROOT/dist/codex/agents"/*.toml; do
  assert_file_exists "$agent_file"
  assert_valid_toml_basic_escapes "$agent_file"
  assert_contains "$agent_file" 'developer_instructions = """'
done

assert_contains "$REPO_ROOT/dist/codex/agents/git-best-practices-agent.toml" 'model = "gpt-5.4"'
assert_contains "$REPO_ROOT/dist/codex/agents/git-best-practices-agent.toml" 'nickname_candidates = ["Branch", "Commit", "Draft"]'
assert_contains "$REPO_ROOT/dist/codex/agents/swift-style-agent.toml" 'nickname_candidates = ["Cedar", "Fluent", "Swiftline", "Canopy", "Ledger"]'
assert_contains "$REPO_ROOT/dist/codex/agents/swift-testing-agent.toml" 'nickname_candidates = ["Harness", "Suite", "Verify"]'
assert_contains "$REPO_ROOT/dist/codex/agents/swift-testing-agent.toml" '#expect, #require, parameterized tests'

clean_home="$(mktemp -d /tmp/blaude-bode-test-clean.XXXXXX)"
cleanup_paths+=("$clean_home")
HOME="$clean_home" ./install.sh --host codex >/dev/null

assert_symlink_exists "$clean_home/.codex/skills/mermaid-author"
assert_equals \
  "$(readlink "$clean_home/.codex/skills/mermaid-author")" \
  "$REPO_ROOT/dist/codex/skills/mermaid-author" \
  "clean codex mermaid-author skill symlink"

assert_codex_agents_exposed "$clean_home"

claude_home="$(mktemp -d /tmp/blaude-bode-test-claude.XXXXXX)"
cleanup_paths+=("$claude_home")
HOME="$claude_home" ./install.sh --host claude >/dev/null

assert_symlink_exists "$claude_home/.claude/skills/mermaid-author"
assert_equals \
  "$(readlink "$claude_home/.claude/skills/mermaid-author")" \
  "$REPO_ROOT/skills/mermaid-author" \
  "clean claude mermaid-author skill symlink"
[[ ! -e "$claude_home/.claude/skills/blaude-bode" ]] \
  || fail "clean install should not create legacy blaude-bode nesting"
assert_symlink_exists "$claude_home/.claude/agents/swift-style-agent.md"
assert_equals \
  "$(readlink "$claude_home/.claude/agents/swift-style-agent.md")" \
  "$REPO_ROOT/agents/swift-style-agent/AGENT.md" \
  "clean claude swift-style-agent symlink"

claude_existing_home="$(mktemp -d /tmp/blaude-bode-test-claude-existing.XXXXXX)"
cleanup_paths+=("$claude_existing_home")
mkdir -p "$claude_existing_home/.claude/skills/blaude-bode/mermaid-author" "$claude_existing_home/.claude/skills/blaude-bode/review" "$claude_existing_home/.claude/agents"
ln -s "$REPO_ROOT/skills/mermaid-author/SKILL.md" "$claude_existing_home/.claude/skills/blaude-bode/mermaid-author/SKILL.md"
ln -s "$REPO_ROOT/skills/review/SKILL.md" "$claude_existing_home/.claude/skills/blaude-bode/review/SKILL.md"
ln -s "$REPO_ROOT/agents/reviewer-agent/AGENT.md" "$claude_existing_home/.claude/agents/reviewer-agent.md"
ln -s "$REPO_ROOT/agents/reviewer.md" "$claude_existing_home/.claude/agents/reviewer.md"

claude_install_output="$(HOME="$claude_existing_home" ./install.sh --host claude 2>&1)"
[[ "$claude_install_output" == *"[claude/skill] migrated nested managed directory blaude-bode/mermaid-author"* ]] \
  || fail "expected migration of legacy managed Claude skill directory"
[[ "$claude_install_output" == *"[claude/skill] migrated nested managed directory blaude-bode/review"* ]] \
  || fail "expected migration of legacy managed ~/.claude/skills/blaude-bode/review directory"
[[ "$claude_install_output" == *"[claude/skill] removed empty legacy blaude-bode directory"* ]] \
  || fail "expected legacy blaude-bode directory to be removed once empty"
[[ "$claude_install_output" == *"[claude/agent] removed stale symlink reviewer-agent.md"* ]] \
  || fail "expected cleanup of stale ~/.claude/agents/reviewer-agent.md symlink after agent removal"
[[ "$claude_install_output" == *"[claude/agent] removed stale symlink reviewer.md"* ]] \
  || fail "expected cleanup of stale ~/.claude/agents/reviewer.md symlink from previous installs"
assert_symlink_exists "$claude_existing_home/.claude/skills/mermaid-author"
assert_equals \
  "$(readlink "$claude_existing_home/.claude/skills/mermaid-author")" \
  "$REPO_ROOT/skills/mermaid-author" \
  "migrated claude mermaid-author skill symlink points to source"
[[ ! -e "$claude_existing_home/.claude/skills/blaude-bode" ]] \
  || fail "expected legacy ~/.claude/skills/blaude-bode directory to be removed"
[[ ! -e "$claude_existing_home/.claude/agents/reviewer-agent.md" ]] \
  || fail "expected stale ~/.claude/agents/reviewer-agent.md symlink to be removed"
[[ ! -e "$claude_existing_home/.claude/agents/reviewer.md" ]] \
  || fail "expected stale ~/.claude/agents/reviewer.md symlink to be removed"

claude_unexpected_home="$(mktemp -d /tmp/blaude-bode-test-claude-unexpected.XXXXXX)"
cleanup_paths+=("$claude_unexpected_home")
mkdir -p "$claude_unexpected_home/.claude/skills/blaude-bode" "$claude_unexpected_home/.claude/agents"
ln -s "$REPO_ROOT/skills/mermaid-author" "$claude_unexpected_home/.claude/skills/blaude-bode/mermaid-author"
printf "user content\n" > "$claude_unexpected_home/.claude/skills/blaude-bode/notes.md"
touch "$claude_unexpected_home/.claude/skills/blaude-bode/.DS_Store"

claude_unexpected_output="$(HOME="$claude_unexpected_home" ./install.sh --host claude 2>&1)"
[[ "$claude_unexpected_output" == *"[claude/skill] migrated nested symlink blaude-bode/mermaid-author"* ]] \
  || fail "expected migration of legacy nested symlink when unrelated files exist"
[[ "$claude_unexpected_output" == *"[claude/skill] WARNING: unexpected content at blaude-bode/notes.md"* ]] \
  || fail "expected warning for unexpected file under legacy blaude-bode directory"
[[ "$claude_unexpected_output" != *"removed empty legacy blaude-bode directory"* ]] \
  || fail "legacy directory should not be removed when unexpected content remains"
[[ -d "$claude_unexpected_home/.claude/skills/blaude-bode" ]] \
  || fail "legacy blaude-bode directory should remain when unexpected content is present"
assert_file_exists "$claude_unexpected_home/.claude/skills/blaude-bode/notes.md"
[[ ! -e "$claude_unexpected_home/.claude/skills/blaude-bode/.DS_Store" ]] \
  || fail "expected .DS_Store inside legacy blaude-bode directory to be removed"
assert_symlink_exists "$claude_unexpected_home/.claude/skills/mermaid-author"

claude_foreign_home="$(mktemp -d /tmp/blaude-bode-test-claude-foreign.XXXXXX)"
cleanup_paths+=("$claude_foreign_home")
foreign_skill_source="$(mktemp -d /tmp/blaude-bode-test-foreign-src.XXXXXX)"
cleanup_paths+=("$foreign_skill_source")
mkdir -p "$claude_foreign_home/.claude/skills" "$claude_foreign_home/.claude/agents"
ln -s "$foreign_skill_source" "$claude_foreign_home/.claude/skills/mermaid-author"

claude_foreign_output="$(HOME="$claude_foreign_home" ./install.sh --host claude 2>&1)"
[[ "$claude_foreign_output" == *"WARNING: $claude_foreign_home/.claude/skills/mermaid-author is a symlink to $foreign_skill_source (not managed by this repo) - skipping"* ]] \
  || fail "expected warning when a foreign symlink owns the target path"
assert_equals \
  "$(readlink "$claude_foreign_home/.claude/skills/mermaid-author")" \
  "$foreign_skill_source" \
  "foreign symlink should be preserved"

existing_home="$(mktemp -d /tmp/blaude-bode-test-existing.XXXXXX)"
cleanup_paths+=("$existing_home")
mkdir -p "$existing_home/.codex/agents" "$existing_home/.codex/skills"
ln -s "$REPO_ROOT/dist/codex/AGENTS.md" "$existing_home/.codex/AGENTS.md"
ln -s "$REPO_ROOT/dist/codex/agents/reviewer-agent.toml" "$existing_home/.codex/agents/reviewer-agent.toml"
ln -s "$REPO_ROOT/dist/codex/skills/review" "$existing_home/.codex/skills/review"

install_output="$(HOME="$existing_home" ./install.sh --host codex 2>&1)"
[[ "$install_output" == *"[codex] removed stale AGENTS.md symlink from previous install"* ]] \
  || fail "expected cleanup of stale ~/.codex/AGENTS.md symlink from previous installs"
[[ "$install_output" == *"[codex/agent] removed stale symlink reviewer-agent.toml"* ]] \
  || fail "expected cleanup of stale ~/.codex/agents/reviewer-agent.toml after agent removal"
[[ "$install_output" == *"[codex/skill] removed stale symlink review"* ]] \
  || fail "expected cleanup of stale ~/.codex/skills/review after skill removal"
[[ ! -e "$existing_home/.codex/AGENTS.md" ]] || fail "expected stale ~/.codex/AGENTS.md symlink to be removed"
[[ ! -e "$existing_home/.codex/agents/reviewer-agent.toml" ]] \
  || fail "expected stale ~/.codex/agents/reviewer-agent.toml symlink to be removed"
[[ ! -e "$existing_home/.codex/skills/review" ]] \
  || fail "expected stale ~/.codex/skills/review symlink to be removed"

echo "All checks passed."
