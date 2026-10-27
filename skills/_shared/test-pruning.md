# Test Pruning

This procedure governs audits and supported removal of tests from task-touched
test-bearing files. The coordinator owns audit dispatch, snapshots, workflow
state, and recovery. The implementation worker never dispatches an auditor,
delegates an audit, or substitutes a self-audit. The Meaningful Assertions
section in `rules/common/testing.md` is the sole canonical value rule. Retrieve
its authoritative text as described below and inject it into the auditor prompt
verbatim; do not duplicate or paraphrase the rule here.

## Retrieve the canonical rule

The coordinator identifies the active harness before preparing an audit
dispatch. For Claude Code and OpenCode, read `../../rules/common/testing.md`
relative to this helper. That locator resolves from the source tree and from
their installed directory layouts. Do not substitute a different checkout or
an uninstalled copy when the active installed rule is available.

For Codex, use the active elelem-managed `AGENTS.md` block and its
`## rules/common/testing.md` entry, as identified by the current instruction
context. Do not use a guessed path or the source checkout. Within the exact
`<!-- elelem:codex:start -->` and `<!-- elelem:codex:end -->` block, locate the
unique `## rules/common/testing.md` rule entry, then locate its unique
`## Meaningful Assertions` section. Do not use a similarly named heading
elsewhere in `AGENTS.md` or another active instruction file.

From the selected rule entry, copy only the complete Meaningful Assertions
section verbatim. Its boundaries are the `## Meaningful Assertions` heading
through the line immediately before the next level-two heading, or before a
higher-level heading if one comes first. For Codex, first bound the rule entry
from `## rules/common/testing.md` to the next `## rules/` entry or the end of
the elelem-managed block, then apply the same section boundaries. Include no
surrounding rule sections, generated labels, or commentary.

Confirm the harness source, managed-block and rule-entry boundaries where
applicable, and exactly one matching section before dispatch. If the
authoritative full section is unavailable, cannot be retrieved, has ambiguous
or duplicate boundaries, or cannot be copied exactly, block the audit before
dispatch. Do not fall back to paraphrase, memory, another harness's source, or
the repository source when Codex's active managed rule is unavailable.

## Scope and entry conditions

Before the first RED step, the coordinator records in `workflow.md` the
immutable task-start HEAD and relevant working-tree state, including exact
contents or equivalent snapshots of relevant pre-existing dirty and untracked
paths. An existing supplied baseline may be used only after validating its
source, revision, scope, and current contents. Never move or replace the
original baseline with a later task checkpoint.

After implementation work stops, derive scope from the worker's actual changed
paths within the task's allowed writes. Do not use a broad HEAD diff to select
tests. Inventory every test and parameterised case in each test-bearing file
the task actually touched, including older tests and cases the worker did not
add. Record stable test and case identifiers. If no test-bearing file was
touched, record the audit as `NOT APPLICABLE` with the empty scope and do not
invent an audit or evidence.

A TDD-only skip does not waive this audit. A TDD skip, audit skip, and check
skip are separate decisions. Only explicit user authorisation can skip the
audit or a check. Record each skip's exact scope, reason, and consequence in
`workflow.md`. A skipped audit is not evidence and permits no test removals.

## Freeze inputs and establish the pre-prune state

The coordinator must ensure that no relevant writer is active. If an audit
input may change during another task, defer the audit to a safe wave barrier.
Never rely on tests owned or changed by another active task as removal
survivors.

Freeze and identify all audit inputs: the in-scope test files, exercised
production code, fixtures, configuration, and resources that affect the
assertions. Account for test-command side effects before running checks. Run
the pre-prune task checks against stable inputs and record the exact commands,
outputs, exit codes, discovered test and case counts per file, and total
counts. If a check changes an audit input, refresh the input inventory and
content identities and rerun the check until the inputs and results are stable.
The coordinator records the resulting pre-prune audit snapshot and evidence in
`workflow.md` before dispatching an auditor.

Every required pre-prune check must exit with status zero. A non-zero exit
status blocks removal and auditor dispatch. Treat the failed check as a task
blocker, correct it through the approved workflow, refresh affected inputs, and
rerun the pre-prune checks before auditing. A failed check is not a valid audit
baseline.

If the runner cannot establish discovery counts, or a test-bearing file has no
discovered tests, stop before removal. Do not treat a successful command that
discovered zero tests as a passing pre-prune baseline.

## Independent audit

