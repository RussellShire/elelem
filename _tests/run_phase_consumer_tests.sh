#!/usr/bin/env bash
set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="${ELELEM_TEST_ROOT:-$(cd "$script_directory/.." && pwd)}"

python3 - "$project_root" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "briefs": "skills/_shared/task-briefs.md",
    "tickets": "skills/_shared/tickets.md",
    "phase_evidence": "skills/_shared/phase-evidence.md",
    "worker_contract": "skills/_shared/worker-contract.md",
    "research": "skills/research/SKILL.md",
    "router": "skills/brainstorming/SKILL.md",
    "standard": "skills/brainstorming-standard/SKILL.md",
    "guided": "skills/brainstorming-guided/SKILL.md",
    "skip": "skills/brainstorming-skip/SKILL.md",
    "committee": "skills/brainstorming-committee/SKILL.md",
    "committee_prompt": "skills/brainstorming-committee/committee-member-prompt.md",
    "design_review": "skills/design-review/SKILL.md",
    "design_prompt": "skills/design-review/design-reviewer-prompt.md",
    "create": "skills/create-tickets/SKILL.md",
    "work": "skills/work-on-ticket/SKILL.md",
    "detect": "skills/detect-ticketing-system/SKILL.md",
    "project_discovery": "skills/_shared/project-context-discovery.md",
    "confluence": "skills/_shared/confluence-discovery.md",
}
texts = {}
for name, relative in paths.items():
    path = root / relative
    if not path.is_file():
        raise SystemExit(f"Required contract is missing: {relative}")
    texts[name] = path.read_text(encoding="utf-8")

passed = 0
failed = 0


def check(name: str, condition: bool) -> None:
    global passed, failed
    if condition:
        print(f"[PASS] {name}")
        passed += 1
    else:
        print(f"[FAIL] {name}")
        failed += 1


def section(text: str, start: str, end: str) -> str:
    try:
        return text.split(start, 1)[1].split(end, 1)[0]
    except IndexError:
        return ""


def has_all(text: str, clauses: tuple[str, ...]) -> bool:
    normalised_text = " ".join(text.split())
    return all(" ".join(clause.split()) in normalised_text for clause in clauses)


def has_required_load(text: str, reference: str) -> bool:
    reference_pattern = re.escape(reference)
    pattern = r"\b(read|load)(?: and apply)?\s+`" + reference_pattern + r"`"
    return bool(re.search(pattern, text, re.IGNORECASE))


def proposal_owner_contract(owner: str) -> bool:
    proposal = section(owner, "## Proposed design proposal\n", "## Required task brief\n")
    fields = (
        "- Goal", "- Requirements", "- Exclusions", "- Architecture", "- Components",
        "- Interfaces", "- Data flow", "- Error handling and failure behaviour",
        "- Tests and verification", "- Assumptions and supporting evidence references",
        "- Unresolved decisions or questions",
    )
    return owner.count("## Proposed design proposal") == 1 and has_all(proposal, fields)


def proposal_consumers_load_schema(texts_to_check: dict[str, str]) -> bool:
    consumers = ("standard", "guided", "skip", "committee", "design_review", "design_prompt")
    return all(has_required_load(texts_to_check[name], "../_shared/task-briefs.md") for name in consumers)


def proposal_delivery_contract(prompt: str) -> bool:
    delivery = ("paste its Proposed design proposal section verbatim into the packet", "source path and content identity")
    return has_required_load(prompt, "../_shared/task-briefs.md") and has_all(prompt, delivery)


def proposal_contract(texts_to_check: dict[str, str]) -> bool:
    owner = texts_to_check["briefs"]
    proposal = section(owner, "## Proposed design proposal\n", "## Required task brief\n")
    consumers = ("standard", "guided", "skip", "committee", "design_review", "design_prompt")
    return (
        proposal_owner_contract(owner)
        and has_all(proposal, ("not an approved plan", "explicit final user approval"))
        and proposal_consumers_load_schema(texts_to_check)
        and all("## Proposed design proposal" not in texts_to_check[name] for name in consumers)
    )


