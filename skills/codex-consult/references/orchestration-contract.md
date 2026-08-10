# Orchestration Contract

The run journal is Claude's concise causal history plus links to supporting material. It is not a
workflow engine, not independent evidence, and not automated telemetry. Claude makes every semantic
judgment. The vendored tools only summarize event streams and check a small set of structural
omissions.

## Record authority

- **Prompt**: the exact immutable input sent for one execution. It records assigned scope.
- **Event stream**: raw Codex JSONL. It records what the harness emitted, and supports lifecycle
  checks, monitoring, and debugging.
- **Handoff**: the exact final agent response. A compact package of agent claims.
- **Evidence**: an inspectable observation that supports or contradicts a verification or decision.
- **Verification**: Claude's evaluation of one criterion using an explicit check and observation.
- **Decision**: Claude's recorded resolution of a consequential disagreement, risk, or user need.
- **Journal**: Claude's compact chronology, task state, decisions, and links to the above.
- **Repository**: the final state relative to the recorded baseline determines what was delivered.

A handoff can establish that an agent *claimed* a test passed. An event stream can establish that the
harness emitted that claim. Neither establishes that the test passed against the accepted repository
state. Check material claims independently before recording a verification.

Evidence need not be a file. Keep a small command result or diff observation inline. Use the optional
`evidence/` directory for lengthy output, screenshots, metrics, failure diagnostics, or material
another reviewer may need later. Never copy handoffs into `evidence/`.

## Run layout

```text
.codex-consult/runs/<run-id>/
  journal.jsonl
  <provider>-<role>-<NN>/execution-<NN>/
    prompt.md
    events.jsonl
    handoff.md
  evidence/                 # optional
  report.md                 # after run_closed
```

Each top-level agent directory is a persistent execution context. Every prompt, event stream, and
handoff cycle gets the next numbered execution; resuming a native session creates another execution
under the same agent.

## Journal entries

One orchestrator owns and appends to `journal.jsonl`. Every nonblank line is one JSON object with
`recorded_at`. Never let two orchestration loops write the same run.

Each `agent` + `execution` pair may appear in at most one `execution` and one `execution_result`.
`verification` and `decision` IDs must be unique within their type. Task IDs intentionally repeat, to
record status changes.

If a unique identity is duplicated, retain the journal, stop appending, and start a successor run
that references the prior run. Never rewrite history.

The fields below are the run protocol, not a runtime-enforced schema.

### `run_started`

The first entry. Records the concise original goal, absolute target worktree, starting Git baseline,
and available tool versions. `repo_head` is the full starting commit; include `repo_branch` only when
HEAD is attached. `repo_status` holds the exact lines from `git status --short --untracked-files=all`,
captured after locally excluding the run root and before creating it.

```jsonl
{"type":"run_started","run_id":"run-20260810-01","goal":"Add request validation without changing the public API.","repo":"/work/project","repo_head":"0123456789abcdef0123456789abcdef01234567","repo_branch":"feature/request-validation","repo_status":[],"claude_version":"2.1.0","codex_version":"0.145.0","recorded_at":"2026-08-10T12:00:00Z"}
```

Omit an unavailable version or a detached `repo_branch`; do not guess. Treat initially dirty paths as
pre-existing user work. If planned work overlaps them, isolate the work or get user direction. The
status alone cannot attribute later edits within the same file.

### `task`

Entries repeat for the same task; the latest is current. Status is `pending`, `active`, `complete`,
`blocked`, or `failed`. Active tasks declare their owned file paths or globs in `files` before
parallel execution; parallel tasks must have disjoint ownership or use isolated worktrees.

This planned boundary is distinct from `execution_result.files_changed`, which is a compact
attribution note. The repository diff determines what actually changed.

```jsonl
{"type":"task","id":"task-01","status":"active","goal":"Add request validation.","acceptance":["Invalid input is rejected","Relevant tests pass"],"files":["src/api.py","tests/test_api.py"],"recorded_at":"2026-08-10T12:01:00Z"}
```

### `execution`

Append before launch so in-flight work survives context loss. The `agent` + `execution` pair is its
identity. Record the absolute `worktree`, full Git `head`, and attached `branch` when present, so
resume and integration target the same tree after context loss. Use `event_source: "exec"` for a
Codex CLI stream. Record `model`, `effort`, and `session_id` when known; a later execution result may
supply the session id.

