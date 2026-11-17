---
name: create-tickets
description: Turns an approved design into tickets in the project's ticketing system, or into a structured Markdown document when no ticketing system is available. Decomposes the design into right-sized child tickets under a single parent epic whose body carries the full design for future sessions to recover.
metadata:
  model: openai/gpt-6.1-sol
  reasoning_effort: medium
---

# Create Tickets

## Load the Ticketing Rules First

Before any ticket decomposition or creation, read `../_shared/tickets.md`
relative to the directory of the actually loaded skill using
`{{READ_FILE_TOOL}}`. If it is missing or inaccessible, block ticket creation;
do not use a checkout, history or link-only fallback.

The `detect-ticketing-system` skill identifies the system. This skill creates
tickets from an approved design while applying the canonical hierarchy,
grouping, marker and sizing rules in `../_shared/tickets.md`.

**Precondition**: the user has explicitly requested ticket creation, and an approved design is available from an explicit workflow approval tied to a plan revision, or from an approved external specification. Conversation context alone is not a durable approved input. If the current workflow has no approved plan revision or approval reference, do not create tickets: return to `workflow-coordinator` to resume the required phases. If there is no active workflow, invoke `workflow-coordinator` to establish one. Missing inputs block creation; do not infer approval from a skipped review or from an earlier ticket context.

This skill creates tickets only when requested. Ticket creation is not an automatic side effect of planning or implementation. For multiple requested tickets, retain their ownership boundaries and use the coordinator's approved scope and dependency/wave plan; do not broaden one ticket to include another.

## Detection Result Handling

Preserve the result returned by `detect-ticketing-system`, including its status, every match, mechanism, evidence, confidence and support. For a `confirmed` supported target, confirm that target with the user before any writes. Confirmation is a user choice, not proof of authentication or project access.

For `candidate` or `ambiguous`, ask the user to select and confirm a supported target before using a backend. For `unsupported`, do not call that backend; ask for a supported alternative or the user's authorisation to use the existing Markdown fallback. For `none`, use the existing Markdown fallback. Preserve an explicit selection for the rest of this request and do not detect again.

## Procedure

1. **Validate the durable approved input.** Confirm the approved plan revision and its explicit approval reference, or the approved external specification. Preserve that provenance and copy the complete approved design into its durable Epic `## Design` section or Markdown fallback. Do not rely on a temporary workflow path as the only copy. Render the complete Epic body, including its goal, design, provenance and tickets index. If no valid design input is available, stop and route to `workflow-coordinator`.

2. **Detect the ticketing system.** Invoke the `detect-ticketing-system` skill. Apply Detection Result Handling. Do not call a backend until the supported target is confirmed by the user. If the selected target has a known body limit, compare it with the complete rendered Epic body and stop before any creation if the body is too large; ask the user for an authorised alternative.

3. **Decompose the design.** Apply the tier mapping, grouping, D2 and sizing rules in `../_shared/tickets.md`. Preserve the approved scope, dependencies and ownership boundaries; do not broaden multiple requested tickets.

4. **Draft the Epic.** Follow the Epic content and provenance requirements in `../_shared/tickets.md`. For a real ticketing system, the `## Tickets` section is a human-readable index; native parent-child relationships are created through the selected system's API. Use the Markdown fallback format from the shared rules when no system is available.

5. **Draft child tickets.** Follow the canonical Story and Task content requirements in `../_shared/tickets.md`. Validate each Story before creation and refuse any Story that contains `## Design` or design content.

6. **Order the tickets.** Present the order using `../_shared/tickets.md` and the approved dependency/wave plan. Keep multiple requested ticket scopes and ownership boundaries explicit; do not impose serial execution where parallel work is permitted.

7. **Create the epic, then the children.** Create in this order so each level can reference its parent:

   1. Create the **Epic** first.
   2. Create each **Story** next, attaching it to the Epic via the system's parent mechanism. Apply the tier marker per `skills/_shared/tickets.md`'s Tier Markers section.
   3. Create each **Task** next, attaching it to its parent (Story if grouped, Epic if flat). Apply the tier marker.

   Use the API appropriate to the detected system (see "Per-System Creation" below).

8. **Back-fill the epic body.** Once all child tickets exist and have real references (issue numbers, Jira keys, Linear IDs), render the complete updated Epic body and check it against a known body limit. If it exceeds the limit, preserve the created tickets, skip the update and report the partial state. Otherwise, attempt the body update at most once. If it is rejected or has an uncertain outcome, do not repeat that body write; preserve the created tickets and report the exact failed operation and current partial state.

   **Failure semantics.** If any Story or Task creation fails mid-run, the skill **MUST**:

   1. Stop further creation immediately.
   2. Back-fill the epic body with whatever children **did** get created, so the user can see the partial state, only when the complete updated body is known to fit or one safe update attempt remains. Do not repeat a rejected or uncertain body write. If safe back-fill is not possible, stop and report the exact failed operation and partial state instead.
   3. Report the failure to the user, citing the specific child that failed and its intended position in the hierarchy.
   4. Leave the partially-created tickets in place.

   The skill **MUST NOT** silently continue past a failure. The skill **MUST NOT** roll back successfully created tickets: rollback requires destructive operations against the ticketing system, which is out of scope and risky. The user decides whether to retry the failed child, fix the underlying issue and re-run, or abandon the partial state.