def committee_mapping_contract(prompt: str) -> bool:
    mapping = section(prompt, "## Subagent Type Selection\n", "## The Three Perspectives\n")
    role_types = (
        "Pragmatist", "Architect", "Advocate", "`architect-reviewer`", "`qa-expert`",
        "`typescript-pro`", "`python-pro`", "`golang-pro`", "`rust-engineer`",
        "`react-specialist`", "`laravel-specialist`", "`java-architect`",
        "`csharp-developer`", "`rails-expert`",
    )
    return bool(mapping) and has_all(mapping, role_types) and "currently exposed type options" not in prompt


def committee_dispatch_contract(dispatcher: str) -> bool:
    fallback = (
        "When a specialised type is unavailable", "currently exposed type options",
        "broad general-purpose capability", "If no suitable available type exists, return a blocker",
    )
    mapping_reference = ("sole role and type", "all three members concurrently in one message", "Use the types in its canonical role mapping")
    return (
        has_all(dispatcher, fallback + mapping_reference)
        and all(type_name not in dispatcher for type_name in ("typescript-pro", "python-pro", "golang-pro", "architect-reviewer", "qa-expert"))
        and "at most one tiebreaking round" in dispatcher
        and "Concerns flagged by two or more members" in dispatcher
    )


def committee_delivery_contract(prompt: str, worker_contract: str) -> bool:
    placeholder = "[PASTE ALL WORKERS AND READ-ONLY WORKERS SECTIONS VERBATIM WITH SOURCE PATH AND IDENTITY]"
    return (
        "Before dispatch, load `../_shared/worker-contract.md`" in prompt
        and "source path and identity" in prompt
        and prompt.count(placeholder) == 4
        and has_all(worker_contract, ("## All workers", "## Read-only workers", "NEEDS_CONTEXT", "BLOCKED"))
    )


def committee_contract(texts_to_check: dict[str, str]) -> bool:
    prompt = texts_to_check["committee_prompt"]
    return (
        committee_mapping_contract(prompt)
        and committee_dispatch_contract(texts_to_check["committee"])
        and committee_delivery_contract(prompt, texts_to_check["worker_contract"])
    )


def ticket_creation_owner_contract(owner: str) -> bool:
    creation = section(owner, "## Creation and Decomposition\n", "## Recovery Before Implementation\n")
    required = (
        "at least 2 coherent named themes", "At least 2 themes each decompose into at least 2 Tasks",
        "total Task count is at least 4", "A single-theme Epic always stays flat",
        "single-Story Epic is forbidden", "more than 6 Tasks", "one-sentence grouping rationale",
        "complete approved design", "approval and revision",
    )
    return has_all(creation, required)


def ticket_recovery_owner_contract(owner: str) -> bool:
    recovery = section(owner, "## Recovery Before Implementation\n", "## Ticket Sizing\n")
    sizing = section(owner, "## Ticket Sizing\n", "## Validation\n")
    validation = section(owner, "## Validation\n", "## Ordering\n")
    recovery_rules = (
        "Maximum walk depth**: 2 hops", "Cycle guard", "Ambiguity guard",
        "explicit Epic tier marker always wins", "parent reference cannot be resolved",
        "manual fallback", "MUST NOT** read or use any `## Design` heading found in a Story body",
        "### Parent references by system", "GitHub Issues", "Jira", "Linear", "GitLab", "Markdown fallback",
    )
    parent_rules = (
        "use the native parent field first", "`Part of #N` and `Epic: #N` references",
        "native `parent` or `epic` field", "Linear**: use the native `parent` field",
        "native group Epic associations", "nearest preceding `### Story:` heading",
    )
    sizing_rules = ("between 2 and 6 child Tasks", "three to five bullet points", "single focused session")
    return has_all(recovery, recovery_rules + parent_rules) and has_all(sizing, sizing_rules) and "single-Story epic" in validation


def ticket_ordering_contract(owner: str, create: str) -> bool:
    ordering = section(owner, "## Ordering\n", "## Procedures\n")
    grouped_order = "When Stories are present, order Stories first by dependency, then Tasks within each Story by dependency."
    return (
        has_all(ordering, ("foundations and dependencies first", "features next", "integration after dependencies", "polish last", grouped_order))
        and "Present the order using `../_shared/tickets.md`" in create
        and grouped_order not in create
    )


