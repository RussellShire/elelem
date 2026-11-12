#!/usr/bin/env bash
set -euo pipefail

E="${1:?evidence directory is required}"
SOURCE_ROOT="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUTPUT_ROOT="${3:-$E/T4-measurements}"
mkdir -p "$OUTPUT_ROOT"

LC_ALL=C PYTHONDONTWRITEBYTECODE=1 python3 - "$E" "$SOURCE_ROOT" "$OUTPUT_ROOT" <<'PY'
import hashlib
import json
import re
import sys
from collections import defaultdict
from pathlib import Path


evidence_root, source_root, output_root = map(Path, sys.argv[1:])
trace_path = evidence_root / "baseline-load-traces.json"
trace_hash = hashlib.sha256(trace_path.read_bytes()).hexdigest()
expected_trace_hash = "b9c9cee9354dd1ba7cc7e625d540eb93d3970649c2aa2d2e4cd425deb8f6aaf2"
if trace_hash != expected_trace_hash:
    raise SystemExit("baseline load trace identity changed")

baseline_root = evidence_root / "baseline"
baseline_traces = json.loads(trace_path.read_text())
baseline_identities = json.loads((evidence_root / "baseline-identities.json").read_text())
scenario_names = {
    "planning": "Conversational standard Planning",
    "executor": "One-task executor",
    "implementer_packet": "Implementer packet",
    "reviewer_packet": "Standard task reviewer packet",
    "pruning_verification": "Pruning and final verification",
}
common_paths = baseline_traces["always_on"]
word_pattern = re.compile(r"[^ \t\r\n\v\f]+")
section_pattern = re.compile(r"(?ms)^## Meaningful Assertions\n.*?(?=^## |\Z)")
source_purposes = {
    "skills/workflow-coordinator/SKILL.md": "phase transitions, handoff validation and coordinator-owned invocation order",
    "skills/_shared/phase-evidence.md": "procedure provenance, upstream gates, evidence validity and recovery",
    "skills/_shared/workflow-artifacts.md": "workflow state, immutable baselines, checkpoints and cleanup",
    "skills/_shared/task-briefs.md": "phase and task schemas, bounded inputs and structured returns",
    "skills/brainstorming/SKILL.md": "user-selected Planning method and selected-mode invocation",
    "skills/brainstorming-standard/SKILL.md": "standard conversational Planning proposal procedure",
    "skills/_shared/project-context-discovery.md": "bounded repository-first discovery without the conditional Atlassian branch",
    "skills/subagent-driven-development/SKILL.md": "approved-wave executor task lifecycle and barriers",
    "skills/_shared/wave-readiness.md": "persisted schedule and wave-readiness requirements",
    "skills/_shared/subagent-dispatch.md": "fresh-child isolation, routing, capability and blocker procedure",
    "skills/_shared/worker-contract.md": "generic and role-specific worker obligations and returns",
    "skills/subagent-driven-development/implementer-prompt.md": "bounded implementer packet structure",
    "skills/subagent-driven-development/reviewer-prompt.md": "independent task-review packet structure",
    "skills/requesting-code-review/SKILL.md": "task review dispatch procedure and review requirements",
    "skills/requesting-code-review/code-reviewer.md": "task reviewer template and review input structure",
    "skills/_shared/code-review.md": "task review severity, feedback and disposition rules",
    "skills/verification-before-completion/SKILL.md": "verification evidence validation, execution or reuse, and citation",
    "skills/verification-before-completion/RULES.md": "verification gate procedural checks",
    "skills/test-driven-development/SKILL.md": "RED/GREEN/refactor method for observable implementation changes",
    "skills/test-driven-development/RULES.md": "TDD failure reasons and required cycle evidence",
    "skills/test-pruning/SKILL.md": "separate final pruning-task trigger and phase boundary",
    "skills/_shared/test-pruning.md": "active-source resolution, audit, application, recovery and pruning evidence",
    "rules/common/testing.md": "canonical Meaningful Assertions value rule",
}
scenario_context = {
    "planning": "Standard Planning after completed Research, with repository context supplied and Atlassian unavailable or disabled; no policy source output is reused.",
    "executor": "One approved scheduled task with implementation, independent task review and task checks; cumulative review, pruning and final verification are accounted separately in scenario 5.",
    "implementer_packet": "Same external task payload excluded; observable Bash changes make TDD method delivery applicable; dispatcher-only routing is excluded unless it was present in the frozen baseline packet.",
    "reviewer_packet": "Same task/change payload excluded; standard independent task review only, with no pruning prerequisite.",
    "pruning_verification": "Favourable cumulative review supplied, one touched Bash test file, unchanged active testing rule, and no pruning edits.",
}
baseline_supplements = {
    "executor": [{
        "path": "skills/requesting-code-review/code-reviewer.md",
        "provenance": "The immutable executor trace includes requesting-code-review/SKILL.md, whose step 4 requires opening this template. Add this necessary transitive source as an explicit supplement without changing baseline-load-traces.json.",
    }],
}


