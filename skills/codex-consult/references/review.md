# Review And Verification

See [`orchestration-contract.md`](orchestration-contract.md) for journal fields.

## Verifying agent work

1. Read the handoff as claims, not results.
2. Inspect the actual diff and changed files. Compare them against the task's declared `files`.
3. Evaluate every acceptance criterion with a check you ran and observed. Never promote the agent's
   `Commands Reported` section to a passing verification.
4. Record each criterion as a `verification` with the exact check and what you observed.
5. On failure, preserve the record, send the exact finding and observation back to the agent, and
   record the recheck as a separate verification.
6. Mark the task terminal only after every criterion has been evaluated.

Base verification on repository state or observed output. Use handoffs and model findings to decide
what to inspect, never what to conclude. Keep short observations inline; use `evidence/` only for
lengthy material worth retaining.

## Blind independent review

The value of a second reviewer comes from its independence. Anchoring it destroys that value.

For the first independent review of a change:

- Start a fresh named `codex-review-NN` agent and a new native session. Never resume the
  implementation session.
- Provide the goal, acceptance criteria, constraints, and the exact review target.
- **Withhold** the implementer's handoff, its claimed test results, any earlier review verdict, and
  your own tentative conclusion.
- Write the exact commit SHA into the prompt and tell Codex to review that snapshot.

```bash
EXECUTION_DIR="<abs-run-dir>/codex-review-01/execution-01"
codex exec --json -o "$EXECUTION_DIR/handoff.md" \
  -s workspace-write -c approval_policy=never \
  -C <worktree> \
  - < "$EXECUTION_DIR/prompt.md" > "$EXECUTION_DIR/events.jsonl"
```

Use plain `codex exec`, not the `review` subcommand. The CLI rejects the combination outright:

```text
$ codex exec review --base main -
error: the argument '--base <BRANCH>' cannot be used with '[PROMPT]'
```

**Check out a worktree at the reviewed commit before launching.** Naming a SHA in the prompt does not
pin the filesystem; if `-C <worktree>` points somewhere that has moved on, Codex reads current files
and reports on the wrong revision, while its handoff still cites the SHA you asked for. Confirm the
worktree is at that commit first:

```bash
git -C <worktree> rev-parse HEAD    # must equal the SHA in prompt.md
```

Reviewing a fixed commit in its own worktree is also what lets unrelated work continue in parallel.

Tell Codex not to edit, and confirm the review worktree is clean afterward. `workspace-write` is used
rather than `read-only` so repository checks can create their normal temporary outputs.

For an uncommitted review, put the base HEAD SHA and the exact reviewed files in the prompt, run the
same command in that working tree, and reserve those files and shared resources as described in
[`compute.md`](compute.md).

## After the review

Verify every material finding against the repository yourself before acting on it. A confident
finding that you cannot reproduce is not a finding.

Reuse the review session for a targeted recheck. Start a fresh reviewer only for a distinct
unresolved question, never to re-ask a question already answered.
