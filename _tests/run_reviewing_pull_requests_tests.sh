#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/elelem-pr-review-tests.XXXXXX")" || exit 1
trap '[[ -n "${TEST_TMP:-}" ]] && rm -rf -- "$TEST_TMP"' EXIT
source "$REPO_ROOT/_install-common.sh"
source "$REPO_ROOT/install-codex.sh"
set +e

passed=0
failed=0
SKILL="$REPO_ROOT/skills/reviewing-pull-requests/SKILL.md"

_pass() { printf '[PASS] %s\n' "$1"; ((passed++)) || true; }
_fail() { printf '[FAIL] %s: %s\n' "$1" "$2"; ((failed++)) || true; }

_load_declaration() {
  local name="$1" file="$2" kind="$3" declaration
  declaration="$(awk -v name="$name" -v kind="$kind" 'index($0, name kind) == 1 {copy=1} copy {print} copy && (kind == "=(" ? $0 == ")" : $0 == "}") {exit}' "$file")"
  [[ -n "$declaration" ]] || return 1
  eval "$declaration"
}

_test_contract() {
  local content startup_content requirement startup_requirement label pattern
  local requirements=(
    'pasted fallback|integration.{0,160}paste'
    'main first comparison|comparison branch first.{0,140}main.{0,80}first choice'
    'comparison typed alternative|native free.form input is unavailable.{0,100}explicit.{0,20}other.{0,100}type the branch'
    'comparison has no default|do not preselect a branch.{0,80}assume a default'
    'branch only discovery|inspect only.{0,100}checked.out PR branch.{0,100}GIT_OPTIONAL_LOCKS=0.{0,100}(obvious issue key|branch.name search hint)'
    'no usable hint manual route|no usable hint.{0,100}skip the lookup.{0,160}directly to asking for a ticket reference'
    'request key excluded|do not infer an issue key from the request'
    'discovery only without supplied ticket|if the user supplied.{0,100}skip Jira discovery'
    'one read.only Jira attempt|one best.effort read.only Jira (lookup|search).{0,160}do not retry'
    'one result confirmation|exactly one usable Jira match.{0,255}(Yes, continue|yes.{0,30}continue).{0,180}proceed only after the user explicitly confirms'
    'multiple Jira choices|multiple distinct issue keys and summaries.{0,180}single.select choices in that prompt'
    'manual ticket override|manual override.{0,160}(type|enter|alternate)'
    'ticket typed alternative|always allow the user to enter a different ticket through native free.form input or an explicit.{0,5}other.{0,10}choice followed by asking them to type'
    'unavailable Jira explanation|briefly say.{0,100}lookup could not be completed.{0,100}without suggesting that the issue does not exist'
    'failed discovery manual route|Jira is unavailable.{0,100}lookup fails or times out.{0,100}no usable match.{0,200}go straight to asking.{0,100}ticket reference'
    'scope confirmation|purpose.{0,100}acceptance criteria.{0,100}dependencies.{0,100}exclusions.{0,200}confirm'
    'clarify criteria|do not infer.{0,100}acceptance criteria'
    'git boundaries|HEAD.{0,100}base tip.{0,100}merge.base.{0,100}status'
    'base validation|ambiguous.{0,100}(pause|stop)'
    'committed range|merge.base.{0,100}pinned HEAD'
    'dirty contamination|dirty.{0,200}contaminat.{0,100}pause'
    'freshness|local refs.{0,100}stale.{0,100}remote.{0,100}unverified'
    'interactive walkthrough|each section.{0,160}(questions|continue).{0,100}pause'
    'review coverage|correctness.{0,100}ticket coverage.{0,100}regressions.{0,100}edge cases.{0,100}tests'
    'finding evidence|trigger.{0,100}consequence.{0,100}(source|evidence)'
    'finding categories|defects.{0,100}questions.{0,100}preferences'
    'severity gate|unresolved.{0,50}Critical.{0,50}Important.{0,100}(approval|approve)'
    'missing evidence gate|missing material evidence.{0,100}(approval|approve)'
    'recommendation choices|approve.{0,60}request changes.{0,60}insufficient evidence'
    'no guarantee|no issues found.{0,100}(not|never).{0,100}guarantee'
    'drift recheck|recheck.{0,100}refs.{0,100}status.{0,100}ticket scope'
    'drift invalidation|material drift.{0,100}invalidat'
    'no actions|no.{0,100}edits.{0,100}remote comments.{0,100}merge.{0,100}commits.{0,100}push'
    'no tests or fetch|no.{0,240}fetch.{0,100}automatic test'
  )
  if [[ ! -f "$SKILL" ]]; then _fail skill_exists 'required review skill is missing'; return; fi
  content="$(tr '\n' ' ' < "$SKILL" | tr -s '[:space:]' ' ')"
  for requirement in "${requirements[@]}"; do
    label="${requirement%%|*}"; pattern="${requirement#*|}"
    if grep -Eiq "$pattern" <<< "$content"; then _pass "$label"; else _fail "$label" 'required instruction missing'; fi
  done
  startup_content="$(awk '/^## 1\. Ticket and comparison branch$/ {capture=1; next} /^## 2\. Git boundaries and review inputs$/ {capture=0} capture {print}' "$SKILL" | tr '\n' ' ' | tr -s '[:space:]' ' ')"
  local startup_requirements=(
    'branch Other is selectable|comparison branch first.{0,255}offer an explicit.{0,5}Other.{0,10}choice.{0,80}type the branch'
    'single Jira result shows key and summary|exactly one usable Jira match has an issue key and summary.{0,100}show both'
    'multiple Jira choices label each key and summary|multiple distinct issue keys and summaries.{0,200}single.select choices.{0,120}labelled with each key and summary'
    'timeout does not retry|lookup fails or times out.{0,255}do not retry'
    'failed discovery asks for pasted content|no usable match.{0,200}go straight to asking for a ticket reference or pasted content'
  )
  for startup_requirement in "${startup_requirements[@]}"; do
    label="${startup_requirement%%|*}"; pattern="${startup_requirement#*|}"
    if grep -Eiq "$pattern" <<< "$startup_content"; then _pass "$label"; else _fail "$label" 'required startup instruction missing'; fi
  done
  if grep -Eiq 'retry (the )?(Jira )?(lookup|search|discovery) (if|when|after|on)' <<< "$content"; then
    _fail 'no discovery retries' 'discovery instructions permit a retry'
  else
    _pass 'no discovery retries'
  fi
}

