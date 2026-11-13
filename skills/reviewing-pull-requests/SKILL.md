---
name: reviewing-pull-requests
description: Guides a conversational, read-only review of another person's locally checked-out pull request against a ticket and a user-selected comparison branch.
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: medium
---

# Reviewing Pull Requests

Use this skill to help the user understand and decide on another person's local PR branch. This is not a review of the user's own implementation and is not `requesting-code-review` or `work-on-ticket`.

Before reviewing, read `../_shared/code-review.md` relative to this loaded skill using `{{READ_FILE_TOOL}}`. If unavailable, stop and explain the missing source. Apply its evidence and Critical/Important/Minor severity discipline to this review; do not import its implementation, dispatch or remote reply procedures. Apply the applicable language pack instructions using `{{INVOKE_SKILL_TOOL}}` before substantive reading or review of task code.

This skill is conversation-only: no artefact writes, edits or fixes, remote comments or review submissions, merges, commits, push, checkout, stash, cleanup, dependency installation, fetch or automatic test execution. Do not implicitly invoke workflow-coordinator, implementation gates or delegation. If the user requests fixes, end the review and route the separate, explicitly authorised implementation request through `workflow-coordinator`; do not make changes inside this skill.

## 1. Ticket and comparison branch

Ask for a ticket reference or ticket content if missing. Always ask the user for the comparison branch, even if one seems obvious or was mentioned in the initial request: confirm their intended branch explicitly using `{{ASK_USER_QUESTION_TOOL}}`. Do not assume a default branch. Wait for both inputs before proceeding.

For a ticket reference, use an available read-only ticket integration to retrieve the ticket content. If the integration is unavailable or cannot retrieve it, ask the user to paste the ticket content. Only read ticket information; do not modify the ticket. Do not require an epic design or implementation workflow context. Ask for linked material only when it is needed to understand the actual scope.

Summarise the ticket's purpose, actual acceptance criteria, dependencies and exclusions, identifying their source, then ask the user to confirm the summary. Do not infer acceptance criteria from code or guess absent requirements. If a criterion or other material scope detail is missing or ambiguous, ask a targeted question and pause until clarified. Distinguish confirmed absence of a criterion from an unknown criterion; if material evidence remains unavailable, explain the limitation and do not recommend approval.

## 2. Git boundaries and review inputs

Capture the current branch identity, HEAD commit, selected base tip, merge-base and status before reviewing. Run Git inspection with `GIT_OPTIONAL_LOCKS=0` to avoid optional index refresh writes. If HEAD is detached or the branch identity is unclear, ask the user to confirm the intended PR revision before proceeding. Never switch branches. Treat the chosen comparison as a local branch or remote-tracking branch, not arbitrary revision syntax. Validate a full ref with `git check-ref-format`, then use exact `git show-ref --verify` checks under `refs/heads/` and `refs/remotes/` as applicable. For a short branch name, check both namespaces; if both exist, ask for the fully qualified ref rather than guessing. Reject option-like inputs, invalid ref names and expressions such as revision operators. Missing or ambiguous refs must pause for a valid user choice. Resolve the selected exact ref and HEAD to commit IDs and use `git merge-base --all` on those IDs. If there is no merge-base or more than one, pause and ask the user to resolve the boundary; do not silently choose one.

Review the committed merge-base to pinned HEAD delta, for example `git diff --no-ext-diff --no-textconv <merge-base> <pinned-HEAD> --`, and surrounding code from the pinned commits, for example `git show <pinned-HEAD>:<path>`. Use committed versions of relevant tests as well. Do not substitute a base-tip-to-HEAD diff or working-tree reads for committed evidence. State that local refs may be stale and remote freshness is unverified; do not fetch automatically.

Capture staged, unstaged and untracked status, including both paths of renames, without modifying them. Preserve all dirty files and exclude unrelated local edits from the review. If dirty state affects a scoped read or any evidence is contaminated or cannot be separated from the pinned committed versions, pause, explain the affected paths and ask the user how to proceed without changing their files. Do not attribute pre-existing or unrelated edits to the PR. Treat failures to inspect relevant inputs as missing evidence, not clean status.

## 3. Walkthrough

After ticket confirmation and boundary capture, explain the implementation in logical data-flow sections, citing exact committed code locations and how each section relates to the ticket. Explain one section at a time, not a wall of text. After each section ask for questions or whether to continue, then pause for the user's response before presenting the next section. Answer questions before advancing. Do not present the findings phase until the walkthrough is complete.

## 4. Findings

After the walkthrough, inspect correctness, ticket coverage, regressions, edge cases and relevant tests against the confirmed scope and pinned committed evidence. Do not run tests automatically. Distinguish tests present in the commit from tests actually run and report any unavailable checks or coverage as limitations.

Discuss findings individually with the user. For each evidenced defect, describe its trigger, consequence and exact source and supporting evidence, then assign Critical, Important or Minor severity using the shared discipline. Distinguish defects, questions and preferences. Ask about uncertain material behaviour rather than inventing defects, and do not attribute pre-existing issues to the PR. Pause for discussion before moving to the next finding. If there are no evidenced issues, say so without asserting that the code is correct.

## 5. Recommendation

Before final advice, recheck relevant refs, status and ticket scope against the captured inputs, including the branch identity, HEAD, base tip, merge-base and relevant dirty state. Re-read a read-only ticket source when available; for pasted or inaccessible content, ask the user to confirm whether the supplied scope is still current. Material drift invalidates affected analysis: pause, identify what changed, recapture the relevant inputs and redo the affected walkthrough and findings before advising. If the new boundary, scope or evidence cannot be established, give insufficient-evidence advice rather than relying on stale conclusions.

Offer one qualified recommendation: approve, request changes, or insufficient evidence. Unresolved Critical or Important findings prevent an approval recommendation. Missing material evidence also prevents an approval recommendation. State relevant unrun tests, coverage and remote-freshness limitations. No issues found is not a guarantee of correctness. The recommendation is advisory; the user owns the decision and any remote review action.
