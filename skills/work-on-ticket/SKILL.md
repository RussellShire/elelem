---
name: work-on-ticket
description: Picks up a ticket from the project's ticketing system, fetches its parent epic, recovers the durable design context, confirms the ticket scope, and routes the recovered context through workflow-coordinator for baseline validation and implementation.
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: medium
---

# Work on Ticket

## Load the Ticketing Rules First

Before fetching or recovering ticket context, read `../_shared/tickets.md`
relative to the directory of the actually loaded skill using
`{{READ_FILE_TOOL}}`. If it is missing or inaccessible, block recovery; do not
use a checkout, history or link-only fallback.

The `detect-ticketing-system` skill identifies the system. The
`workflow-coordinator` owns phase transitions. This skill bridges session
boundaries without bypassing current workflow validation.

Before applying the phase-evidence gate, read `../_shared/phase-evidence.md`
relative to the directory of the actually loaded skill using
`{{READ_FILE_TOOL}}`. If it is missing or inaccessible, block recovery; do not
use a checkout, history or link-only fallback.

Apply `../_shared/phase-evidence.md` to recovered context. Return upstream gaps
to the coordinator, not an inferred phase completion from a ticket, approval or
scope confirmation. Preserve accessible provenance for legitimate prior work.

**Precondition**: the user has referenced a specific ticket to work on (for example, "work on #42", "pick up PROJ-123", "implement issue 7"). Without a specific reference, this skill does not apply; if the user is asking what to work on next, that is a triage question, not this skill.

## Procedure

You **MUST** complete these steps in order. Do not skip a step and do not reorder them.

1. **Detect the ticketing system.** Invoke the `detect-ticketing-system` skill to identify where the ticket lives.

2. **Fetch the ticket.** Retrieve its full content: title, description, labels, status, parent or epic relationship, child or sub-issue references, and linked tickets. See "Per-system fetch" below for the specific API calls.

3. **Run `resolve_epic_context`.** Apply the complete tier-marker, parent-walk, fallback and recovery safeguards in `../_shared/tickets.md`. If a required parent cannot be resolved or any guard fails, use `{{ASK_USER_QUESTION_TOOL}}` to ask the user to resolve the specific reference, then stop without partial context.

4. **Extract and qualify the design.** Extract the full Epic `## Design`, provenance and any Story theme returned by the shared procedure. Carry the entire ticket scope, acceptance criteria, dependencies and exclusions forward without broadening it. If the Epic has no `## Design`, follow the shared manual fallback and ask for context; do not guess or proceed. Recovered ticket content is not automatic proof that assumptions remain valid or that implementation is approved.

5. **Explore the codebase.** Read the current state of files relevant to the ticket. Note anything that has changed since the design was written, anything already partially implemented, and anything the design assumes but does not actually exist yet. This is a preliminary baseline for coordinator validation, not a substitute for the coordinator's recorded baseline and resume checks. Evaluate recovered prior context for current validity; do not blindly skip Research or Planning because a ticket or approval exists.

6. **Present the scope.** Show the user a structured summary before asking for confirmation:

   - **Ticket**: title and reference
   - **Design context** (from epic): the recovered design section, or a note that none was found
   - **This ticket's scope**:
     - What to build (from the ticket description)
     - Acceptance criteria (from the ticket)
     - Dependencies (from linked tickets, what must exist before this work)
     - What is explicitly out of scope (from sibling tickets, things that belong to other tickets)
   - **Current codebase state**: relevant observations from step 5

