---
name: codex-consult
description: >
  Consult, delegate to, or orchestrate Codex (GPT) via codex exec. Three modes: (1) Consult -- get a
  second opinion on a plan, solution, architecture decision, or problem you're stuck on.
  (2) Delegate -- hand off one independent work item (writing tests, implementing a component, code
  review) to Codex in the background while you continue working. (3) Orchestrate -- run a supervised
  multi-task run with a durable journal, blind review, and independent verification. Use when the
  user says "ask Codex", "second opinion", "what does GPT think", "validate this plan", "cross-check
  this", "consult Codex", "delegate to Codex", "have Codex write tests", "get another take",
  "orchestrate this with Codex", "supervise Codex", or similar. Consider self-triggering when you've
  been going back and forth on an approach without progress, when a decision has significant
  consequences and an independent review would reduce risk, or when you have independent work items
  that Codex could handle in parallel.
excluded_hosts:
  - codex
requires:
  - codex
  - python3
---

# Codex Consult

Call Codex (GPT) non-interactively from Claude Code. Claude keeps the global context, plans, and
verifies. Codex gets focused, bounded execution through its own CLI.


## Choosing a mode

| Mode | Use when | Sandbox | Cost |
|------|----------|---------|------|
| **Consult** | You want a second opinion on a plan, solution, or blocker | `-s read-only` (must be explicit) | one foreground call |
| **Delegate** | You have one independent, self-contained work item | `-s workspace-write` | one background call |
| **Orchestrate** | Multiple tasks, or the result must be auditable and independently verified | `-s workspace-write` | a durable run |

Start with the lightest mode that fits. Most asks are Consult. Reach for Orchestrate only when the
work spans several tasks, needs blind review, or someone will later ask what was actually checked.

### Do NOT delegate or orchestrate when

- The task depends on something you're currently building; Codex sees the filesystem as it is now
- The task requires your conversation context and can't be written down (Codex starts cold)
- Two agents would edit the same file, unless you isolate them with a worktree (see
  `~/.claude/skills/codex-consult/references/compute.md`)

## Codex basics

Codex reads `AGENTS.md` automatically (`~/.codex/AGENTS.md` global, `<repo>/AGENTS.md` per project),
the same way Claude Code reads CLAUDE.md.

Set the Bash tool timeout to 300000ms. Consultations typically take 30-120 seconds; delegations run
longer.

**`codex exec` defaults to `-s workspace-write`, not read-only.** Verify with the banner it prints:
`sandbox: workspace-write [workdir, /tmp, $TMPDIR]`. Always pass `-s read-only` explicitly for a
consultation. Omitting it hands a "second opinion" write access to the user's repository.

Flags that matter:

- `-s read-only`: blocks filesystem writes. It does **not** block command execution; Codex still runs
  `rg`, `git diff`, and test commands, which is what makes a consultation useful. Not the default.
- `-s workspace-write`: allows writes under the workspace roots shown in the banner.
- `-c approval_policy=never`: never pause to ask for approval. It does not pre-approve anything; a
  sandboxed operation that needs escalation just fails, and the failure returns to the model. This is
  already the `codex exec` default, so pass it to be explicit and immune to config changes, not
  because it changes behavior. Prefer it over `--full-auto`, which no longer appears in
  `codex exec --help`.
- `-o <file>`: write the final message to a file. This is the handoff.
- `--json`: stream events as JSONL to stdout. Redirect to a file so you can monitor a background run.
- `-C <path>`: working directory. `-i <path>`: attach images. `-m <model>`: pick a model.
- `--skip-git-repo-check`: required outside a git repository or an untrusted directory.
- `--ephemeral`: don't persist the session. Omit it unless you're certain you won't follow up;
  a persisted session lets you resume a targeted follow-up instead of re-explaining.
- `--output-schema <file>`: constrain the final response to a JSON Schema. Use for delegations whose
  handoff you intend to parse rather than read.

