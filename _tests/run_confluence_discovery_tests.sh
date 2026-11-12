#!/usr/bin/env bash
set -euo pipefail

project_root="${ELELEM_TEST_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
fixture_mode=""
if [[ "${1:-}" == "--contract-fixture" ]]; then
    fixture_mode="${2:?}"
fi

python3 - "$project_root" "$script_path" "$fixture_mode" <<'PY'
import os
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1])
script_path = Path(sys.argv[2])
fixture_mode = sys.argv[3]
context_path = root / "skills/_shared/project-context-discovery.md"
confluence_path = root / "skills/_shared/confluence-discovery.md"
harness_note = 'Confluence context is available but not safely scoped for this run. If this repository has a stable Confluence mapping, add `.opencode/project-context.json` with a `confluence` object such as `{ "enabled": true, "space": "<space>", "rootPages": ["<page title>"], "labels": ["<label>"] }`. `space` is the preferred primary scope, `rootPages` pins exact entry pages, `labels` further narrow candidates, and `enabled: false` disables Confluence for this repository.'


def read_text(path: Path, owner: str) -> str:
    if not path.is_file():
        raise SystemExit(f"{owner} is missing: {path}")
    return path.read_text(encoding="utf-8")


def require(text: str, clauses: tuple[str, ...], failure: str) -> None:
    missing = [clause for clause in clauses if clause not in text]
    if missing:
        raise SystemExit(f"{failure}: {missing}")


def section(text: str, heading: str, next_heading: str) -> str:
    start = text.index(heading)
    end = text.index(next_heading, start)
    return text[start:end]


def validate_disabled_gate(context: str, confluence: str) -> None:
    require(
        context,
        (
            "Before loading it, check `.opencode/project-context.json` for a valid JSON `confluence.enabled` value of boolean `false`",
            "when that is present, skip Confluence entirely and do not load the helper or emit its harness note.",
        ),
        "Disabled no-load gate missing",
    )


def validate_unavailable_gate(context: str, confluence: str) -> None:
    require(
        context,
        ("If Atlassian MCP is unavailable, do not load the optional helper or emit its harness note.",),
        "Unavailable no-load gate missing",
    )


def validate_helper_loading(context: str, confluence: str) -> None:
    require(
        context,
        (
            "Consider the optional Confluence helper only when Atlassian MCP is available.",
            "resolve `./confluence-discovery.md` relative to the directory of the actually loaded `project-context-discovery.md`, not the current working directory or repository checkout.",
            "Read that sibling helper before using its schema or procedure.",
        ),
        "Relative helper loading contract missing",
    )


def validate_schema_and_selection(context: str, confluence: str) -> None:
    require(
        confluence,
        (
            "`enabled`: boolean.",
            "`space`: string.",
            "`rootPages`: array of page titles.",
            "`labels`: array of label strings",
            "Malformed JSON, wrong field types, or any other parse or validation failure",
            "A usable repository-owned config requires `space`, or `rootPages` together with a validated `space` or safe harness-provided mapping.",
            "Repository-owned Confluence config is more specific than a harness-provided mapping.",
            "Invalid repository config does not block an otherwise safe harness mapping",
            "If any configured title resolves to zero or multiple pages, repository-owned scoping is unsafe for that run.",
            "Each configured title **MUST** resolve to exactly one page.",
            "If a safe harness-provided mapping still exists, continue with that mapping.",
            "Otherwise fall back to repository context with the harness note.",
            "select at most 3 Confluence pages total.",
            "Configured `rootPages` are scope guards, not part of the 3-page cap unless a root page is itself selected as relevant context.",
            "Rank by page score, deduplicate by page ID, then order by descending score and page ID.",
            "Medium or low confidence **MUST NOT** auto-select and **MUST** fall back safely.",
            "If scoring produces medium or low confidence for the chosen space or any selected page, do not auto-use Confluence for that run.",
        ),
        "Confluence schema and selection contract missing",
    )


def validate_space_scoring(context: str, confluence: str) -> None:
    require(
        section(confluence, "### Space Scoring\n", "### Page Scoring\n"),
        (
            "+4 if the candidate exactly matches configured `space` and resolves to a unique space",
            "+4 if the candidate exactly matches a validated harness-provided mapping and resolves to a unique space",
            "+2 if the candidate name or key exactly matches a brief term or standard documentation target term",
            "+1 if the candidate is the only returned space after applying configured scope and brief terms",
            "-2 if multiple candidate spaces remain tied on the same best signals",
            "High confidence: score 4 or more, with no tie for the best score",
            "Medium confidence: score 2 to 3, or any tied best score",
            "Low confidence: score 1 or less",
        ),
        "Space scoring contract failed",
    )


def validate_page_scoring(context: str, confluence: str) -> None:
    require(
        section(confluence, "### Page Scoring\n", "## Handling Outcomes\n"),
        (
            "+4 if the page title exactly matches a configured `rootPages` entry",
            "+2 if the page title exactly matches a brief term or standard documentation target term",
            "+1 for each matching configured label, up to +2 total",
            "+1 if the page is a direct child of a resolved root page",
            "-2 if the same title resolves to multiple pages within the active scope",
            "High confidence: score 4 or more, with a unique page ID after deduplication",
            "Medium confidence: score 2 to 3",
            "Low confidence: score 1 or less",
        ),
        "Page scoring contract failed",
    )


