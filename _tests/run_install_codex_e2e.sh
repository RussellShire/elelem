#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$REPO_ROOT/_install-common.sh"
source "$REPO_ROOT/install-codex.sh"

passed=0
failed=0

_pass() {
  echo "[PASS] $1"
  (( passed++ )) || true
}

_fail() {
  echo "[FAIL] $1: $2"
  (( failed++ )) || true
}

test_full_install_to_tmp_user_scope() {
  local name="full_install_to_tmp_user_scope"
  local tmphome agents_target skills_target payload_file
  tmphome="$(mktemp -d)"
  trap "rm -rf '$tmphome'" RETURN

  agents_target="$tmphome/.codex/AGENTS.md"
  skills_target="$tmphome/.agents/skills"
  payload_file="$(mktemp)"
  trap "rm -rf '$tmphome'; rm -f '$payload_file'" RETURN

  local common_files=()
  local f
  for f in "$REPO_ROOT/rules/common/"*.md; do
    common_files+=("$(basename "$f")")
  done

  local lang_dirs=("python")
  _codex_render_agents_payload "$payload_file" common_files lang_dirs
  _codex_upsert_managed_block "$agents_target" "$payload_file"
  _codex_scan_file_for_placeholders "$agents_target" || { _fail "$name" "AGENTS.md placeholder scan failed"; return; }

  mkdir -p "$skills_target"
  local manifest=()
  local skills_files=()
  while IFS= read -r -d '' f; do
    skills_files+=("${f#"$REPO_ROOT/skills"/}")
  done < <(find "$REPO_ROOT/skills" -type f -print0)
  install_files_from_dir "$REPO_ROOT/skills" "$skills_target" ".agents/skills" manifest skills_files _codex_skill_resolve_dst
  _codex_substitute_placeholders_tree "$skills_target"
  scan_no_unsubstituted_placeholders "$skills_target" || { _fail "$name" "skills placeholder scan failed"; return; }

  if [[ ! -f "$agents_target" ]]; then
    _fail "$name" "expected $agents_target to exist"
    return
  fi

  if ! grep -q 'elelem:codex:start' "$agents_target"; then
    _fail "$name" "managed block start marker missing from AGENTS.md"
    return
  fi

  if ! grep -q 'rules/common/coding-style.md' "$agents_target"; then
    _fail "$name" "expected common rule heading missing from AGENTS.md"
    return
  fi

  if ! grep -q 'rules/python/coding-style.md' "$agents_target"; then
    _fail "$name" "expected python rule heading missing from AGENTS.md"
    return
  fi

  if grep -q '^globs:' "$agents_target"; then
    _fail "$name" "language-pack frontmatter leaked into AGENTS.md"
    return
  fi

  local skill_md="$skills_target/debugging/SKILL.md"
  if [[ ! -f "$skill_md" ]]; then
    _fail "$name" "expected skills/debugging/SKILL.md not present"
    return
  fi

  if ! grep -q '^name: debugging$' "$skill_md"; then
    _fail "$name" "debugging SKILL.md lost its frontmatter"
    return
  fi

  if ! grep -RIlF '/skills or $skill-name' "$skills_target" >/dev/null 2>&1; then
    _fail "$name" "skills did not receive Codex INVOKE_SKILL_TOOL substitution"
    return
  fi

  if ! grep -RIlF 'request_user_input' "$skills_target" >/dev/null 2>&1; then
    _fail "$name" "skills did not receive Codex ASK_USER_QUESTION_TOOL substitution"
    return
  fi

  if ! grep -RIlF 'update_plan' "$skills_target" >/dev/null 2>&1; then
    _fail "$name" "skills did not receive Codex TASK_TRACKER_TOOL substitution"
    return
  fi

  if ! grep -RIlF 'spawn_agent' "$skills_target" >/dev/null 2>&1; then
    _fail "$name" "skills did not receive Codex DISPATCH_AGENT_TOOL substitution"
    return
  fi

  _pass "$name"
}

