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
  "skills/brainstorming/SKILL.md"
  "skills/work-on-ticket/SKILL.md"
  "skills/fast-path-implementation/SKILL.md"
  "skills/wave-planning/SKILL.md"
  "skills/_shared/phase-evidence.md"
  "skills/_shared/workflow-artifacts.md"
  "skills/_shared/task-briefs.md"
  "skills/_shared/wave-readiness.md"
  "skills/_shared/test-pruning.md"
  "skills/test-driven-development/SKILL.md"
  "skills/subagent-driven-development/SKILL.md"
  "skills/subagent-driven-development/implementer-prompt.md"
  "skills/subagent-driven-development/reviewer-prompt.md"
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

test_test_pruning_contract_is_documented() {
  local file token requirement normalized missing=0
  local requirements=(
    "rules/common/testing.md|Meaningful Assertions"
    "rules/common/testing.md|distinct defects"
    "skills/_shared/test-pruning.md|uncertain"
    "skills/_shared/test-pruning.md|distinct"
    "skills/_shared/test-pruning.md|survivor"
    "skills/_shared/test-pruning.md|read-only"
    "skills/_shared/test-pruning.md|NOT APPLICABLE"
    "skills/_shared/test-pruning.md|canonical value rule"
    "skills/_shared/test-pruning.md|pre-prune"
    "skills/_shared/test-pruning.md|post-prune"
    "skills/_shared/test-pruning.md|discovery-count"
    "skills/_shared/test-pruning.md|invalidation"
    "skills/_shared/test-pruning.md|workflow.md"
    "skills/_shared/test-pruning.md|{{DISPATCH_AGENT_TOOL}}"
    "skills/_shared/test-pruning.md|COMPLETE CURRENT MEANINGFUL ASSERTIONS SECTION VERBATIM"
    "skills/_shared/test-pruning.md|TASK_START_HEAD_AND_BASELINE_REFERENCE"
    "skills/_shared/test-pruning.md|PRE_EXISTING_CONTENT_IDENTITIES_OR_SNAPSHOTS"
    "skills/_shared/test-pruning.md|ACTUAL_TASK_DIFF_PATHS_AND_SCOPE_EVIDENCE"
    "skills/_shared/test-pruning.md|TEST_SOURCE_AND_CONTEXT"
    "skills/_shared/test-pruning.md|INPUT_PATHS_AND_CONTENT_IDENTITIES"
    "skills/_shared/test-pruning.md|ACTIVE_TASK_OWNERSHIP_AND_STABILITY_EVIDENCE"
    "skills/_shared/test-pruning.md|APPROVED_BEHAVIOUR_TO_REQUIREMENT_MAP"
    "skills/_shared/test-pruning.md|PRE_PRUNE_CHECKS_AND_DISCOVERY_COUNTS"
    "skills/_shared/test-pruning.md|POST_PRUNE_COMMAND_AND_COUNTING_METHOD"
    "skills/_shared/test-pruning.md|RECOVERY"
    "skills/_shared/test-pruning.md|survivor stability"
    "skills/test-driven-development/SKILL.md|TDD-only skip"
    "skills/test-driven-development/SKILL.md|Assertions protect named behaviour"
    "skills/subagent-driven-development/SKILL.md|pre-prune"
    "skills/subagent-driven-development/SKILL.md|post-prune"
    "skills/subagent-driven-development/SKILL.md|no nested audit dispatch"
    "skills/subagent-driven-development/implementer-prompt.md|baseline"
    "skills/subagent-driven-development/implementer-prompt.md|recovery"
    "skills/subagent-driven-development/implementer-prompt.md|Do not prune"
    "skills/subagent-driven-development/implementer-prompt.md|audit your own work"
    "skills/subagent-driven-development/reviewer-prompt.md|survivor mapping"
    "skills/subagent-driven-development/reviewer-prompt.md|final green snapshot"
    "skills/subagent-driven-development/reviewer-prompt.md|Important finding"
    "README.md|test pruning"
    "README.md|live"
  )
  for requirement in "${requirements[@]}"; do
    file="${requirement%%|*}"
    token="${requirement#*|}"
    if [[ ! -f "$REPO_ROOT/$file" ]]; then
      _fail "test_pruning_contract_${file//\//_}_${token//[^[:alnum:]]/_}" "expected $file to document $token"
      missing=1
      continue
    fi
    normalized="$(tr '\n' ' ' < "$REPO_ROOT/$file" | tr -s '[:space:]' ' ')"
    if ! grep -Fqi "$token" <<< "$normalized"; then
      _fail "test_pruning_contract_${file//\//_}_${token//[^[:alnum:]]/_}" "expected $file to document $token"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "test_pruning_contract_is_documented"
  fi
}