def words(text: str) -> list[str]:
    return word_pattern.findall(text)


def source_identity(root: Path, relative: str) -> tuple[bytes, str]:
    content = (root / relative).read_bytes()
    return content, hashlib.sha256(content).hexdigest()


def full_event(root: Path, relative: str, role: str) -> dict[str, object]:
    content, identity = source_identity(root, relative)
    text = content.decode("utf-8")
    return {
        "source": relative,
        "selection": "full file",
        "role": role,
        "sha256": identity,
        "span_sha256": hashlib.sha256(content).hexdigest(),
        "start_line": 1,
        "end_line": len(text.splitlines()),
        "words": len(words(text)),
        "text": text,
    }


def section_event(root: Path, relative: str, heading: str, role: str) -> dict[str, object]:
    content, identity = source_identity(root, relative)
    text = content.decode("utf-8")
    match = section_pattern.search(text) if heading == "Meaningful Assertions" else None
    if match is None:
        section = re.compile(rf"(?ms)^## {re.escape(heading)}\n.*?(?=^## |\Z)").search(text)
        match = section
    if match is None:
        raise SystemExit(f"required section is unavailable: {relative}#{heading}")
    selected = match.group(0)
    start_line = text[:match.start()].count("\n") + 1
    end_line = start_line + len(selected.splitlines()) - 1
    return {
        "source": relative,
        "selection": f"## {heading}",
        "role": role,
        "sha256": identity,
        "span_sha256": hashlib.sha256(selected.encode()).hexdigest(),
        "start_line": start_line,
        "end_line": end_line,
        "words": len(words(selected)),
        "text": selected,
    }