test_main_flow_keeps_user_rules_and_project_skills_selections_separate() {
  local name='main_flow_keeps_user_rules_and_project_skills_selections_separate'
  local fixture_root project_directory home_directory user_source project_source source_directory manifest_file installed_skill manifest_base expected_manifest actual_manifest source_file
  local common_rule_count
  fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/elelem-codex-mixed-scopes.XXXXXX")"
  trap 'rm -rf "$fixture_root"' RETURN

  project_directory="$fixture_root/project"
  home_directory="$fixture_root/home"
  user_source="$fixture_root/invocation/user/source"
  project_source="$fixture_root/invocation/project/source"
  mkdir -p "$project_directory" "$home_directory" "$fixture_root/xdg" "$fixture_root/codex" "$fixture_root/tmp" "$user_source" "$project_source"
  for source_directory in "$user_source" "$project_source"; do
    cp "$REPO_ROOT/_install-common.sh" "$REPO_ROOT/install-codex.sh" "$source_directory/"
    cp -R "$REPO_ROOT/rules" "$REPO_ROOT/skills" "$REPO_ROOT/agents" "$source_directory/"
  done
  common_rule_count="$(find "$project_source/rules/common" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')"

  cat > "$fixture_root/invocation/user/run-installer.sh" <<'INSTALLER'
#!/usr/bin/env bash
invocation_directory="$(cd "$(dirname "$0")" && pwd)"
fixture_root="$(cd "$invocation_directory/../.." && pwd)"
cd "$fixture_root/project" || exit 1
"$invocation_directory/source/install-codex.sh"
installer_status=$?
printf '\nCODEX_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
INSTALLER
  cat > "$fixture_root/invocation/project/run-installer.sh" <<'INSTALLER'
#!/usr/bin/env bash
invocation_directory="$(cd "$(dirname "$0")" && pwd)"
fixture_root="$(cd "$invocation_directory/../.." && pwd)"
cd "$fixture_root/project" || exit 1
"$invocation_directory/source/install-codex.sh"
installer_status=$?
printf '\nCODEX_INSTALLER_EXIT=%s\n' "$installer_status"
exit "$installer_status"
INSTALLER
  chmod +x "$fixture_root/invocation/user/run-installer.sh" "$fixture_root/invocation/project/run-installer.sh"

  if ! printf '\n\n\n \n\n' | HOME="$home_directory" XDG_CONFIG_HOME="$fixture_root/xdg" CODEX_HOME="$fixture_root/codex" TMPDIR="$fixture_root/tmp" PYTHONDONTWRITEBYTECODE=1 TERM=dumb NO_COLOR=1 /usr/bin/script -q "$fixture_root/user-session.log" "$fixture_root/invocation/user/run-installer.sh" >/dev/null; then
    _fail "$name" 'user-scope rules-only installer exited unsuccessfully'
    return
  fi
  if ! grep -Fq 'CODEX_INSTALLER_EXIT=0' "$fixture_root/user-session.log"; then
    _fail "$name" 'user-scope rules-only installer did not complete'
    return
  fi

  if ! python3 - "$project_directory" "$common_rule_count" <<'PY' | HOME="$home_directory" XDG_CONFIG_HOME="$fixture_root/xdg" CODEX_HOME="$fixture_root/codex" TMPDIR="$fixture_root/tmp" PYTHONDONTWRITEBYTECODE=1 TERM=dumb NO_COLOR=1 /usr/bin/script -q "$fixture_root/project-session.log" "$fixture_root/invocation/project/run-installer.sh" >/dev/null; then
import sys
import time

project = sys.argv[1].encode()
common_rule_count = int(sys.argv[2])
chunks = [b"\x1b[A\n", project + b"\n"]
for _ in range(common_rule_count):
    chunks.extend((b" ", b"\x1b[B"))
chunks.extend((b"\n", b"\n", b" \n", b"\n", b"\n"))
for chunk in chunks:
    sys.stdout.buffer.write(chunk)
    sys.stdout.flush()
    time.sleep(0.25)
PY
    _fail "$name" 'project-scope skills-only installer exited unsuccessfully'
    return
  fi
  if ! grep -Fq 'CODEX_INSTALLER_EXIT=0' "$fixture_root/project-session.log"; then
    _fail "$name" 'project-scope skills-only installer did not complete'
    return
  fi

  manifest_file="$user_source/.elelem-manifest-codex"
  if [[ ! -f "$manifest_file" ]]; then
    _fail "$name" 'user-scope rules-only manifest is missing'
    return
  fi
  manifest_base="$(sed -n '1p' "$manifest_file")"
  if [[ "$manifest_base" != "$home_directory" ]] || tail -n +2 "$manifest_file" | grep -q '[^[:space:]]'; then
    _fail "$name" "user-scope rules-only manifest has base '$manifest_base' and entries '$(tail -n +2 "$manifest_file" | tr '\n' ',')'"
    return
  fi
  if ! grep -Fq 'rules/common/workflow.md' "$home_directory/.codex/AGENTS.md" || [[ -e "$home_directory/.agents/skills/subagent-driven-development/SKILL.md" ]]; then
    _fail "$name" 'user-scope rules-only selection was not preserved'
    return
  fi

  manifest_file="$project_source/.elelem-manifest-codex"
  manifest_base="$(sed -n '1p' "$manifest_file")"
  installed_skill="$project_directory/.agents/skills/subagent-driven-development/SKILL.md"
  if [[ ! -f "$manifest_file" || "$manifest_base" != "$project_directory" ]] || ! grep -Fq '.agents/skills/subagent-driven-development/SKILL.md' "$manifest_file" || ! grep -Fq '.agents/skills/_shared/worker-contract.md' "$manifest_file" || [[ ! -f "$installed_skill" ]] || ! grep -Fq '../_shared/worker-contract.md' "$installed_skill" || [[ ! -f "$(dirname "$installed_skill")/../_shared/worker-contract.md" ]]; then
    _fail "$name" 'project-scope skills-only output or manifest entries are incorrect'
    return
  fi
  expected_manifest="$fixture_root/expected-project-manifest"
  actual_manifest="$fixture_root/actual-project-manifest"
  while IFS= read -r source_file; do
    printf '.agents/skills/%s\n' "${source_file#"$project_source/skills/"}"
  done < <(find "$project_source/skills" -type f | sort) > "$expected_manifest"
  tail -n +2 "$manifest_file" | sed '/^$/d' > "$actual_manifest"
  if ! cmp -s "$expected_manifest" "$actual_manifest"; then
    _fail "$name" 'project-scope manifest entries do not match the selected skills source'
    return
  fi
  if ! grep -Fq 'No elelem rules are currently installed for this scope.' "$project_directory/AGENTS.md" || grep -Eq '^## rules/' "$project_directory/AGENTS.md" || grep -Fq 'rules/' "$manifest_file" || ! grep -Fq 'rules/common/workflow.md' "$home_directory/.codex/AGENTS.md"; then
    _fail "$name" 'project rule deselection activated rules or disturbed the user-scope installation'
    return
  fi

  _pass "$name"
}

