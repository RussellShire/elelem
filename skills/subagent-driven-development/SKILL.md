---
name: subagent-driven-development
description: Executes approved workflow waves using bounded specialist workers, default independent reviews and verification barriers.
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: high
---

# Subagent-Driven Development

Execute an approved plan through complete, safe waves. By default, waves have
an independent `READY` review before dispatch. This skill is an
execution phase, not an architecture or decomposition phase. The workflow
coordinator owns phase transitions and shared workflow state. See
`../workflow-coordinator/SKILL.md`, `../_shared/workflow-artifacts.md`,
`../_shared/task-briefs.md`, `../_shared/wave-readiness.md`,
`../_shared/subagent-dispatch.md`, and `../../rules/common/subagents.md`.

## Entry and prerequisites

Before dispatch or reuse, load and apply `../_shared/phase-evidence.md` to ordered
upstream evidence. Return upstream gaps to the coordinator; approval and a
readiness label cannot repair omitted procedures or authorise fake backfill.

If there is no active valid workflow, invoke `workflow-coordinator` through
`{{INVOKE_SKILL_TOOL}}`; do not start an independent execution pipeline. Before
validating approval or the baseline, load and apply
`../_shared/workflow-artifacts.md`. Before consuming task briefs, load and apply
`../_shared/task-briefs.md`. Require
an explicitly user-approved plan revision and completed wave planning. By
default, require an independent `READY` verdict. Before accepting a readiness
verdict or a readiness-review skip, load and apply
`../_shared/wave-readiness.md`. If the user explicitly
authorised skipping only the readiness review, accept the recorded scoped skip
instead, but independently confirm that the persisted schedule and task briefs
are complete and satisfy the wave ownership, dependency, resource, input and
capacity constraints in `../_shared/wave-readiness.md`. A skipped review is not
a `READY` verdict. Confirm approval and the applicable planning record remain
valid against the recorded baseline. Never infer design approval from a review
verdict, skip or silence.

If the user explicitly skipped wave planning, accept only one complete,
fully specified task brief with exact scope and inputs. Do not invent tasks,
decompose architecture, or improvise concurrency. An explicit skip of any other
phase must have recorded scope, reason and consequence. A skipped review is not
approval; skipped checks must never be described as passed or verified. A
skip-authorised task may be accepted for explicitly authorised downstream work
without being marked verified, but only after checking that its outputs are
safe and sufficient for that dependent task. A review, check or wave skip does
not waive dependent safety requirements automatically; unknown critical inputs
block dispatch.

All workflow phases run by default. Never infer that a small task authorises
skipping a phase. Complexity triage may advise task sizing or classification,
but it never routes execution or bypasses a phase. `fast-path-implementation`
is only a compatibility entry point for a single task explicitly scheduled by
the coordinator, and follows this executor's reviews and checks.

Ask once for Git preference only if the coordinator has not recorded it. The
default is to leave changes uncommitted. Do not ask for routine task or wave
approvals or commit prompts. If the recorded preference is ask-before-commit,
defer commits and report that preference rather than interrupting execution.
Only the coordinator may commit, and only according to the recorded preference
after the relevant checks; workers may perform authorised read-only Git
inspection but no Git mutations. Never push.

## Consume approved waves

Use the persisted task briefs and dependency graph as the execution contract;
do not recreate or broaden them. Each brief defines exact allowed writes,
stable reads, prohibited concurrent reads, dependencies, resources, acceptance
criteria, verification commands, independent specialist type and rationale, and
lowest-capable implementation tier (`low`, `medium` or `high`) with rationale.
Same-wave tasks must have disjoint writes and must not consume another task's changing
files or results. Stable shared reads are allowed. Respect resource constraints
and verified harness concurrency. Before each dispatch, load and apply
`../_shared/subagent-dispatch.md` for isolation, specialist selection, native
model resolution, retained pins and drift checks. The coordinator records the
nested selection record defined in `../_shared/task-briefs.md` before dispatch.
Do not replace its routing procedure or infer runtime execution from the pin.