def annotate_event(name: str, event: dict[str, object], occurrence: int) -> None:
    source = str(event["source"])
    path = source.split("#", 1)[0]
    selection = str(event["selection"])
    purpose = (
        "cumulative review validation"
        if name == "pruning_verification" and path == "skills/_shared/code-review.md"
        else source_purposes.get(path, "scenario-specific source contract")
    )
    if selection.startswith("## "):
        action = "source-derived delivery"
    elif path.endswith("/SKILL.md") and name == "implementer_packet":
        action = "method skill delivery for worker invocation"
    elif name == "implementer_packet" or path.endswith("implementer-prompt.md"):
        action = "implementer role-prompt delivery"
    elif name == "reviewer_packet" or path.endswith("reviewer-prompt.md"):
        action = "independent task-review prompt delivery"
    elif name == "executor" and path == "skills/requesting-code-review/SKILL.md":
        action = "task-review procedure invocation and source load"
    elif name == "executor" and path == "skills/requesting-code-review/code-reviewer.md":
        action = "task reviewer template load and dispatch"
    elif name == "executor" and path == "skills/_shared/code-review.md":
        action = "task-review severity and disposition rules"
    elif path.endswith("/SKILL.md"):
        action = "skill invocation and source load"
    else:
        action = "procedure source read"
    if path == "skills/_shared/worker-contract.md" and selection == "full file":
        actor = "coordinator/executor dispatcher" if name == "pruning_verification" else "executor dispatcher"
        action = "read to select applicable role sections"
    elif path == "skills/_shared/worker-contract.md" and name == "executor":
        if selection == "## Implementation workers" or (selection == "## All workers" and occurrence == 0):
            actor = "executor dispatcher to implementer"
        else:
            actor = "executor dispatcher to independent task reviewer"
    elif path == "skills/_shared/worker-contract.md" and name == "implementer_packet":
        actor = "executor dispatcher to implementer"
    elif path == "skills/_shared/worker-contract.md" and name == "reviewer_packet":
        actor = "executor dispatcher to independent task reviewer"
    elif path == "skills/_shared/worker-contract.md" and name == "pruning_verification":
        actor = "coordinator and executor to read-only pruning auditor"
    elif name == "planning":
        actor = {
            "skills/workflow-coordinator/SKILL.md": "active workflow coordinator",
            "skills/brainstorming/SKILL.md": "coordinator invoking the Planning router",
            "skills/brainstorming-standard/SKILL.md": "selected standard Planning skill",
            "skills/_shared/project-context-discovery.md": "coordinator invoking repository context discovery",
        }.get(path, "active workflow coordinator")
    elif name == "executor":
        actor = {
            "skills/subagent-driven-development/SKILL.md": "executor",
            "skills/_shared/subagent-dispatch.md": "executor dispatcher",
            "skills/subagent-driven-development/implementer-prompt.md": "executor dispatcher to implementer",
            "skills/subagent-driven-development/reviewer-prompt.md": "executor dispatcher to independent task reviewer",
            "skills/requesting-code-review/SKILL.md": "executor invoking TASK review",
            "skills/requesting-code-review/code-reviewer.md": "executor dispatcher loading TASK reviewer template",
            "skills/_shared/code-review.md": "executor applying TASK review severity and disposition rules",
            "skills/verification-before-completion/SKILL.md": "executor/coordinator applying task verification",
            "skills/verification-before-completion/RULES.md": "executor/coordinator applying task verification rules",
        }.get(path, "executor validating task prerequisites and checks")
    elif name == "implementer_packet":
        actor = "executor dispatcher to implementer"
    elif name == "reviewer_packet":
        actor = "executor dispatcher to independent task reviewer"
    elif name == "pruning_verification":
        actor = {
            "skills/test-pruning/SKILL.md": "executor invoking the final pruning task",
            "skills/_shared/test-pruning.md": "coordinator and read-only pruning auditor",
            "skills/_shared/code-review.md": "coordinator validating cumulative reviewer PASS",
            "skills/_shared/subagent-dispatch.md": "coordinator dispatcher for the pruning auditor",
            "skills/verification-before-completion/SKILL.md": "coordinator invoking final verification",
            "skills/verification-before-completion/RULES.md": "verification gate",
            "rules/common/testing.md": "coordinator delivering the canonical rule to the auditor",
        }.get(path, "coordinator validating final task inputs")
    else:
        actor = "scenario owner"
    event.pop("role", None)
    event["actor"] = actor
    event["action"] = action
    event["purpose"] = purpose
    event["reuse_status"] = "source content is read or delivered in this invocation; no prior source output is reused"


def annotate_events(name: str, events: list[dict[str, object]]) -> list[dict[str, object]]:
    occurrences: dict[tuple[str, str], int] = defaultdict(int)
    for event in events:
        key = (str(event["source"]).split("#", 1)[0], str(event["selection"]))
        annotate_event(name, event, occurrences[key])
        occurrences[key] += 1
    return events


