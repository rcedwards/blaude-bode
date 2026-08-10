# Final Report

Write `report.md` only after orchestration work has finished. Do not start agents, continue tasks, or
write an interim report here. Return to [`workflow.md`](workflow.md) when more work is needed.

## Preconditions

Confirm that:

- `run_closed.validation` contains the complete descriptive validation result;
- every execution has a terminal execution result, and every task is terminal;
- `run_closed` is the final journal entry and carries `judgment: passed|blocked`;
- no further run work is planned.

If any of these is false, stop and return to orchestration. Never edit the journal to make the report
look complete.

Read the complete `journal.jsonl`, then ground each claim in its proper source:

- actual delivery: final repository state relative to the `run_started` Git baseline;
- your checks: verification observations and referenced evidence;
- assigned scope: the exact prompts;
- agent claims: the exact handoffs;
- lifecycle and chronology: journal entries;
- ambiguous process activity: raw events or direct observation;
- decisions and final judgment: decision and `run_closed` entries.

The journal is working memory, not independent evidence. Surface conflicts and missing facts; do not
silently repair them.

## Structure

Use exactly these five top-level sections, in this order. Do not add other `##` sections. Create the
report once; replace it only when explicitly asked to correct or regenerate it.

```markdown
# Report

## Summary

## Changes

## Orchestration Graph

## Consensus

## Final Results
```

### Summary

The original `run_started.goal`, the overall result, `run_closed.judgment`, and the main reason for
that outcome. State unresolved work plainly. Keep it short.

### Changes

Compare the final repository state with `run_started.repo_head` and `repo_status`, then connect
material delivered changes to their tasks or agents. Do not attribute initially dirty paths without
supporting evidence. Distinguish complete, blocked, failed, and intentionally unchanged work. Do not
reproduce the journal line by line, and do not treat `execution_result.files_changed` as mechanical
attribution.

### Orchestration Graph

A readable Mermaid `flowchart TD` built from journal chronology, grounded in handoffs, verification
evidence, repository changes, and raw events only when needed:

- `A_CLAUDE{{"Claude Code<br/>planner · orchestrator"}}`;
- separate non-empty Claude-agent and Codex-agent subgraphs;
- material reviews, checks, decisions, and produced deliverables;
- the final judgment and state, including meaningful fix and recheck loops.

One node per named agent, ordered by first execution, carrying its task, recorded model and effort,
main result, and terminal status. Combine an agent's resumed executions into its node. Keep a linear
run minimal, and never create an empty subgraph.

Label edges concisely: `assign`, `review`, `verified`, `resolution`, `consensus`, `claude_decision`,
`produced`, `fix required`, `recheck`, `accepted`. Show only evidence that affected a decision or the
final judgment. Combine routine passing checks and group related decisions, but keep Claude decisions,
user actions, and unresolved outcomes distinct.

Mark reconstructed facts as `inferred`. Never infer verification results, decision outcomes,
judgments, or terminal status.

The `mermaid-author` skill covers rendering-safe syntax.

### Consensus

Summarize consequential `decision` entries with outcome, basis, resolution, and risk. State plainly
when no decision was required. Keep consensus, Claude decisions, user actions, accepted risks, and
unresolved outcomes distinct. Missing basis or untreated residual risk belongs under Risks /
Follow-ups.

### Final Results

Two subsections, in this order:

```markdown
### Gate Result

### Risks / Follow-ups
```

Under **Gate Result**, report `run_closed.judgment`, its summary, and the recorded validation issues
and warnings. Validation is an omission check, not evidence of correctness and not the source of the
judgment. Do not recompute or soften the recorded judgment.

Under **Risks / Follow-ups**, list unresolved checks, blocked or failed work, required user actions,
accepted risks, and concrete next steps. Write `None recorded.` when nothing remains.

End Final Results with one compact `Run metadata` bullet carrying the available `claude` and `codex`
versions from `run_started`. Omit unavailable values. Do not add a schema version or a reproducibility
section.

## Final check

Reread the finished report. Confirm the five `##` sections appear once and in order, the Mermaid block
renders, every material claim is grounded, and Final Results faithfully reflects `run_closed.judgment`,
the validation output, risks, and follow-ups. Reconcile every numeric total against the journal
entries or handoffs it summarizes.