Load `../_shared/worker-contract.md` before dispatch. Deliver the applicable
sections verbatim with source identity, complete brief and required stable source
and method context under `../_shared/subagent-dispatch.md`. Workers return
structured results using `../_shared/task-briefs.md`.

Dispatch independent tasks in a wave in the same turn, or use only a background
mechanism whose availability and completion semantics are verified by the
harness. Do not invent a dispatch tool or assume that sequential calls are
concurrent. If concurrency is unavailable, report the limitation and follow
the approved schedule only where serial execution is valid; do not silently
substitute a different plan.

Before the first RED step, the coordinator records or validates the immutable
task-start HEAD and relevant dirty or untracked contents in `workflow.md`.
Preserve that baseline separately from later task and audit snapshots.

## Touched-path history

Ordinary implementation tasks return changed paths and rename mappings, not
whole-file test inventories. The coordinator accumulates actual touched-path
history across tasks and reviewer corrections, including reverted edits and
renames, against the immutable workflow baseline and task checkpoints. Task
review and task verification have no pruning-audit prerequisite. Defer the one
whole-file inventory and audit to the final task below.

## Task lifecycle and barriers

For every task, independently review the actual changes against its brief and
quality requirements by default. Use `./reviewer-prompt.md` and the current
dispatch procedure. If the user explicitly skipped a task review, do not
dispatch a reviewer for that scope; record the review as `SKIPPED`, including
its authorisation, scope and consequence. Do not imply a review verdict or
approval. Otherwise, review outcomes are not user approval. Critical and
important issues must be resolved before completion; delegate in-scope
corrections to a worker within the same boundaries, then re-review. A missing
requirement, contract or architecture decision is a blocker to return to
planning, not a prompt to silently redesign.

Batch related in-scope review corrections within the approved task boundaries;
retain independent re-review and fresh task checks after the batch. Before
correction dispatch, load and apply `../_shared/subagent-dispatch.md` for the
retained implementation pin and current drift checks.

After review or its recorded skip, the orchestrator reads the actual changed
paths and evidence, then runs fresh task verification by default. Do not trust
a worker's report alone. Honour an explicitly authorised verification skip only
for its recorded scope, and record that verification as `SKIPPED` with its
authorisation and consequence. Run all other applicable checks; a scoped skip
does not waive checks outside its scope. Task-local checks may run while other
tasks are active only when every input is known stable. Freeze the task's scope
and files while checking them. Do not run broad checks while any relevant
writer remains active.
Keep task lifecycle status separate from review and verification results. A task
with an authorised skipped review or check may be accepted for explicitly
authorised downstream work as `accepted-unverified`, never `verified` or
`integrated` while the required gate remains skipped. Later actual gates may
establish those statuses under `../_shared/workflow-artifacts.md`.

Report verified task progress as it becomes available, without routine approval
prompts. If a check requires outputs from other tasks, defer it explicitly until
the safe wave barrier; do not label it passed early. Complete the wave's
integration checks after all its writers stop. Do not dispatch a dependent wave
until its prerequisites and required barrier checks are satisfied. Preserve
the coordinator's task status and evidence records; workers do not write them.

## TDD and worker evidence

For code that changes observable behaviour, require the worker to invoke
`test-driven-development` through `{{INVOKE_SKILL_TOOL}}` and provide the
RED-to-GREEN evidence described in `../test-driven-development/SKILL.md` and
`./implementer-prompt.md` by default. Require a genuine failing test before
production code, its expected failure, and a fresh passing run afterward. Do
not accept "tests pass" as RED evidence. Honour an explicit, scoped user TDD
skip, record its scope and consequence, and report the TDD evidence as skipped,
not passed. The TDD skip does not waive other checks outside its scope.
User-authorised documentation or configuration work may use the
explicit non-code exception in the task brief; do not invent tests or fabricate
TDD evidence for it. Pure refactors retain existing checks unless explicitly
skipped by the user.

