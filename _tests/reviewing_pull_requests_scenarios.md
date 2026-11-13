# Interactive pull request review scenarios

These are bounded tabletop scenarios, not executed evidence. Each starts with the skill loaded and the shared review rules accessible. Responses are examples of the required next action, not exact wording.

## Missing ticket

Input: The user asks to review a colleague's current branch and supplies no ticket. No comparison branch has been confirmed.

Expected next response: Ask for the ticket reference or pasted ticket content and ask which comparison branch to use. Pause for the answers. If only a reference is supplied and no read-only integration can retrieve it, request pasted content.

## Missing chosen base

Input: The user supplies ticket ABC-12 with clear criteria and asks to review the checked-out branch, without choosing a comparison branch. A local `main` branch exists.

Expected next response: Ask which comparison branch to use, without assuming `main`. Pause before selecting a Git boundary.

## Dirty scoped file

Input: Ticket ABC-12 and comparison branch `main` are confirmed. The pinned PR changes `src/order.go`, which also has unstaged edits; the proposed evidence was read from its working tree rather than the pinned commit.

Expected next response: Identify `src/order.go` as contaminated, stop relying on that read and ask how to proceed while preserving the edits. Pause; do not stash, discard or attribute those edits to the PR. A clean committed read must be established before using the evidence.

## Uncertain criterion

Input: The ticket says orders must be processed promptly, but gives no threshold. The user has confirmed `main` as the comparison branch.

Expected next response: Ask what timing requirement, if any, is actually intended and pause. Do not invent a threshold or present a timing violation as a defect.

## No evidenced issues

Input: Ticket scope and `main` are confirmed, boundaries and status remain stable, the interactive walkthrough and evidence review are finished, and no defects were substantiated. Tests were inspected but not run.

Expected next response: Report that no evidenced issues were found, note that tests were not run and local remote freshness is unverified, and provide a qualified recommendation only if no material evidence is missing. State that no issues found does not guarantee correctness and the decision belongs to the user.

## Revision drift

Input: After a walkthrough and findings on pinned HEAD A, the final recheck finds HEAD B on the same branch. The changed revision affects the previously discussed order handler.

Expected next response: Explain that HEAD changed and affected analysis is invalid, pause, then recapture boundaries and re-examine the affected walkthrough and findings before final advice. If the new inputs cannot be established, recommend insufficient evidence rather than reusing stale conclusions.
