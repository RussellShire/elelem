---
name: brainstorming-committee
description: "Develops a proposed design through explicitly selected committee deliberation by three perspectives."
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: high
---

# Brainstorming (Committee)

Hands-off Planning method, selected explicitly by the user. Three perspectives deliberate on consequential design decisions and return a proposed design. The coordinator owns independent review, explicit final approval and later workflow phases.

The coordinator verifies active-model capability and owns lifecycle. Committee preparation and review require high-capability reasoning. Before dispatch, read `../_shared/subagent-dispatch.md` and follow its model-resolution and routing requirements. Metadata does not switch a model. Never silently use a lower-cost tier for preparation or review.

## Load Required Files First

Before using their contracts, read these files using `{{READ_FILE_TOOL}}`
relative to the directory of the actually loaded Committee skill:

- Read `../_shared/task-briefs.md` for the proposed-design schema
- Read `committee-member-prompt.md` for the sole role and type mapping and prompt templates
- Read `../_shared/subagent-dispatch.md` for dispatch procedure

If a required file is missing or inaccessible, return a blocker to the
coordinator. Do not use a checkout, history or link-only fallback. Do not repeat
Research. Use coordinator-supplied findings and approved external inputs. For a
bounded consequential gap not covered by Research, read
`../_shared/project-context-discovery.md` from this skill installation and
follow its repository-first procedure and conditional Confluence activation.

## Preconditions

- This skill runs only in the coordinator's active Planning phase. If invoked directly without an active workflow, invoke `workflow-coordinator`, preserve committee as the requested method and stop. Do not start another workflow or invoke the router recursively.
- If a coordinator is active but Planning is not the current phase, return control to it without continuing this skill.
- The user must explicitly select committee mode. Do not select it automatically based on task size or decision count. Respect actual harness plan-mode restrictions; keep drafts in conversation or coordinator-authorised staging and do not silently switch models.

## Procedure

1. **Orient to the confirmed brief.** Use the user-confirmed goal, coordinator-supplied research record, approved external inputs, assumptions and unresolved questions. If a material gap blocks committee work, return it to the coordinator; do not repeat broad discovery.
2. **Identify decisions.** Group consequential choices such as architecture, interfaces, data flow, errors and verification. Do not impose a subsystem-count limit or automatically split a cohesive request into unrelated tickets. If breadth creates genuine uncertainty, flag it to the coordinator for user discussion.
3. **Deliberate.** For each decision group, dispatch all three members concurrently in one message using `{{DISPATCH_AGENT_TOOL}}` and the templates in `committee-member-prompt.md`. Use the types in its canonical role mapping and verify high-capability dispatch through the shared procedure. When a specialised type is unavailable, inspect the dispatch tool's currently exposed type options and select an available type whose description indicates broad general-purpose capability. Do not assume a type identifier. If no suitable available type exists, return a blocker to the coordinator and do not dispatch. Each member receives the same bounded brief, relevant stable evidence, decisions and prior consensus, never full session history. Members return proposals, reasoning, concerns and unresolved questions, not user approval.
4. **Synthesise consensus.** Apply the rules below, retaining material dissent and concerns. Use at most one tiebreaking round per decision. If it does not resolve the issue, return the unresolved choice to the coordinator for the user's decision.
5. **Assemble a proposed design.** Use the complete proposal schema in `../_shared/task-briefs.md`. Summarise material splits and risks without exposing deliberation transcripts.
6. **Return to the coordinator.** Return the consolidated proposal, unresolved decisions and substantive uncertainty. Do not invoke design review, seek final user approval, persist an approved plan, create tickets or begin implementation.

Committee members and any tiebreaker return their results to this Planning
procedure for reconciliation. Return the proposal to the coordinator after
reconciliation. This ends the committee procedure only; the proposal does not
approve or advance the workflow.

## Committee Roles

Dispatch the Pragmatist, Architect and Advocate using the sole role and type
mapping in `committee-member-prompt.md`. Resolve model routing through
`../_shared/subagent-dispatch.md` before dispatch.

## Synthesising Consensus

| Outcome             | Action                                                                            |
|---------------------|-----------------------------------------------------------------------------------|
| All three agree     | Recommend that approach, retaining any material concern.                         |
| Two of three agree  | Recommend the majority view and record substantive dissent.                      |
| All three disagree  | Run one tiebreaking round (see below).                                            |

Concerns flagged by two or more members **MUST** be addressed in the design, even if the specific recommendation differs.

## Tiebreaking

If a round produces irreconcilable disagreement (not just preference differences), dispatch at most one tiebreaking round. Pass all three positions to a single high-capability reviewer, resolved through the shared dispatch procedure. The tiebreaking template is in `committee-member-prompt.md`. If it does not converge, return the unresolved decision to the coordinator for the user's decision.

## Working in Existing Codebases

- Follow existing patterns. Include only changes needed for the requested outcome.
- **MUST NOT** propose unrelated refactoring. Committee members are explicitly instructed in their prompts to stay within scope; the synthesiser must reject any recommendation that exceeds it.

## Common Mistakes

| Mistake                                                                | Why it is wrong                                                                                                                |
|------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------|
| Asking routine questions during deliberation                           | Return material gaps or user choices to the coordinator for targeted discussion. |
| Dispatching committee members sequentially                             | They **MUST** run concurrently. One message, three tool calls.                                                                 |
| Passing session history to committee members                           | Violates context isolation from `../../rules/common/subagents.md`. Pass the brief, the codebase context, the decisions, and prior consensus only. |
| Assuming a subagent type or model is available                          | Verify its availability and routing through the shared dispatch procedure.          |
| Showing the user the full deliberation transcripts                     | The user wants the design, not the process. Surface only the result, splits, and flagged risks.                                |
| Treating committee consensus as review or approval | The coordinator performs independent review and obtains explicit user approval. |
| Running more than one tiebreaking round                                | If one tiebreaker cannot converge, the decision is genuinely unresolved and belongs to the user.                               |
| Letting the synthesiser quietly drop a concern flagged by two members  | Two members flagging a concern is signal. Address it in the design or the round did not really converge.                       |