def validate_page_medium_threshold(context: str, confluence: str) -> None:
    require(
        section(confluence, "### Page Scoring\n", "## Handling Outcomes\n"),
        ("Medium confidence: score 2 to 3",),
        "Page medium confidence threshold failed",
    )


def validate_page_low_threshold(context: str, confluence: str) -> None:
    require(
        section(confluence, "### Page Scoring\n", "## Handling Outcomes\n"),
        ("Low confidence: score 1 or less",),
        "Page low confidence threshold failed",
    )


def validate_harness_note(context: str, confluence: str) -> None:
    if confluence.count(harness_note) != 1:
        raise SystemExit("Harness note copy mismatch")
    require(
        confluence,
        (
            "The procedure **MUST** show this harness note at most once per run",
            "Do not show the note when Confluence is disabled, when a valid mapping or valid config is in use including `space`-only config, or when Atlassian MCP is unavailable.",
            "If Atlassian MCP is unavailable, skip the note.",
            "append a separate Confluence context note after the repository note, including:",
            "The Confluence space used",
            "The selected pages, with titles and page IDs",
            "The confidence level for the chosen space and each selected page",
        ),
        "Harness note suppression or supplementary output contract missing",
    )


validators = {
    "disabled": validate_disabled_gate,
    "unavailable": validate_unavailable_gate,
    "loading": validate_helper_loading,
    "space-scoring": validate_space_scoring,
    "page-scoring": validate_page_scoring,
    "page-medium": validate_page_medium_threshold,
    "page-low": validate_page_low_threshold,
    "note": validate_harness_note,
}
context = read_text(context_path, "Project context discovery owner")
confluence = read_text(confluence_path, "Confluence discovery owner")

if fixture_mode:
    validators[fixture_mode](context, confluence)
    raise SystemExit(0)


def replace_once(text: str, old: str, new: str) -> str:
    if old not in text:
        raise SystemExit(f"Mutation fixture source clause is missing: {old}")
    return text.replace(old, new, 1)


def replace_in_section(
    text: str,
    heading: str,
    next_heading: str,
    old: str,
    new: str,
) -> str:
    source_section = section(text, heading, next_heading)
    changed_section = replace_once(source_section, old, new)
    return text.replace(source_section, changed_section, 1)


def write_fixture_sources(fixture_root: Path, changed_file: str, mutated: str) -> None:
    shared_directory = fixture_root / "skills/_shared"
    shared_directory.mkdir(parents=True)
    (shared_directory / "project-context-discovery.md").write_text(
        mutated if changed_file == "context" else context,
        encoding="utf-8",
    )
    (shared_directory / "confluence-discovery.md").write_text(
        mutated if changed_file == "confluence" else confluence,
        encoding="utf-8",
    )


def run_fixture_validation(fixture_root: Path, mode: str) -> subprocess.CompletedProcess[str]:
    environment = os.environ.copy()
    environment["ELELEM_TEST_ROOT"] = str(fixture_root)
    return subprocess.run(
        ["bash", str(script_path), "--contract-fixture", mode],
        capture_output=True,
        check=False,
        env=environment,
        text=True,
    )


def run_mutation_fixture(
    name: str,
    mode: str,
    changed_file: str,
    original: str,
    replacement: str,
    expected_failure: str,
    add_clause_before_mutation: bool = False,
    section_scope: tuple[str, str] | None = None,
) -> None:
    source = context if changed_file == "context" else confluence
    if add_clause_before_mutation and original not in source:
        source = f"{source}\n{original}\n"
    if section_scope:
        mutated = replace_in_section(source, *section_scope, original, replacement)
    else:
        mutated = replace_once(source, original, replacement)
    if section_scope == ("### Page Scoring\n", "## Handling Outcomes\n"):
        validate_space_scoring(context, mutated)
    with tempfile.TemporaryDirectory(prefix="confluence-contract-") as temporary_directory:
        fixture_root = Path(temporary_directory)
        write_fixture_sources(fixture_root, changed_file, mutated)
        result = run_fixture_validation(fixture_root, mode)
        output = result.stdout + result.stderr
        if result.returncode == 0 or expected_failure not in output:
            raise SystemExit(f"{name} mutation was not rejected by its intended contract: {output}")
    print(f"[PASS] {name} source mutation rejected")


run_mutation_fixture(
    "unavailable load exclusion",
    "unavailable",
    "context",
    "If Atlassian MCP is unavailable, do not load the optional helper or emit its harness note.",
    "If Atlassian MCP is unavailable, load the optional helper and emit its harness note.",
    "Unavailable no-load gate missing",
    add_clause_before_mutation=True,
)
run_mutation_fixture(
    "relative helper loading",
    "loading",
    "context",
    "resolve `./confluence-discovery.md` relative to the directory of the actually loaded `project-context-discovery.md`, not the current working directory or repository checkout.",
    "Resolve `./confluence-discovery.md` relative to the repository checkout.",
    "Relative helper loading contract missing",
    add_clause_before_mutation=True,
)

validate_disabled_gate(context, confluence)
validate_unavailable_gate(context, confluence)
validate_helper_loading(context, confluence)
validate_schema_and_selection(context, confluence)
validate_space_scoring(context, confluence)
validate_page_scoring(context, confluence)
validate_harness_note(context, confluence)
PY
