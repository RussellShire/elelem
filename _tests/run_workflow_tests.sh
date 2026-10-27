#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/elelem-workflow-tests.XXXXXX")" || {
  printf '[FAIL] temporary_directory: could not create test directory\n' >&2
  exit 1
}
trap '[[ -n "${TEST_TMP:-}" ]] && rm -rf -- "$TEST_TMP"' EXIT

source "$REPO_ROOT/_install-common.sh"
source "$REPO_ROOT/install-codex.sh"

passed=0
failed=0
workflow_files=(
  "skills/workflow-coordinator/SKILL.md"
  "skills/research/SKILL.md"
  "skills/wave-planning/SKILL.md"
  "skills/_shared/workflow-artifacts.md"
  "skills/_shared/task-briefs.md"
  "skills/_shared/wave-readiness.md"
)
skill_files=(
  "skills/workflow-coordinator/SKILL.md"
  "skills/research/SKILL.md"
  "skills/wave-planning/SKILL.md"
)

_pass() {
  printf '[PASS] %s\n' "$1"
  (( passed++ )) || true
}

_fail() {
  printf '[FAIL] %s: %s\n' "$1" "$2"
  (( failed++ )) || true
}

_load_array() {
  local array_name="$1"
  local installer="$2"
  local declaration
  declaration="$(awk -v name="$array_name" 'substr($0, 1, length(name) + 2) == name "=(" {copy=1} copy {print} copy && $0 == ")" {exit}' "$installer")"
  if [[ -z "$declaration" ]]; then
    return 1
  fi
  eval "$declaration"
}

_load_function() {
  local function_name="$1"
  local installer="$2"
  local declaration
  declaration="$(awk -v name="$function_name" 'substr($0, 1, length(name) + 4) == name "() {" {copy=1} copy {print} copy && $0 == "}" {exit}' "$installer")"
  if [[ -z "$declaration" ]]; then
    return 1
  fi
  eval "$declaration"
}

_check_required_files() {
  local file
  local missing=0
  for file in "${workflow_files[@]}"; do
    if [[ ! -f "$REPO_ROOT/$file" ]]; then
      _fail "required_file_${file//\//_}" "expected $file to exist"
      missing=1
    else
      _pass "required_file_${file//\//_}"
    fi
  done
  return "$missing"
}

_check_skill_frontmatter() {
  local file relative name frontmatter
  for relative in "${skill_files[@]}"; do
    file="$REPO_ROOT/$relative"
    name="${relative#skills/}"
    name="${name%/SKILL.md}"
    if [[ ! -f "$file" ]]; then
      continue
    fi
    frontmatter="$(sed -n '2,/^---$/p' "$file" | sed '$d')"
    if [[ "$(head -n 1 "$file")" != '---' ]] || ! awk 'NR > 1 && $0 == "---" {found=1; exit} END {exit !found}' "$file" || ! printf '%s\n' "$frontmatter" | grep -Eq "^name: ${name//\//-}$" || ! printf '%s\n' "$frontmatter" | grep -Eq '^name: [a-z0-9]+(-[a-z0-9]+)*$'; then
      _fail "skill_frontmatter_${name//\//_}" "expected YAML frontmatter with name ${name//\//-}"
    else
      _pass "skill_frontmatter_${name//\//_}"
    fi
  done
}

_copy_and_substitute_harness() {
  local harness="$1"
  local target="$2"
  local resolve_function="$3"
  local placeholders_ref="$4"
  local substitutions_ref="$5"
  local file manifest=() files=()
  local source_dir="$REPO_ROOT/skills"
  mkdir -p "$target"
  for file in "${workflow_files[@]}"; do
    if [[ ! -f "$source_dir/${file#skills/}" ]]; then
      _fail "${harness}_installer_copy_and_substitution" "source files are incomplete; cannot exercise installer helpers"
      return
    fi
    files+=("${file#skills/}")
  done
  install_files_from_dir "$source_dir" "$target" skills manifest files "$resolve_function"
  substitute_tool_names "$target" "$placeholders_ref" "$substitutions_ref"
  for file in "${files[@]}"; do
    if [[ ! -f "$target/$file" ]]; then
      _fail "${harness}_installer_copy_and_substitution" "installer helper did not copy $file"
      return
    fi
    if grep -q '{{' "$target/$file"; then
      _fail "${harness}_installer_copy_and_substitution" "unsubstituted tool placeholder remains in $file"
      return
    fi
  done
  _pass "${harness}_installer_copy_and_substitution"
}