Without `--json`, progress goes to stderr and the final result to stdout. With `--json`, stdout
becomes the JSONL event stream and `-o` is how you get the final message.

## Trust boundary

This governs every mode. A handoff establishes that Codex **claimed** something. It does not
establish that the claim is true.

- A handoff is a package of claims. An event stream shows what the harness emitted.
- Neither establishes that a test passed against the accepted repository state.
- A `Commands Reported` section is **not** a verification. Run the check yourself and observe it.
- Verify against repository state or observed output. Use Codex's findings to decide what to inspect,
  not what to conclude.

Do not trust self-reported success. Verify before reporting anything as done.

## Consult mode

Read-only, foreground. You wait, synthesize, and present both perspectives.

```bash
out="$(mktemp /tmp/codex-consult.XXXXXX)"      # X's MUST be last; BSD mktemp ignores a suffix
cat <<'PROMPT' | codex exec -s read-only -o "$out" -
Your prompt here.
PROMPT
echo "$out"                                     # print it; $out is gone in your next Bash call
```

Both details bite. `mktemp /tmp/x.XXXXXX.md` does not substitute on macOS: it creates a literal
`x.XXXXXX.md` the first time and fails with `File exists` on every call after. And `-s read-only` is
not the default, so omitting it gives a consultation write access.

Every consultation prompt needs three parts: **role framing** (Codex is a consultant, not an
implementer), **context** (the plan or problem, file paths to examine, constraints, what you already
tried), and a **specific ask**. Vague prompts get vague answers.

> **Good**: "Review this migration plan. Specifically: (1) will the schema change be safe under
> concurrent writes? (2) should any steps be reordered? (3) what's the rollback path if step 3 fails?"
>
> **Bad**: "What do you think of this plan?"

Codex cannot use `@` file references in exec mode. Give it real paths.

Templates for plan validation, solution review, getting unstuck, and approach comparison are in
`~/.claude/skills/codex-consult/references/templates.md`.

### Presenting the result

Read the output file, then delete it. Synthesize; don't parrot. Tell the user you consulted Codex and
what you asked.

```
I consulted Codex on [what you asked about]. Here's the combined assessment:

**Codex's take:** [key points]
**Where we align:** [briefly]
**Where we differ:** [both rationales, if any]
**My recommendation:** [your synthesis]
```

Collapse this when there are no meaningful disagreements. The format exists to surface differences,
not to manufacture debate.

When you and Codex disagree, resolve it by acceptance fit, direct evidence, risk, simplicity, and
reversibility. Never by agent count; two models agreeing is not evidence. See
`~/.claude/skills/codex-consult/references/consensus.md`.

## Delegate mode

One independent work item, workspace-write, background.

Pre-flight: confirm the task is independent of your in-progress work, that no file Codex will touch
overlaps a file you plan to touch, and that the task is fully describable without your conversation
history.

```bash
d="$(mktemp -d /tmp/codex-delegate.XXXXXX)" && echo "DELEGATE_DIR=$d"
codex exec --json -o "$d/handoff.md" \
  -s workspace-write -c approval_policy=never \
  - < prompt.md > "$d/events.jsonl"
```

Echo the directory and then use its **literal** path in every later command. Shell variables do not
survive between Bash calls, so a follow-up referring to `$d` silently expands to nothing and writes
to `/handoff.md`.

Run it with `run_in_background: true`. Note that the Bash timeout caps the run: a delegation that
needs longer than the timeout you set is killed mid-flight, leaving a truncated event stream and no
handoff. Size the timeout to the task, and on a kill treat the execution as `failed` rather than
inferring what it might have finished.

While it runs, check progress without pulling raw logs into context:

```bash
python3 ~/.claude/skills/codex-consult/scripts/codex_orch_tools.py \
  monitor --log /tmp/codex-delegate.XXXXXX/events.jsonl --once
```

