---
name: wave-planning
description: "Packages an approved file-level blueprint into bounded tasks and safe waves, with independent readiness review by default before dispatch."
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: high
---

# Wave Planning

Package an explicitly approved file-level blueprint, linked to its approved
design, into complete bounded tasks and safe execution waves. Conversational
planning and readiness review require
high-capability reasoning. Verify that the active primary-session model is
appropriate before conversational planning. Metadata does not switch the
active model. If unsuitable, stop and ask the user to switch models; do not
switch silently. Record the confirmed model and reuse that confirmation while
it remains active, without prompting again. Before delegated preparation or
reviewer selection, load and apply `../_shared/subagent-dispatch.md`. Preparation
and reviewer policy is unchanged by implementation configuration or fallback;
missing required capability remains a blocker.

## Preconditions

Require an approved plan revision with its user approval source reference and
the matching approved blueprint revision with its separate blueprint approval
source. Apply separately recorded scoped skips only with equivalent complete
supplied input and exact provenance under `../_shared/phase-evidence.md`.
Load and apply `../_shared/phase-evidence.md` to validate preparation, independent
blueprint review and separate approval in order, including matching design and
source identities, original baseline and ordered accepted checkpoints. A review
verdict, single-task or readiness skip cannot supply missing instructions.
Before checking workflow baseline and approval validity, load and apply
`../_shared/workflow-artifacts.md`. Missing or stale inputs block planning.
Do not infer approval from a review verdict, silence, prior conversation or
implementation request.
Return missing or stale blueprint evidence or incomplete instructions as
`NEEDS_CONTEXT` to the coordinator before packaging or readiness review.

## Decomposition

Before packaging the blueprint, load and apply `../_shared/task-briefs.md`.
Preserve and package cohesive blueprint units into complete task contracts with
a requirement-to-unit-to-task map, matching revision and unit IDs, and complete
applicable steps, tests, failure cases and acceptance criteria. Work without
rediscovering implementation instructions. Map every approved requirement to
one or more tasks, including integration, tests, error cases and final
verification requirements. Deliver full applicable instructions, not links alone.
Capture the complete task contract. Define task dependencies as a
directed acyclic graph; contracts and foundations precede consumers, and
integration is explicit work. One-task waves are valid. Do not impose a fixed
file-count limit or ask bounded workers to discover architecture.

Prefer cohesive bounded tasks that allow multiple genuine sequential RED/GREEN cycles
per worker. Do not manufacture splits or unapproved architecture to increase width.

For each task, name exact allowed writes and known formatter, generator, build
and test outputs; stable reads; interfaces and assumptions; dependencies;
acceptance criteria; verification commands; and specialist type with its own
rationale, independent of the model. Assign the lowest capable implementation tier
(`low`, `medium` or `high`) with a short task-specific rationale. Include resource
constraints such as ports, databases, fixtures,
temporary outputs and global tools. Same-wave writes must not overlap. A task
must not read a file another concurrent task can change. Shared stable reads
are allowed. Do not schedule tasks whose external resources conflict.

After implementation tiers and independent specialists are assigned, resolve
each task's concrete preflight candidate through `../_shared/subagent-dispatch.md`
before readiness review. Inspect the live model-override instruction, verify
native selector, resolved target, schema, availability, capability, effort or
variant and explicit routing, and obtain any required exact user model request
for its named task and bounded corrections. Record the preflight candidate,
request evidence or inspected evidence that a request is not required, and
preflight revision through `../_shared/task-briefs.md`. This is not the actual
dispatch pin; do not pin until final checks immediately before the call.
Configuration faults, missing evidence, unsupported controls or missing required
consent block affected tasks. A review skip cannot waive preflight. Do not choose
concrete models in the approved blueprint, infer reasoning effort from a tier,
or change specialist to obtain a model.

Assign stable wave identifiers and cap concurrency at verified harness and
resource capacity. If capacity cannot be verified, report the limitation and
do not assume parallelism. Skipping wave planning permits one bounded,
complete, fully specified task only; do not improvise a wave plan or parallel
dispatch.

Place ready independent tasks in the earliest safe wave up to verified harness
and resource capacity. Record concrete reasons for serialisation, including
concurrency one, from dependencies, ownership, stable reads or resource limits.

## Readiness review and explicit skips

Before validating or reviewing readiness, load and apply
`../_shared/wave-readiness.md`. Wave planning remains required unless the user
explicitly skips that phase. Skipping only the independent readiness review does
not skip wave planning.
The planner must still complete and validate the requirement map, task briefs,
dependency graph, ownership, stable inputs, resource model, capacity and
verification barriers described above and in `../_shared/wave-readiness.md`.
Missing or unknown critical inputs, unsafe ownership or resource conflicts, and
unverified capacity remain blockers, not matters a skip can waive.

By default, before any dispatch, obtain an independent high-capability review
of the full waves, task briefs, dependency graph and resource model. This review
is separate from design review and does not require another user prompt when it
only changes scheduling. Use `../_shared/wave-readiness.md`. If the user
explicitly authorised skipping only this readiness review, do not invoke a
reviewer or claim `READY`; record the review as `SKIPPED` with the authorisation,
scope, reason and consequence. The planning record must make clear that the
schedule is planner-completed but has no independent readiness verdict. A skip
does not approve a design or blueprint or authorise changes to either. Return
instruction gaps to Implementation Planning through the coordinator for review
and separate blueprint approval. Return real behaviour/architecture gaps to
design Planning and affected design/blueprint gates. Scheduling-only corrections
stay here and renew readiness, not blueprint approval. Do not turn an
architectural gap into an unapproved task.

Return the proposed `waves.md` contents and revision, the readiness record
(independent verdict `READY` or `GAPS`, or authorised review status
`SKIPPED`), and any scheduling-only adjustments to the coordinator for
persistence. The coordinator alone writes shared workflow files. `READY` may
only be recorded when returned by the independent reviewer; do not convert
planner checks or a skip into that verdict. Do not dispatch implementation
agents; the coordinator owns transitions and execution hand-off.

The readiness reviewer returns the verdict and findings to this Wave Planning
procedure for reconciliation. Return the reconciled schedule, readiness result
and blockers to the coordinator. This ends Wave Planning, not the overall
workflow. The coordinator records the schedule and next action in existing
`workflow.md` and proceeds to execution without routine prompting only after
the approved-plan, approved-blueprint, readiness or explicitly scoped skip,
capability and safety gates are satisfied. A `SKIPPED` review is not `READY`.
