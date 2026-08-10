---
name: claude-code-consult
description: Get a second opinion from Claude Code on a plan, proposed solution, debugging path, or blocker. Use when the user explicitly wants Claude's take or when Codex has already gathered context and wants an external critique without handing off the full task.
excluded_hosts:
  - claude
---

# Claude Code Consult

Use local `claude` as an external reviewer after building context in Codex. Keep the ask narrow and intentional. This wrapper is for consultation, not agentic delegation.

## Workflow

1. Gather context locally first. Read the code, reproduce the issue, or draft the plan before consulting Claude.
2. Choose the mode that matches the ask:
   - `plan`: validate a proposed sequence of work
   - `solution`: critique an implementation approach or compare options
   - `stuck`: help debug or unblock a problem after failed attempts
   - `raw`: send an untemplated question when the built-in framing is a poor fit
3. Build a compact prompt packet with:
   - the goal
   - the relevant constraints
   - what you already tried or decided
   - the exact question you want answered
4. Attach only the files that matter. Prefer one to three focused files or excerpts over broad repository dumps.
5. Run the wrapper script and use Claude's output as input to your own judgment.

## Delegation Guidance

These rules are still useful when you choose to run Claude in a truly agentic workflow outside this wrapper:

- good candidates: tests for code you already wrote, an isolated component, or a code review pass
- do not delegate when the task depends on code you are currently building, when file ownership overlaps, or when the task requires the current conversation context
- run Claude in the background and review its output before marking the work item complete

This wrapper does not implement agentic delegation. `claude --print` can critique or advise, but it cannot safely own and execute bounded code changes.

## Commands

Use the wrapper:

```bash
scripts/claude-code-consult.sh <plan|solution|stuck|raw> [options] [prompt]
```

Options:

- `--file <path>`: attach a relevant file with line numbers; repeat as needed
- `--file <path:N-M>`: attach only a focused line range from a file
- `--model <model>`: pass a specific Claude model
- `--effort <low|medium|high|max>`: request more or less reasoning effort

If prompt text is omitted, the script reads from stdin.

Examples:

```bash
scripts/claude-code-consult.sh plan \
  --file App/Feature/CheckoutCoordinator.swift \
  "Goal: add retry support without changing the public API. Review this plan for missing steps and risk."

scripts/claude-code-consult.sh solution <<'EOF'
Goal: remove duplicate analytics events during app startup.
Constraints:
- keep the existing tracker interface
- avoid adding global state
Proposed solution:
- move initialization behind a lazy provider
- gate emission on the first active session
Question:
- what failure modes or simpler alternatives do you see?
EOF

scripts/claude-code-consult.sh stuck \
  --file Sources/Auth/AuthManager.swift \
  --file Tests/AuthTests/AuthManagerTests.swift:1-200 <<'EOF'
Symptoms:
- tests pass individually but fail in suite order
Attempts:
- reset singletons in tearDown
- removed shared clock override
Question:
- what are the most likely root causes and next debugging steps?
EOF
```

## Prompt Quality

Do:

- state the decision or blocker clearly
- include constraints and prior attempts
- ask for critique, risks, missing assumptions, or next debugging steps
- keep attached context tightly scoped
- prefer excerpts over whole files when the context is large

Do not:

- ask Claude to inspect the whole repository by default
- outsource the primary analysis before doing your own local work
- treat Claude's answer as authoritative when it conflicts with observed code or tests

## Review Hygiene

A second opinion is worth something only if it is independent. Anchoring the reviewer destroys the
thing you asked for.

When you want a genuine critique rather than a sanity check:

- Withhold your own tentative conclusion, any earlier review verdict, and claimed test results.
- Give the goal, the constraints, and the acceptance criteria. Let Claude reach its own read.
- Pin the target. Name the exact commit SHA or the exact files and line ranges under review, not
  "the current state," which moves while you work.
- Start a fresh consultation rather than continuing one that already contains your position.

Before committing to a consequential or hard-to-reverse design, consider asking for a proposal from
only the goal, constraints, and acceptance criteria, without showing your plan. An unanchored
proposal you can compare against is more useful than a critique of the plan you already favor.

## Output Handling

Treat Claude as a reviewer.

- Compare its answer against the codebase and the user's goal.
- Pull out the useful parts: missing risks, sharper tradeoffs, alternate debugging steps.
- Ignore speculative advice that is not grounded in the provided context.
- Treat every claim as a claim. A reported command result establishes only that Claude said it. Run
  the check yourself and observe it before acting on it.

## Resolving Disagreement

When Claude's answer conflicts with yours, decide by acceptance fit, direct evidence, risk,
simplicity, and reversibility.

Never decide by agreement count. Two models converging is correlated noise, not corroboration, and a
single dissent backed by a failing check outranks confident agreement.

Verify a material finding against the code before you act on it. A finding you cannot reproduce is
not a finding. Send a targeted follow-up on the specific point rather than asking for another broad
review.

## Failure Handling

If the script reports that `claude` is missing, install or expose the CLI first.

Check auth with:

```bash
claude auth status
```

If it does not report `"loggedIn": true`, run:

```bash
claude auth login
```

If `claude auth status` is false inside Codex but `claude --print "Reply with OK only."` works in your normal terminal, treat that as a sandbox or process-isolation issue rather than a bad login. Re-run the Claude command outside the sandbox or with escalated permissions.

If the command fails because the environment blocks outbound access, surface that constraint and continue without the consultation.
