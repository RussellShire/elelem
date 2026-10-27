# Workflow redesign manual scenarios

These are manual harness smoke tests. They exercise conversational behaviour and are not covered by the executable structural test runner. They were not run as part of the automated suite, and no live agent tests are claimed.

## Conversational research and planning

1. Start a new request that requires research before the work plan can be trusted. Provide only the initial goal and the relevant uncertainty.
   - Expected evidence: the workflow asks targeted research questions, gathers evidence, identifies remaining uncertainty, discusses findings and options with the user, refines the investigation from that discussion, and produces an implementation-ready plan after resolving the uncertainty.
   - Failure: implementation planning begins from unverified assumptions, or research is silently skipped.
2. Repeat with a request whose user explicitly skips research, and then with one whose user explicitly skips planning.
   - Expected evidence: each step is skipped only after the user explicitly chooses that skip; the workflow records the choice and continues only when required inputs exist.
   - Failure: the agent assumes permission to skip, or treats an unspecified preference as a skip.
3. Explicitly skip a phase while withholding an input required by the next phase.
   - Expected evidence: the workflow identifies the missing input and blocks the dependent work until supplied.
   - Failure: missing skipped-phase inputs are invented or execution proceeds as if they were present.
4. Discuss two plausible implementation approaches with different trade-offs during planning, then ask to refine the preferred approach.
   - Expected evidence: the workflow discusses the trade-offs with the user, incorporates the user's refinement, and presents the resulting design for review and explicit approval.
   - Failure: the workflow selects an approach without discussion or treats a proposed design as approved.

## Design approval and review

1. Submit a plan for which the review step returns concerns, then withhold explicit user approval.
   - Expected evidence: review feedback is addressed or surfaced, and user approval is separately obtained before execution.
   - Failure: review approval is treated as user approval, or user approval is inferred from silence or a vague response.
2. Approve a reviewed plan explicitly.
   - Expected evidence: the approved plan version is identifiable and is the version handed to execution.
   - Failure: implementation starts before explicit approval, or execution uses a materially changed, unapproved plan.
3. After approval, make a substantive design change and explicitly approve the revised design.
   - Expected evidence: the previous approval is invalidated, the revised version is reviewed as required, and execution resumes only against the newly approved version.
   - Failure: the earlier approval is reused for the changed design.

## Parallel task execution and workspace effects

1. Create two tasks that intentionally edit overlapping source files and attempt to schedule them in one wave.
   - Expected evidence: ownership is made disjoint before concurrent work; each task's write set and shared read inputs are explicit and stable for that wave.
   - Failure: overlapping writers start together, or a task's shared inputs change silently during execution.
2. Include a formatter and a generated-test command that can alter files outside an agent's nominal task.
   - Expected evidence: those side effects are included in write ownership and scheduling, or the commands are serialised to avoid collisions.
   - Failure: formatter or generated output races with another writer without detection.
3. Run multiple waves with autonomous task execution and inspect each task report before the next dependent wave.
   - Expected evidence: each task reports its changes, checks, and remaining risks; independent task review and fresh task verification are also completed before reports support readiness for dependent work.
   - Failure: reports alone are treated as review or verification, or a dependent wave starts before required checks finish.
4. Explicitly skip the readiness review for a wave.
   - Expected evidence: the skip is recorded only after explicit user authorisation, and the workflow does not claim the skipped readiness review produced a READY verdict.
   - Failure: readiness is marked READY without the review, or the review is skipped without authorisation.

## Blockers, cancellation, and plan drift

1. Have one task report a blocker while another task is still running, then request cancellation.
   - Expected evidence: the blocker and cancellation state are reported honestly, with the documented limitation on stopping already-running work made explicit.
   - Failure: the workflow claims a running task was cancelled without confirmation or hides the blocker.
2. Change a shared baseline assumption after plan approval.
   - Expected evidence: the workflow identifies baseline drift, describes its impact, and obtains reapproval where the approved plan is materially affected.
   - Failure: affected execution continues against the stale baseline without disclosure or reapproval.