def baseline_events(name: str) -> list[dict[str, object]]:
    events = []
    for item in baseline_traces["baseline_traces"][name]:
        content, identity = source_identity(baseline_root, item["path"])
        text = content.decode("utf-8")
        actual_words = len(words(text))
        if identity != item["sha256"] or actual_words != item["words"]:
            raise SystemExit(f"frozen baseline trace mismatch: {item['path']}")
        events.append({
            "source": item["path"],
            "selection": "full file",
            "role": "baseline read or delivery",
            "sha256": identity,
            "span_sha256": hashlib.sha256(content).hexdigest(),
            "start_line": 1,
            "end_line": len(text.splitlines()),
            "words": actual_words,
            "text": text,
        })
    for supplement in baseline_supplements.get(name, []):
        event = full_event(baseline_root, supplement["path"], "conditional transitive read")
        if event["sha256"] != baseline_identities[supplement["path"]]:
            raise SystemExit(f"baseline supplement identity mismatch: {supplement['path']}")
        event["trace_supplement"] = supplement["provenance"]
        events.append(event)
    if name == "pruning_verification":
        events.append(section_event(baseline_root, "rules/common/testing.md", "Meaningful Assertions", "canonical reviewer delivery"))
    return annotate_events(name, events)


final_sources = {
    "planning": [
        ("skills/workflow-coordinator/SKILL.md", "full"),
        ("skills/_shared/phase-evidence.md", "full"),
        ("skills/_shared/workflow-artifacts.md", "full"),
        ("skills/_shared/task-briefs.md", "full"),
        ("skills/brainstorming/SKILL.md", "full"),
        ("skills/brainstorming-standard/SKILL.md", "full"),
        ("skills/_shared/project-context-discovery.md", "full"),
    ],
    "executor": [
        ("skills/subagent-driven-development/SKILL.md", "full"),
        ("skills/_shared/phase-evidence.md", "full"),
        ("skills/_shared/workflow-artifacts.md", "full"),
        ("skills/_shared/task-briefs.md", "full"),
        ("skills/_shared/wave-readiness.md", "full"),
        ("skills/_shared/subagent-dispatch.md", "full"),
        ("skills/_shared/worker-contract.md", "full"),
        ("skills/subagent-driven-development/implementer-prompt.md", "full"),
        ("skills/subagent-driven-development/reviewer-prompt.md", "full"),
        ("skills/requesting-code-review/SKILL.md", "full"),
        ("skills/requesting-code-review/code-reviewer.md", "full"),
        ("skills/_shared/code-review.md", "full"),
        ("skills/verification-before-completion/SKILL.md", "full"),
        ("skills/verification-before-completion/RULES.md", "full"),
        ("skills/_shared/worker-contract.md#All workers", "section"),
        ("skills/_shared/worker-contract.md#Implementation workers", "section"),
        ("skills/_shared/worker-contract.md#All workers", "section"),
        ("skills/_shared/worker-contract.md#Read-only workers", "section"),
    ],
    "implementer_packet": [
        ("skills/subagent-driven-development/implementer-prompt.md", "full"),
        ("skills/_shared/worker-contract.md#All workers", "section"),
        ("skills/_shared/worker-contract.md#Implementation workers", "section"),
        ("skills/test-driven-development/SKILL.md", "full"),
        ("skills/test-driven-development/RULES.md", "full"),
    ],
    "reviewer_packet": [
        ("skills/subagent-driven-development/reviewer-prompt.md", "full"),
        ("skills/_shared/worker-contract.md#All workers", "section"),
        ("skills/_shared/worker-contract.md#Read-only workers", "section"),
    ],
    "pruning_verification": [
        ("skills/test-pruning/SKILL.md", "full"),
        ("skills/_shared/test-pruning.md", "full"),
        ("skills/_shared/code-review.md", "full"),
        ("skills/_shared/phase-evidence.md", "full"),
        ("skills/_shared/subagent-dispatch.md", "full"),
        ("skills/_shared/task-briefs.md", "full"),
        ("skills/_shared/workflow-artifacts.md", "full"),
        ("skills/verification-before-completion/SKILL.md", "full"),
        ("skills/verification-before-completion/RULES.md", "full"),
        ("skills/_shared/worker-contract.md", "full"),
        ("skills/_shared/worker-contract.md#All workers", "section"),
        ("skills/_shared/worker-contract.md#Read-only workers", "section"),
        ("rules/common/testing.md#Meaningful Assertions", "section"),
    ],
}


