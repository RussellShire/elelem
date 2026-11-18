# Task Briefs and Worker Reports

Each implementation brief is a self-contained contract derived from the
approved design. The coordinator and wave planner use it to keep workers
bounded, specialised and isolated. Workers do not infer architecture from
repository discovery or inherit conversational context.

## Phase inputs and returns

Apply this boundary contract to phase skills as well as delegated work. Phase
inputs include objective, method, scope and revision, applicable constraints,
required outputs and unresolved decisions. Supply precise artefact sections and
accessible source references, including relevant approval, exact-source skips,
baseline, checkpoint and evidence references. Select only what the next phase
needs; references must be accessible to its actual recipient.

Sufficiency takes precedence over arbitrary size caps. Broad reviews still
receive the full approved design and cumulative changes where required. Preserve
complete implementation briefs and all existing gates. Do not copy the whole
ledger or transcript. If necessary inputs are missing, return `NEEDS_CONTEXT`
rather than guess or rediscover broadly.

Phase returns include scope and revision, outcome, concise findings or proposed
content, evidence provenance, questions and blockers, and a next-action
recommendation. Return to the owning phase or coordinator under the existing
handoff path; a concise report does not replace original evidence or grant
approval. Implementation workers also follow the complete brief and structured
return below.

## Implementation blueprint schema

This is the sole blueprint schema. It refines the approved design into cohesive
implementation units, not scheduled tasks or a competing task-brief schema.
Include all fields, explicitly marking genuine inapplicability with a reason:

- Blueprint revision, approved design revision and approval reference, immutable
  baseline plus ordered accepted checkpoints, and relevant source identities.
- A set of stable unit IDs and a complete requirement-to-unit map, including
  integration, test and error requirements; explicit dependency edges between units.
- For each unit: exact create/modify paths, verified existing functions or document
  headings with source identities, and distinctly labelled proposed new paths and
  symbols. Never present a proposed location as already inspected.
- Required stable reads, bounded context, interfaces and invariants, behavioural
  failure cases, exclusions and complete applicable implementation instructions. Include
  bounded pseudocode only where tricky logic needs it, not near-complete source.
- Ordered implementation and ordered per-behaviour test-first steps, or authorised
  non-code checks with skip provenance; test paths, scenarios, assertions and
  commands and expected results labelled planned, never execution evidence.
- Known generated, formatter and test outputs, side effects and resources,
  conflicts and isolation needs, integration steps and acceptance criteria.
- Assumptions, unresolved consequential decisions and blockers. Return
  `NEEDS_CONTEXT` for missing paths, behaviour or contracts rather than guessed
  precision or assigning a stronger worker to compensate.

No wave IDs or concrete model assignments belong here. Wave Planning owns task
packaging, scheduling and implementation-tier selection. A sufficient blueprint
lets workers identify permitted changes, test sequence and escalation boundaries
without making new consequential architecture or behaviour decisions. Instructions
must be complete enough to deliver self-contained applicable steps in task briefs,
not links alone. Unresolved consequential decisions block downstream work.

## Proposed design proposal

Every Planning method returns one self-contained proposed design with these
sections:

- Goal
- Requirements
- Exclusions
- Architecture
- Components
- Interfaces
- Data flow
- Error handling and failure behaviour
- Tests and verification
- Assumptions and supporting evidence references
- Unresolved decisions or questions

Include every section, marking it explicitly as not applicable when appropriate.
Use verified research and approved external inputs as evidence, distinguish
facts from assumptions and user decisions, and carry unresolved points forward.
This is a proposal for independent Design Review, not an approved plan. Only the
coordinator obtains explicit final user approval and persists the approved
design.

## Required task brief

Every task brief records:

- Stable task and wave identifiers, objective and specialist subagent type.
- The matching blueprint revision and unit IDs, requirement-to-unit-to-task
  mapping, and complete applicable instructions, exact-file steps and test
  sequence from those units, not links alone. Use this task schema, not a second
  blueprint-derived task schema.