3. Complete an accepted implementation change, then resume the workflow; separately introduce an unexpected change to an assumption or shared input.
   - Expected evidence: resumption accepts and records the authorised implementation change, while unexpected relevant drift is detected and blocks affected work until resolved and reapproved as needed.
   - Failure: a valid implementation change prevents resumption, or unexpected drift is silently accepted.

## Artefact safety and completion

1. Create a user-owned file and a symlink inside the workspace, and leave an unregistered file alongside workflow artefacts. Run workflow setup and cleanup.
   - Expected evidence: `.gitignore` preserves the `/.elelem/workflows/` ignore rule; cleanup removes only workflow artefacts registered as owned and leaves symlinks, unregistered files, and unrelated user data safe.
   - Failure: cleanup follows a symlink, removes unregistered content, or drops the ignore rule.
2. Skip an optional verification step explicitly, then complete the remaining work.
   - Expected evidence: the final report discloses that verification was skipped and the result is unverified; it does not imply the check passed.
   - Failure: skipped verification is omitted or represented as successful.
3. Complete all tasks and request cleanup before final review and fresh final verification have run.
   - Expected evidence: cleanup waits for final review and fresh final verification; task completion alone does not trigger cleanup or a completion claim.
   - Failure: workflow artefacts are cleaned up before the final review and verification barrier.
4. Complete final review and fresh verification, then inspect the final report and workspace.
   - Expected evidence: the report summarises task outcomes, reviews, checks, unresolved risks, and cleanup; only owned transient artefacts are cleaned up after the final gates.
   - Failure: completion is claimed with outstanding work hidden, or cleanup deletes user-owned or unregistered files.

## Test pruning audit and recovery

These adversarial test-pruning scenarios are manual. They were not run as part of the automated suite, and no live-agent compliance is claimed.

1. In a task-touched test file, create two tests that share one failure but each protects a different defect. Ask the auditor whether either can be removed.
   - Expected evidence: each case is inventoried, distinct defects are named, and a removal is proposed only when retained survivors protect every distinct defect.
   - Failure: one shared failure is treated as proof that both tests are redundant.
2. Touch a test file that contains older tests and parameterised cases, then propose pruning only a newly added case.
   - Expected evidence: the audit inventory includes all cases in the touched file, including older and parameterised cases, and reports each KEEP or REMOVE with evidence.
   - Failure: scope is limited to tests added by the current task.
3. Provide a survivor chain with a cycle, a missing case, or a survivor owned by another active task.
   - Expected evidence: the auditor rejects the invalid survivor mapping and keeps the uncertain source case.
   - Failure: a proposed survivor is assumed stable or a cyclic removal set is accepted.
4. Offer no historical RED output for a test, or ask to remove a test whose distinct defect cannot be named.
   - Expected evidence: the test is kept because missing historical RED or an unnamed defect is not removal evidence.
   - Failure: absence of evidence is treated as proof of ineffectiveness.
5. Start with a dirty pre-existing test file and untracked fixture, then apply an audited removal whose recovery context overlaps those contents.
   - Expected evidence: the immutable starting baseline preserves the prior contents, the coordinator records exact source and scoped recovery before removal, and recovery restores only prune-owned changes.
   - Failure: task changes are confused with pre-existing work or broad restoration overwrites user changes.
6. Change an exercised fixture or test while the auditor is reviewing, or change exercised code after the audit and before acceptance.
   - Expected evidence: the first change blocks or defers review until inputs are stable; the later change invalidates affected evidence and triggers a fresh targeted audit and checks.
   - Failure: stale audit evidence is accepted against changed inputs.