## Blockers and scope control

Workers report `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT` or `BLOCKED`. Read
the actual changes and verify evidence for every returned result. Supply missing
authorised context rather than guessing. Before acting on a blocker or review
finding, load and apply `../_shared/subagent-dispatch.md` for containment,
continuation and recovery. Return inadequate plans or architecture to the
coordinator for user-authorised resolution; do not expand scope or patch worker
output in the orchestrator context.

## Final feature review and verification

After all requested tasks, task reviews/checks and integration barriers are resolved, invoke
`requesting-code-review` for the cumulative, current uncommitted changes,
including tracked and untracked files, by default. If the user explicitly
skipped final review, record that scoped skip and do not imply a review verdict
or approval. The review must inspect actual changes; `BASE..HEAD` alone is
insufficient when work is uncommitted. Resolve critical and important findings
by delegating within approved task boundaries and repeat the relevant review
and checks. Record minor findings for the user.

Before deciding whether to enter pruning, load and apply the cumulative review
adapter in `../_shared/code-review.md` to the raw cumulative result and current
revision. Retain its result, raw review and provenance; do not substitute a
review verdict from another phase.

After the cumulative final reviewer result is validated as `PASS`, invoke `test-pruning`
through `{{INVOKE_SKILL_TOOL}}` as one separate final review-phase task. User
approval is not this trigger. The invoked skill loads and applies
`../_shared/test-pruning.md`; the coordinator alone owns audit dispatch and
state, with no nested audit dispatch. If final review was skipped, require
explicit sequencing authorisation under the helper before pruning; a skip is
not a `PASS`. A pruning skip permits no pruning edits and waives neither review
nor verification.

Only actual pruning edits require an independent bounded pruning-delta review
of those edits and affected coverage. A no-change audit needs none. Resolve
in-scope findings within that delta; substantive corrections return to the
proper implementation/review boundary. Do not automatically repeat cumulative
review or restart pruning. Use targeted invalidation and evidence recovery
under the helper when necessary, not a review-prune loop.

Run final verification after the last pruning edit and review correction.
Invoke `verification-before-completion` against the full current state by
default. Honour an explicitly authorised final verification skip only for its
recorded scope, and record it as `SKIPPED`; do not imply that checks passed or
verification occurred. Run all other applicable checks and report the skipped
scope as unverified. Do not label the full workflow verified while a required
final check is skipped. Run the project's required complete checks only after
relevant writers stop. Keep final review, final verification and any explicitly
skipped gates distinct. Report task and wave status, actual changed paths,
review findings, commands and outputs,
TDD evidence where applicable, deferred checks, and any authorised skips and
their consequences. Follow the coordinator's clean-up phase separately.

Persisted workflow state is canonical. When the harness supports it, the
coordinator mirrors task progress through `{{TASK_TRACKER_TOOL}}`; the mirror is
for user-visible progress only and never becomes a separate source of truth.
Do not invent tracker parameters or let workers update the tracker.

### Executor handoff

Workers return reports and evidence through the executor. Reconcile each
worker's scope, outcome, changed paths, checks, questions and blockers against
its brief; workers do not hand workflow state directly to the coordinator.
The executor validates the returned scope, outcome and evidence before
continuing safe task-local checks with stable inputs while other workers run.
Respect task dependencies and wave barriers, required independent reviews and
verification before returning the executor's reconciled result to the active
coordinator. A worker's "stop after handoff" ends that worker task, not the
overall workflow. The coordinator validates the executor handoff, records the
result and next action in existing `workflow.md`, then proceeds without routine
prompting when no gate or blocker requires a pause.

## Prompt templates

- `./implementer-prompt.md`: bounded worker prompt for approved tasks.
- `./reviewer-prompt.md`: independent per-task review prompt, including for a
  single task invoked through the fast-path compatibility entry point.