The coordinator selects a suitable independent test or quality specialist and
uses the current `subagent-dispatch.md` procedure to verify the concrete
high-capability model and harness routing. The coordinator alone dispatches
the auditor. The auditor is read-only: it must not edit files, run tests or
other mutating checks, change workflow state, dispatch another agent, or
perform removals. Give it the frozen inputs and pre-prune evidence listed in
the prompt. If those inputs are incomplete or unstable, it returns `BLOCKED`.

The auditor inventories every test and case in scope and returns exactly one
`KEEP` or `REMOVE` decision for each, with evidence. A `REMOVE` decision must
name each distinct defect the source test or case detects and map every such
defect to one or more retained survivor tests. A shared failure alone is not
proof of preservation. Survivors must be real, stable tests that will remain
after all proposed removals; an outside-scope survivor must not be owned by an
active task. Reject missing or cyclic survivor references, uncertain defect
coverage, and any inference from absent historical RED evidence. Keep uncertain
cases and uniquely valuable ineffective tests, recording their concerns.

The auditor also maps every approved behaviour in the task design to retained
tests. A required approved behaviour without retained coverage is an Important
finding and blocks acceptance. Report unrelated pre-existing coverage gaps
separately without expanding the task. If the audit finds no removals, record
the complete KEEP inventory and its evidence; do not imply that an audit was
skipped.

## Apply supported removals and recover safely

Before assigning any removal, the coordinator records in `workflow.md` the
exact source test or case, its path and surrounding context, the auditor's
defect-to-survivor evidence, and a scoped recovery patch or snapshot that can
restore only the proposed pruning changes. Record the expected per-file and
total discovery-count changes. If exact source or safe recovery material
cannot be preserved, do not remove the case.

The assigned implementation worker applies only the audited test or case
removals. It must not change production code, add tests, perform unrelated
helper cleanup, delete a test file, or remove the last test in a file. It
reports each applied and withheld removal. The coordinator inspects the actual
diff against the audit and the allowed writes before accepting it.

Run the post-prune command against stable inputs. Compare discovery results
and counts with the recorded expected removals, per file and in total. Confirm
that every test-bearing file still discovers at least one test and that the
overall command did not succeed with zero discovered tests. Unexpected counts,
failures, changed inputs, or ownership violations block acceptance.

If application or verification fails, the coordinator assigns restoration to
the same implementation worker. The worker restores only pruning-owned changes
using the recorded recovery material. The coordinator must not edit files or
apply restoration directly, and verifies the worker's resulting diff. Do not
use a broad Git restore or reset, or overwrite unrelated user changes. If the
scoped recovery no longer applies cleanly or ownership is uncertain, stop and
ask the user while preserving the current state.

An Important uncovered approved behaviour blocks acceptance. Return an
in-scope correction to the assigned worker for TDD and a targeted fresh audit;
if the correction is outside the approved task, return to the coordinator for
planning and approval. Unrelated old gaps are reported only.

## Evidence, invalidation, and handoff

The coordinator records the accepted post-prune snapshot in `workflow.md`,
including content identities for retained test files and exercised code,
fixtures, configuration, and resources, plus post-prune commands, outputs,
exit codes, and actual discovery counts. Record the content difference between
the pre-prune snapshot and this accepted snapshot. That difference must contain
only the exact authorised pruning changes. Exact authorised pruning changes do
not invalidate the audit; they are the expected result of its approved
removals. The original task-start baseline remains immutable and distinct from
both snapshots.

Before acceptance, compare current audit inputs with the accepted post-prune
snapshot, not with the pre-prune snapshot. Any additional change to an audited
test or case, exercised code, fixture, configuration, or relevant resource
invalidates the affected evidence. A changed test inventory requires a fresh
inventory; changed exercised behaviour inputs require a targeted audit of
affected cases and survivors. Changes to active-task ownership or survivor
stability invalidate the affected survivor evidence. Re-run applicable checks
and dispatch a fresh independent audit on stable inputs only for those
unexpected changes. Record new recovery material before any further removal.
Do not repeat the audit merely because the accepted snapshot contains the exact
authorised pruning changes. Changes outside the frozen audit inputs do not
invalidate evidence merely because they are in the same repository. Final
review inspects the audit and accepted snapshot, and repeats neither unless
evidence has been invalidated.

## Auditor prompt template

The coordinator fills every bracketed field from the approved task, actual
diff, stable source, and workflow record before dispatch. Paste the complete
current canonical Meaningful Assertions section into its slot verbatim. Do not
send the prompt with unresolved bracketed fields or make the auditor recover
missing context from session history.

