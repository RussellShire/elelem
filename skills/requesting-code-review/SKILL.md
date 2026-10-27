---
name: requesting-code-review
description: Dispatches a read-only code reviewer with the exact change set and context needed to assess production readiness. Selects a reviewer and model tier by scope and capability, and applies severity discipline to the result.
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: medium
---

# Requesting Code Review

The iron-law rules (when reviews are mandatory, forbidden response phrases) live in `../../rules/common/code-review.md`. The procedural rules that bind once a review skill is running (verify before acting, severity discipline, when to push back, GitHub inline reply procedure) live in `../_shared/code-review.md`. Subagent iron-law rules live in `../../rules/common/subagents.md` and the dispatch procedure rules live in `../_shared/subagent-dispatch.md`. This skill is the procedure that dispatches a reviewer.

Before running the procedure below, you **MUST** read `../_shared/code-review.md` and `../_shared/subagent-dispatch.md` using the Read tool if you have not already read them in this session.

## Procedure

1. **Check for a scoped review skip.** If the user explicitly skipped this review, including a skip recorded in the active workflow, return `SKIPPED` with the exact scope, reason and consequence. Do not dispatch a reviewer or present the skip as a verdict or approval.

2. **Select the review mode and identify its inputs.** The workflow coordinator supplies the mode and captured boundaries. Never guess a baseline from `HEAD~1` or infer one from current Git state.

   - **Current tree:** Use when reviewing uncommitted work. Receive the baseline commit captured at task/workflow start, the review's exact allowed paths, and a captured description/diff of relevant pre-existing dirty changes to exclude from findings and preserve. Review tracked changes with `git diff <BASELINE_SHA> -- <ALLOWED_PATHS>`; this includes staged and unstaged changes. Enumerate untracked files with `git ls-files --others --exclude-standard -- <ALLOWED_PATHS>` and read the exact contents of each in-scope file. Do not treat the file list alone as reviewed content. Compare the implementation delta with the captured pre-existing state, and do not report pre-existing changes as introduced by this work.
   - **Committed range:** Use only when the work is represented by commits. Receive the exact base and head commit SHAs, and review `git diff <BASE_SHA>..<HEAD_SHA> -- <ALLOWED_PATHS>`.

   For current-tree review, a baseline equal to `HEAD` is valid: `git diff <BASELINE_SHA>` includes staged and unstaged worktree changes. Never substitute `HEAD..HEAD` or an empty committed range for the current-tree diff. If boundaries, pre-existing state, or allowed paths are missing, return `BLOCKED` and ask the coordinator to supply them.

3. **Select the reviewer type and model tier.** Per `../../rules/common/subagents.md` and `../_shared/subagent-dispatch.md`, choose the most specific reviewer available for the change. Select the model tier by scope and required capability. Bounded local changes may use a lower-cost capable model; cross-file integration, design-level or cross-cutting review requires a capable reviewer. Do not use an unconditional low-cost default.

4. **Fill the template.** Open `code-reviewer.md` in this skill directory and populate:

    - `{WHAT_WAS_IMPLEMENTED}`: a one-line description of what the change builds
    - `{DESCRIPTION}`: a short paragraph of what the change builds and the design decisions that matter for review
    - `{PLAN_REFERENCE}`: a pointer to the approved design, ticket, or plan the work is delivering against
    - `{REVIEW_MODE}`: `current-tree` or `committed-range`
    - `{ALLOWED_PATHS}`: exact paths within review scope
    - Current-tree inputs: `{BASELINE_SHA}` and `{PREEXISTING_CHANGES}` with the coordinator's captured initial dirty state to exclude/preserve
    - Committed-range inputs: `{BASE_SHA}` and `{HEAD_SHA}`

5. **Dispatch.** Send the filled template to the reviewer subagent using the verified routing and model selected in step 3. The reviewer is read-only and must not edit files or create commits.

6. **Act on the output.** Process the reviewer's findings through `receiving-code-review` and apply the severity discipline in `../_shared/code-review.md`: fix Critical before anything else, fix Important before the next task or merge, log Minor for later. Report `REVIEWED` only when the scoped review was actually performed; report `SKIPPED` for an explicit user skip and `BLOCKED` when required inputs or routing are unavailable.

## Worked Example

You have just completed Task 2 in an orchestrated flow: adding verification and repair functions for a conversation index. The task has uncommitted changes, so the coordinator supplies a current-tree baseline captured at task start and the exact allowed paths. Do not infer a baseline commit from history.

```bash
git diff <BASELINE_SHA> -- <ALLOWED_PATHS>
git ls-files --others --exclude-standard -- <ALLOWED_PATHS>
```

Dispatch a capable reviewer selected for the scope, with the filled template. The reviewer reads each listed in-scope untracked file and compares current changes with the captured initial dirty state:

- `{WHAT_WAS_IMPLEMENTED}`: Verification and repair functions for the conversation index
- `{DESCRIPTION}`: Added `verifyIndex()` and `repairIndex()` covering four issue types: missing entries, stale entries, hash mismatches, and orphaned files. Repair is idempotent and logs every action.
- `{PLAN_REFERENCE}`: Task 2 of the deployment plan in the approved design
- `{REVIEW_MODE}`: `current-tree`
- `{BASELINE_SHA}`: `a7981ec` (captured at Task 2 start; this may equal current `HEAD`)
- `{ALLOWED_PATHS}`: `pkg/index.go`, `pkg/index_test.go`
- `{PREEXISTING_CHANGES}`: `pkg/index.go` and `pkg/index_test.go` were clean at Task 2 start

The reviewer returns `REVIEWED` with:

- Strengths: clean separation, real tests, no mocks of code under test
- Important: no progress indicators on long repair runs
- Minor: magic number (100) for the reporting interval
- Assessment: ready to proceed with Important fixed

Fix the Important issue, leave the Minor one logged, then move to Task 3. Do not proceed while the Important issue is unfixed (see `../_shared/code-review.md`).

## Template

The full reviewer prompt template lives at `skills/requesting-code-review/code-reviewer.md`. Keep its placeholders in sync with the list in step 4 when editing either file.