def final_events(name: str) -> list[dict[str, object]]:
    events = []
    for source, selection in final_sources[name]:
        if selection == "full":
            relative = source
            events.append(full_event(source_root, relative, "mandatory read or delivery"))
        else:
            relative, heading = source.split("#", 1)
            events.append(section_event(source_root, relative, heading, "source-derived role delivery"))
    return annotate_events(name, events)


def assert_pruning_review_purpose(root: Path, version: str) -> None:
    event = full_event(root, "skills/_shared/code-review.md", f"{version} source selfcheck")
    annotate_event("pruning_verification", event, 0)
    if event["purpose"] != "cumulative review validation":
        raise SystemExit(f"{version} pruning source must classify shared review as cumulative review validation")


assert_pruning_review_purpose(source_root, "final")


def assert_executor_trace_consistency(events: list[dict[str, object]]) -> None:
    mandatory_review_reads = {
        "skills/requesting-code-review/SKILL.md": (
            "executor invoking TASK review",
            "task-review procedure invocation and source load",
            "task review dispatch procedure and review requirements",
        ),
        "skills/requesting-code-review/code-reviewer.md": (
            "executor dispatcher loading TASK reviewer template",
            "task reviewer template load and dispatch",
            "task reviewer template and review input structure",
        ),
        "skills/_shared/code-review.md": (
            "executor applying TASK review severity and disposition rules",
            "task-review severity and disposition rules",
            "task review severity, feedback and disposition rules",
        ),
    }
    for source, expected_labels in mandatory_review_reads.items():
        matching_events = [event for event in events if event["source"] == source]
        if len(matching_events) != 1 or matching_events[0]["selection"] != "full file":
            raise SystemExit(f"executor trace must include exactly one full task-review read: {source}")
        actual_labels = tuple(str(matching_events[0][key]) for key in ("actor", "action", "purpose"))
        if actual_labels != expected_labels:
            raise SystemExit(f"executor trace must classify this source as task review: {source}")

    section_deliveries = sorted(
        (str(event["selection"]), str(event["actor"]))
        for event in events
        if event["source"] == "skills/_shared/worker-contract.md" and event["selection"] != "full file"
    )
    expected_deliveries = sorted([
        ("## All workers", "executor dispatcher to implementer"),
        ("## Implementation workers", "executor dispatcher to implementer"),
        ("## All workers", "executor dispatcher to independent task reviewer"),
        ("## Read-only workers", "executor dispatcher to independent task reviewer"),
    ])
    if section_deliveries != expected_deliveries:
        raise SystemExit("executor trace must deliver exactly one implementer packet and one task-review packet")
    if any("cumulative" in str(event[key]).lower() for event in events for key in ("actor", "action", "purpose")):
        raise SystemExit("executor trace contains an unsupported cumulative-review role")


def duplicate_spans(events: list[dict[str, object]]) -> list[dict[str, object]]:
    spans: dict[str, list[dict[str, object]]] = defaultdict(list)
    for event_index, event in enumerate(events):
        text = str(event["text"])
        for paragraph in re.finditer(r"(?ms)^\s*\S.*?(?=^\s*$|\Z)", text):
            normalized = " ".join(paragraph.group(0).split())
            if not normalized:
                continue
            source_start_line = int(event["start_line"]) + text[:paragraph.start()].count("\n")
            spans[normalized].append({
                "event_index": event_index,
                "source": event["source"],
                "source_sha256": event["sha256"],
                "selection": event["selection"],
                "span_sha256": hashlib.sha256(paragraph.group(0).encode()).hexdigest(),
                "start_line": source_start_line,
                "end_line": source_start_line + len(paragraph.group(0).splitlines()) - 1,
                "words": len(words(paragraph.group(0))),
            })
    duplicates = []
    for normalized, locations in spans.items():
        distinct_events = {location["event_index"] for location in locations}
        if len(distinct_events) > 1:
            duplicates.append({"text": normalized, "locations": locations, "words_per_copy": len(words(normalized))})
    return duplicates


