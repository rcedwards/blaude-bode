# Orchestration Workflow

One complete supervised run, from planning through the final report. This file owns the lifecycle.
Read [`orchestration-contract.md`](orchestration-contract.md) before creating or interpreting any
journal entry.


## Run initialization

From the target Git worktree, exclude run data locally *before* creating it:

```bash
REPO="$(git rev-parse --show-toplevel)"
cd "$REPO"
EXCLUDE_FILE="$(git rev-parse --git-path info/exclude)"
grep -qxF '/.codex-consult/' "$EXCLUDE_FILE" ||
  printf '\n/.codex-consult/\n' >> "$EXCLUDE_FILE"
grep -qxF '/.codex-consult/' "$EXCLUDE_FILE"
git check-ignore -q .codex-consult/.ignore-check
git rev-parse HEAD
git branch --show-current
git status --short --untracked-files=all
```

Use only this local exclude. Do not edit the tracked `.gitignore`; the run is your working material,
not a repository artifact.

Do not create the run unless both exclude checks succeed.

Record the concise original goal, `REPO`, the full starting HEAD, the attached branch when the branch
output is nonempty, and the exact status lines as `goal`, `repo`, `repo_head`, optional `repo_branch`,
and `repo_status` in `run_started`.

Initially dirty paths are pre-existing user work. If planned work overlaps them, use an isolated
clean worktree or ask the user, rather than claiming those changes as the run's output.

## Full workflow

1. Inspect the repository and user context to understand the goal and its constraints.
2. Run initialization. Create `.codex-consult/runs/<run-id>/journal.jsonl` and append `run_started`
   with the goal, absolute repository path, captured Git baseline, and available `claude` and `codex`
   versions.
3. Turn the goal into a concrete plan: expected deliverables, acceptance criteria, risks, and the
   verification path for each criterion. A criterion you cannot check is not a criterion.
4. Get a second opinion on the plan when it materially reduces risk, and record that review as a task
   and an execution cycle. For a consequential or hard-to-reverse design choice, first ask a fresh
   Codex agent to propose an approach from **only** the goal, constraints, and acceptance criteria
   (`templates.md`, "Independent design proposal"). Compare the two using evidence, not agent count,
   then finalize.
5. Split the finalized plan into `active` task entries with goals, acceptance criteria, and owned
   `files`. Serialize overlapping work or use isolated worktrees ([`compute.md`](compute.md)).
   **Check each acceptance criterion against the allowlist before launching.** If a criterion names a
   command, every file that command needs to succeed must be in `files`. A criterion the agent is
   forbidden from satisfying produces a correct refusal and a wasted cycle: a well-behaved agent
   reports blocked rather than exceeding its scope, and a badly-behaved one edits outside the
   allowlist. Neither gets you the deliverable.
6. For each task, run a focused agent cycle (below). Repeat fix and review cycles as needed.
7. Record only consequential resolutions or user dependencies as `decision`
   ([`consensus.md`](consensus.md)). Append a terminal `task` entry only after its acceptance criteria
   have been evaluated.
8. When every task is terminal, re-read the complete journal and inspect the final repository state
   and diff.
9. Run the descriptive close check:

```bash
python3 ~/.claude/skills/codex-consult/scripts/codex_orch_tools.py validate .codex-consult/runs/<run-id>
```

10. Resolve omissions that can be corrected by appending, and inspect every non-passing verification.
    Never rewrite journal history. If a duplicate identity or other structural conflict cannot be
    corrected by appending, retain the run and start a successor. Otherwise append one final
    `run_closed` with `judgment: passed|blocked`, the exact validation result, unresolved risks, and
    follow-ups. Validation detects omissions; you decide acceptance.
11. After `run_closed`, write `report.md` once, following [`report.md`](report.md).

The close sequence is `validate` → `run_closed` → `report.md`. Validation never decides acceptance,
and the report never repairs journal history.

## Focused agent cycle

Run this for each task. Prefer Codex as the first mover for bounded coding work.

1. Read the complete journal, the current task, and the references the phase needs.
2. Confirm the task's acceptance criteria and owned `files`.
3. Compare active task files and shared resources before parallel work. Serialize overlap or use a
   worktree.
4. Reuse a relevant agent, or create a named one. For an independent review, always start a fresh
   agent and a new native session ([`review.md`](review.md)).
5. Resolve the execution's absolute worktree, full HEAD, and attached branch. Save the exact prompt
   and append `execution` **before** launch ([`monitoring.md`](monitoring.md)).
6. Monitor with the vendored tools. Do not edit files owned by the active agent.
7. Save the exact handoff, inspect it and the repository, then append a terminal `execution_result`.
8. Evaluate the acceptance criteria and record each material check as a `verification`.
9. Record only consequential resolutions or user dependencies as a `decision`.
10. Append `complete` when the criteria are satisfied, `failed` when they are conclusively unmet with
    no in-scope recovery left, or `blocked` when a user or external dependency prevents completion or
    judgment. Otherwise leave the task `active` and return the unresolved work to step 6 of the full
    workflow.

Routine bounded work needs Codex implementation plus your verification, and nothing more. Add a fresh
reviewer only for material risk or a distinct unresolved question. Do not repeat an identical review
hoping for a different answer.

## When to stop

Orchestration is worth its overhead only when the run has several tasks, real risk, or an audit
requirement. If you find yourself opening a run for a single bounded change, close it and use Delegate
mode instead.