test_coexistence_three_manifests() {
  local name="coexistence_three_manifests"
  local tmphome
  tmphome="$(mktemp -d)"
  trap "rm -rf '$tmphome'" RETURN

  local claude_base="$tmphome/.claude"
  local opencode_base="$tmphome/.config/opencode"
  local codex_base="$tmphome"

  mkdir -p "$claude_base/rules/common" "$opencode_base/rules/common" "$codex_base/.agents/skills/debugging"

  local manifest_claude=("rules/common/coding-style.md")
  local manifest_opencode=("rules/common/coding-style.md")
  local manifest_codex=(".agents/skills/debugging/SKILL.md")

  cp "$REPO_ROOT/rules/common/coding-style.md" "$claude_base/rules/common/"
  cp "$REPO_ROOT/rules/common/coding-style.md" "$opencode_base/rules/common/"
  cp "$REPO_ROOT/skills/debugging/SKILL.md" "$codex_base/.agents/skills/debugging/"

  local mf_claude="$tmphome/.elelem-manifest-claude"
  local mf_opencode="$tmphome/.elelem-manifest-opencode"
  local mf_codex="$tmphome/.elelem-manifest-codex"

  write_manifest "$mf_claude" "$claude_base" manifest_claude
  write_manifest "$mf_opencode" "$opencode_base" manifest_opencode
  write_manifest "$mf_codex" "$codex_base" manifest_codex

  if [[ ! -f "$mf_claude" ]] || [[ ! -f "$mf_opencode" ]] || [[ ! -f "$mf_codex" ]]; then
    _fail "$name" "expected three distinct manifest files"
    return
  fi

  _pass "$name"
}

test_install_dot_sh_offers_codex() {
  local name="front_controller_offers_codex"
  if grep -q '"Codex"' "$REPO_ROOT/install.sh"; then
    _pass "$name"
  else
    _fail "$name" "install.sh harness_items array does not include Codex"
  fi
}

test_post_install_scan_ignores_unrelated_files_under_skills_root() {
  local name="post_install_scan_ignores_unrelated_files_under_skills_root"
  local tmpbase
  tmpbase="$(mktemp -d)"
  trap "rm -rf '$tmpbase'" RETURN

  mkdir -p "$tmpbase/.agents/skills"
  mkdir -p "$tmpbase/third-party/plugin/skills/foo"

  cat > "$tmpbase/third-party/plugin/skills/foo/SKILL.md" <<'PLUGIN'
---
name: foo
description: third-party
---

TODO: this is fine, it belongs to a different installer.
PLUGIN

  local manifest=()
  local skills_files=("debugging/SKILL.md")
  install_files_from_dir "$REPO_ROOT/skills" "$tmpbase/.agents/skills" ".agents/skills" manifest skills_files _codex_skill_resolve_dst
  _codex_substitute_placeholders_tree "$tmpbase/.agents/skills"

  local scoped_exit=0
  ( scan_no_unsubstituted_placeholders "$tmpbase/.agents/skills" ) || scoped_exit=$?
  if (( scoped_exit != 0 )); then
    _fail "$name" "scoped scan tripped on a clean install"
    return
  fi

  local broad_exit=0
  ( scan_no_unsubstituted_placeholders "$tmpbase" ) || broad_exit=$?
  if (( broad_exit == 0 )); then
    _fail "$name" "broad scan against base did not trip on unrelated TODO marker; test setup is wrong"
    return
  fi

  _pass "$name"
}

test_install_dot_sh_offers_codex
test_full_install_to_tmp_user_scope
test_main_flow_keeps_user_rules_and_project_skills_selections_separate
test_coexistence_three_manifests
test_post_install_scan_ignores_unrelated_files_under_skills_root

total=$(( passed + failed ))
echo
echo "${passed}/${total} tests passed"
(( failed == 0 )) || exit 1