test_claude_installer_copy_and_substitution() {
  local installer="$REPO_ROOT/install-claude.sh"
  SKILLS_SOURCE="$REPO_ROOT/skills"
  if ! _load_array CLAUDE_PLACEHOLDERS "$installer" || ! _load_array CLAUDE_SUBSTITUTIONS "$installer" || ! _load_function _skill_resolve_dst "$installer"; then
    _fail "claude_installer_copy_and_substitution" "could not extract installer maps or destination resolver"
    return
  fi
  _copy_and_substitute_harness claude "$TEST_TMP/claude/skills" _skill_resolve_dst CLAUDE_PLACEHOLDERS CLAUDE_SUBSTITUTIONS
}

test_opencode_installer_copy_and_substitution() {
  local installer="$REPO_ROOT/install-opencode.sh"
  SKILLS_SOURCE="$REPO_ROOT/skills"
  if ! _load_array OPENCODE_PLACEHOLDERS "$installer" || ! _load_array OPENCODE_SUBSTITUTIONS "$installer" || ! _load_function _skill_resolve_dst "$installer"; then
    _fail "opencode_installer_copy_and_substitution" "could not extract installer maps or destination resolver"
    return
  fi
  _copy_and_substitute_harness opencode "$TEST_TMP/opencode/skills" _skill_resolve_dst OPENCODE_PLACEHOLDERS OPENCODE_SUBSTITUTIONS
}

test_codex_installer_copy_and_substitution() {
  local target="$TEST_TMP/codex/skills"
  local file manifest=() files=()
  local source_dir="$REPO_ROOT/skills"
  mkdir -p "$target"
  for file in "${workflow_files[@]}"; do
    if [[ ! -f "$source_dir/${file#skills/}" ]]; then
      _fail "codex_installer_copy_and_substitution" "source files are incomplete; cannot exercise installer helpers"
      return
    fi
    files+=("${file#skills/}")
  done
  install_files_from_dir "$source_dir" "$target" .agents/skills manifest files _codex_skill_resolve_dst
  _codex_substitute_placeholders_tree "$target"
  if ! scan_no_unsubstituted_placeholders "$target"; then
    _fail "codex_installer_copy_and_substitution" "Codex installer scan found unresolved placeholders"
    return
  fi
  for file in "${files[@]}"; do
    if [[ ! -f "$target/$file" ]]; then
      _fail "codex_installer_copy_and_substitution" "installer helper did not copy $file"
      return
    fi
    if grep -q '{{' "$target/$file"; then
      _fail "codex_installer_copy_and_substitution" "unsubstituted tool placeholder remains in $file"
      return
    fi
  done
  _pass "codex_installer_copy_and_substitution"
}

test_stale_workflow_lifecycle_instructions_are_absent() {
  local file stale=0
  local targets=(
    "rules/common/workflow.md"
    "rules/common/skills-policy.md"
    "skills/brainstorming/SKILL.md"
  )
  local patterns=(
    'The Brainstorming Router Is the Design Step'
    'The router enters plan mode and asks the user to pick one of four modes'
    'Before any code edit, no matter how small: brainstorming'
  )
  local index
  for file in "${targets[@]}"; do
    if [[ ! -f "$REPO_ROOT/$file" ]]; then
      continue
    fi
    for index in "${!patterns[@]}"; do
      if grep -Fq "${patterns[$index]}" "$REPO_ROOT/$file"; then
        _fail "stale_workflow_lifecycle_${index}_${file//\//_}" "obsolete lifecycle instruction remains in $file"
        stale=1
      fi
    done
  done
  if (( stale == 0 )); then
    _pass "stale_workflow_lifecycle_instructions_are_absent"
  fi
}

test_gitignore_excludes_workflow_artifacts() {
  local synthetic="$REPO_ROOT/.elelem/workflows/automated-test-probe.md"
  if git -C "$REPO_ROOT" check-ignore -q --no-index "$synthetic"; then
    _pass "gitignore_excludes_workflow_artifacts"
  else
    _fail "gitignore_excludes_workflow_artifacts" "git check-ignore did not exclude /.elelem/workflows/"
  fi
}