def unique_source_word_count(events: list[dict[str, object]]) -> int:
    seen_source_lines = set()
    count = 0
    for event in events:
        identity = (str(event["source"]), str(event["sha256"]))
        first_line = int(event["start_line"])
        for line_offset, line in enumerate(str(event["text"]).splitlines()):
            source_line = identity + (first_line + line_offset,)
            if source_line in seen_source_lines:
                continue
            seen_source_lines.add(source_line)
            count += len(words(line))
    return count


def count_events(events: list[dict[str, object]]) -> dict[str, object]:
    total = sum(int(event["words"]) for event in events)
    unique = unique_source_word_count(events)
    duplicates = duplicate_spans(events)
    duplicate_words = sum(int(item["words_per_copy"]) * (len(item["locations"]) - 1) for item in duplicates)
    report_events = [{key: value for key, value in event.items() if key != "text"} for event in events]
    return {
        "events": report_events,
        "unique_procedural_source_words": unique,
        "total_procedural_words_delivered": total,
        "identified_duplicated_span_count": len(duplicates),
        "identified_duplicated_span_words": duplicate_words,
        "identified_duplicated_spans": duplicates,
    }


accounting_probe = count_events([
    {
        "source": "fixture.md",
        "selection": "full file",
        "sha256": "fixture-identity",
        "start_line": 1,
        "end_line": 3,
        "words": 3,
        "text": "repeat repeat\n\nword\n",
    },
    {
        "source": "fixture.md",
        "selection": "lines 1-1",
        "sha256": "fixture-identity",
        "start_line": 1,
        "end_line": 1,
        "words": 2,
        "text": "repeat repeat\n",
    },
])
if (accounting_probe["unique_procedural_source_words"], accounting_probe["total_procedural_words_delivered"], accounting_probe["identified_duplicated_span_count"], accounting_probe["identified_duplicated_span_words"]) != (3, 5, 1, 2):
    raise SystemExit("source-word overlap and repeated-delivery accounting check failed")

baseline_common = []
final_common = []
for relative in common_paths:
    baseline_content, baseline_hash = source_identity(baseline_root, relative)
    expected_hash = baseline_identities[relative]
    if baseline_hash != expected_hash:
        raise SystemExit(f"baseline common-rule identity mismatch: {relative}")
    final_content, final_hash = source_identity(source_root, relative)
    baseline_common.append({"path": relative, "sha256": baseline_hash, "words": len(words(baseline_content.decode("utf-8")))})
    final_common.append({"path": relative, "sha256": final_hash, "words": len(words(final_content.decode("utf-8")))})

baseline_section = section_event(baseline_root, "rules/common/testing.md", "Meaningful Assertions", "canonical section")
final_section = section_event(source_root, "rules/common/testing.md", "Meaningful Assertions", "canonical section")
if baseline_section["text"].encode() != final_section["text"].encode():
    raise SystemExit("canonical Meaningful Assertions section changed")

scenarios = {}
for scenario in scenario_names:
    baseline = count_events(baseline_events(scenario))
    final_source_events = final_events(scenario)
    if scenario == "executor":
        assert_executor_trace_consistency(final_source_events)
    final = count_events(final_source_events)
    scenarios[scenario] = {
        "name": scenario_names[scenario],
        "baseline": baseline,
        "final": final,
        "delta": {
            "unique_procedural_source_words": final["unique_procedural_source_words"] - baseline["unique_procedural_source_words"],
            "total_procedural_words_delivered": final["total_procedural_words_delivered"] - baseline["total_procedural_words_delivered"],
            "identified_duplicated_span_count": final["identified_duplicated_span_count"] - baseline["identified_duplicated_span_count"],
            "identified_duplicated_span_words": final["identified_duplicated_span_words"] - baseline["identified_duplicated_span_words"],
        },
    }

