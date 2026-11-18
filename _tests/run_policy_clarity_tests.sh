#!/usr/bin/env bash
set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "$script_directory/.." && pwd)"

python3 - "$project_root" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "common_style": "rules/common/coding-style.md",
    "common_testing": "rules/common/testing.md",
    "javascript_style": "rules/javascript/coding-style.md",
    "go_style": "rules/go/coding-style.md",
    "typescript_style": "rules/typescript/coding-style.md",
    "rust_style": "rules/rust/coding-style.md",
    "go_tooling": "rules/go/tooling.md",
    "javascript_tooling": "rules/javascript/tooling.md",
    "typescript_tooling": "rules/typescript/tooling.md",
    "python_tooling": "rules/python/tooling.md",
    "php_tooling": "rules/php/tooling.md",
    "rust_tooling": "rules/rust/tooling.md",
    "go_testing": "rules/go/testing.md",
    "javascript_testing": "rules/javascript/testing.md",
    "typescript_testing": "rules/typescript/testing.md",
    "python_testing": "rules/python/testing.md",
    "php_testing": "rules/php/testing.md",
    "rust_testing": "rules/rust/testing.md",
    "artifacts": "skills/_shared/workflow-artifacts.md",
    "pruning": "skills/_shared/test-pruning.md",
    "readme": "README.md",
}

for relative in paths.values():
    if not (root / relative).is_file():
        print(f"[FAIL] Required source is missing: {relative}")
        raise SystemExit(1)
texts = {name: (root / relative).read_text(encoding="utf-8") for name, relative in paths.items()}
passed = 0
failed = 0


def normalise(text: str) -> str:
    return " ".join(text.split()).lower()


def section(text: str, heading: str, end_heading: str) -> str:
    try:
        content = text.split(heading, 1)[1]
    except IndexError:
        return ""
    return content.split(end_heading, 1)[0] if end_heading else content


def has_all(text: str, terms: tuple[str, ...]) -> bool:
    value = normalise(text)
    return all(normalise(term) in value for term in terms)


def has_clause(text: str, terms: tuple[str, ...]) -> bool:
    return any(has_all(line, terms) for line in text.splitlines())


def has_pattern(text: str, pattern: str) -> bool:
    return re.search(pattern, normalise(text)) is not None


def check(identifier: str, condition: bool) -> None:
    global passed, failed
    if condition:
        print(f"[PASS] {identifier}")
        passed += 1
    else:
        print(f"[FAIL] {identifier}")
        failed += 1