def linear_degradation_contract(owner: str, create: str, work: str) -> bool:
    markers = section(owner, "## Tier Markers\n", "## Creation and Decomposition\n")
    recovery = section(owner, "### Degraded Linear Recovery\n", "### Termination rule\n")
    marker_rules = ("degraded two-tier Linear", "`story:<slug>`", "lowercase, hyphenated ASCII", "derived from the Story theme statement")
    recovery_rules = ("Only after Linear rejects the nested Epic-Story-Task shape", "following its parent to the Epic in one hop", "Extract the Epic's `## Design`", "`story:<slug>` label to find the corresponding `### Story:")
    create_rules = ("Attempt the two-level nest first", "Linear's API rejects the nested shape", "degraded two-tier representation", "MUST** document this degradation in the Step 9 report")
    return (
        has_all(markers, marker_rules)
        and has_all(recovery, recovery_rules)
        and has_all(create, create_rules)
        and "`parent` and labels fields required by the shared resolver" in work
        and "lowercase, hyphenated ASCII" not in create + work
        and "`story:<slug>` label to find the corresponding" not in create + work
        and "Finding the Parent" not in work
    )


def ticket_consumers_contract(create: str, work: str) -> bool:
    create_rules = ("issue_write", "sub_issue_write", "createJiraIssue", "glab issue create", "Markdown Fallback")
    work_rules = ("issue_read", "getJiraIssue", "glab issue view", "scope confirmation", "Looks good, proceed")
    return (
        "read `../_shared/tickets.md`" in create
        and "read `../_shared/tickets.md`" in work
        and all(token not in create for token in ("D2 rule", "single-theme Epic", "total Task count is at least 4", "A single-Story epic", "between 2 and 6 child Tasks"))
        and all(token not in work for token in (
            "at most 2 hops", "legacy fallback only when", "Ambiguity guard", "scan the body for `Part of #N`",
            "If a parent reference exists but cannot be fetched", "use the native parent field first",
            "native `parent` or `epic` field", "nearest preceding `### Story:` heading",
        ))
        and has_all(create, create_rules + (
            "user has explicitly requested ticket creation", "approved plan revision", "not an automatic side effect",
            "Confirm the result with the user before creating anything", "Stop further creation immediately",
            "MUST NOT** roll back successfully created tickets",
        ))
        and has_all(work, work_rules + (
            "user has referenced a specific ticket", "Adjust scope", "Need more context",
            "Return the recovered ticket context to the active coordinator", "does not satisfy upstream phases",
            "Markdown fallback rules in `../_shared/tickets.md`",
        ))
    )


def ticket_contract(texts_to_check: dict[str, str]) -> bool:
    owner = texts_to_check["tickets"]
    create = texts_to_check["create"]
    work = texts_to_check["work"]
    owner_sections = (
        has_all(owner, ("## Hierarchy Model", "## Tier Markers", "## Recovery Before Implementation", "rule in \"Creation and Decomposition\""))
        and "decomposition rule in `create-tickets/SKILL.md`" not in owner
    )
    return (
        owner_sections
        and ticket_creation_owner_contract(owner)
        and ticket_recovery_owner_contract(owner)
        and ticket_ordering_contract(owner, create)
        and linear_degradation_contract(owner, create, work)
        and ticket_consumers_contract(create, work)
    )


def installed_ticket_contract(texts_to_check: dict[str, str]) -> bool:
    consumers = ("create", "work", "detect")
    return all(
        has_required_load(
            section(texts_to_check[name], "## Load the Ticketing Rules First\n", "\n\n"),
            "../_shared/tickets.md",
        )
        and has_all(
            section(texts_to_check[name], "## Load the Ticketing Rules First\n", "\n\n"),
            ("actually loaded skill", "do not use a checkout, history or link-only fallback"),
        )
        for name in consumers
    )