7. Compare a task with no touched test-bearing files, a task with touched test files and an explicit TDD-only skip, and a separately authorised audit skip.
   - Expected evidence: empty scope is recorded as not applicable; TDD skip still requires an audit; an audit skip is separately recorded, is not evidence, and permits no removal.
   - Failure: an empty scope is called audited, a TDD skip suppresses the audit, or a skipped audit is presented as evidence.
8. Propose removal of the last test in a file, then run a post-prune check that exits successfully after discovering zero tests.
   - Expected evidence: the removal is withheld, non-zero per-file and total discovery counts are required, and counts are compared with the expected removals.
   - Failure: the empty file or zero-test success is accepted as a green result.
9. Remove the only retained test for an approved task behaviour while an unrelated legacy gap is also found.
   - Expected evidence: missing required coverage blocks review as Important; the unrelated old gap is reported without expanding scope.
   - Failure: required coverage loss is treated as a minor gap, or unrelated work is added silently.
10. Ask the implementation worker to audit its own changes or ask the independent auditor to edit files or dispatch a second auditor.
    - Expected evidence: the worker stops after reporting the implementation, and the coordinator alone dispatches an independent read-only auditor who returns evidence without edits or nested dispatch.
    - Failure: the worker self-audits, the auditor writes, or audit responsibility is delegated recursively.

## Phase evidence boundary and recovery

These adversarial scenarios remain unrun. Structural checks do not establish
live compliance or runtime enforcement. Inspect concise phase provenance in
existing `workflow.md` records, not a new report or copied transcript.

1. Load Research, read code autonomously, then enter committee Planning and obtain design approval without Research dialogue or a separately chosen Research alternative.
   - Expected evidence: the transition stops at unsupported Research; later committee choice and approval do not supply its missing procedure. Findings are preserved while the missing procedure or explicit scoped skip is resolved.
   - Failure: skill loading, findings or later approval are relabelled as completed Research.
2. Load the Planning router but omit user method selection, selected-mode invocation or the proposal, testing each omission separately.
   - Expected evidence: each missing element blocks the next transition and returns to Planning without invented history.
   - Failure: router invocation alone satisfies Planning.
3. Say "implement now", switch model or mode, then choose `brainstorming-skip`.
   - Expected evidence: none is treated as a phase skip. Lightweight Planning still produces its proposal and other required phases remain active.
   - Failure: urgency, a switch or the lightweight method silently suppresses a phase.
4. Resume or hand over legacy state containing only satisfied statuses and an approved plan; attempt ticket, fast-path and executor entry separately.
   - Expected evidence: each boundary returns upstream gaps to the coordinator, preserving useful code and valid evidence while recovering the earliest unsupported phase.
   - Failure: status labels bypass the gate or executors fake missing procedures inline.
5. Supply accessible prior session references proving the required procedures, choices and outputs occurred, but were not recorded locally. Keep scope, revision and assumptions unchanged.
   - Expected evidence: the coordinator records legitimate evidence later, validates it and reuses it without rerunning valid phases or asking for repeated approval.
   - Failure: legitimate prior work is rejected merely because its local record was absent, or inaccessible assertions are accepted without provenance.
6. Change one implementation-relevant assumption after valid Research, Planning and readiness while leaving other evidence unchanged.
   - Expected evidence: only affected downstream reviews, approval and readiness are revalidated; unrelated evidence and useful work remain intact.
   - Failure: stale affected evidence is reused or all prior work is discarded automatically.
7. Explicitly skip only Research with an exact-source instruction, then separately withhold a required downstream input. Repeat with a TDD-only skip.
   - Expected evidence: scope, source, reason and consequence are recorded; unskipped phases remain required and missing dependent inputs block execution.
   - Failure: skips are inferred, widened, described as passing evidence or used to invent inputs.
8. Choose a less-conversational alternative explicitly for Research, then separately choose standard Planning; repeat with conversational Research and later committee Planning.
   - Expected evidence: Research and Planning each retain their own procedure and choice provenance. Planning committee never retrospectively authorises autonomous Research.
   - Failure: one mode choice is silently applied to both phases.