result = {
    "method": "LC_ALL=C whitespace-delimited word occurrences; unique source words are the union of source-line spans keyed by path, full-file SHA256 and physical line, so overlapping full/section reads count once while repeated spellings within a source span each count; total delivered sums all trace events; no runtime token estimate",
    "baseline_trace_sha256": trace_hash,
    "baseline_trace_supplements": baseline_supplements,
    "conditions": {
        "frozen_baseline": baseline_traces["conditions"],
        "harness_and_scope": "OpenCode project scope",
        "common_rules": "all common rules selected",
        "language_packs": "none",
        "failures_or_skips": "none",
        "external_payload": "same task/change payload excluded from policy totals",
        "scenario_context": scenario_context,
    },
    "scenario_context": scenario_context,
    "always_on_common_rules": {
        "paths": common_paths,
        "baseline_words": sum(item["words"] for item in baseline_common),
        "final_words": sum(item["words"] for item in final_common),
        "delta_words": sum(item["words"] for item in final_common) - sum(item["words"] for item in baseline_common),
        "baseline_sources": baseline_common,
        "final_sources": final_common,
    },
    "canonical_meaningful_assertions": {
        "byte_identical": True,
        "baseline_sha256": hashlib.sha256(baseline_section["text"].encode()).hexdigest(),
        "final_sha256": hashlib.sha256(final_section["text"].encode()).hexdigest(),
        "baseline_bytes": len(baseline_section["text"].encode()),
        "final_bytes": len(final_section["text"].encode()),
        "section": "rules/common/testing.md: ## Meaningful Assertions through the next level-two heading or end of file",
    },
    "scenarios": scenarios,
}

json_path = output_root / "policy-load-measurements.json"
markdown_path = output_root / "policy-load-measurements.md"
json_path.write_text(json.dumps(result, indent=2) + "\n")
lines = [
    "# Fixed policy-load measurements",
    "",
    f"Baseline trace SHA256: `{trace_hash}`",
    "",
    "Counts are LC_ALL=C whitespace-delimited word occurrences, not runtime tokens. Unique counts union source-line spans by path, file SHA256 and physical line, deduplicating overlapping full/section reads while preserving repeated spellings in each source span. Delivered totals count every trace event. External task payload is excluded. Baseline/final reads are explicit scenario traces, not unconditional link closure.",
    "",
    "Fixed setup: OpenCode project scope, all common rules selected, no language pack, no failures or skips, and the same external task/change payload excluded.",
    "",
    "Scenario conditions:",
]
for scenario, condition in scenario_context.items():
    lines.append(f"- {scenario_names[scenario]}: {condition}")
lines.extend([
    "",
    f"Always-on common rules: baseline {result['always_on_common_rules']['baseline_words']}, final {result['always_on_common_rules']['final_words']}, delta {result['always_on_common_rules']['delta_words']:+d} words.",
    "",
    "| Scenario | Version | Unique procedural source words | Total procedural words delivered | Duplicate spans | Duplicate-span words |",
    "|---|---:|---:|---:|---:|---:|",
])
for scenario, record in scenarios.items():
    for version in ("baseline", "final"):
        counts = record[version]
        lines.append(
            f"| {record['name']} | {version} | {counts['unique_procedural_source_words']} | {counts['total_procedural_words_delivered']} | {counts['identified_duplicated_span_count']} | {counts['identified_duplicated_span_words']} |"
        )
    delta = record["delta"]
    lines.append(
        f"| {record['name']} | delta | {delta['unique_procedural_source_words']:+d} | {delta['total_procedural_words_delivered']:+d} | {delta['identified_duplicated_span_count']:+d} | {delta['identified_duplicated_span_words']:+d} |"
    )
lines.extend([
    "",
    "Duplicated spans count exact repeated non-empty paragraphs delivered through distinct trace events within a scenario. The JSON trace names each source, section boundary, SHA256 and word count; it is a source-delivery measure, not a harness token or compliance claim.",
    "The frozen baseline trace file remains unchanged. Any required transitive baseline input omitted from it is recorded in the JSON as a provenance-backed supplement.",
    "",
    f"Canonical Meaningful Assertions bytes identical: {result['canonical_meaningful_assertions']['baseline_bytes']} bytes, SHA256 `{result['canonical_meaningful_assertions']['baseline_sha256']}`.",
])
markdown_path.write_text("\n".join(lines) + "\n")
print(markdown_path)
PY
