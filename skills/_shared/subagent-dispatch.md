# Subagent Dispatch - Procedural Rules

The workflow coordinator owns dispatch and shared state. These procedures
supplement `../../rules/common/subagents.md`. Read this file before every
dispatch.

## Context isolation

Delegated work starts fresh without inherited parent transcript. Verify the
actual current interface, schema and version against accessible harness evidence.
A documented fresh-child creation interface suffices without an explicit
inheritance parameter. Use an exposed inheritance control when required by the
actual schema; do not invent fields or assume that an omitted field means fresh.
Load `./task-briefs.md` and `./worker-contract.md` before dispatch. Supply the
bounded sufficient inputs, not parent history. Paste the applicable All workers
and role-specific worker-contract sections verbatim into each worker packet,
with the source path and content identity. Include applicable standing rules and
method instructions, exact read/write and side-effect scope, stable inputs and
baseline, authorised skips and structured returns. Missing, inaccessible,
ambiguous or conflicting required sources block affected dispatch; report the
precise source and scope rather than guessing. Links alone do not deliver
instructions. Do not include dispatcher-only routing or prerequisite algorithms
in the worker packet.

Do not reuse accumulated child history as a fresh start or silently fall back to
history forks. Missing required isolation is a capability blocker; obtain
explicit alternative authorisation before continuing under different semantics.
Before recording capability and inheritance evidence, load and apply
`./phase-evidence.md`.

Reuse still-valid isolation or compaction capability checks only while the
harness, schema and configuration remain unchanged. This never waives the
per-dispatch model enumeration and routing checks below.

## Subagent type selection

Before each dispatch, select the most specific available subagent type that
fits the task, including reviewers. Identify the language, framework or domain,
then choose a specialist that fits. Use a general-purpose agent only when no
specialist applies. Record the specialist type and rationale in each task
brief. Default to no nested delegation unless the dispatch explicitly permits
it and the harness supports it.

## Model selection

Preparation phases (Research, Planning, Implementation Planning and Wave Planning)
and independent design, blueprint or readiness reviews require high-capability
reasoning. Select reviewers by scope and capability, not by assuming every review is tiny. Cross-cutting or
design-level review needs a capable reviewer. The implementation configuration
and explicit-alternative rules below do not change preparation or reviewer policy.

### Implementation tiers

Implementation tiers are `low`, `medium` and `high`. Assign the lowest capable
tier with a short task-specific rationale in the brief, before native resolution.
Choose the specialist independently; specialist selection is independent of the
model and must not be changed to obtain a different model.

| Tier | Implementation task signal |
|------|----------------------------|
| low | Bounded mechanical work with explicit requirements |
| medium | Multi-file integration or moderate judgement |
| high | Broad reasoning or difficult implementation decisions |

These signals are guidance, not model names, an availability guarantee or an
automatic phase bypass. Concrete models remain user-configured. Do not infer a
reasoning effort or variant from the tier name. Use native configuration and
the actual exposed dispatch interface, not a new runtime router or framework.

### Native implementation configuration

Resolve only the requested implementation tier using the applicable adapter.
Inspect effective native configuration without exposing secrets, retaining
source/revision and precedence evidence. Configuration choices do not replace
per-dispatch enumeration, capability or explicit-routing checks.

#### OpenCode

Use `providers.<provider>.models.<tier>.modelID`, with exact `low`, `medium` or
`high` model keys. `modelID` is an opaque provider-local API target, including
slashes; do not parse it as a cross-provider redirect or alias chaining.
The explicit selector is `provider/alias[#variant]`, independent of the agent.

`GET /api/config` returns an array of document/directory `Config.Entry` records,
not a merged configuration object. Apply documented scope and precedence before
requiring a unique effective provider+alias identity for the tier. Multiple
layers overriding one identity are not duplicates. Include disabled and inactive
provider/alias candidates when detecting ambiguity; do not silently discard
them to select a convenient remaining provider. Missing, malformed or multiple
effective matches are configuration-resolution faults.

Cross-check the resolved alias against the current catalogue using
`{{MODEL_ENUMERATION}}` and full metadata from `GET /api/model` where needed.
Verify the alias's own capabilities, limits and variants. Do not assume metadata
is inherited from its API target or accept unknown-model fallback metadata as
capability evidence. A `#variant` is not an implementation tier. Verify any
selected variant actually exists and retain it in the explicit selector.

#### Claude Code

