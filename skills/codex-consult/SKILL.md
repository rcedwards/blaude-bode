---
name: codex-consult
description: >
  Consult or delegate to Codex (GPT) via codex exec. Two modes: (1) Consult -- get a second opinion
  on a plan, solution, architecture decision, or problem you're stuck on. (2) Delegate -- hand off
  independent work (writing tests, implementing a component, code review) to Codex in the background
  while you continue working. Use when the user says "ask Codex", "second opinion", "what does GPT
  think", "validate this plan", "cross-check this", "consult Codex", "delegate to Codex", "have
  Codex write tests", "get another take", or similar. Consider self-triggering when you've been
  going back and forth on an approach without progress, when a decision has significant consequences
  and an independent review would reduce risk, or when you have independent work items that Codex
  could handle in parallel.
excluded_hosts:
  - codex
---

# Codex Consult

Call Codex (GPT) non-interactively from Claude Code. Two modes of operation:

- **Consult**: Get a second opinion. Codex runs in read-only mode (the default). You wait for
  the response, synthesize it with your own perspective, and present both to the user.
- **Delegate**: Hand off independent work. Codex runs with `--full-auto` (workspace-write). You
  run it in the background and continue working. You review the output before reporting it done.

## Choosing the right mode

### Consult when:

- You want to validate an implementation plan before executing
- You want an independent perspective on a solution or architecture decision
- You're stuck on a problem and want a fresh approach from a different model
- You're weighing multiple approaches and want another perspective

### Delegate when:

- Writing tests for code you just wrote
- Implementing a component while you work on another
- Code review of completed work items
- Any independent task that doesn't depend on your in-progress work

### Do NOT delegate when:

- The task depends on something you're currently building (it will work against stale state)
- Multiple agents would edit the same file (merge conflicts are inevitable)
- The task requires your current conversation context (Codex starts cold)

## Codex basics

Codex reads `AGENTS.md` files automatically for project instructions (`~/.codex/AGENTS.md` for
global defaults, `<repo>/AGENTS.md` for project-specific). This is similar to CLAUDE.md for
Claude Code.

Sandbox modes in non-interactive (`codex exec`) mode:

| Mode | Flag | Behavior |
|------|------|----------|
| Read-only | (default, no flag) | Reads anywhere, writes and commands blocked |
| Workspace-write | `--full-auto` | Pre-approves edits and commands in workspace |

Use read-only (default) for consultations, `--full-auto` for delegations.

Progress output goes to stderr, final result to stdout. The `-o` flag captures the final message
to a file for clean reading.

---

## Consult Mode

### Constructing the prompt

Every consultation prompt needs three parts:

**1. Role framing** -- Tell Codex it's acting as a consultant/reviewer.

**2. Context** -- Include relevant context directly in the prompt. Codex has filesystem access,
but providing key information upfront saves time and focuses the analysis. Include:
- The plan, solution, or problem description
- Relevant file paths to examine (Codex cannot use `@` file references in exec mode)
- Constraints or requirements the user has mentioned
- What you've already tried (if getting unstuck)

**3. Specific ask** -- Be precise about what feedback you want. Vague prompts get vague answers.

**Good**: "Review this migration plan. Specifically: (1) will the schema change be safe under
concurrent writes? (2) should any steps be reordered? (3) what's the rollback path if step 3 fails?"

**Bad**: "What do you think of this plan?"

### Running the consultation

Create a unique temp file, then run Codex in read-only mode (no `--full-auto`):

```bash
out="$(mktemp /tmp/codex-consult.XXXXXX.txt)"
cat <<'PROMPT' | codex exec --ephemeral -o "$out" -
Your prompt here.
PROMPT
```

If you are NOT inside a git repository (e.g., reviewing files in ~/.claude/), add
`--skip-git-repo-check`.

To set a specific working directory (useful when running from a different context):

```bash
cat <<'PROMPT' | codex exec --ephemeral -C /path/to/project -o "$out" -
Your prompt here.
PROMPT
```

To attach screenshots or images for UI-related consultations:

```bash
codex exec --ephemeral -i screenshot.png -o "$out" "Review this UI and suggest improvements"
```

Flags:
- (no `--full-auto`): Read-only mode. Codex can read the entire codebase but cannot write or
  run commands. This is the correct mode for consultations.
