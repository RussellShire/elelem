---
name: implementation-planning
description: "Refines a validated approved design into a precise file-level blueprint and reconciles independent blueprint review before separate user approval."
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: high
---

# Implementation Planning

## Entry and prerequisites

Only the active coordinator invokes this phase after validating the ordered
upstream evidence and explicit design approval. Require the full validated
approved design, revision and approval source, immutable baseline plus accepted
checkpoints, relevant source identities, constraints, evidence and applicable
exact-source skips. Missing or stale inputs return `NEEDS_CONTEXT` to that owner.

Before preparation, load `../_shared/task-briefs.md`,
load `../_shared/workflow-artifacts.md` and load `../_shared/phase-evidence.md`
using `{{READ_FILE_TOOL}}`, relative to the actually loaded skill. Before review,
load `../_shared/subagent-dispatch.md` and load `../_shared/worker-contract.md`.
Missing or inaccessible sources block the phase, not a checkout/history fallback.
The Implementation blueprint schema is canonical; do not invent another schema.
Apply the existing dispatch capability and routing policy, not a new algorithm.
Confirm high-capability preparation reasoning; metadata does not switch models.
If unsuitable, return a capability blocker, not a silent downgrade or escalation.

## Preparation

1. Perform bounded source inspection against the supplied design and source
   identities. Verify exact existing paths, functions and document headings;
   distinguish proposed new paths and symbols from inspected existing locations.
   Resolve only bounded consequential source gaps; do not repeat Research or
   rediscover the architecture. Return missing behaviour or contracts upstream.
2. Draft a revision using every canonical blueprint field. Map every approved
   requirement into stable cohesive units and explicit dependencies. Supply full
   instructions, contracts, failure cases, ordered test-first steps and test
   specifications, planned commands/results, side effects, resources, integration
   and acceptance. Planned checks are not execution evidence. Do not assign wave
   IDs, implementation tiers or concrete models.
3. Check sufficiency: a worker must identify permitted changes, test sequence
   and escalation boundaries without new consequential architecture or behaviour
   choices. Any unresolved consequential decisions return `NEEDS_CONTEXT` with
   precise missing facts. A stronger worker cannot cure underspecification.

## Independent blueprint review

Use `{{DISPATCH_AGENT_TOOL}}` with `blueprint-reviewer-prompt.md` and an independent
high-capability reviewer selected through the loaded dispatch policy. Supply the
full approved design, full draft and revision, canonical schema, bounded relevant
source context/identities and skips. Deliver the verbatim schema and All workers
and Read-only workers obligations with identities as directed by the prompt.
Do not pass session history or links alone.

Reconcile source-supported findings and re-review corrected drafts, at most
three reviewer dispatches per cycle. Return unresolved material findings after
the third dispatch. `Approved` is valid only for the exact draft most recently
reviewed with that verdict; it is not user approval or wave readiness. For real
behaviour or architecture changes, return to the coordinator for design Planning,
design review and renewed explicit design approval before a revised blueprint.
If review is explicitly skipped, return `SKIPPED` with its exact source, scope,
reason and consequence, never `Approved`. A preparation skip requires equivalent
complete supplied input and skips neither review nor separate approval.

## Return

Return the exact draft content and revision in conversation, with design/source
identities, reconciled review verdict and iteration evidence, findings, questions,
blockers and recommended next action to the coordinator. Do not write shared
state or persist blueprint content; do not seek user approval; do not schedule
or implement. Drafts remain in conversation, never in external staging, including
combined design-and-blueprint documents. The coordinator alone obtains separate
explicit approval of the exact revision and, once writes are permitted, persists
that approved content as `.elelem/workflows/<ticket-or-slug>/blueprint.md` under
the shared artefact contract. Approval grants no exception to write restrictions.
