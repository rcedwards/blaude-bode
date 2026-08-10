# Running And Monitoring Agents


## Launching an execution

Create the next numbered execution directory under its named agent:

```text
codex-impl-01/execution-01/
  prompt.md
  events.jsonl
  handoff.md
```

Save `prompt.md` and append the `execution` journal entry **before** launch, so in-flight work
survives context loss. Resolve the recorded Git values from the same path you pass to `-C`:

```bash
git -C <worktree> rev-parse --show-toplevel
git -C <worktree> rev-parse HEAD
git -C <worktree> branch --show-current
```

Then launch:

```bash
EXECUTION_DIR="<abs-run-dir>/codex-impl-01/execution-01"
codex exec --json -o "$EXECUTION_DIR/handoff.md" \
  -s workspace-write -c approval_policy=never \
  -C <worktree> \
  - < "$EXECUTION_DIR/prompt.md" > "$EXECUTION_DIR/events.jsonl"
```

Never use `--ephemeral` in a run: you lose the session and cannot resume. Use broader access than
`workspace-write` only with explicit authorization and isolation.

**Capture the session id as soon as the stream exists.** Resume needs it, and nothing else records
it. Read `thread_id` from the first `thread.started` event and put it in the `execution_result`:

```bash
rg -m1 -o '"thread_id":"[^"]+"' "$EXECUTION_DIR/events.jsonl"
```

Do this before the execution scrolls out of your context. An execution whose session id was never
recorded can only be redone from scratch under a new agent.

Every prompt must require the handoff shape from
[`orchestration-contract.md`](orchestration-contract.md). Extract the last agent message from the
event stream only when normal handoff capture failed.

## Resuming

Resume a relevant idle session as the next execution under the same agent:

```bash
EXECUTION_DIR="<abs-run-dir>/codex-impl-01/execution-02"
codex exec -C <worktree> -s workspace-write -c approval_policy=never \
  resume --json -o "$EXECUTION_DIR/handoff.md" \
  <session-id> - < "$EXECUTION_DIR/prompt.md" > "$EXECUTION_DIR/events.jsonl"
```

Read the absolute worktree from the preceding execution and reuse it with `-C` and the same
`session_id`. Inspect the worktree's *current* HEAD and branch and record those in the new execution.
The prior `head` is a snapshot; do not check out or reset to it merely because the worktree advanced.

A fresh native session requires a new named agent.

## State and monitor

Compact snapshot of one stream:

```bash
python3 ~/.claude/skills/codex-consult/scripts/codex_orch_tools.py state <session-id> \
  --file <events-jsonl> --json
```

Watch every in-flight execution in a run, or explicit streams:

```bash
python3 ~/.claude/skills/codex-consult/scripts/codex_orch_tools.py monitor --repo <repo> --run-id <run-id>
python3 ~/.claude/skills/codex-consult/scripts/codex_orch_tools.py monitor --log <events-jsonl> --fail-on-agent-failure
```

Always select the target with `--run-id` plus its repository, or with `--log`. Add `--once` to scan
and exit instead of polling.

These tools parse event streams locally and emit compact JSON. That is the point: do not copy raw
event logs into context unless you are inspecting one ambiguous or failed agent.

The monitor is read-only. It emits completion, failure, unknown-format, missing-stream, and stale
notifications. Treat silence and staleness as **ambiguous**, not as failure. Inspect the handoff and
the repository before appending an `execution_result`.

If `state` reports low parse confidence, the CLI's event format has moved ahead of the vendored
parser. Run `state --dump-event-types`, update `scripts/codex_orchestrator/events.py`, and do not
infer agent status in the meantime.

Do not persist parser positions in the journal. After context loss, just call `state` again.