7. **Get explicit scope confirmation.** Use `{{ASK_USER_QUESTION_TOOL}}` to confirm that the recovered ticket scope is what the user intends. This confirmation is not design approval and does not skip any workflow phase. Plain-text confirmation is not sufficient.

   ```
   {{ASK_USER_QUESTION_TOOL}}:
     question: "Does this scope look right for implementation?"
     header: "Scope"
     options:
       - label: "Looks good, proceed"
          description: "The recovered scope and acceptance criteria are correct. Route this context to the workflow coordinator."
       - label: "Adjust scope"
         description: "Something needs changing before implementation begins."
       - label: "Need more context"
         description: "Fetch additional tickets or explore the codebase further before deciding."
     multiSelect: false
   ```

   If the user selects "Adjust scope" or "Need more context", address the feedback and re-present with `{{ASK_USER_QUESTION_TOOL}}` again. Only proceed to step 8 after "Looks good, proceed".

8. **Route to `workflow-coordinator`.** Invoke `workflow-coordinator` with a recovered ticket payload containing the ticket identity and reference, full durable design and its provenance, exact ticket scope, acceptance criteria, dependencies, exclusions, observed codebase state, and the user's explicit scope confirmation. The coordinator validates current baseline assumptions, reuses approval only when its revision and baseline remain valid, and runs all remaining required phases by default. Do not invoke `work-on-ticket` recursively or invoke `subagent-driven-development` directly. If the coordinator has already been entered for this ticket, provide the payload to that active coordinator rather than starting a second one.

   ```
   {{INVOKE_SKILL_TOOL}}:
      skill: "workflow-coordinator"
   ```

    Before invoking, construct the recovered ticket context by combining:

    1. The durable design and approval/revision or external specification provenance recovered from the Epic (the architectural context)
   2. The ticket scope (what specifically this ticket delivers)
   3. The acceptance criteria from the ticket (the spec that the spec reviewer will check against)
    4. Codebase observations from step 5, marked as preliminary baseline evidence

## Per-System Fetch

Fetch each system's ticket data and marker/parent fields needed by
`resolve_epic_context`. Interpret those fields using the canonical marker and
recovery rules in `../_shared/tickets.md`.

### GitHub Issues

With GitHub MCP tools: `issue_read` with the issue number. Response includes body, labels, and parent or sub-issue relationship fields for the shared resolver.

With `gh` CLI:

```bash
gh issue view <number> --json title,body,labels,milestone,projectItems
```

Retrieve the `labels` array for shared tier-marker resolution.

### Jira

With Atlassian MCP tools: `getJiraIssue` with the issue key. Response includes the `parent`, `epic` and issue type fields natively for the shared resolver.

### GitLab Issues

With GitLab MCP tools if available; otherwise:

```bash
glab issue view <number>
```

Retrieve the native group-Epic association and labels where available for the shared resolver.

### Linear

With Linear MCP tools. The response includes the `parent` and labels fields required by the shared resolver.

## Handling Multiple Tickets

For multiple requested tickets, carry each ticket's identity, scope, and ownership/clean-up boundary separately to the coordinator. It may plan dependencies and waves across the explicitly approved combined scope, and may run independent work concurrently. Do not blanket-serialise tickets, recommend separate sessions as a requirement, or silently expand any ticket scope. Where the user's request does not approve a combined scope, keep the workflows separate.

## Edge Cases

- **Ticket already partially implemented**: read git history and current code state, present what exists to the user, and adjust the scope to cover only the remaining work before step 7.
- **Ticket depends on unfinished work**: flag the dependency. Ask the user whether to work on the dependency first or to proceed with stubs or interfaces for the missing pieces.
- **Ticket description is vague**: use the epic's design context to fill in gaps. If still unclear after that, ask the user targeted questions before proceeding. You **MUST NOT** guess at requirements.
- **No ticketing system detected**: if the user provides a ticket reference but `detect-ticketing-system` returns "none", ask the user to paste the ticket content (and the parent epic content if applicable) directly, then run `resolve_epic_context` against the pasted content using the Markdown fallback rules in `../_shared/tickets.md`.

Return the recovered ticket context to the active coordinator. Ticket approval
or scope confirmation does not satisfy upstream phases. Pause for missing
evidence, user choice or approval, unsafe state, or a real blocker.
