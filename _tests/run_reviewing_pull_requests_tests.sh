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
  local content requirement label pattern
  local requirements=(
    'ticket request|ask.{0,120}(ticket reference|ticket content)'
    'pasted fallback|integration.{0,160}paste'
    'chosen base|always ask.{0,100}comparison branch'
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
  local harness="$1" target="$2" installed="$2/reviewing-pull-requests/SKILL.md" reference count=0 expected
  case "$harness" in claude) expected='AskUserQuestion' ;; opencode) expected='question' ;; codex) expected='request_user_input' ;; esac
  if [[ ! -f "$installed" ]] || grep -q '{{' "$installed" || ! grep -Fq "$expected" "$installed"; then _fail "${harness}_install" 'skill missing or tool substitution incorrect'; return; fi
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