- `--ephemeral`: Don't persist the session (one-shot consultation).
- `-C <path>`: Set working directory explicitly.
- `-i <path>`: Attach image(s) for visual context.
- `--skip-git-repo-check`: Required when running outside a git repository.
- `-o "$out"`: Capture Codex's final response for clean reading.

Set the Bash tool timeout to 300000ms. Consultations typically take 30-120 seconds, but complex
codebase questions where Codex needs to read several files can take longer.

### Presenting consultation results

After Codex responds:

1. Read the output from the temp file, then delete it
2. Synthesize both perspectives. Don't just parrot Codex's response. Add your own analysis.
3. Flag disagreements explicitly. When you and Codex disagree, explain both positions and let the
   user decide. Disagreements are the most valuable part since they surface genuine tradeoffs.
4. Be transparent. Tell the user you consulted Codex and what you asked.

Format:

```
I consulted Codex on [what you asked about]. Here's the combined assessment:

**Codex's take:**
[Summary of key points from Codex]

**Where we align:**
[Areas of agreement, briefly]

**Where we differ:**
[Disagreements with both rationales, if any]

**My recommendation:**
[Your synthesized recommendation based on both perspectives]
```

Simplify this when there are no meaningful disagreements. The format exists to surface differences
when they exist, not to manufacture debate.

### Consultation templates

#### Plan validation

```
You are reviewing an implementation plan as a technical consultant. Analyze the plan for gaps,
risks, and ordering issues. Do not implement anything or modify any files.

Here is the plan:
---
[THE PLAN]
---

The codebase is in the current directory. Review these files for additional context: [FILE PATHS]

Evaluate:
1. Are there missing steps or implicit assumptions?
2. Is the step ordering correct, or should anything be reordered?
3. What are the riskiest steps and how should they be mitigated?
4. What's the rollback path if something fails partway through?
5. Anything else that concerns you?
```

#### Solution review

```
You are reviewing a proposed solution as a technical consultant. Evaluate correctness, edge cases,
and tradeoffs. Do not implement anything or modify any files.

Problem: [WHAT WE'RE SOLVING]

Proposed solution: [THE SOLUTION]

Relevant files to examine: [FILE PATHS]

Evaluate:
1. Will this solution correctly handle the stated problem?
2. What edge cases might it miss?
3. Are there simpler alternatives worth considering?
4. What are the maintenance or performance implications?
```

#### Getting unstuck

```
You are a technical consultant providing a fresh perspective on a problem someone has been stuck on.

Problem: [DESCRIPTION]

What's been tried so far and why it didn't work:
[APPROACHES TRIED]

Relevant files to examine: [FILE PATHS]

Please:
1. Do your own analysis of the relevant code
2. Identify what might be going wrong
3. Suggest approaches that haven't been tried
4. If you can identify the root cause, explain it
```

#### Approach comparison

```
You are a technical consultant helping evaluate competing approaches. Do not implement anything
or modify any files.

Problem: [WHAT WE'RE SOLVING]

Approach A: [DESCRIPTION]
Approach B: [DESCRIPTION]

Relevant files to examine: [FILE PATHS]

For each approach, evaluate:
1. Correctness and completeness
2. Complexity and maintainability
3. Performance characteristics
4. Risk and failure modes

Then give your recommendation with reasoning.
```

---

## Delegate Mode

### Pre-flight checks

Before delegating, verify:

1. **Independence**: The task does not depend on files you are actively editing or work you
   haven't finished yet. Codex will see the filesystem as it is right now.
2. **No file overlap**: List the files Codex will create or modify. If any overlap with files you
   plan to touch, do not delegate.
3. **Self-contained**: The task can be fully described without your conversation history. If you
   find yourself needing to explain a chain of decisions from the current session, the task
   probably needs your context.

### Running the delegation

Create a unique temp file, then run Codex with `--full-auto` in the background:

```bash
out="$(mktemp /tmp/codex-delegate.XXXXXX.txt)"
cat <<'PROMPT' | codex exec --full-auto -o "$out" -
[TASK DESCRIPTION WITH FULL CONTEXT]
PROMPT
```

Run this via Bash with `run_in_background: true` and a timeout of 300000ms. Continue working on
your own tasks while Codex runs. You will be notified when it completes.

Note the temp file path so you can read it when Codex finishes.

Delegation does not use `--ephemeral` so the session persists. If you need to follow up on
incomplete work, resume the session:

```bash
codex exec resume --last "follow-up instructions here"
```