Every delegation prompt names specific file paths, verification commands to run, constraints on what
not to touch, and what "done" means. Break complex work into focused, single-purpose tasks; one
delegation asking for five features produces worse results than five delegations.

End every delegation prompt with the handoff contract:

```markdown
Finish with a concise final response using exactly these headings:

## Status

## Summary

## Files Changed

## Claims / Findings

## Commands Reported

## Caveats / Blockers

Constraints:
- Do not commit, create branches, or revert unrelated changes
- Do not modify any files outside the ones listed above
```

The fixed shape is what makes the handoff checkable. Templates are in
`~/.claude/skills/codex-consult/references/templates.md`.

For code review specifically, prefer the built-in subcommand, which is purpose-built and produces
better structure than a freeform prompt:

```bash
codex exec review --base <branch> -o "$out/handoff.md"     # or --uncommitted, or --commit <sha>
```

### Reviewing delegated work

1. Read the handoff. Treat it as claims.
2. Inspect the actual diff and changed files. Compare against the paths you allowed.
3. Run the verification commands yourself and observe the result.
4. Fix minor issues yourself; re-delegate major ones with sharper instructions.
5. Only then report the item complete.

To follow up on incomplete work, resume rather than starting cold. Resume by explicit session id, and
re-pass the sandbox flags:

```bash
rg -m1 '"type":"thread.started"' /tmp/codex-delegate.XXXXXX/events.jsonl   # read thread_id
codex exec -s workspace-write -c approval_policy=never \
  resume <session-id> "follow-up instructions here"
```

Resume restores the conversation, not your invocation flags: sandbox and approval are resolved fresh
each time, so a resume without `-s` silently drops back to the default. Avoid `--last`, which picks
the newest session scoped to the current directory. Any other consult or delegation you started since
can become "last."

## Orchestrate mode

A supervised run: Claude plans, decomposes into tasks, assigns scoped Codex agents, independently
verifies each result, records consequential decisions, and closes with a report. Every prompt, event
stream, and handoff is kept so the run can be inspected later.

Read `~/.claude/skills/codex-consult/references/workflow.md` and follow it. It owns run initialization, the task
lifecycle, closure, and the report. Load the other references only as the current phase needs them:

- `references/orchestration-contract.md`: journal entry types, record authority, validation semantics
- `references/monitoring.md`: launching, capturing, resuming, and monitoring agents
- `references/review.md`: verification and blind independent review
- `references/consensus.md`: recording decisions
- `references/compute.md`: parallel file ownership, worktrees, resource gating
- `references/report.md`: the final report structure

## General guidelines

- **Don't overuse this.** Codex calls cost time and tokens. Reserve consultation for genuine decision
  points and delegation for work that's clearly independent and substantial enough to justify the
  overhead.
- **Context is everything.** Codex starts cold. Give it enough to be useful without dumping the
  session.
- **Don't bias a consultation.** Don't lead the prompt toward your preferred answer. For an
  independent review, also withhold the implementer's handoff and your tentative conclusion
  (`references/review.md`).
- **The user decides.** A second opinion is advisory, not authoritative.
- **Task granularity.** Files over ~2000 lines slow Codex down because it re-reads them. Point at line
  ranges or split the task.
- **Sandbox limits.** `workspace-write` plus `approval_policy=never` fails closed: there is no
  escalation path, so a blocked operation just errors. Before delegating, check whether the task needs
  anything outside the workspace roots in the banner. Common tripwires: package managers needing
  network and a global cache, test runs writing to SDK or simulator caches in `~/`, git hooks that
  need separate trust, and anything expecting interactive input. Name those needs in the prompt so the
  failure is diagnosable. Broad access belongs in an externally hardened container and needs explicit
  authorization.

The orchestration layer and its tooling are adapted from
[codex-orchestrator](https://github.com/alexzh3/codex-orchestrator) (MIT); see
`~/.claude/skills/codex-consult/scripts/LICENSE.upstream`.