9. **Report to the user.** Summarise:

   - Number of tickets created at each tier (Epic, Stories if any, Tasks)
   - Links or references for each
   - Implementation order
   - Dependencies between tickets
   - Any system-specific degradations applied (e.g. Linear two-tier flattening, GitLab no-Epic mode, GitHub fallback to labelled flat)

    Then use {{ASK_USER_QUESTION_TOOL}} to ask whether they want to adjust anything (reorder, split, merge, relabel) before closing out. Ticket creation does not start implementation automatically. If implementation is requested, route through `workflow-coordinator` with the approved scope and recovered ticket context.

## Per-System Creation

### GitHub Issues

With GitHub MCP tools (preferred):

1. Use `issue_write` to create the Epic, each Story (if any), and each Task. Apply tier labels at creation: `tier:epic`, `tier:story`, `tier:task` (use `get_label` and create labels if missing).
2. Include matching textual parent references in Story and Task bodies when creating them. Use `sub_issue_write` once for Epic -> Story, then once for Story -> Task, to try Epic -> Story -> Task. Apply the exact degradation in `skills/_shared/tickets.md`'s GitHub Relationship Degradation section. If Task-to-Story is explicitly rejected, keep the successful Epic-to-Story relationship and give the Task no native parent; its body already contains `Part of #<story>, Epic: #<epic>`. Never give a Story-grouped Task a native Epic parent. If Epic-to-Story is explicitly rejected, use textual parent references throughout and create no native parent relationships. For a flat Epic and Tasks, include `Part of #<epic>` in each Task body at creation and attempt each Epic-to-Task relationship at most once; if a flat Epic-to-Task relationship is explicitly rejected, give that Task no native parent. Do not retry rejected edges, reparent successful children, or delete successful links. If an outcome is uncertain, stop further ticket creation and relationship writes, then report the exact operation and partial state without retrying.
3. Tier labels remain mandatory in every path.
4. Reference dependencies in the description: "Depends on #N".

Before creating the Epic, validate the complete rendered Epic body against a known body limit. If the Epic creation is rejected for size or has an uncertain outcome, stop, report the exact operation and partial state, and create no children under a missing or incomplete Epic. Do not retry with a changed or shortened body.

With `gh` CLI (fallback):

```bash
gh issue create --title "..." --body "..." --label "tier:epic"
```

The `gh` CLI cannot create native sub-issue links, so parent references **MUST** go in the Task or Story body as text (`Part of #<parent>`, plus `Epic: #<epic>` for Tasks under Stories). Tier labels are still mandatory.

### Jira

With Atlassian MCP tools:

1. `getVisibleJiraProjects` to find the target project. If more than one is visible, use {{ASK_USER_QUESTION_TOOL}} to ask the user which.
2. `getJiraProjectIssueTypesMetadata` to confirm available issue types (Epic, Story, Task, Sub-task).
3. `createJiraIssue` for the Epic first, then each Story (if any), then each Task. The native issue type **is** the tier marker per `skills/_shared/tickets.md` (no separate label needed).
4. Use the native `epic` and `parent` fields to attach Stories to the Epic and Tasks to their parent Story or Epic.
5. `createIssueLink` for any cross-Task dependency links beyond the parent relationship.

### GitLab Issues

With GitLab MCP tools if available; otherwise use `glab`:

```bash
glab issue create --title "..." --description "..." --label "tier:epic"
```

If group **Epics** are available (premium GitLab), use the native group Epic for the top tier and create Stories and Tasks as Issues with `tier:story` and `tier:task` labels respectively. Stories link to the Epic via the native Epic-Issue association; Tasks link to their parent Story via "Part of #<story>" body text.

If group Epics are **not** available, the top tier becomes a labelled Issue (`tier:epic`) and the rest cascades the same way (Story is a labelled Issue with "Part of #<epic>", Task is a labelled Issue with "Part of #<story>, Epic: #<epic>"). The skill **MUST** warn the user explicitly via the report when degrading to no-Epic mode rather than silently flattening.

### Linear

With Linear MCP tools. Use {{ASK_USER_QUESTION_TOOL}} to ask the user for team and project context before creating issues; Linear requires these upfront.

Use Issue + sub-issue + sub-issue, applying Linear tier markers from `../_shared/tickets.md`. **Do not** map Epic to Linear Project: Project is a different lifecycle concept and conflating it would break recovery.

Attempt the two-level nest first. If Linear's API rejects the nested shape, use the degraded two-tier representation in `../_shared/tickets.md`. The skill **MUST** document this degradation in the Step 9 report to the user.

### Markdown Fallback

When `detect-ticketing-system` returns "none" and the user requested ticket creation, write one permanent structured Markdown deliverable per Epic at the project root or a user-specified location. It is not a temporary workflow artefact, so never register or delete it during workflow clean-up. Follow the durable Epic structure and heading markers defined in `../_shared/tickets.md`. The file is the durable Epic equivalent; `work-on-ticket` can read it when the user references a Task.

## Closing the Loop

After reporting, remind the user: "To pick up any of these tickets in a new session, reference it (for example, 'work on #42'). The `work-on-ticket` skill fetches the ticket and runs `resolve_epic_context` to recover the durable design from the parent Epic, then routes the approved scope through `workflow-coordinator`."
