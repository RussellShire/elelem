---
name: receiving-code-review
description: Evaluates incoming code review feedback, records dispositions and hands accepted corrections to the authorised executor. Enforces the forbidden-response rules and the pushback requirement when a suggestion is technically wrong.
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: high
---

# Receiving Code Review

The iron-law rules (when reviews are mandatory, forbidden response phrases) live in `../../rules/common/code-review.md`. The procedural rules that bind once this skill is running (verify before acting, clarify before partial implementation, YAGNI on "implement properly", when to push back, severity discipline, GitHub inline reply procedure) live in `../_shared/code-review.md`. This skill is the procedure that applies those rules to a concrete batch of feedback.

Before running the procedure below, you **MUST** read `../_shared/code-review.md` using `{{READ_FILE_TOOL}}` if you have not already read it in this session.

## The Response Procedure

Run these steps, in order, on every piece of review feedback. Evaluation and disposition do not grant execution authority.

1. **Read the complete feedback.** Do not react, do not start implementing, do not respond. Read every item to the end.
2. **Restate and contain.** Restate the technical requirement or identify what is unclear. An unclear finding blocks itself and work whose dependencies, inputs or resources may be affected. Continue evaluating or progressing only already-authorised work demonstrated to be independent after the coordinator records the dependency, input and resource independence. Unknown impact blocks potentially affected work. Respect wave and other existing barriers. See `../_shared/code-review.md`.
3. **Verify each item against the codebase.** For external reviewers, check that the suggestion is correct for this stack, does not break existing behaviour, does not conflict with a prior decision, and does not violate YAGNI on unused code. For your human partner, trust the correctness but still confirm the scope.
4. **Evaluate and disposition.** For each item, accept, push back with technical reasoning, or ask a follow-up question. Severity orders only corrections that are already authorised and eligible; it does not override scope, ownership or dependency constraints. See `../_shared/code-review.md` for pushback requirements.
5. **Respond.** State the disposition per item, the question that remains, or the technical reason for pushing back. Do not promise to implement a correction from this review role. Forbidden responses are listed in `../../rules/common/code-review.md`.
6. **Hand off accepted corrections.** During an active workflow, return accepted corrections to the owning executor for bounded worker dispatch under the existing task contract and retained model pin. The executor applies the workflow's review and check gates to the correction; the coordinator does not patch worker output. Outside an active workflow, return the accepted correction to `workflow-coordinator` before any edit. Do not patch directly or start an implementation flow from this skill.

## Source-Specific Procedure

### From your human partner

- Trusted source for correctness. Skip the codebase-verification step in 3, but clarify any unclear scope. Accepted corrections still follow the active executor handoff or, outside an active workflow, go through `workflow-coordinator` before edits.
- Still forbidden: performative agreement, thanks, "you're absolutely right".
- If the partner's instruction conflicts with something you observed in the code, state the observation and ask rather than silently reinterpreting.

### From external reviewers (including subagent reviewers and bots)

- Not trusted by default. Every item goes through step 3 verification.
- Run `grep`, read the referenced files, check test coverage, check version and platform constraints before accepting a suggestion.
- If a suggestion conflicts with an architectural decision your human partner previously made, stop and escalate to the partner before implementing either side.
- If you cannot verify an item without more information, state the limitation explicitly: "I cannot verify this without X. Should I investigate, ask, or proceed?"

## Worked Examples

### Performative vs technical

Reviewer: "Remove the legacy code path."

Forbidden: "You're absolutely right! Let me remove that now."

Correct: "Checking. The build target is macOS 10.15+; the non-legacy API requires 13+. The legacy path is needed for backward compatibility. The current legacy branch uses the wrong bundle ID. Fix the bundle ID or drop pre-13 support and delete the legacy path. Which?"

### YAGNI on "implement properly"

Reviewer: "Implement proper metrics tracking with a database, date filters, and CSV export."

Correct: "Grepped the codebase. Nothing calls the `/metrics` endpoint. Proposing removal under YAGNI. Is there usage I am missing?"

### Unclear item in a batch

Partner: "Fix items 1 through 6."

You understand 1, 2, 3, and 6. You do not understand 4 and 5.

Forbidden: implement 1, 2, 3, 6 now and ask about 4, 5 later.

Correct: "I can evaluate items 1, 2, 3 and 6. Items 4 and 5 are unclear, so they and any work that may depend on them are paused. I need clarification before those corrections can be authorised. The coordinator can continue only already-authorised work shown to be independent and within the current wave."

### Gracefully correcting your own pushback

You pushed back on a suggestion. After further checking, the reviewer was right.

Correct: "Verified. `foo()` propagates the cancellation token when called from the async path. The wrapper at `bar.ts:88` changes the finding; I am revising the disposition and returning the correction through the owning executor."

Forbidden: long apology, re-litigation of why you pushed back, over-explanation.

### GitHub inline reply

An inline comment exists on `widget.ts:42` in PR #123.

Correct: `gh api repos/{owner}/{repo}/pulls/123/comments/{comment_id}/replies -f body='Fixed in widget.ts:42. Bundle ID guard added and tested against 10.15 and 13.'`

Forbidden: top-level PR comment that references the line in prose.

## Escape Hatch

If you are uncomfortable pushing back out loud, signal with the phrase "Strange things are afoot at the Circle K". Your human partner will pick up on it and open the conversation for you. This does not exempt you from the pushback requirement in `../_shared/code-review.md`; it routes the pushback through a different channel.