```jsonl
{"type":"execution","agent":"codex-impl-01","execution":"execution-01","task":"task-01","provider":"codex","role":"implementation","mode":"headless","event_source":"exec","model":"gpt-5","effort":"high","worktree":"/work/project-codex-impl-01","head":"0123456789abcdef0123456789abcdef01234567","branch":"codex-impl-01","prompt":"codex-impl-01/execution-01/prompt.md","events":"codex-impl-01/execution-01/events.jsonl","handoff":"codex-impl-01/execution-01/handoff.md","recorded_at":"2026-08-10T12:02:00Z"}
```

### `execution_result`

Claude's terminal understanding of one execution: `complete`, `blocked`, or `failed`. It links the
exact handoff and summarizes reported or observed files, results, and caveats. It is not process
telemetry and not authoritative file attribution. A complete execution result does not complete the
task.

```jsonl
{"type":"execution_result","agent":"codex-impl-01","execution":"execution-01","task":"task-01","status":"complete","session_id":"thread-123","handoff":"codex-impl-01/execution-01/handoff.md","summary":"Implemented validation and tests.","files_changed":["src/api.py","tests/test_api.py"],"caveats":[],"recorded_at":"2026-08-10T12:20:00Z"}
```

An execution is in flight until a matching terminal result exists. Completed executions require a
nonempty handoff. A missing handoff on a blocked or failed execution is a warning, and must never be
fabricated.

### `verification`

One criterion, evaluated. Result is `passed`, `failed`, `inconclusive`, or `skipped`. `check` is the
exact command or inspection; `observation` states what you actually observed.

```jsonl
{"type":"verification","id":"check-01","task":"task-01","criterion":"Relevant tests pass","method":"command","check":"python -m pytest tests/test_api.py -q","result":"passed","observation":"12 tests passed; exit code 0.","evidence":["evidence/task-01-tests.txt"],"recorded_at":"2026-08-10T12:25:00Z"}
```

The agent's `Commands Reported` section is not a verification.

### `decision`

A consequential resolution. Outcome is `consensus`, `claude_decision`, or `user_action_required`.
`basis` references checks, handoffs, evidence, or repository paths; `risk` states residual risk.
Decisions explain history. They never delete or rewrite failed checks.

```jsonl
{"type":"decision","id":"decision-01","task":"task-01","finding":"The first implementation accepted whitespace-only names.","outcome":"consensus","resolution":"Reject stripped empty names and retain the regression test.","basis":["check-01","codex-impl-01/execution-02/handoff.md"],"risk":"low","recorded_at":"2026-08-10T12:45:00Z"}
```

### `run_closed`

The final entry. Copy the pre-close validation result into `validation` verbatim, and record the
semantic `judgment` as `passed` or `blocked`, plus unresolved risks and follow-ups.

```jsonl
{"type":"run_closed","judgment":"passed","summary":"All acceptance criteria were independently verified.","validation":{"ok":true,"issues":[],"warnings":[],"non_passing_verifications":[]},"risks":[],"follow_ups":[],"recorded_at":"2026-08-10T13:00:00Z"}
```

Validation does not decide `judgment`. Review its output, every non-passing verification, open
decisions, and repository state before closing.

## Handoff contract

Every agent prompt asks for a concise final response with these headings:

```markdown
## Status

## Summary

## Files Changed

## Claims / Findings

## Commands Reported

## Caveats / Blockers
```

Codex writes this exact response via `-o`. Do not rewrite a handoff into a cleaner summary; put your
own observations in the execution result or verification instead.

## Failed checks and reruns

Keep both observations. A passing rerun supports accepting the corrected repository state, but it
does not erase the earlier failure. Record the failed verification, the fix execution, and the
passing verification as separate entries.

## Descriptive validation

`validate` is a small omission check. It is not truth validation and not acceptance. It checks:

- JSON objects and the seven journal entry type names;
- one initial `run_started` and at most one final `run_closed`;
- execution and result identities, pairing, order, and matching task IDs when recorded;
- task references, plus duplicate verification and decision IDs;
- declared prompt, event, handoff, and evidence files exist;
- terminal execution results and latest task states before closure;
- nonempty completed-execution handoffs;
- recognized verification results, plus a list of every non-passing verification.

Its output is ordinary JSON, not a journal entry:

```json
{
  "ok": true,
  "issues": [],
  "warnings": [],
  "non_passing_verifications": []
}
```

Validation does not enforce every documented field, confine paths, resolve decision bases, match
reruns, clear failures, infer consensus, verify provenance, or decide acceptance. Copy the complete
result into `run_closed.validation`, then author `report.md` from the full run context.
