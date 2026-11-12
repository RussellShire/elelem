# Workflow

Use `workflow-coordinator` before implementation-oriented proposals and
implementation. Research hypotheses and options remain permitted. The
coordinator owns phase transitions and shared state; phase skills own their
procedures. An active workflow with a validated approved design does not restart
Planning before each edit.

Every workflow phase runs by default. Only an explicit scoped user instruction
may skip a phase or method; record its source, scope, reason and consequence.
A skip is not approval or evidence and does not supply missing inputs. Never
infer a skip from complexity, urgency or familiarity. Validate prior research,
design and evidence against their source, revision, scope and assumptions.
Explicit user approval of the current design is required before implementation,
separate from any review verdict. Substantive design changes require renewed
approval.

Research and Planning are conversational by default and require a capable
primary-session model. Reviews are independent by default. Implementation
uses an approved schedule with independent readiness review unless explicitly
skipped; a skipped Wave Planning phase permits one complete bounded task, not
improvised concurrency. Preserve task ownership, stable inputs, resource
isolation, original baselines and unrelated user work. A worker report is not
independent review or verification. Do not label skipped checks or reviews as
passed; accepted work with a required skipped gate remains unverified.

The coordinator validates each phase or task handoff and continues eligible work
without routine approvals. Findings and blockers pause affected work and its
dependants, not demonstrably independent eligible work; wave barriers still
apply. Unknown impact pauses potentially affected work, and a proven global
safety failure stops new dispatch. Do not silently expand scope or change models.

Store necessary workflow artefacts under `.elelem/workflows/<ticket-or-slug>/`.
Before creating them, ensure root `.gitignore` contains the exact `.elelem/`
entry and verify the intended path is ignored. Preserve existing content and
user work. Respect plan-mode write permissions. The coordinator alone owns shared
workflow state and applies `skills/_shared/workflow-artifacts.md` for registry,
baselines, resume and safe clean-up. Clean up only registered workflow-created
paths; never delete unrelated or pre-existing files. Leave changes uncommitted by
default and never push.

Final cumulative review, the separate final test-pruning task, final
verification and clean-up are distinct gates. Pruning follows cumulative reviewer
`PASS`, not user approval. If cumulative review is skipped, pruning requires
explicit sequencing authorisation; a skip is not `PASS`. A pruning skip permits
no pruning removals and waives no other gate. Final verification follows the
last edit and review correction. Never claim a skipped or unsuccessful check
passed.
