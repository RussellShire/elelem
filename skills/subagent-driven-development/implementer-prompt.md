# Implementer Worker Prompt Template

## Caller-side routing checklist (non-executable)

Routing and prerequisites are completed by the caller and stay outside the
worker packet. Before constructing a dispatch, load and apply
`../_shared/subagent-dispatch.md`, inspect the live model-override instruction,
and use the completed preflight candidate and applicable exact-request evidence
from the task record. Present the native selector and resolved provider/API
target, settings, required effort or variant, specialist and named task scope.

Where the live tool requires an explicit user model request, verify that the
exact model/variant request covers the named task and bounded in-scope
corrections. Configuration, tier selection and generic approval do not satisfy
that requirement. Missing evidence, unsupported controls, missing required
consent or a configuration fault blocks the affected call.

Immediately before sending, refresh availability, capability, schema, consent
and routing checks. Populate the actual dispatch pin only after those checks.
Compare the invocation's actual model, required effort and specialist controls
with that pin. Do not treat model text in the worker packet or metadata as
routing evidence.

#### OpenCode invocation shape (non-executable)

This labelled shape shows separate documented agent and model arguments. It is
not a command to execute; use only fields verified in the current live schema.
The model value is the authorised native selector, not an API target substituted
into an alias field.

```text
subagent({
  description: "[task description]",
  agent: "[independent specialist]",
  model: "[authorised native selector]",
  prompt: "[complete worker packet]"
})
```

#### Claude Code

Only use model selection when the current Agent tool schema exposes it, and use
an accepted value from its actual model enum. Add a reasoning-effort control
only if the live schema exposes the required control. If a required selection
cannot be expressed, return a blocker rather than inventing an argument.

#### Codex

Use independent `agent_type`, `model` and `reasoning_effort` fields only when
the current session tool schema exposes the required fields. Feature-gated or
unsupported required controls block dispatch. Native tier profile files are
source-only and do not add a child profile argument.

## Worker packet payload (separate from caller routing)

The caller supplies the following content as the complete worker prompt:

### Worker obligations and source identity

Paste the complete All workers and Implementation workers sections from
`../_shared/worker-contract.md` verbatim, including source path and content
identity. Include applicable standing rules and task-specific method
instructions.

### Task brief

Paste the complete approved task brief: requirement mapping, objective,
acceptance criteria, interfaces, dependencies, exclusions, exact allowed
writes, stable reads, prohibited concurrent reads, known side effects, resource
limits, verification commands and expected evidence.

Supply the matching blueprint revision and unit IDs, complete
requirement-to-unit-to-task map, full applicable exact-file instructions,
verified existing anchors versus proposed new paths or symbols, contracts,
invariants, failure cases, ordered per-behaviour test-first steps, test
specifications, planned commands and results, outputs, resources, integration
and acceptance criteria, not links alone. Missing consequential instructions
return `NEEDS_CONTEXT`; do not rediscover architecture or invent behaviour.

### Baseline, context and methods

Supply the immutable task-start HEAD and relevant dirty or untracked contents,
exact identities or snapshots, relevant stable source context, applicable
standing rules, authorised scoped skips with source and consequences, and
method instructions or explicit required skill invocation.

### Return

Require exactly one status, `DONE`, `DONE_WITH_CONCERNS`, `NEEDS_CONTEXT` or
`BLOCKED`, with the structured worker return from the supplied brief. Include
each acceptance criterion and evidence, actual touched paths including reverted
edits and renames, command outputs and exit codes, per-behaviour TDD evidence
where applicable, deferred checks and questions. Do not claim independent
verification or integration.