common_default = section(texts["common_style"], "## Default Rule: Write Code Without Comments", "## Docblocks")
functional_syntax = section(common_default, "### Required functional syntax", "")
annotations = section(texts["javascript_style"], "## Type Safety", "## Modern JavaScript")
check("C01 configured functional syntax stays minimal", has_clause(functional_syntax, ("permitted only when necessary", "configured compiler, build or type toolchain", "required framework contract")) and has_clause(functional_syntax, ("tool consumption alone", "optional ide hints", "redundant typing do not make syntax necessary")) and has_clause(functional_syntax, ("exception does not permit", "suppressions", "check-disabling directives")))
docblocks = section(texts["common_style"], "## Docblocks", "## Function and Method Length")
check("C02 required functional syntax applies in tests without permitting test prose", has_all(functional_syntax, ("production and test files", "required")) and has_clause(common_default, ("in test files", "explanatory comments and narration are forbidden")) and has_clause(common_default, ("only prose-comment exception is ticket references for regression tests",)) and has_clause(common_default, ("ban does not apply to required functional syntax", "narrow exception")) and has_clause(common_default, ("when you think explanatory prose is needed", "all three conditions above")) and has_clause(docblocks, ("restriction does not apply to required functional syntax",)))
check("C03 explanatory comments retain the three conditions", has_clause(common_default, ("external bug/limitation", "or", "non-obvious performance optimisation", "measurable benchmark")) and has_clause(common_default, ("specific ticket/issue/benchmark reference" ,)) and has_clause(common_default, ("cannot be extracted to a well-named function",)))
check("C05 JavaScript annotations are conditional", has_clause(annotations, ("project needs", "active project policy permit")) and all(has_clause(annotations, (annotation, "when needed")) for annotation in ("@param", "@returns", "@type")) and not any(re.search(r"\b(?:must|always|required|mandatory)\b", normalise(line)) for line in annotations.splitlines() if any(annotation in normalise(line) for annotation in ("@param", "@returns", "@type"))))
check("C06 JSDoc describes configured static checking rather than runtime validation", has_clause(annotations, ("configured editor assistance", "static checking")) and has_clause(annotations, ("jsdoc types do not validate values at runtime",)))
go_type_safety = section(texts["go_style"], "## Type Safety", "## Strings")
typescript_type_safety = section(texts["typescript_style"], "## Type Safety", "## Modern TypeScript")
rust_type_safety = section(texts["rust_style"], "## Type Safety", "## Strings")
check("C07 Go ignored errors require policy-permitted justification or explicit handling", has_clause(go_type_safety, ("ignore errors", "unless", "justification comment", "permitted by active project policy", "explains why")) and has_clause(go_type_safety, ("if such a comment is not permitted", "handle the error explicitly", "request direction")))
check("C08 TypeScript any rationale and removal plan require policy permission", has_clause(typescript_type_safety, ("never use", "any", "comment permitted by active project policy", "explains why", "plan to remove")) and has_clause(typescript_type_safety, ("if the comment is not permitted", "use", "unknown", "request direction")))
check("C09 Rust unwrap and expect require policy-permitted safety rationale", has_clause(rust_type_safety, ("unwrap()", "expect()", "programmer errors", "comment permitted by active project policy", "explaining why it is safe")) and has_clause(rust_type_safety, ("otherwise use explicit handling or request direction",)))
tooling_cases = (
    ("C10", "Go lint suppression", "go_tooling", "`//nolint:rulename // reason`", ("active project policy", "why", "functional syntax does not authorise")),
    ("C11", "JavaScript lint suppression", "javascript_tooling", "why", ("active project policy", "functional syntax does not authorise")),
    ("C12", "TypeScript lint suppression", "typescript_tooling", "why", ("active project policy", "functional syntax does not authorise")),
    ("C13", "Python inline-ignore suppression", "python_tooling", "ticket reference", ("active project policy", "why", "functional syntax does not authorise")),
    ("C14", "PHP static-analysis suppression", "php_tooling", "why", ("active project policy", "functional syntax does not authorise")),
    ("C15", "Rust Clippy suppression", "rust_tooling", "why", ("active project policy", "functional syntax does not authorise")),
)
for identifier, label, name, existing_requirement, conditions in tooling_cases:
    linting = section(texts[name], "## Formatting and Linting", "## Build and Run")
    suppression_clauses = [line for line in linting.splitlines() if "suppress" in normalise(line) or "silence" in normalise(line)]
    required_comment_terms = ("why", "ticket reference") if existing_requirement == "ticket reference" else ("why",)
    if name == "go_tooling":
        required_comment_terms = ("//nolint:rulename // reason",)
    valid = any(has_all(line, ("only when", "active project policy permits it", *required_comment_terms, *conditions, "fix the underlying issue or seek direction")) for line in suppression_clauses)
    check(f"{identifier} {label} eligibility", valid)