Resume inherits the sandbox settings from the original session, so do not pass `--full-auto` again.

### Prompting for delegation

Treat Codex like a teammate with explicit context and a clear definition of "done." Effective
delegation prompts include:

- **Specific file paths** (Codex cannot use `@` references in exec mode)
- **Verification commands** to run after implementation (test suite, linter, type checker)
- **Constraints** on what NOT to touch
- **Deliverables** that define "done"

Break complex work into focused, single-purpose tasks. A delegation that asks for five features
at once will produce worse results than five focused delegations.

All delegation prompts should end with these constraints:

```
Constraints:
- Do not commit, create branches, or revert unrelated changes
- Do not modify any files outside the ones listed above
- When finished, summarize: files changed, verification results, and any unresolved issues
```

### Delegation templates

#### Write tests

```
Write tests for the following code. The codebase is in the current directory.

Files to test: [FILE PATHS]

Testing framework and conventions: [FRAMEWORK, e.g. "Swift Testing (not XCTest)", "pytest", etc.]

Key behaviors to cover:
- [BEHAVIOR 1]
- [BEHAVIOR 2]
- [EDGE CASE]

Place test files at: [TARGET PATHS, e.g. "Tests/MyFeatureTests/"]

Follow existing test patterns in the project. Look at nearby test files for conventions.

Verification:
- Run: [TEST COMMAND, e.g. "swift test --filter MyFeatureTests"]
- Fix any failures before reporting done

Constraints:
- Do not commit, create branches, or revert unrelated changes
- Do not modify any files outside the test files listed above
- When finished, summarize: files created, tests run, pass/fail results, and any unresolved issues
```

#### Implement a component

```
Implement the following component. The codebase is in the current directory.

What to build: [DESCRIPTION]

Requirements:
- [REQUIREMENT 1]
- [REQUIREMENT 2]

Files to create or modify: [TARGET PATHS]

Reference these existing files for patterns and conventions: [SIMILAR FILES]

Verification:
- Run: [BUILD/TEST COMMAND]
- Confirm no lint errors: [LINT COMMAND]

Constraints:
- Do not commit, create branches, or revert unrelated changes
- Do not modify any files outside the ones listed above
- When finished, summarize: files changed, what was implemented, verification results, and any
  unresolved issues
```

#### Code review

Use the built-in review subcommand for code review delegation:

```bash
out="$(mktemp /tmp/codex-review.XXXXXX.txt)"
codex exec review --base <target-branch> -o "$out"
```

Or for uncommitted changes:

```bash
codex exec review --uncommitted -o "$out"
```

Or for a specific commit:

```bash
codex exec review --commit <sha> -o "$out"
```

The built-in `codex exec review` is purpose-built for code review and produces better structured
output than a freeform prompt. It automatically analyzes the diff and focuses on correctness,
style, and risk.

### Reviewing delegated work

When Codex finishes:

1. **Read the output** from the temp file to see what Codex reports it did, then delete it
2. **Check the actual changes** with `git diff` or by reading modified files. The output file
   describes intent, not necessarily what happened. Verify.
3. **Run tests** or build commands to confirm the changes are correct
4. **Fix issues** yourself if minor, or re-delegate with more specific instructions if major
5. **Only then** report the work item as complete to the user

Do not trust Codex's self-reported success. Verify before reporting.

---

## General guidelines

- **Don't overuse this.** Codex calls cost time and tokens. Reserve consultations for genuine
  decision points, significant plans, or when truly stuck. Reserve delegation for tasks that are
  clearly independent and substantial enough to justify the overhead.
- **Context is everything.** Codex starts cold with no conversation history. Give it enough context
  to be useful but don't dump your entire session.
- **Independence matters.** For consultations, don't bias the prompt toward your preferred answer.
  For delegations, don't hand off tasks that depend on your in-progress work.
- **The user decides.** For consultations, present both perspectives and let the user choose. A
  second opinion is advisory, not authoritative.
- **Task granularity.** Break complex work into focused, single-purpose tasks. Files over ~2000
  lines slow Codex down since it reads the entire file multiple times. Consider pointing Codex
  at specific line ranges or splitting the task.
- **Sandbox limits.** `--full-auto` gives Codex sandboxed workspace-write access. Delegation
  tasks must be completable within that sandbox without extra approvals. If a task needs network
  access, elevated permissions, or interactive input, it will fail silently.