test_tdd_completion_gate_is_behaviour_based() {
  local file="$REPO_ROOT/skills/test-driven-development/SKILL.md"
  local content
  content="$(tr '\n' ' ' < "$file")"
  if grep -Fq 'Every new function or method has a test' <<< "$content" || grep -Fq 'Edge cases and error paths covered' <<< "$content"; then
    _fail "tdd_completion_gate_is_behaviour_based" "generic function and edge-case checklist remains"
    return
  fi
  if ! grep -Eiq 'Every new (or changed )?behaviour' <<< "$content" || ! grep -Eiq 'cases?[^.]{0,120}(defined|derived|mapped)[^.]{0,120}approved behaviours' <<< "$content"; then
    _fail "tdd_completion_gate_is_behaviour_based" "expected new behaviours and behaviour-defined cases in the completion gate"
    return
  fi
  _pass "tdd_completion_gate_is_behaviour_based"
}

test_pruning_safety_gates_are_explicit() {
  local helper="$REPO_ROOT/skills/_shared/test-pruning.md"
  local helper_content
  helper_content="$(tr '\n' ' ' < "$helper")"
  if ! grep -Eiq 'non-zero exit (status|code)' <<< "$helper_content" || ! grep -Eiq 'blocks? (any )?removal' <<< "$helper_content"; then
    _fail "pruning_safety_gates_are_explicit" "a non-zero pre-prune check must block removals"
    return
  fi
  if ! grep -Eiq 'worker[^.]{0,100}restor' <<< "$helper_content" || ! grep -Eiq 'coordinator[^.]{0,100}(must not|does not|never)[^.]{0,80}(edit|restor|apply)' <<< "$helper_content"; then
    _fail "pruning_safety_gates_are_explicit" "restoration must be assigned to a worker, not coordinator edits"
    return
  fi
  _pass "pruning_safety_gates_are_explicit"
}

test_auditor_rule_source_is_harness_aware_and_bounded() {
  local helper="$REPO_ROOT/skills/_shared/test-pruning.md"
  local content requirement pattern missing=0
  content="$(tr '\n' ' ' < "$helper")"
  local requirements=(
    'Claude Code source|Claude Code.{0,160}rules/common/testing\.md'
    'OpenCode source|OpenCode.{0,160}rules/common/testing\.md'
    'Codex source|Codex.{0,200}(AGENTS\.md.{0,100}rules/common/testing\.md|rules/common/testing\.md.{0,100}AGENTS\.md)'
    'Codex managed block|Codex.{0,200}(active.{0,100}elelem-managed.{0,100}AGENTS\.md|AGENTS\.md.{0,100}active.{0,100}elelem-managed)'
    'exact section|only.{0,100}Meaningful Assertions section.{0,100}verbatim'
    'section boundary|next level-two heading'
    'unavailable authority|authoritative.{0,160}(unavailable|cannot be retrieved)'
    'blocked dispatch|block.{0,100}dispatch'
  )
  for requirement in "${requirements[@]}"; do
    pattern="${requirement#*|}"
    if ! grep -Eiq "$pattern" <<< "$content"; then
      _fail "auditor_rule_source_${requirement%%|*}" "expected harness-specific authoritative rule retrieval contract"
      missing=1
    fi
  done
  if (( missing == 0 )); then
    _pass "auditor_rule_source_is_harness_aware_and_bounded"
  fi
}

