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

## Overview

Use `gh` to run GitHub operations from the command line.
Prefer `gh` over browser navigation when the user asks for GitHub data, changes, or status.

## Arguments

The user may supply a specific command or query as an argument. It is optional. With no argument,
infer the intent from the surrounding request.

## Quick Workflow

1. Confirm repository context with `git remote -v` and `gh repo view` when needed.
2. Select the command group: PRs, issues, repo, Actions, or API.
3. Run read-only commands first when diagnosing.
4. Use `--json` and `--jq` for structured results when output needs filtering.
5. Report key results concisely with identifiers (PR number, issue number, run ID, URL).

## Pull Requests

```bash
gh pr list
gh pr view <number>
gh pr diff <number>
gh pr checks <number>
gh pr create --title "<title>" --body "<body>"
gh pr checkout <number>
gh api repos/{owner}/{repo}/pulls/<number>/comments   # PR review comments
```

## Issues

```bash
gh issue list
gh issue view <number>
gh issue create --title "<title>" --body "<body>"
gh issue close <number>
```

## Repository

```bash
gh repo view
gh repo clone <owner>/<repo>
gh browse                                             # open the repo in a browser
```

## Actions and Runs

```bash
gh run list
gh run view <run-id>
gh run watch <run-id>
```

## API

```bash
gh api <endpoint>
gh api repos/{owner}/{repo}                           # repo details
gh api repos/{owner}/{repo}/pulls/<number>/reviews    # PR reviews
```

## Output and Help

- Use `--json` for machine-readable output.
- Use `--jq '<expr>'` to filter JSON output.
- Use `gh help <command>` when command flags are unclear.