- Requirement mapping, including integration, test and error-handling needs.
- Bounded context, relevant contracts, interfaces, assumptions and exclusions.
- Exact allowed write paths, plus known formatter, generator, build and test
  outputs. Anything not named is not an allowed write.
- Stable read paths and files that must not be read while concurrent writers
  can change them.
- Dependency edges, resource needs and possible conflicts: ports, databases,
  fixtures, temporary outputs or global tools.
- Acceptance criteria and task-local verification commands with expected
  evidence.
- Required implementation tier (`low`, `medium` or `high`) and short lowest-capable
  tier rationale, separate from the independent specialist rationale. Preparation
  and reviewer selection retain their scope/capability policy.
- Before readiness, record the preflight candidate: configured source/revision,
  requested tier and rationale, independent specialist, native selector,
  resolved provider/API target, reasoning effort or variant, and preflight
  revision. Record effort or variant as explicitly absent when inapplicable.
  Include current tool schema, catalogue/capability and explicit-routing
  evidence. Distinguish the native selector from an opaque API target.
- Record whether the live tool requires an exact user model request. When
  required, retain the request source and exact named task/correction scope; when
  not required, record the inspected interface evidence for that conclusion.
  Preserve fallback flag, reason, warning and source as historical or explicitly
  authorised alternative context only, never as authority for automatic use.
- The actual dispatch pin is distinct from the preflight candidate. Populate it
  only after final availability, capability, consent and routing checks, and
  confirmation that required controls are supported, immediately before the
  call. Compare the actual invocation settings with that pin before sending.
  Retain the actual submitted call arguments or a captured tool-call evidence
  reference. Include model, effort/variant and specialist controls as actually
  submitted, with explicit unsupported or absent evidence where relevant. Keep
  this invocation evidence distinct from the preflight candidate, authorised
  pin and observed runtime evidence. Keep observed runtime evidence and
  uncertainty separate from both candidate and pin. External runtime retries
  and switches remain outside the pin.
- In-scope corrections consume the retained actual pin with fresh availability,
  routing and drift checks, not a newly selected current-session model. Preserve
  original selection provenance and require explicit authorisation when a
  material route, required effort or consent-scope change invalidates it.
  Historical pins, including fallback records, do not prove missing consent.

The complete requirement map must cover every approved requirement. Same-wave
tasks have disjoint writes and may not read one another's changing files.
Shared reads are allowed only when those inputs remain stable for the full
wave. Integration work is a task, not an implicit assumption.
Prefer cohesive bounded tasks that permit multiple genuine sequential RED/GREEN cycles
without splitting work artificially or changing approved architecture.

## Dispatch constraints

Before dispatch, load and apply `subagent-dispatch.md`. Supply the complete
brief, necessary stable source context and applicable worker contract sections
as directed there. Workers return through their owning phase and do not modify
shared workflow state.

## Structured worker return

The worker returns exactly one outcome and enough evidence to act on it:

- `DONE`: acceptance criteria met; list changed paths, commands and outputs.
- `DONE_WITH_CONCERNS`: bounded work returned, with unresolved concerns and
  their impact identified.
- `NEEDS_CONTEXT`: name the missing fact or contract; do not guess or expand
  the task.
- `BLOCKED`: state the blocking condition, attempted safe actions and required
  user or coordinator decision.

Ordinary workers report exact actual changed paths and rename mappings,
including intermediate or reverted edits and reviewer corrections, together
with baseline references, checks and per-behaviour TDD evidence. They do not
prepare whole-file test/case inventories or pruning evidence for task review.
The coordinator retains that history for one final union inventory after
cumulative final reviewer `PASS`. The separate final pruning brief supplies
the full frozen union and safety evidence under `test-pruning.md`; it is not an
ordinary implementation handoff requirement.

Before recording returned task state, load and apply `workflow-artifacts.md`.
Independent review and verification remain required by default. Task-local
checks may run during other work only on stable inputs; broad verification
waits until all relevant writers stop.

## Blockers and corrections

Load and apply `subagent-dispatch.md` to classify blockers, contain their
impact and resume eligible work. Return missing requirements or architecture to
the coordinator; do not silently expand scope or change models.