Use the user-accepted native slots `low=haiku`, `medium=sonnet`, `high=opus`.
Explicit pins are `ANTHROPIC_DEFAULT_HAIKU_MODEL`,
`ANTHROPIC_DEFAULT_SONNET_MODEL` and `ANTHROPIC_DEFAULT_OPUS_MODEL`, through
supported `settings.env` or process environment. Inspect effective settings and
environment precedence. Explain shared alias effects on other native consumers;
do not modify user settings or invent implementation-only aliases.

Use the actual per-call model enum, not an arbitrary full model ID in a
restricted argument. Check effective alias-family resolution, same-family parent
selection, override settings/mods and restrictions before claiming the pin is
routable. Verify capability and reasoning effort metadata against the actual
version/schema; effort is separate from model selection. Record both the native
call selector and resolved model, rather than assuming a slot proves its target.

#### Codex

Use native `$CODEX_HOME/<tier>.config.toml` files (`low.config.toml`,
`medium.config.toml`, `high.config.toml`) as a declarative source only for explicit
model, reasoning effort and provider compatibility. Since 0.134 these are named
profile files, not `[profiles.<tier>]` tables. This workflow convention is not a
native child tier resolver. Do not pass `--profile` to a child spawn, apply
unrelated profile settings or change the parent session to select a worker.

Classic Codex 0.163 exposes independent `agent_type`, `model` and
`reasoning_effort` fields when model overrides are exposed. V2 field exposure can
be gated; inspect the actual session tool schema and feature/version evidence.
Do not infer availability from version alone, invent a child profile parameter
or merge model/effort into the specialist identifier. Use independent native
fields only when the actual schema supports them. Specialist configuration
overrides and inherited provider conflicts that prevent the requested selection
are blockers, not reasons to change specialist or parent provider. Never assume
a profile switches a child's inherited provider.

### Explicit alternative and task pin

Before readiness review, inspect the live model-override instruction for the
selected dispatch tool. Present both the native selector and its resolved
provider/API target, plus applicable settings, effort or variant and named task
scope. Where that live tool requires an explicit user model request, obtain an
exact model/variant request for each named task and its bounded in-scope
corrections. Configuration, tier selection and design approval are not that
request. Record the request source and scope. Do not impose this requirement on
a harness whose live interface does not require it.

Missing, invalid or unresolvable selected implementation configuration is a
configuration fault. This includes duplicate effective mappings,
disabled/inactive mappings and unavailable mapped targets established during
configuration-resolution checks. A configuration fault blocks affected
dispatch. An alternative, including the current session model, may be used only
when the user explicitly requests that exact selection for the named task or a
specifically identified contingency, and its availability, capability, effort
and explicit specialist routing checks pass. It is not an automatic fallback.
Do not manufacture a variant such as `#high`, drop effort/variant or silently
rely on inheritance.

An inability to inspect configuration or enumerate the environment is missing
evidence, not a configuration fault; block dispatch until the required evidence
is available. A valid but incapable mapping, unsupported required effort,
unsupported route, invocation mismatch and actual execution failure are distinct
blockers, not configuration-fallback opportunities. Do not search for an
arbitrary working model, use omitted-model defaults or silently escalate the
workflow tier. An execution failure does not trigger reselection.

Before recording or consuming an implementation-selection record, load and apply
`./workflow-artifacts.md`. Record selection provenance in the existing task
record using `./task-briefs.md`. In-scope corrections reuse the retained actual
pin with fresh availability, routing and drift checks. An unchanged bounded
correction reuses that retained actual pin; do not reselect the then-current
session model. A target, variant, required effort, selector identity affecting
the route or task-scope change invalidates the affected consent and preflight.
Material configuration drift pauses affected work for renewed checks and
authorisation. A source revision change demonstrated to leave route, constraints
and consent unchanged may reuse existing evidence with that equivalence recorded.
Legacy fallback records remain historical and provide no inferred consent;
validate missing applicable consent before reuse.

These rules govern workflow selection and explicit alternatives only. Existing
external plugins' runtime retries and model switches remain outside this policy
and unchanged. Do not disable or block solely because of a runtime plugin.
Do not claim workflow pins prevent external runtime changes. Distinguish requested
workflow selection from observed effective runtime execution, recording available
harness evidence and any uncertainty. A worker self-report is not routing proof.

### Resolution procedure

Before readiness and before every dispatch:

1. Enumerate the model identifiers exposed by the current environment using
   `{{MODEL_ENUMERATION}}`.