test_new_markdown_links_resolve() {
  local relative file markdown_link target unresolved=0 inspected=0
  for relative in "${workflow_files[@]}"; do
    file="$REPO_ROOT/$relative"
    [[ -f "$file" ]] || continue
    (( inspected++ )) || true
    while IFS= read -r markdown_link; do
      target="${markdown_link%%#*}"
      target="${target%%\?*}"
      [[ -z "$target" || "$target" == http:* || "$target" == https:* || "$target" == mailto:* || "$target" == *'{{'* ]] && continue
      if [[ ! -e "$(dirname "$file")/$target" ]]; then
        _fail "markdown_link_${relative//\//_}" "linked path does not exist: $target"
        unresolved=1
      fi
    done < <(grep -Eo '\]\([^)]*\)' "$file" | sed -E 's/^\]\(([^)]*)\)$/\1/' || true)
  done
  if (( inspected == 0 )); then
    _fail "new_markdown_links_resolve" "no new workflow documents were available to inspect"
  elif (( unresolved == 0 )); then
    _pass "new_markdown_links_resolve"
  fi
}

_is_source_reference() {
  local reference="$1"
  [[ "$reference" =~ ^(\./|\.\./)[A-Za-z0-9_./-]+\.md$ ]] && return 0
  case "$reference" in
    workflow-artifacts.md|task-briefs.md|wave-readiness.md) return 0 ;;
  esac
  return 1
}

test_new_backticked_source_references_resolve() {
  local relative file reference target unresolved=0 inspected=0
  for relative in "${workflow_files[@]}"; do
    file="$REPO_ROOT/$relative"
    [[ -f "$file" ]] || continue
    while IFS= read -r reference; do
      _is_source_reference "$reference" || continue
      (( inspected++ )) || true
      if [[ "$reference" == "./"* || "$reference" == "../"* ]]; then
        target="$(dirname "$file")/$reference"
      else
        target="$REPO_ROOT/skills/_shared/$reference"
      fi
      if [[ ! -e "$target" ]]; then
        _fail "source_reference_${relative//\//_}" "referenced source file does not exist: $reference"
        unresolved=1
      fi
    done < <(grep -Eo '`[^`]+\.md`' "$file" | sed -E 's/^`([^`]*)`$/\1/' || true)
  done
  if (( inspected == 0 )); then
    _fail "new_backticked_source_references_resolve" "no source references were available to inspect"
  elif (( unresolved == 0 )); then
    _pass "new_backticked_source_references_resolve"
  fi
}

_check_readiness_contract_reference() {
  local relative="$1"
  local test_name="$2"
  local file="$REPO_ROOT/$relative"
  local token
  local missing=0
  local tokens=(
    '../_shared/wave-readiness.md'
    'readiness review'
    'SKIPPED'
    'scope'
    'planner'
    'checks'
  )
  for token in "${tokens[@]}"; do
    if [[ "$token" == 'readiness review' ]]; then
      grep -Eiq 'readiness[[:space:]-]+review' "$file" && continue
    elif grep -Fq "$token" "$file"; then
      continue
    fi
    _fail "$test_name" "expected $relative to reference readiness contract token: $token"
    missing=1
  done
  if (( missing == 0 )); then
    _pass "$test_name"
  fi
}

test_parallel_agent_readiness_contract_reference() {
  _check_readiness_contract_reference "skills/dispatching-parallel-agents/SKILL.md" "parallel_agent_readiness_contract_reference"
}

test_fast_path_readiness_contract_reference() {
  _check_readiness_contract_reference "skills/fast-path-implementation/SKILL.md" "fast_path_readiness_contract_reference"
}

test_required_files_exist() {
  _check_required_files || true
}

test_required_files_exist
_check_skill_frontmatter
test_claude_installer_copy_and_substitution
test_opencode_installer_copy_and_substitution
test_codex_installer_copy_and_substitution
test_stale_workflow_lifecycle_instructions_are_absent
test_gitignore_excludes_workflow_artifacts
test_new_markdown_links_resolve
test_new_backticked_source_references_resolve
test_parallel_agent_readiness_contract_reference
test_fast_path_readiness_contract_reference

total=$(( passed + failed ))
printf '\n%s/%s tests passed\n' "$passed" "$total"
(( failed == 0 )) || exit 1