def ticket_phase_evidence_contract(work: str) -> bool:
    loading = work.split("Apply `../_shared/phase-evidence.md`", 1)[0]
    return (
        has_required_load(loading, "../_shared/phase-evidence.md")
        and has_all(loading, (
            "relative to the directory of the actually loaded skill",
            "{{READ_FILE_TOOL}}",
            "If it is missing or inaccessible, block recovery",
            "do not use a checkout, history or link-only fallback",
        ))
    )


def ticket_unresolved_parent_question_contract(work: str) -> bool:
    recovery = section(work, "3. **Run `resolve_epic_context`.**", "4. **Extract and qualify the design.**")
    return has_all(recovery, (
        "required parent cannot be resolved",
        "{{ASK_USER_QUESTION_TOOL}}",
        "ask the user to resolve the specific reference",
        "stop without partial context",
    ))


def repository_discovery_contract(project: str) -> bool:
    activation = (
        "Run repository discovery first.", "If Atlassian MCP is unavailable, do not load the optional helper",
        "check `.opencode/project-context.json`",
        "resolve `./confluence-discovery.md` relative to the directory of the actually loaded `project-context-discovery.md`",
        "Read that sibling helper before using its schema or procedure.",
    )
    return "## Optional Confluence Activation" in project and has_all(project, activation)


def discovery_contract(texts_to_check: dict[str, str]) -> bool:
    research = texts_to_check["research"]
    committee = texts_to_check["committee"]
    return (
        has_required_load(research, "../_shared/project-context-discovery.md")
        and has_all(research, ("actually loaded", "Research skill"))
        and has_required_load(committee, "../_shared/project-context-discovery.md")
        and has_all(committee, ("actually loaded", "Committee skill", "bounded consequential gap"))
        and installed_ticket_contract(texts_to_check)
        and repository_discovery_contract(texts_to_check["project_discovery"])
        and "## Optional Confluence Branch" in texts_to_check["confluence"]
    )


def phase_behaviour_contract(texts_to_check: dict[str, str]) -> bool:
    return (
        has_all(texts_to_check["research"], ("Research is collaborative by default", "Ask the user which uncertainty or option to investigate next", "Return findings, evidence references", "blockers to the active coordinator"))
        and has_all(texts_to_check["router"], ("The user chooses explicitly", "Do not ask as plain text or assume a default", "invoke exactly one selected mode skill"))
        and has_all(texts_to_check["standard"], ("Ask one question per message", "Explore alternatives", "self-contained proposal", "does not approve it"))
        and has_all(texts_to_check["guided"], ("Show your working", "Name the patterns", "Invite questions", "one self-contained proposal"))
        and has_all(texts_to_check["skip"], ("user must explicitly select this method", "If no design exists", "one focused follow-up", "not a phase skip"))
        and has_all(texts_to_check["design_review"], ("holistic review", "Approved", "Issues Found", "SKIPPED", "The coordinator owns user approval"))
        and all("records the result and next action" not in texts_to_check[name] for name in ("research", "router", "standard", "guided", "skip", "committee", "design_review", "work"))
    )


check("canonical proposal schema and actual pre-use loading", proposal_contract(texts))
check("design reviewer loads and delivers canonical proposal schema", proposal_delivery_contract(texts["design_prompt"]))
check("committee mapping has one owner and retains fallback and deliberation", committee_contract(texts))
check("ticket hierarchy, grouping and recovery have one owner", ticket_contract(texts))
check(
    "ticket entry loads canonical phase evidence before applying it",
    "Apply `../_shared/phase-evidence.md`" in texts["work"]
    and ticket_phase_evidence_contract(texts["work"]),
)
check(
    "unresolved ticket parent asks user to resolve the reference before stopping",
    ticket_unresolved_parent_question_contract(texts["work"]),
)
check("discovery and ticket consumers load installed-source contracts", discovery_contract(texts))
check("phase-specific interaction and approval boundaries remain", phase_behaviour_contract(texts))

missing_goal = texts.copy()
missing_goal["briefs"] = missing_goal["briefs"].replace("- Goal\n", "", 1)
check("proposal schema mutation missing a field is rejected", not proposal_contract(missing_goal))