2. For implementation, resolve the native mapping or reuse the retained actual
   task pin as above. For preparation and reviews, select a model by the unchanged
   scope/capability policy. Verify explicit routing to the independent specialist
   using the actual exposed interface; do not invent parameters or schema fields.
3. Never construct an identifier from a pattern or rely on remembered
   availability. Confirm both identifier and routing support.
4. Confirm that the active primary-session model has high-capability reasoning
   before conversational Research or Planning. Skill metadata does not switch
   it. If it is unsuitable, ask the user to switch; do not replace the
   user-facing conversation with an unrequested detached agent.
5. If enumeration, routing or required capability cannot be verified, report
   a blocker. A configuration fault also blocks; an alternative requires the
   exact user request and complete checks above. Never silently inherit, downgrade
   or substitute a model.

### Tier changes and blockers

Use the tier required by the task from the outset. Do not use a low-cost
implementer default for preparation or independent design/readiness reviews.
Do not silently change a workflow-selected tier after failure. For actual
execution failures, report the blocker and wait for explicit resolution; do not
force an unchanged workflow retry or escalate without authorisation. External
runtime plugin recovery remains outside this workflow-selection policy.

| You might think...                              | Reality |
|-------------------------------------------------|---------|
| "I know the naming pattern"                    | Enumerate the environment; never invent an identifier. |
| "This was available before"                     | Confirm current availability and routing for every dispatch. |
| "The examples list it"                         | Examples are not an availability guarantee. |
| "The skill metadata selected this model"        | Metadata does not switch the active primary model. |
| "I can silently use the inherited model instead"| A configuration fault blocks; only an explicitly requested, checked and explicitly routed alternative may proceed. |

## Answering subagent questions

When a subagent asks a question before or during its task, answer it clearly
and completely before allowing it to proceed. Do not rush implementation or
expect a worker to guess missing requirements.

## Process discipline

When coordinating a workflow, do not:

- Skip a review unless the user explicitly skipped that scoped phase; record
  the skip and never present it as a verdict.
- Proceed while an applicable review has unresolved issues affecting the scope
  being considered. Do not hold proven-independent eligible work for findings
  that do not affect it.
- Accept "close enough" where acceptance criteria are unmet.
- Treat an implementer's report as independent review or verification.
- Force an unchanged retry after failure.
- Silently repair worker output in coordinator context; delegate in-scope
  corrections under the existing task contract.
- Start the next wave before current writers settle and the integration
  barrier completes.

## Blockers and recovery

Assess a blocker's impact before any further dispatch, using actual task
dependencies, contracts and resources rather than symptom names. Classify it as:

- Task-local: pause the task and its transitive dependants.
- Shared-contract: pause producers or consumers whose production or consumption
  of an affected contract or resource is invalid, and their downstream
  dependants. An unaffected producer may continue when its authorised work is
  demonstrably valid.
- Global safety: stop all new dispatch when workflow-wide authorisation,
  ownership, isolation or safe operation is invalid.

In the existing coordinator-owned task records, record the blocking condition,
class or unresolved classification, affected tasks/contracts/resources,
evidence, independence rationale and recovery condition.

Continue only already-authorised eligible work within the approved schedule,
with valid prerequisites, approval and readiness, stable inputs, disjoint
ownership including generated and test writes, available resources, relevant
assumptions and evidence. A blocker does not by itself stop demonstrably
unaffected eligible work. Independent progress never permits entering a later
wave early or bypassing review, acceptance, verification or integration
barriers. Broad checks wait until all relevant writers stop.

For unknown impact, pause potentially affected work and continue only where an
unaffected boundary can be demonstrated. If no safe boundary can be established,
provisionally hold all new dispatch until scope is established; do not mislabel
uncertainty as a proven global safety failure.

Cancel affected active work only where safe cancellation is supported and safe.
Otherwise let it settle without claiming it was cancelled or stopped, and do not
automatically accept its output. Unaffected active work and stable-input checks
may continue when they meet the continuation criteria. Preserve unaffected valid
work and evidence. Renew affected assumptions, contracts, approval, readiness,
review and verification under `./phase-evidence.md`. Resume affected work only
after supported resolution is recorded and dependent eligibility is revalidated.

Do not force unchanged retries, silently expand scope, redesign, escalate the
model tier or patch worker code in the coordinator context. Substantive design
changes return to Planning and require renewed user approval. Report independent
progress separately from blocked work. Required unresolved work or barriers
continue to block overall completion; dependent work waits for its prerequisites
and integration checks. Never represent failed or blocked work as successful.