test_audit_invalidation_uses_accepted_green_snapshot() {
  local helper="$REPO_ROOT/skills/_shared/test-pruning.md"
  local content
  content="$(tr '\n' ' ' < "$helper")"
  if ! grep -Eiq 'accepted post-prune snapshot' <<< "$content" || ! grep -Eiq 'exact authorised pruning changes' <<< "$content" || ! grep -Eiq 'authorised pruning changes (do not|must not) invalidate' <<< "$content"; then
    _fail "audit_invalidation_uses_accepted_green_snapshot" "invalidation must distinguish accepted pruning changes from later input changes"
    return
  fi
  _pass "audit_invalidation_uses_accepted_green_snapshot"
}

test_test_pruning_helper_installs_and_skill_links_resolve() {
  local harness root skill relative target unresolved=0
  local harnesses=(claude opencode codex)
  local skills=("test-driven-development/SKILL.md" "subagent-driven-development/SKILL.md")
  for harness in "${harnesses[@]}"; do
    root="$TEST_TMP/$harness/skills"
    for skill in "${skills[@]}"; do
      relative="../_shared/test-pruning.md"
      if ! grep -Fq "$relative" "$root/$skill" || [[ ! -f "$root/$(dirname "$skill")/$relative" ]]; then
        _fail "${harness}_test_pruning_skill_link_${skill//\//_}" "expected the installed skill link to resolve to the shared helper"
        unresolved=1
      else
        _pass "${harness}_test_pruning_skill_link_${skill//\//_}"
      fi
    done
  done
  (( unresolved == 0 ))
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

test_phase_evidence_contract() {
  local relative="skills/_shared/phase-evidence.md"
  local content="" requirement pattern
  local requirements=(
    'boundary validation|entry, transitions, handover, resume, reuse and execution'
    'ordered upstream gate|validate applicable upstream phases in order'
    'scope identity|scope, revision and current assumptions'
    'procedure provenance|actual procedure provenance'
    'required outputs|outputs and required user choices'
    'invocation is insufficient|Loading a skill.*cannot establish procedural work'
    'later approval is insufficient|later review or approval cannot establish omitted procedures'
    'Research dialogue|Research:.*dialogue.*separately user-selected alternative'
    'Planning method|Planning:.*explicit method selection.*selected-mode invocation.*proposal'
    'separate committee choice|Planning committee.*cannot retrospectively authorise autonomous Research'
    'skip provenance|exact-source user instruction.*scope, reason and consequence'
    'implement is not skip|implement.*mode switch.*not.*skip'
    'lightweight method is not skip|brainstorming-skip.*not a phase skip'
    'missing dependent inputs|Missing dependent inputs still block'
    'valid delayed recording|Record legitimate prior evidence later only with accessible provenance'
    'unsupported recovery|earliest unsupported phase'
    'no fabricated history|Do not invent history or backfill unsupported claims'
    'preserve valid work|Preserve useful findings, code, user work and genuinely valid evidence'
    'affected downstream revalidation|revalidate affected downstream reviews, approval and readiness'
    'bounded persistence|existing.*workflow.md.*no separate report'
    'not per tool call|not.*per-tool-call.*checks'
    'procedural limitation|procedural gate, not runtime enforcement'
  )
  if [[ -f "$REPO_ROOT/$relative" ]]; then
    content="$(tr '\n' ' ' < "$REPO_ROOT/$relative" | tr -s '[:space:]' ' ')"
  fi
  for requirement in "${requirements[@]}"; do
    pattern="${requirement#*|}"
    if grep -Eiq "$pattern" <<< "$content"; then
      _pass "phase_evidence_${requirement%%|*}"
    else
      _fail "phase_evidence_${requirement%%|*}" "expected $relative to protect this phase evidence requirement"
    fi
  done
}

test_phase_evidence_boundary_references() {
  local requirement file token content
  local requirements=(
    'rules/common/workflow.md|skills/_shared/phase-evidence.md'
    'rules/common/workflow.md|before implementation-oriented proposals'
    'rules/common/skills-policy.md|skills/_shared/phase-evidence.md'
    'skills/workflow-coordinator/SKILL.md|../_shared/phase-evidence.md'
    'skills/workflow-coordinator/SKILL.md|entry, transitions, handover, resume, reuse and execution'
    'skills/_shared/workflow-artifacts.md|./phase-evidence.md'
    'skills/research/SKILL.md|../_shared/phase-evidence.md'
    'skills/brainstorming/SKILL.md|../_shared/phase-evidence.md'
    'skills/work-on-ticket/SKILL.md|upstream gaps to the coordinator'
    'skills/fast-path-implementation/SKILL.md|upstream gaps to the coordinator'
    'skills/subagent-driven-development/SKILL.md|upstream gaps to the coordinator'
    'README.md|procedural gate, not runtime enforcement'
  )
  for requirement in "${requirements[@]}"; do
    file="${requirement%%|*}"
    token="${requirement#*|}"
    content="$(tr '\n' ' ' < "$REPO_ROOT/$file" | tr -s '[:space:]' ' ')"
    if grep -Fqi "$token" <<< "$content"; then
      _pass "phase_evidence_boundary_${file//\//_}_${token//[^[:alnum:]]/_}"
    else
      _fail "phase_evidence_boundary_${file//\//_}_${token//[^[:alnum:]]/_}" "expected boundary contract: $token"
    fi
  done
}

test_phase_evidence_installed_links_resolve() {
  local harness root relative link
  local harnesses=(claude opencode codex)
  local files=(
    'workflow-coordinator/SKILL.md' 'research/SKILL.md' 'brainstorming/SKILL.md'
    'work-on-ticket/SKILL.md' 'fast-path-implementation/SKILL.md'
    'subagent-driven-development/SKILL.md' '_shared/workflow-artifacts.md'
  )
  for harness in "${harnesses[@]}"; do
    root="$TEST_TMP/$harness/skills"
    for relative in "${files[@]}"; do
      link='../_shared/phase-evidence.md'
      [[ "$relative" == '_shared/workflow-artifacts.md' ]] && link='./phase-evidence.md'
      if [[ -f "$root/$relative" ]] && grep -Fq "$link" "$root/$relative" && [[ -f "$root/$(dirname "$relative")/$link" ]]; then
        _pass "${harness}_phase_evidence_link_${relative//\//_}"
      else
        _fail "${harness}_phase_evidence_link_${relative//\//_}" "expected installed boundary reference to resolve to the canonical helper"
      fi
    done
  done
}

test_required_files_exist() {
  _check_required_files || true
}

_check_skill_frontmatter
test_phase_evidence_contract
test_phase_evidence_boundary_references
test_claude_installer_copy_and_substitution
test_opencode_installer_copy_and_substitution
test_codex_installer_copy_and_substitution
test_test_pruning_contract_is_documented
test_test_pruning_helper_installs_and_skill_links_resolve
test_tdd_completion_gate_is_behaviour_based
test_pruning_safety_gates_are_explicit
test_auditor_rule_source_is_harness_aware_and_bounded
test_audit_invalidation_uses_accepted_green_snapshot
test_stale_workflow_lifecycle_instructions_are_absent
test_gitignore_excludes_workflow_artifacts
test_new_markdown_links_resolve
test_new_backticked_source_references_resolve
test_parallel_agent_readiness_contract_reference
test_fast_path_readiness_contract_reference
test_phase_evidence_installed_links_resolve

total=$(( passed + failed ))
printf '\n%s/%s tests passed\n' "$passed" "$total"
(( failed == 0 )) || exit 1