duplicated_schema = texts.copy()
duplicated_schema["standard"] += "\n## Proposed design proposal\n" + section(
    texts["briefs"], "## Proposed design proposal\n", "## Required task brief\n"
)
check("duplicated proposal schema in a consumer is rejected", not proposal_contract(duplicated_schema))

missing_planning_load = texts.copy()
missing_planning_load["standard"] = missing_planning_load["standard"].replace(
    "read `../_shared/task-briefs.md`", "use `../_shared/task-briefs.md`", 1
)
check("Planning link without actual schema load is rejected", not proposal_contract(missing_planning_load))

missing_review_delivery = texts["design_prompt"].replace(
    "paste its Proposed design proposal section verbatim into the packet",
    "refer to its Proposed design proposal section",
    1,
)
check(
    "reviewer source read without schema delivery is rejected",
    has_required_load(missing_review_delivery, "../_shared/task-briefs.md")
    and not proposal_delivery_contract(missing_review_delivery),
)

missing_role_mapping = texts.copy()
missing_role_mapping["committee_prompt"] = missing_role_mapping["committee_prompt"].replace(
    "| TypeScript           | `typescript-pro`     |", "| TypeScript           | unavailable          |", 1
)
check("committee stack mapping mutation is rejected", not committee_contract(missing_role_mapping))

missing_committee_delivery = texts.copy()
missing_committee_delivery["committee_prompt"] = missing_committee_delivery["committee_prompt"].replace(
    "[PASTE ALL WORKERS AND READ-ONLY WORKERS SECTIONS VERBATIM WITH SOURCE PATH AND IDENTITY]", "", 1
)
check("committee worker contract delivery mutation is rejected", not committee_contract(missing_committee_delivery))

missing_ticket_guard = texts.copy()
missing_ticket_guard["tickets"] = missing_ticket_guard["tickets"].replace(
    "**Maximum walk depth**: 2 hops", "Maximum walk depth: unlimited", 1
)
check("ticket recovery depth mutation is rejected", not ticket_contract(missing_ticket_guard))

missing_grouped_order = texts.copy()
missing_grouped_order["tickets"] = missing_grouped_order["tickets"].replace(
    "When Stories are present, order Stories first by dependency, then Tasks within each Story by dependency.",
    "When Stories are present, use the general implementation order.",
    1,
)
check("grouped ticket order mutation is rejected", not ticket_ordering_contract(missing_grouped_order["tickets"], texts["create"]))

missing_linear_owner = texts["tickets"].replace("lowercase, hyphenated ASCII", "lowercase ASCII", 1)
check("Linear marker ownership mutation is rejected", not linear_degradation_contract(missing_linear_owner, texts["create"], texts["work"]))

duplicated_linear_rule = texts["work"] + "\nUse the Task's `story:<slug>` label to find the corresponding `### Story:` grouping."
check("duplicated Linear recovery rule in consumer is rejected", not linear_degradation_contract(texts["tickets"], texts["create"], duplicated_linear_rule))

duplicated_parent_rule = texts["work"] + "\nGitHub Issues: use the native parent field first."
check("duplicated parent resolution rule in consumer is rejected", not ticket_consumers_contract(texts["create"], duplicated_parent_rule))

missing_source_guard = texts.copy()
missing_source_guard["work"] = missing_source_guard["work"].replace(
    "use a checkout, history or link-only fallback", "use the repository checkout as fallback", 1
)
check("ticket consumer checkout fallback mutation is rejected", not discovery_contract(missing_source_guard))

link_only_phase_evidence = texts["work"].replace(
    "read `../_shared/phase-evidence.md`",
    "link to `../_shared/phase-evidence.md`",
    1,
)
check(
    "ticket phase-evidence link without actual load is rejected",
    "Apply `../_shared/phase-evidence.md`" in link_only_phase_evidence
    and not ticket_phase_evidence_contract(link_only_phase_evidence),
)


print(f"Cases: {passed + failed}, Passed: {passed}, Failed: {failed}")
if failed:
    raise SystemExit(1)
print("Focused phase and ticket source-contract checks only; no runtime compliance or integration claim.")
PY
