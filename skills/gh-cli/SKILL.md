---
name: gh-cli
description: >
  Execute GitHub workflows with the gh CLI for pull requests, issues, repositories, workflow runs,
  and authenticated API calls. Use when the user asks to inspect, create, update, or automate GitHub
  actions from the terminal, especially for PR checks, issue management, repo metadata, run status,
  or gh api queries. Also use when the user says "gh", "gh cli", "use the GitHub CLI", "list my PRs",
  "view PR checks", "open an issue", "watch the workflow run", or "hit the GitHub API".
---

# GitHub CLI

Use `gh` for GitHub data, changes, and status rather than the browser. Use `--json` with `--jq`
when output needs filtering, and `gh help <command>` when flags are unclear. Report results with
their identifiers (PR or issue number, run ID, URL).

Before `gh pr create` or `gh pr edit`, load the `git-conventions` skill for the draft-first rule,
title format, and body. PR review comments: `gh api repos/{owner}/{repo}/pulls/<number>/comments`;
reviews: `gh api repos/{owner}/{repo}/pulls/<number>/reviews`.