framework_cases = (
    ("C16", "Go", "go_testing", "standard `testing` package", ("testify/assert", "already uses it")),
    ("C17", "JavaScript", "javascript_testing", "vitest", ("jest", "project already uses it", "mocha/chai", "existing projects")),
    ("C18", "TypeScript", "typescript_testing", "vitest", ("jest", "project already uses it")),
    ("C19", "Python", "python_testing", "pytest", ("unittest", "preserve the established applicable framework")),
    ("C20", "PHP", "php_testing", "phpunit", ("pest", "project already uses it")),
    ("C21", "Rust", "rust_testing", "built-in test framework", ("rstest", "new projects or when the project already uses it")),
)
for identifier, language, name, preferred_framework, established_choice in framework_cases:
    framework = section(texts[name], "## Framework", "## File and Function Naming")
    preferred_clause = re.escape(preferred_framework)
    valid = has_pattern(framework, rf"use .*{preferred_clause}.* for new projects or projects without an established applicable framework")
    valid = valid and has_clause(framework, ("preserve", "established applicable framework", "existing projects"))
    valid = valid and has_clause(framework, ("do not introduce a second runner", "migrate frameworks", "approved migration"))
    valid = valid and has_clause(framework, ("framework preference", "does not authorise dependency installation"))
    valid = valid and has_clause(framework, ("multiple frameworks", "project context or ask the user", "rather than assuming a hierarchy"))
    valid = valid and has_clause(framework, ("framework-specific api instructions and examples below apply only when using the named framework", "different established applicable framework", "use its equivalent apis rather than changing frameworks to follow an example"))
    if name in ("go_testing", "javascript_testing", "typescript_testing", "php_testing"):
        valid = valid and has_clause(framework, established_choice)
    if name in ("javascript_testing", "typescript_testing"):
        structure = section(texts[name], "## Structure", "## Assertions")
        assertions = section(texts[name], "## Assertions", "## What Not to Mock")
        mocking = section(texts[name], "## What Not to Mock", "")
        valid = valid and has_clause(structure, ("for jest or vitest", "test.each"))
        assertion_apis = ("expect(value).tobe", ".toequal()", ".resolves", ".rejects")
        if name == "javascript_testing":
            assertion_apis = (*assertion_apis, ".tohavelength")
        valid = valid and all(has_clause(assertions, ("jest or vitest", api)) for api in assertion_apis)
        valid = valid and has_clause(mocking, ("for vitest timers", "vi.usefaketimers"))
    if name == "javascript_testing":
        valid = valid and "avoid mocha/chai in new code" not in normalise(framework)
    if name == "python_testing":
        valid = valid and has_clause(framework, ("unittest", "new code in existing projects"))
        valid = valid and "do not use unittest in new code" not in normalise(framework)
        naming = section(texts[name], "## File and Function Naming", "## Structure")
        structure = section(texts[name], "## Structure", "## Assertions")
        assertions = section(texts[name], "## Assertions", "## What Not to Mock")
        valid = valid and has_clause(framework, ("unittest projects", "class-level", "setup", "teardown", "subtest", "assertraises", "remain valid"))
        valid = valid and has_clause(naming, ("in pytest", "fixtures", "conftest.py"))
        valid = valid and has_clause(structure, ("for pytest", "class-based setup or teardown", "use fixtures"))
        valid = valid and has_clause(structure, ("in pytest", "pytest.mark.parametrize"))
        valid = valid and has_clause(structure, ("in pytest", "tmp_path", "monkeypatch"))
        valid = valid and has_clause(assertions, ("in pytest", "plain", "assert"))
        valid = valid and has_clause(assertions, ("for pytest exceptions", "pytest.raises"))
        valid = valid and has_clause(assertions, ("unittest", "assertRaises"))
    if name == "php_testing":
        naming = section(texts[name], "## File and Function Naming", "## Structure")
        structure = section(texts[name], "## Structure", "## Assertions")
        assertions = section(texts[name], "## Assertions", "## What Not to Mock")
        valid = valid and has_clause(naming, ("for phpunit", "test classes", "testcase"))
        valid = valid and has_clause(naming, ("for phpunit", "data providers", "dataprovider"))
        valid = valid and has_clause(structure, ("for phpunit", "setup()", "teardown()"))
        valid = valid and has_clause(structure, ("for phpunit", "data providers", "dataprovider"))
        valid = valid and all(has_clause(assertions, ("for phpunit", api)) for api in ("assertsame()", "assertequals()", "expectexception", "assertstringcontainsstring", "assertarrayhaskey"))
    if name == "go_testing":
        assertions = section(texts[name], "## Assertions", "## What Not to Mock")
        valid = valid and has_clause(assertions, ("when using", "testify/require", "testify/assert"))
    if name == "rust_testing":
        structure = section(texts[name], "## Structure", "## Assertions")
        valid = valid and has_clause(structure, ("rstest", "parameterised tests", "new projects or when the project already uses it"))
        valid = valid and has_clause(structure, ("preserve the established applicable framework", "rather than introducing", "rstest"))
        naming = section(texts[name], "## File and Function Naming", "## Structure")
        valid = valid and has_clause(naming, ("criterion", "new projects or when the established project already uses it"))
        valid = valid and has_clause(naming, ("do not replace existing benchmark tools", "install it without approved dependency changes"))
    check(f"{identifier} {language} framework scope", valid)