```text
{{DISPATCH_AGENT_TOOL}} ([VERIFIED_TEST_OR_QUALITY_SPECIALIST]):
  description: "Independently audit test pruning for [TASK_ID]"
  prompt: |
    You are an independent, read-only test-pruning auditor. Follow the supplied
    task contract and canonical value rule. Do not edit files, run tests or
    other mutating checks, change workflow state, dispatch another agent, or
    apply removals. Do not infer missing inputs. Return BLOCKED if the supplied
    scope or evidence is incomplete, unstable, or inconsistent.

    ## Approved task and required behaviours

    Task: [TASK_ID]
    Approved design revision: [DESIGN_REVISION]
    Approved behaviours, each with its requirement identifier:
    [APPROVED_BEHAVIOUR_TO_REQUIREMENT_MAP]

    ## Immutable baseline and audit scope

    Task-start HEAD and baseline source:
    [TASK_START_HEAD_AND_BASELINE_REFERENCE]
    Relevant pre-existing dirty and untracked contents, preserved separately
    from task changes:
    [PRE_EXISTING_CONTENT_IDENTITIES_OR_SNAPSHOTS]
    Actual task-changed paths and evidence used to derive scope:
    [ACTUAL_TASK_DIFF_PATHS_AND_SCOPE_EVIDENCE]
    Every in-scope test-bearing file and every test or parameterised case,
    including older tests:
    [COMPLETE_FILE_AND_CASE_INVENTORY]
    Exact source and surrounding context for the inventoried cases:
    [TEST_SOURCE_AND_CONTEXT]

    ## Frozen exercised inputs and ownership

    Stable production code, fixtures, configuration, and resources exercised:
    [INPUT_PATHS_AND_CONTENT_IDENTITIES]
    Concurrent writers and test ownership information:
    [ACTIVE_TASK_OWNERSHIP_AND_STABILITY_EVIDENCE]
    Pre-prune commands, exit codes, outputs, and per-file and total discovery
    counts:
    [PRE_PRUNE_CHECKS_AND_DISCOVERY_COUNTS]
    Planned post-prune command and discovery-counting method:
    [POST_PRUNE_COMMAND_AND_COUNTING_METHOD]

    ## Canonical value rule, authoritative text

    [PASTE THE COMPLETE CURRENT MEANINGFUL ASSERTIONS SECTION VERBATIM]

    ## Audit

    Assess every test and case in the supplied inventory against the canonical
    rule. Return exactly one KEEP or REMOVE decision for each. For every
    decision, identify the behaviour and evidence. For each REMOVE, list every
    distinct defect the source case detects and map each defect to one or more
    named retained survivor tests. Verify that every survivor exists, is
    stable, is not owned by another active task, and remains after all proposed
    removals. Do not accept one shared failure as proof that distinct defects
    are preserved. Reject cycles, missing survivors, and uncertain coverage.
    Absence of historical RED evidence or inability to name a defect is not
    evidence for removal. Keep uncertain cases and uniquely valuable
    ineffective cases, and state the concern.

    Map every approved behaviour to retained test identifiers. Mark any
    required approved behaviour without retained coverage as an Important
    finding. Report unrelated gaps separately without proposing scope expansion.
    From the supplied per-file pre-prune counts and your proposed removals,
    calculate projected per-file and total post-prune counts. Flag a projected
    zero-test file or total as a blocker. The coordinator must validate and
    record these expected counts and a scoped recovery patch or snapshot in
    workflow.md before assigning removal. The recovery record is coordinator
    owned and is created after your audit, before any removal worker is
    assigned.
    Do not recommend deleting a file or its last test. You have no authority to
    make edits or delegate this audit.

    ## Required report

    Verdict: READY only when the inventory and evidence are complete and there
    is no Important finding for required behaviour coverage; otherwise BLOCKED.
    Complete inventory: one KEEP or REMOVE row per test or case.
    For each row: path, stable test/case identifier, decision, named behaviour,
    rationale, and evidence from the supplied stable inputs.
    For each REMOVE: all distinct defects and a defect-to-survivor mapping.
    Behaviour coverage: each approved behaviour and its retained test IDs, or
    an Important finding when coverage is absent.
    Discovery: confirm supplied pre-prune counts are non-zero per file and
    total, and provide projected post-prune per-file and total counts for the
    proposed removals, or identify the blocker.
    Stability: list any missing, changing, or ownership-uncertain inputs.
    Unrelated gaps: report only, with no scope expansion.
    Do not claim tests passed, checks ran, files changed, or removals were
    applied. Return evidence and recommendations only.
```
