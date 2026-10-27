---
name: complexity-triage
description: Advisory classification of a defined task's complexity; never routes execution or authorises bypassing workflow phases.
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: medium
---

# Complexity Triage

Classify a defined task as SIMPLE or COMPLEX using evidence from the approved
design and available research. This classification is advisory only. It does
not decompose architecture, choose an execution pipeline, approve scope, or
authorise skipping workflow phases, reviews or checks. The workflow coordinator
owns phase transitions; implementation uses its approved schedule, which by
default has an independent `READY` verdict. If the user explicitly skips only
the readiness review, the schedule may instead have a recorded `SKIPPED` review
and must still pass the planner's full safety checks. Apply
`../_shared/wave-readiness.md` and
`../subagent-driven-development/SKILL.md` as the canonical gate.

Triage may help planning describe effort or select a bounded task shape. A
SIMPLE result does not automatically invoke `fast-path-implementation`.
That compatibility entry point may be used only for one task explicitly
scheduled by the coordinator, and it retains the standard review and
verification lifecycle. Task size is never evidence that a phase should be
skipped. Only the user can authorise a scoped skip, whose scope, reason and
consequence the coordinator records.

## Evidence criteria

Use these criteria to make the classification useful, not as routing gates.
Do not default to SIMPLE when evidence is incomplete. If an answer depends on
missing requirements, architecture or context, report the uncertainty and
return it to the appropriate planning phase.

| # | Criterion | Evidence to examine |
|---|---|---|
| 1 | Uniform change type | Whether the task applies one consistent kind of change |
| 2 | No new logic | Whether it introduces functions, control flow, error handling or business rules |
| 3 | No new interfaces | Whether it changes public contracts, exports, endpoints or events |
| 4 | Deterministic from approved inputs | Whether the approved brief specifies the exact intended result |
| 5 | Independently understandable | Whether the task's correctness relies on another task's changing result |
| 6 | Small total delta | A rough estimate of substantive changes and how it was derived |

Present the evidence and uncertainty to the coordinator in this format:

```text
Complexity triage

| # | Criterion | Evidence | Assessment |
|---|---|---|---|
| 1 | Uniform change type | [specific observation] | supports / does not support |
| 2 | No new logic | [specific observation] | supports / does not support |
| 3 | No new interfaces | [specific observation] | supports / does not support |
| 4 | Deterministic from approved inputs | [specific observation] | supports / does not support |
| 5 | Independently understandable | [specific observation] | supports / does not support |
| 6 | Small total delta | [estimate and method] | supports / does not support |

Advisory classification: SIMPLE / COMPLEX / INSUFFICIENT EVIDENCE
Reason: [brief evidence-based summary]
Execution authority: workflow coordinator and approved wave schedule
```

Do not use qualifying language to conceal uncertainty. Do not treat a reviewer's
classification as approval. If implementation reveals that the brief is
incomplete or architecture is needed, stop and report the gap; do not silently
reclassify, re-decompose or bypass the coordinator.