_test_order_and_frontmatter() {
  if [[ ! -f "$SKILL" ]]; then _fail frontmatter_and_order 'required review skill is missing'; return; fi
  if awk 'NR == 1 && $0 != "---" {exit 1} NR == 2 && $0 != "name: reviewing-pull-requests" {exit 1} /^description: .+/ {description=1} /^metadata:$/ {metadata=1} /^## 1\. Ticket/ {a=NR} /^## 2\. Git/ {b=NR} /^## 3\. Walkthrough/ {c=NR} /^## 4\. Findings/ {d=NR} /^## 5\. Recommendation/ {e=NR} END {exit !(description && metadata && a && a<b && b<c && c<d && d<e)}' "$SKILL"; then
    _pass frontmatter_and_order
  else _fail frontmatter_and_order 'frontmatter or ordered phases missing'; fi
}

_test_install() {
  local harness="$1" installer="$REPO_ROOT/install-$1.sh" target="$TEST_TMP/$1/skills" resolver placeholders substitutions
  local manifest=() files=() source
  if [[ ! -f "$SKILL" ]]; then _fail "${harness}_install" 'required review skill is missing'; return; fi
  SKILLS_SOURCE="$REPO_ROOT/skills"
  while IFS= read -r -d '' source; do
    case "${source#$SKILLS_SOURCE/}" in
      reviewing-pull-requests/SKILL.md|_shared/code-review.md) files+=("${source#$SKILLS_SOURCE/}") ;;
    esac
  done < <(find "$SKILLS_SOURCE" -type f -print0)
  if (( ${#files[@]} != 2 )); then _fail "${harness}_install" 'recursive discovery missed a required source'; return; fi
  if [[ "$harness" == codex ]]; then
    resolver=_codex_skill_resolve_dst
  else
    placeholders="$(printf '%s' "$harness" | tr '[:lower:]' '[:upper:]')_PLACEHOLDERS"
    substitutions="$(printf '%s' "$harness" | tr '[:lower:]' '[:upper:]')_SUBSTITUTIONS"
    if ! _load_declaration "$placeholders" "$installer" '=(' || ! _load_declaration "$substitutions" "$installer" '=(' || ! _load_declaration _skill_resolve_dst "$installer" '() {'; then _fail "${harness}_install" 'installer declarations missing'; return; fi
    resolver=_skill_resolve_dst
  fi
  mkdir -p "$target"
  install_files_from_dir "$SKILLS_SOURCE" "$target" skills manifest files "$resolver"
  if [[ "$harness" == codex ]]; then _codex_substitute_placeholders_tree "$target"; else substitute_tool_names "$target" "$placeholders" "$substitutions"; fi
  _check_installed "$harness" "$target"
}

_check_installed() {
  local harness="$1" target="$2" installed="$2/reviewing-pull-requests/SKILL.md" reference count=0 expected section comparison_prompt jira_prompt
  case "$harness" in claude) expected='AskUserQuestion' ;; opencode) expected='question' ;; codex) expected='request_user_input' ;; esac
  if [[ ! -f "$installed" ]] || grep -q '{{' "$installed" || ! grep -Fq "$expected" "$installed"; then _fail "${harness}_install" 'skill missing or tool substitution incorrect'; return; fi
  section="$(awk '/^## 1\. Ticket and comparison branch$/ {capture=1; next} /^## 2\. Git boundaries and review inputs$/ {capture=0} capture {print}' "$installed")"
  comparison_prompt="$(grep -i 'comparison branch' <<< "$section" | head -n 1)"
  jira_prompt="$(grep -i 'usable Jira match' <<< "$section" | head -n 1)"
  if grep -Fq "\`$expected\`" <<< "$comparison_prompt"; then _pass "${harness}_comparison_prompt_adapter"; else _fail "${harness}_comparison_prompt_adapter" 'comparison prompt does not use the installed question adapter'; fi
  if grep -Fq "\`$expected\`" <<< "$jira_prompt"; then _pass "${harness}_jira_prompt_adapter"; else _fail "${harness}_jira_prompt_adapter" 'Jira prompt does not use the installed question adapter'; fi
  while IFS= read -r reference; do
    ((count++)) || true
    if [[ ! -f "$target/reviewing-pull-requests/$reference" ]]; then _fail "${harness}_install" "unresolved reference $reference"; return; fi
  done < <(grep -Eo '`\.\./[A-Za-z0-9_./-]+\.md`' "$installed" | tr -d '`')
  if (( count == 0 )); then _fail "${harness}_install" 'no shared reference inspected'; else _pass "${harness}_install"; fi
}

_test_contract
_test_order_and_frontmatter
_test_install claude
_test_install opencode
_test_install codex
printf '\n%d passed, %d failed\n' "$passed" "$failed"
(( failed == 0 ))
