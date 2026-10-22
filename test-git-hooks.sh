#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test_root="$(mktemp -d /tmp/blaude-bode-hooks.XXXXXX)"
trap 'rm -rf "$test_root"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
new_repo() {
  repo="$test_root/$1"
  mkdir -p "$repo/skills/original" "$repo/agents/original-agent"
  cp -R "$REPO_ROOT/.githooks" "$repo/"
  printf 'Original skill\n' > "$repo/skills/original/SKILL.md"
  printf 'Original agent\n' > "$repo/agents/original-agent/AGENT.md"
  cat > "$repo/build.sh" <<'STUB'
#!/usr/bin/env bash
echo build >> calls
exit "${BUILD_FAIL:-0}"
STUB
  cat > "$repo/install.sh" <<'STUB'
#!/usr/bin/env bash
[[ $# == 0 ]] || exit 99
echo install >> calls
exit "${INSTALL_FAIL:-0}"
STUB
  chmod +x "$repo/build.sh" "$repo/install.sh"
  cd "$repo"
  git init -q
  git config user.email hooks@example.test
  git config user.name 'Hook tests'
  git config core.hooksPath /dev/null
  git add .
  git commit -qm 'Add initial fixture'
  old_ref="$(git rev-parse HEAD)"
}
commit_change() {
  git add -A
  git commit -qm 'Change fixture'
  new_ref="$(git rev-parse HEAD)"
}
assert_calls() {
  [[ "$(cat calls 2>/dev/null || true)" == "$1" ]] || fail "expected '$1' in $repo/calls"
}
run_hook() {
  case "$1" in
    post-checkout) .githooks/post-checkout "$old_ref" "$new_ref" 1 ;;
    post-merge) git update-ref ORIG_HEAD "$old_ref"; .githooks/post-merge 0 ;;
    post-commit) .githooks/post-commit ;;
  esac
}

for hook in post-checkout post-merge post-commit; do
  for change in add remove rename body support unrelated; do
    new_repo "$hook-$change"
    case "$change" in
      add) mkdir skills/added; echo Added > skills/added/SKILL.md ;;
      remove) rm agents/original-agent/AGENT.md ;;
      rename) git mv skills/original skills/renamed ;;
      body) echo Updated >> skills/original/SKILL.md ;;
      support) echo Support > skills/original/helper.sh ;;
      unrelated) echo Readme > README.md ;;
    esac
    commit_change
    run_hook "$hook" >/dev/null
    case "$change" in
      add|remove|rename) assert_calls install ;;
      body|support)
        if [[ "$hook" == post-commit ]]; then assert_calls ''; else assert_calls build; fi ;;
      unrelated) assert_calls '' ;;
    esac
  done
  new_repo "$hook-install-failure"
  rm skills/original/SKILL.md
  commit_change
  INSTALL_FAIL=1 run_hook "$hook" > output
  assert_calls install
  [[ "$(cat output)" == *'install failed'* ]] || fail 'missing installer recovery message'
done

new_repo pre-commit
printf 'Update\n' >> skills/original/SKILL.md
git add skills
BUILD_FAIL=1 .githooks/pre-commit > output 2>&1
assert_calls build
[[ "$(cat output)" == *'build failed'* ]] || fail 'missing build recovery message'

new_repo pre-commit-add
mkdir skills/added
echo Added > skills/added/SKILL.md
git add skills
.githooks/pre-commit >/dev/null
assert_calls build

new_repo checkout-files
new_ref="$old_ref"
.githooks/post-checkout "$old_ref" "$new_ref" 0
assert_calls ''

new_repo first-commit
.githooks/post-commit >/dev/null
assert_calls install

echo 'Git hook checks passed.'
