#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

python3 - "$REPO_ROOT" <<'PY'
import hashlib
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "workflow": "rules/common/workflow.md",
    "skills": "rules/common/skills-policy.md",
    "subagents": "rules/common/subagents.md",
    "testing": "rules/common/testing.md",
    "evidence": "skills/_shared/phase-evidence.md",
    "artifacts": "skills/_shared/workflow-artifacts.md",
    "briefs": "skills/_shared/task-briefs.md",
    "worker": "skills/_shared/worker-contract.md",
    "dispatch": "skills/_shared/subagent-dispatch.md",
    "readiness": "skills/_shared/wave-readiness.md",
    "review": "skills/_shared/code-review.md",
    "pruning": "skills/_shared/test-pruning.md",
    "coordinator": "skills/workflow-coordinator/SKILL.md",
    "executor": "skills/subagent-driven-development/SKILL.md",
    "parallel": "skills/dispatching-parallel-agents/SKILL.md",
    "wave": "skills/wave-planning/SKILL.md",
    "pruning_skill": "skills/test-pruning/SKILL.md",
    "implementer": "skills/subagent-driven-development/implementer-prompt.md",
    "reviewer": "skills/subagent-driven-development/reviewer-prompt.md",
    "fast": "skills/fast-path-implementation/SKILL.md",
    "verification": "skills/verification-before-completion/SKILL.md",
    "debugging": "skills/debugging/SKILL.md",
    "debug_rules": "skills/debugging/RULES.md",
    "design_prompt": "skills/design-review/design-reviewer-prompt.md",
    "design_skill": "skills/design-review/SKILL.md",
    "code_prompt": "skills/requesting-code-review/code-reviewer.md",
    "investigator": "skills/debugging/investigator-prompt.md",
    "committee": "skills/brainstorming-committee/committee-member-prompt.md",
    "blueprint_skill": "skills/implementation-planning/SKILL.md",
    "blueprint_prompt": "skills/implementation-planning/blueprint-reviewer-prompt.md",
    "standing_review": "rules/common/code-review.md",
}
for relative in paths.values():
    if not (root / relative).is_file():
        print(f"[FAIL] Required policy source is missing: {relative}")
        raise SystemExit(1)
texts = {name: (root / path).read_text() for name, path in paths.items()}


def normal(text):
    return " ".join(text.split()).lower()


def require(text, *terms):
    value = normal(text)
    return all(normal(term) in value for term in terms)


def check(name, condition):
    if not condition:
        raise AssertionError(name)
    print(f"[PASS] {name}")


def review_owner(text):
    return require(text, "actually performed favourable", "Status `REVIEWED`", "Ready to merge `Yes`", "no unresolved Critical or Important", "exact current cumulative revision", "raw reviewer result", "reviewer identity", "reviewed revision", "`REVIEWED` alone is not sufficient", "`With fixes`, `No`, `BLOCKED`", "`SKIPPED`", "stale or missing", "Missing provenance", "explicit sequencing authorisation")


def worker_delivery(dispatch, worker, prompt):
    return require(dispatch, "load `./task-briefs.md` and `./worker-contract.md` before dispatch", "paste the applicable All workers and role-specific worker-contract sections verbatim", "source path and content identity", "links alone do not deliver") and require(worker, "## All workers", "## Implementation workers", "## Read-only workers", "NEEDS_CONTEXT", "authorised read-only Git inspection") and require(prompt, "paste the complete All workers and Implementation workers sections", "verbatim", "source path and content identity")


def between(text, start, end):
    return text.split(start, 1)[1].split(end, 1)[0]


def required_loads(text, paths):
    value = normal(text)
    return all(re.search(r"(?:load|read)(?: and apply)? `" + re.escape(path.lower()) + r"`", value) for path in paths)


executor_blockers = between(texts["executor"], "## Blockers and scope control", "## Final feature review and verification")
parallel_blockers = between(texts["parallel"], "Workers report `DONE`", "For implementation, this skill")
coordinator_final = between(texts["coordinator"], "Before validating a cumulative", "Do not use user approval")
implementation_role = between(texts["worker"], "## Implementation workers", "## Read-only workers")
correction_checks = {
    "executor loads upstream evidence before dispatch or reuse": bool(re.search(r"before dispatch or reuse, load and apply `\.\./_shared/phase-evidence\.md`", normal(texts["executor"]))),
    "executor delegates blocker algorithm": required_loads(executor_blockers, ["../_shared/subagent-dispatch.md"]) and "provisionally pause all new dispatch" not in normal(executor_blockers),
    "parallel dispatcher delegates blocker algorithm": required_loads(parallel_blockers, ["../_shared/subagent-dispatch.md"]) and "provisionally pause all new dispatch" not in normal(parallel_blockers),
    "implementation role inspects final changes": require(implementation_role, "Before returning", "inspect actual changes", "every changed path", "allowed", "uncertainty", "unintended", "do not hide", "outside scope"),
}
for name, valid in correction_checks.items():
    print(f"[{'PASS' if valid else 'FAIL'}] {name}")
if not all(correction_checks.values()):
    raise AssertionError("review corrections are missing")
