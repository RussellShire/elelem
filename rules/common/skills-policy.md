# Skills

Use `workflow-coordinator` as the entry point before implementation. It owns
phase transitions and invokes the applicable phase skills. Within an active
workflow, `brainstorming` selects the Planning method; do not invoke it again
before an edit when a validated approved design already covers the work.

The coordinator invokes `implementation-planning` after design approval and
before Wave Planning, including independent blueprint review and separate user
approval of its exact revision. Load the canonical blueprint and task schema in
`skills/_shared/task-briefs.md`; do not duplicate schemas in consumers. Reuse valid
approved implementation instructions for covered corrections, not repeated
Research/Planning. Separate preparation/review/approval skips never imply approval
or supply missing instructions. Follow the evidence and artefact owners for
revision linkage and recovery.

Invoke required skills through `{{INVOKE_SKILL_TOOL}}`; reading their files is
not invocation. Perform their procedures and retain evidence under
`skills/_shared/phase-evidence.md`. Loading a skill or recording a status alone
is not evidence. Only an explicit scoped user instruction may skip a phase or
method; record its source, scope, reason and consequence. A skip is not
approval, a passing result, or a substitute for missing inputs. No complexity
heuristic bypasses a phase.

Use `debugging` by default for bugs, `test-driven-development` for applicable
implementation changes, `requesting-code-review` for applicable reviews and
`verification-before-completion` before success or readiness claims. Final
test pruning is a separate task after cumulative reviewer `PASS`; ordinary task
reviews have no pruning inventory prerequisite. Honour only explicitly scoped
skips without inventing evidence or waiving other gates.

System instructions precede developer instructions, then user instructions,
repository rules and defaults. A scoped user skip cannot override higher
priority instructions or authorise a false claim.

Subagents dispatched for a specific task do not scan for skills. The
coordinator selects phases and supplies applicable source-derived instructions;
workers follow their brief and any explicitly required skill invocation.
