# Consensus And Decisions

Record a `decision` only for a consequential disagreement, an accepted risk, a resolution that
changes the work, or a required user action. Routine agreement is not a decision. See
[`orchestration-contract.md`](orchestration-contract.md) for the journal fields.

Outcomes:

- `consensus`: Claude and the relevant Codex agent converge after inspecting evidence.
- `claude_decision`: Claude chooses, and records the rationale, the rejected alternative, and the
  residual risk.
- `user_action_required`: progress or acceptance needs an explicit user choice or external action.

## Resolving a disagreement

1. State the disputed finding and cite your own observation, not the agent's claim.
2. Send a targeted follow-up to the relevant agent. Do not request another broad review.
3. Inspect the response, the repository state, and the relevant checks.
4. If a fix is chosen, assign and verify it before completing the task.
5. Record a decision only when the outcome affects implementation, acceptance, risk, or user action.

Choose by acceptance fit, direct evidence, risk, simplicity, and reversibility. Never by agent count:
two models agreeing is correlated noise, not corroboration, and a lone dissent backed by a failing
check outranks unanimous confidence.

Record the finding, resolution, basis, and risk without erasing failed verifications. Use
`claude_decision` when you can proceed within existing authority. Use `user_action_required` when
authority or required information is missing; an unresolved required user action normally closes the
run as blocked.
