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
