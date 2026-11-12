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

## Procedure

1. **Validate the durable approved input.** Confirm the approved plan revision and its explicit approval reference, or the approved external specification. Preserve that provenance and copy the complete approved design into its durable Epic `## Design` section or Markdown fallback. Do not rely on a temporary workflow path as the only copy. If no valid input is available, stop and route to `workflow-coordinator`.

2. **Detect the ticketing system.** Invoke the `detect-ticketing-system` skill. Confirm the result with the user before creating anything.

3. **Decompose the design.** Apply the tier mapping, grouping, D2 and sizing rules in `../_shared/tickets.md`. Preserve the approved scope, dependencies and ownership boundaries; do not broaden multiple requested tickets.

4. **Draft the Epic.** Follow the Epic content and provenance requirements in `../_shared/tickets.md`. For a real ticketing system, the `## Tickets` section is a human-readable index; native parent-child relationships are created through the selected system's API. Use the Markdown fallback format from the shared rules when no system is available.

5. **Draft child tickets.** Follow the canonical Story and Task content requirements in `../_shared/tickets.md`. Validate each Story before creation and refuse any Story that contains `## Design` or design content.

6. **Order the tickets.** Present the order using `../_shared/tickets.md` and the approved dependency/wave plan. Keep multiple requested ticket scopes and ownership boundaries explicit; do not impose serial execution where parallel work is permitted.

7. **Create the epic, then the children.** Create in this order so each level can reference its parent:

   1. Create the **Epic** first.
   2. Create each **Story** next, attaching it to the Epic via the system's parent mechanism. Apply the tier marker per `skills/_shared/tickets.md`'s Tier Markers section.
   3. Create each **Task** next, attaching it to its parent (Story if grouped, Epic if flat). Apply the tier marker.

   Use the API appropriate to the detected system (see "Per-System Creation" below).

8. **Back-fill the epic body.** Once all child tickets exist and have real references (issue numbers, Jira keys, Linear IDs), update the epic body's `## Tickets` section with the actual references and links at all tiers.

   **Failure semantics.** If any Story or Task creation fails mid-run, the skill **MUST**:

   1. Stop further creation immediately.
   2. Back-fill the epic body with whatever children **did** get created, so the user can see the partial state.
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
2. Use `sub_issue_write` to attach children to their parent. **Decision rule for nesting**, in order:
   1. Try Epic -> Story -> Task using two `sub_issue_write` calls (Story as sub-issue of Epic; Task as sub-issue of Story).
   2. If the second-level nest is rejected by the API, attach Tasks as sub-issues of the Story but reference the Epic via body text (`Epic: #<epic>`).
   3. If the first-level nest is also rejected, fall back to fully flat: Stories and Tasks are labelled siblings of the Epic, and parent references go in body text (`Part of #<story>, Epic: #<epic>`).
3. Tier labels are mandatory in **every** path.
4. Reference dependencies in the description: "Depends on #N".

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
