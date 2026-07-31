---
name: git-conventions
description: >-
  Canonical conventions for git commit messages, branch names, and pull requests. Use this skill
  before writing any commit message, before creating a branch, and before opening or updating a
  pull request. Also use when the user asks how a commit message should be worded, what to name a
  branch, why a commit was rejected by the commit guard hook, or how to fill out a PR description
  or test plan. Covers the imperative-subject format, the 350-character message cap, the
  one-logical-change rule, the `rcedwards/JIRA-TICKET-description` branch format, and the
  draft-first PR workflow.
---

# Git Conventions

The rules below are canonical. For rewriting existing history (amend, interactive rebase,
splitting commits, force-push safety), use the `git-best-practices-agent` subagent.

## Commit Messages

- Imperative subject, <=50 chars, capitalized, no trailing period ("Add retry to token refresh",
  not "Added"/"Adds"). Test: "If applied, this commit will [subject]".
- Blank line between the subject and the body; wrap the body at 72 chars.
- Explain WHY, not what. The diff already shows what changed.
- Keep it concise; add detail only where it earns its place. The whole message must stay under
  350 characters. Brevity is a must.
- One logical change per commit. Don't bundle unrelated edits; commits needn't be artificially
  small, but each must be a single coherent change. Review the staged diff before committing.
- The subject must summarize the whole change, not one narrow aspect of it.
- Don't list the files that changed. The diff already does.
- Don't narrate the review exchange ("Addresses review feedback", "Per PR comments").
- No conventional-commit prefixes (`chore:`, `fix:`, `feat:`, `docs:`). Write a plain descriptive
  subject.
- Never add AI attribution signatures (`Co-Authored-By: Claude`, "Generated with Claude Code",
  robot emoji, etc.).
- Never add `Co-Authored-By` trailers of any kind.
- Include the Jira ticket key when there is one.

### Enforcement

For Claude, these rules are enforced by the `git-commit-guard.sh` PreToolUse hook: deterministic
checks block AI signatures and messages over 350 characters, and an LLM gate blocks commits that
bundle unrelated changes or whose subject under-describes the diff. The gate fails open, so an
error or timeout never blocks a commit.

Other hosts have no such hook, so the rules above must be followed by hand.

## Branch Naming

Format: `rcedwards/JIRA-TICKET-short-description`

Examples:
- `rcedwards/GD-6163-sk2-firebase-event`
- `rcedwards/FOX-1234-fix-login-bug`

The `rcedwards/` prefix signals the branch is owned by one person and may be rewritten.

## Pull Requests

Create PRs as drafts first: `gh pr create --draft`.

Title format: `[GD-XXXX] - Description`.

Always use the PR template from `.github/pull_request_template.md`.

### Description

- Keep it concise and focused on the core problem and solution.
- Skip implementation specifics and architecture explanations.
- Skip the screenshots section when there are no UI changes.
- Say what the change does, not how it is implemented.

### Test Plan

- Only essential manual testing steps.
- Focus on core functionality verification.
- Drop edge cases unless critical.
- Keep steps actionable and specific.

### Triggering CI

To run the CI pipeline on a PR: `gh pr comment <PR_NUMBER> -b "ci test"`.

### General

- Be concise; assume reviewers understand the technical context.
- Focus on business value and user impact.
- Remove boilerplate that adds no value.
- No emojis in the title or body.

## Commit-by-Commit Reviewability

GitHub supports reviewing PRs commit-by-commit, so history must read forward, never backward.

- Each commit builds on the last. A later commit never undoes or contradicts an earlier one on the
  same branch.
- No fix-up-the-fix commits. If an earlier commit was wrong, rebase and fold the fix into the
  commit that introduced it rather than stacking a corrective commit on top.
- One concern per commit. Separate refactoring from behavior changes, infrastructure from feature
  logic.
- The branch should tell a story: setup, then implementation, then wiring it together.
- Clean up history with interactive rebase before opening the PR. If the branch is already pushed,
  rebase and force-push with `--force-with-lease` (feature branches only, never main or develop).
