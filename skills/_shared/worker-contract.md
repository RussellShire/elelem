# Worker Contract

Dispatchers load this contract before dispatch and paste the applicable sections
verbatim into each worker packet, with source path and content identity. A link
alone does not deliver instructions. Supply only applicable role sections, the
complete bounded task and necessary methods and source context. Routing and
prerequisite algorithms remain with the dispatcher, not the worker packet.

## All workers

Work only within the supplied scope, exact permitted writes, stable reads and
resource limits. Do not read inputs identified as changing concurrently. Do not
infer missing context from session history, broaden scope or rediscover the
architecture. If a required fact, contract, baseline or permission is missing,
return `NEEDS_CONTEXT`; if requirements conflict or safe work is blocked, return
`BLOCKED`. Ask the owning phase for resolution rather than guessing.

Do not write shared workflow state, commit, push, create branches, use worktrees,
perform destructive Git operations, use elevated privileges or delegate unless
the dispatch explicitly permits delegation and the harness supports it.
Authorised read-only Git inspection is permitted. Preserve user work and
pre-existing changes. Follow only supplied scoped skips, with their provenance;
a skipped gate is not evidence.

Return the scope, outcome, exact changed paths including reverted edits and
rename mappings, relevant baseline identities, commands and outputs with exit
status, evidence, questions and blockers to the dispatching owner. A report is
not independent verification or workflow acceptance. Stop writing after handoff.

## Implementation workers

Confirm the supplied immutable task-start baseline and relevant pre-existing
contents before editing. Change only the exact allowed paths and named outputs.
For observable behaviour changes, invoke `test-driven-development` and provide
genuine per-behaviour RED and GREEN evidence unless an explicit scoped TDD skip
is supplied. For authorised non-code work use the specified content or format
checks without fabricating TDD evidence. Run only stable task-local checks;
defer checks that depend on concurrent writers. Do not claim integration.

Before returning, inspect actual changes and confirm every changed path is
allowed. Report uncertainty or unintended changes; do not hide them or silently
fix anything outside scope.

Ordinary implementation does not audit or prune tests. Report touched paths,
not a whole-file inventory. The separately assigned final pruning worker follows
its own audited decisions and recovery contract.

## Read-only workers

Do not edit files or state, run competing writers, or claim to have inspected
material you did not read. Follow the supplied scope and permitted commands;
report evidence, uncertainty and precise source locations. Reviewers assess the
actual supplied change or proposal independently; an implementer report is not
proof. Return the role-specific verdict to the owning phase, not user approval
or a verification claim.