artifact_state = section(texts["artifacts"], "## State fields", "### Context-reduction checkpoint")
cleanup = section(texts["artifacts"], "## Clean-up contract", "")
readme_workflows = section(texts["readme"], "## Workflow skills", "### Implementation model selection")
check("C22 temporary archive eligibility keeps ownership, temporary status, scope and release gates together", has_pattern(artifact_state, r"for a recovery snapshot, also record its ownership, purpose and explicit temporary classification") and has_pattern(cleanup, r"recovery snapshot is a cleanup candidate only when that workflow created it, explicitly registered it as temporary, recorded its ownership and purpose, and it remains within the recorded owned scope") and has_pattern(cleanup, r"no longer be required for active recovery or evidence, and all applicable final review, verification and cleanup gates must permit removal") and has_pattern(cleanup, r"candidate eligibility does not release evidence or waive a gate") and has_pattern(cleanup, r"filename, extension or registration alone is not authority"))
check("C23 protected archive meanings and path safeguards remain explicit", has_pattern(cleanup, r"user-owned, pre-existing, unregistered and harness-owned archives, and user deliverables, remain protected") and has_pattern(readme_workflows, r"user-owned, pre-existing, unregistered and harness-owned archives, and user-requested deliverables.*remain protected") and has_pattern(cleanup, r"before deleting each eligible path, reject absolute paths, `\.\.` traversal, paths outside its recorded root, and any symlink in the file or parent path") and has_pattern(cleanup, r"re-check the resolved parent remains inside that root") and has_pattern(cleanup, r"preserve unregistered and unknown files, including unknown directories") and has_pattern(cleanup, r"delete `workflow\.md` last so a failure retains the recovery registry") and has_pattern(cleanup, r"if any registered file is retained or clean.?up fails, retain `workflow\.md` and report the remaining paths") and has_pattern(cleanup, r"remove the workflow directory or staging directories only if empty"))
meaningful_assertions = section(texts["common_testing"], "## Meaningful Assertions", "## Test-Driven Development")
pruning_scope = section(texts["pruning"], "## Scope and entry conditions", "### Scoped skip inputs and acceptance")
case_boundaries = section(meaningful_assertions, "### Test and case boundaries", "")
check("C25 canonical boundary ownership is consumed from the active source", "### Test and case boundaries" in meaningful_assertions and has_pattern(meaningful_assertions, r"this section is the sole canonical value rule") and has_pattern(pruning_scope, r"apply the case boundary definition from the already retrieved active canonical meaningful assertions section"))
check("C26 three harnesses checking two requirements map to six units despite aggregate PASS", has_pattern(case_boundaries, r"three harnesses checking two independent requirements produce six decision units, even when one aggregate pass is printed"))
check("C27 case boundaries distinguish scenario inputs, setup, helper targets and parent assertions", has_pattern(case_boundaries, r"a case is a separately exercised scenario or input-result combination") and has_pattern(case_boundaries, r"test setup, expected-data and expected-inventory construction, fixture copying, polling, and helper mechanics do not create cases by themselves") and has_pattern(case_boundaries, r"assertion helper checking independently driven product targets must preserve their case identities") and has_pattern(case_boundaries, r"bound distinct non-loop parent assertions separately, without double-counting parameterised children") and has_pattern(pruning_scope, r"source case.*independently varied input or outcome.*execution evidence") and has_pattern(meaningful_assertions, r"treat parameterised cases independently when their inputs or outcomes differ"))
rust_dependencies = section(texts["rust_tooling"], "## Dependency Management", "## Formatting and Linting")
check("C28 Cargo 1.2.3 is the default caret-compatible example", has_pattern(rust_dependencies, r'`"1\.2\.3"` \(default, caret-compatible\)'))
check("C29 Cargo equals 1.2.3 is the exact example", has_pattern(rust_dependencies, r'`"=1\.2\.3"` \(exact\)'))
readme_headings = re.findall(r"^## .+$", texts["readme"], re.MULTILINE)
check("C30 README loading and authoring headings are distinct and unique", readme_headings.count("## On-demand language packs") == 1 and readme_headings.count("## Writing a new language pack") == 1 and "## On-demand language packs" != "## Writing a new language pack")

print(f"Total: {passed + failed}; passed: {passed}; failed: {failed}")
if failed:
    raise SystemExit(1)
PY
