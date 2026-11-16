#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/elelem-merge-main-tests.XXXXXX")" || exit 1
trap '[[ -n "${TEST_TMP:-}" ]] && rm -rf -- "$TEST_TMP"' EXIT
source "$REPO_ROOT/_install-common.sh"
source "$REPO_ROOT/install-codex.sh"
set +e

passed=0
failed=0
SKILL="$REPO_ROOT/skills/merge-main/SKILL.md"

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
    'new and resumed triggers|merge main into this branch.{0,120}finish merging main and fix tests'
    'single coordinator|reuse.{0,120}active.{0,80}coordinator.{0,160}(do not|never).{0,60}(recursive|second)'
    'approval boundary|read.only.{0,180}(preflight|discovery).{0,200}(mutation|execution).{0,140}approv'
    'phase ownership|Research.{0,120}Planning.{0,120}design review.{0,120}approval.{0,120}readiness'
    'no implicit skips|no implicit.{0,40}skip'
    'initial boundaries|branch.{0,120}HEAD.{0,160}(operation|merge).{0,160}(index|staged).{0,160}unstaged.{0,100}untracked'
    'current feature only|detached.{0,180}(main|feature).{0,180}(stop|pause|block)'
    'immutable provenance|immutable.{0,80}(start|baseline).{0,180}(edit|path).{0,80}history'
    'clean new merge|fresh merge.{0,180}clean.{0,100}index.{0,100}worktree'
    'ignore exception safety|ignore.{0,180}(isolate|separate).{0,180}(pause|block)'
    'fetch failure boundary|git fetch[^`]{0,180} origin.{0,220}fail.{0,140}(stop|block).{0,100}stale'
    'explicit main fetch mapping|git fetch[^`]{0,180}origin refs/heads/main:refs/remotes/origin/main'
    'fetch target isolation|git fetch --no-tags --refmap= origin'
    'same fetch evidence|FETCH_HEAD.{0,160}(equal|match).{0,160}refs/remotes/origin/main.{0,180}(block|stop)'
    'exact incoming ref|refs/remotes/origin/main.{0,180}(commit ID|commit object|commit)'
    'normal merge command|git merge --no-commit "\$incoming"'
    'fast-forward configuration gate|merge\.ff.{0,120}false.{0,80}only.{0,160}(block|stop)'
    'autostash configuration gate|merge\.autoStash.{0,80}true.{0,160}(block|stop)'
    'branch merge options gate|branch\.<current>\.mergeOptions.{0,200}(block|stop)'
    'unverifiable merge settings|unverifiable.{0,100}(setting|config).{0,140}(block|stop).{0,140}ask'
    'fast-forward semantics|fast.forward.{0,100}(move|HEAD).{0,200}--no-ff'
    'actual failure state|exit.{0,120}(status|code).{0,160}(MERGE_HEAD|unmerged).{0,180}(unrelated|other).{0,80}fail'
    'resume target|exactly one.{0,80}MERGE_HEAD.{0,160}(pin|target|incoming)'
    'unknown provenance|provenance.{0,160}unknown.{0,120}(ask|pause).{0,180}pre.merge'
    'no resumed retarget|do not fetch.{0,120}(replace|target).{0,180}origin/main'
    'index stages preserved|index stages.{0,160}(existing|inherited).{0,80}resolutions'
    'partial staging preserved|staged.{0,80}unstaged.{0,160}(separately|separate).{0,180}partial'
    'coordinator staging|coordinator.{0,140}(staging|stage).{0,240}git --literal-pathspecs -C "\$root" add -- "\$path"'
    'no blanket staging|never.{0,80}blanket staging.{0,80}git add -A.{0,80}git add \.'
    'literal path boundaries|root.relative.{0,180}(quoted|quoting).{0,100}(separate|argument).{0,180}(no|never).{0,100}(wildcard|glob)'
    'literal scoped reads|path.scoped reads.{0,180}(--literal-pathspecs|literal).{0,180}(diff|ls-files)'
    'drift blocks|unexpected.{0,120}(drift|change).{0,160}(pause|stop|block)'
    'three way intent|base.{0,100}both sides.{0,160}(purpose|intent).{0,120}contracts.{0,120}(callers|tests)'
    'ambiguous behaviour|material.{0,80}ambig.{0,160}(ask|question).{0,100}pause'
    'special conflicts|add/add.{0,160}rename/delete.{0,200}generated.{0,200}binary'
    'no global side choice|never.{0,80}(ours|theirs).{0,80}(global|blanket)'
    'conflict free review|auto.merg.{0,160}(integration|semantic).{0,120}(surface|contract|defect)'
    'check discovery|documentation.{0,100}CI.{0,180}(check|test).{0,140}(pillar|surface)'
    'regression first corrections|debugging.{0,180}test.driven.development.{0,160}(regression|failing test)'
    'test integrity|do not weaken.{0,100}(test|eval).{0,160}unrelated'
    'resources and costs|paid.{0,120}(budget|cost).{0,160}shared.{0,120}(resource|container|stack)'
    'resource identity|mount.{0,100}(worktree|checkout).{0,160}(switch|stop)'
    'unknown failures|unattributed.{0,120}(unknown|unverified)'
    'review prune final ordering|task review.{0,160}cumulative.{0,80}review.{0,160}(separate|final).{0,60}(test.pruning|pruning).{0,160}final verification'
    'evidence invalidation|later edits.{0,100}invalidat.{0,160}(paid|budget)'
    'final index state|git ls-files -u.{0,160}git diff --check.{0,160}(dirty|untracked)'
    'no automatic recovery|no automatic.{0,100}(stash|rollback).{0,180}(abort|reset)'
    'no commits or pushes|do not commit or push'
    'result identities|starting.{0,80}(current|final) HEAD.{0,120}incoming.{0,100}(ID|commit)'
    'actual verification limits|failed.{0,60}skipped.{0,60}unrun.{0,100}(gate|check).{0,100}(prevent|block)'
  )
  if [[ ! -f "$SKILL" ]]; then _fail skill_exists 'required merge-main skill is missing'; return; fi
  content="$(tr '\n' ' ' < "$SKILL" | tr -s '[:space:]' ' ')"
  for requirement in "${requirements[@]}"; do
    label="${requirement%%|*}"; pattern="${requirement#*|}"
    if grep -Eiq "$pattern" <<< "$content"; then _pass "$label"; else _fail "$label" 'required safety contract missing'; fi
  done
}