for name, dependencies in {
    "wave": ["../_shared/workflow-artifacts.md", "../_shared/task-briefs.md", "../_shared/wave-readiness.md", "../_shared/subagent-dispatch.md"],
    "executor": ["../_shared/workflow-artifacts.md", "../_shared/task-briefs.md", "../_shared/wave-readiness.md"],
    "pruning_skill": ["../_shared/test-pruning.md", "../_shared/code-review.md"],
    "design_skill": ["../_shared/subagent-dispatch.md"],
    "parallel": ["../_shared/wave-readiness.md"],
    "coordinator": ["../_shared/phase-evidence.md", "../_shared/workflow-artifacts.md", "../_shared/task-briefs.md", "../_shared/wave-readiness.md", "../_shared/subagent-dispatch.md", "../_shared/code-review.md"],
    "briefs": ["workflow-artifacts.md", "subagent-dispatch.md"],
    "readiness": ["subagent-dispatch.md"],
    "pruning": ["subagent-dispatch.md"],
}.items():
    for dependency in dependencies:
        check(f"{name} explicitly loads {dependency}", required_loads(texts[name], [dependency]))
check("worker role sections are delivered with provenance", worker_delivery(texts["dispatch"], texts["worker"], texts["implementer"]))
for name in ("reviewer", "design_prompt", "code_prompt", "investigator", "pruning", "readiness"):
    check(f"{name} delivers read-only worker obligations", require(texts[name], "All workers", "Read-only workers", "identity"))
check("brief contains bounded inputs and return", require(texts["briefs"], "Exact allowed write paths", "Stable read paths", "resource needs", "Acceptance criteria", "Structured worker return", "reverted edits"))
check("fast path invokes standard executor", require(texts["fast"], "invoke `subagent-driven-development`", "{{INVOKE_SKILL_TOOL}}", "standard independent task reviewer") and not (root / "skills/fast-path-implementation/fast-path-reviewer-prompt.md").exists())
check("executor uses standard reviewer", require(texts["executor"], "./reviewer-prompt.md", "fast-path compatibility") and "fast-path-reviewer-prompt.md" not in texts["executor"])
check("exact ignore and registry-limited cleanup", require(texts["artifacts"], "exact entry `.elelem/`", "exact registered files", "Never delete", "workflow.md` last") and require(texts["workflow"], "exact `.elelem/`", "only registered workflow-created paths"))
check("scoped TDD skips are explicit", require(texts["testing"], "explicitly authorise a scoped TDD skip", "exact source, scope, reason and consequence", "does not supply RED or GREEN evidence"))
check("read-only git inspection is permitted", require(texts["subagents"], "authorised read-only Git inspection", "MUST NOT", "destructive Git"))
check("debugging scope and budget use RULES owner", require(texts["debugging"], "scope discipline in `RULES.md`", "Investigation Budget from `RULES.md`") and require(texts["debug_rules"], "three hypothesis cycles", "five files"))
check("standing constraints remain intelligible", require(texts["workflow"], "Explicit user approval", "independent", "stable inputs", "original baselines", "user work", "scoped user instruction", "not approval or evidence", "worker report is not independent") and require(texts["skills"], "reading their files is not invocation", "System instructions precede developer instructions"))


def blueprint_gate_ownership(workflow: str, skills: str, review: str, dispatch: str) -> bool:
    return (
        require(workflow, "Implementation Planning", "independent blueprint review", "separate explicit user approval")
        and require(skills, "implementation-planning", "task-briefs.md", "blueprint review")
        and require(review, "blueprint review", "design approval and blueprint approval", "separate user decisions")
        and require(dispatch, "Implementation Planning", "blueprint", "high-capability reasoning")
    )


check("blueprint gates retain canonical owners and capable preparation policy", blueprint_gate_ownership(texts["workflow"], texts["skills"], texts["standing_review"], texts["dispatch"]))


def skip_policy(text):
    return require(text, "explicit scoped user instruction", "scope, reason and consequence", "not approval or evidence", "does not supply missing inputs")


def active_authority(text):
    return require(text, "complete instruction context", "active elelem-managed", "do not infer the canonical rule source from adjacency", "do not fall back", "ambiguous")


def accepted_state(text):
    return require(text, "accepted-unverified", "never as `verified` or `integrated`", "skipped")


check("skip policy rejects unauthorised skipping", skip_policy(texts["workflow"]) and not skip_policy(texts["workflow"].replace("explicit scoped user instruction", "inferred instruction")))
check("skipped-state contract rejects misleading verified label", accepted_state(texts["artifacts"]) and not accepted_state(texts["artifacts"].replace("never as `verified` or `integrated`", "mark as verified")))
check("design and readiness verdicts remain distinct", require(texts["readiness"], "distinct from design review", "`READY` or `GAPS`") and require(texts["design_prompt"], "not user approval", "Approved | Issues Found"))
for path in sorted(set(paths.values()) | {
    "_tests/run_policy_owner_tests.sh",
    "_tests/run_workflow_tests.sh",
    "_tests/run_workflow_continuation_tests.sh",
    "_tests/run_implementation_model_selection_tests.sh",
    "rules/common/verification.md",
    "skills/requesting-code-review/SKILL.md",
    "skills/design-review/SKILL.md",
    "skills/dispatching-parallel-agents/SKILL.md",
}):
    print(f"[INPUT] {hashlib.sha256((root / path).read_bytes()).hexdigest()} {path}")
print("Focused source-contract checks only; no runtime compliance or integration claim.")
PY
