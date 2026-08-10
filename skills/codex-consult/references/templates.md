# Prompt Templates

Fill in the bracketed parts. Codex cannot use `@` file references in exec mode, so always give real
paths.

## Consult

### Plan validation

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

### Solution review

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

### Getting unstuck

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

### Approach comparison

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

### Independent design proposal

Use before committing to a consequential or hard-to-reverse design. Give only the goal, constraints,
and acceptance criteria. Withholding your own plan is the point: you want an unanchored proposal to
compare against, not a critique of yours.

```
You are proposing a technical approach. Do not implement anything or modify any files.

Goal: [WHAT MUST BE TRUE WHEN THIS IS DONE]

Constraints: [WHAT CANNOT CHANGE, e.g. public API, dependencies, performance budget]

Acceptance criteria:
- [CRITERION 1]
- [CRITERION 2]

Relevant files to examine: [FILE PATHS]

Propose an approach. Explain the main design decision, what you rejected and why, the riskiest part,
and how it would be verified.
```

## Delegate

Every delegation prompt ends with the handoff contract. The fixed heading shape is what makes the
result checkable.

```
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

### Write tests

```
Write tests for the following code. The codebase is in the current directory.

Files to test: [FILE PATHS]

Testing framework and conventions: [FRAMEWORK, e.g. "Swift Testing (not XCTest)", "pytest"]

Key behaviors to cover:
- [BEHAVIOR 1]
- [BEHAVIOR 2]
- [EDGE CASE]

Place test files at: [TARGET PATHS]

Follow existing test patterns in the project. Look at nearby test files for conventions.

Verification:
- Run: [TEST COMMAND]
- Fix any failures before reporting done

[HANDOFF CONTRACT]
```

### Implement a component

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

[HANDOFF CONTRACT]
```

### Fix a specific finding

Use to close a verification failure. Send the exact observation, not a paraphrase, and scope the fix
to that finding.

```
A verification check failed. Fix the cause.

Check that failed: [EXACT COMMAND]
Observed: [EXACT OUTPUT OR OBSERVATION]

Acceptance criterion this violates: [CRITERION]

Files you may modify: [PATHS]

Do not refactor beyond the fix, and do not change the check itself.

Verification:
- Re-run: [EXACT COMMAND]

[HANDOFF CONTRACT]
```

### Blind review

Never include the implementer's handoff, claimed test results, prior review verdicts, or your own
tentative conclusion. See [`review.md`](review.md).

```
Review a change as an independent reviewer. Do not modify the target.

Review this exact snapshot: commit [SHA]

Goal the change was meant to achieve: [GOAL]

Acceptance criteria:
- [CRITERION 1]
- [CRITERION 2]

Constraints that applied: [CONSTRAINTS]

Report correctness problems, unhandled edge cases, and violated constraints. For each finding, cite
the file and line and state how you would confirm it.

[HANDOFF CONTRACT]
```