_test_source() {
  if [[ ! -f "$SKILL" ]]; then _fail source_format 'required merge-main skill is missing'; return; fi
  if awk 'NR==1 && $0!="---" {bad=1} NR==2 && $0!="name: merge-main" {bad=1} /^description: .+/ {description=1} END {exit (bad || !description)}' "$SKILL"; then _pass discovery; else _fail discovery 'missing skill identity or description'; fi
}

_install_sources() {
  local harness="$1" target="$2" resolver placeholders substitutions
  local manifest=() files=() source
  SKILLS_SOURCE="$REPO_ROOT/skills"
  while IFS= read -r -d '' source; do files+=("${source#$SKILLS_SOURCE/}"); done < <(find "$SKILLS_SOURCE" -type f -name '*.md' -print0)
  if [[ "$harness" == codex ]]; then resolver=_codex_skill_resolve_dst
  else
    placeholders="$(printf '%s' "$harness" | tr '[:lower:]' '[:upper:]')_PLACEHOLDERS"
    substitutions="$(printf '%s' "$harness" | tr '[:lower:]' '[:upper:]')_SUBSTITUTIONS"
    _load_declaration "$placeholders" "$REPO_ROOT/install-$harness.sh" '=(' || return 1
    _load_declaration "$substitutions" "$REPO_ROOT/install-$harness.sh" '=(' || return 1
    _load_declaration _skill_resolve_dst "$REPO_ROOT/install-$harness.sh" '() {' || return 1
    resolver=_skill_resolve_dst
  fi
  mkdir -p "$target" || return 1
  install_files_from_dir "$SKILLS_SOURCE" "$target" skills manifest files "$resolver" || return 1
  if [[ "$harness" == codex ]]; then _codex_substitute_placeholders_tree "$target"; else substitute_tool_names "$target" "$placeholders" "$substitutions"; fi
}

_test_install() {
  local harness="$1" target="$TEST_TMP/$1/skills" installed reference count=0 tool
  local expected=()
  installed="$target/merge-main/SKILL.md"
  if [[ ! -f "$SKILL" ]]; then _fail "${harness}_install" 'required merge-main skill is missing'; return; fi
  if ! _install_sources "$harness" "$target"; then _fail "${harness}_install" 'installer helper failed'; return; fi
  case "$harness" in
    claude) expected=('`Read`' '`Skill`' '`AskUserQuestion`') ;;
    opencode) expected=('`read`' '`skill`' '`question`') ;;
    codex) expected=('`read the file`' '`/skills or $skill-name`' '`request_user_input`') ;;
  esac
  if [[ ! -f "$installed" ]] || grep -q '{{' "$installed"; then _fail "${harness}_install" 'discovery or substitution failed'; return; fi
  for tool in "${expected[@]}"; do
    if ! grep -Fq "$tool" "$installed"; then _fail "${harness}_install" "incorrect substitution for $tool"; return; fi
  done
  while IFS= read -r reference; do
    ((count++)) || true
    if [[ ! -f "$target/merge-main/$reference" ]]; then _fail "${harness}_install" "unresolved reference $reference"; return; fi
  done < <(grep -Eo '`\.\./[A-Za-z0-9_./-]+\.md`' "$installed" | tr -d '`')
  if (( count == 0 )); then _fail "${harness}_install" 'no portable reference checked'; else _pass "${harness}_install"; fi
}

_test_contract
_test_source
_test_install claude
_test_install opencode
_test_install codex
printf '\n%d passed, %d failed\n' "$passed" "$failed"
(( failed == 0 ))
