#!/usr/bin/env bash
set -uo pipefail

checkout_root="$(CDPATH= cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fixture_parent="${ELELEM_TEST_ROOT:?Set ELELEM_TEST_ROOT to a retained fixture directory}"
isolation_shim="${BASH_ENV:?Set BASH_ENV to the isolation shim}"
passed=0
failed=0

prepare_case() {
  local name="$1" harness="$2"
  case_root="$(mktemp -d "$fixture_parent/$name.XXXXXX")" || return 1
  mkdir -p "$case_root/invocation" "$case_root/work/project" "$case_root/home" "$case_root/xdg" "$case_root/tmp" || return 1
  ln -s "$checkout_root/install-$harness.sh" "$case_root/invocation/install-$harness.sh" || return 1
  ln -s "$checkout_root/_install-common.sh" "$case_root/invocation/_install-common.sh" || return 1
  ln -s "$checkout_root/uninstall.sh" "$case_root/invocation/uninstall.sh" || return 1
  cp -R "$checkout_root/rules" "$case_root/invocation/rules" || return 1
  cp -R "$checkout_root/skills" "$case_root/invocation/skills" || return 1
  cp -R "$checkout_root/agents" "$case_root/invocation/agents" || return 1
  cat > "$case_root/run-installer.sh" <<'EOF'
#!/usr/bin/env bash
"$1"
status=$?
printf '\nINSTALLER_EXIT=%s\n' "$status"
exit "$status"
EOF
  cat > "$case_root/run-uninstaller.sh" <<'EOF'
#!/usr/bin/env bash
"$1"
status=$?
printf '\nUNINSTALLER_EXIT=%s\n' "$status"
exit "$status"
EOF
  manifest="$case_root/invocation/.elelem-manifest-$harness"
}

run_installer() {
  local harness="$1" project_input="$2" cdpath_value="${3:-}" scope="${4:-project}"
  if [[ "$scope" == user ]]; then
    printf '\n\n\n\n \n' > "$case_root/input"
  else
    printf '\033[A\n%s\n\n\n\n \n' "$project_input" > "$case_root/input"
  fi
  (
    cd "$case_root/work" || exit 2
    HOME="$case_root/home" XDG_CONFIG_HOME="$case_root/xdg" TMPDIR="$case_root/tmp" \
      ELELEM_TEST_ROOT="$case_root" BASH_ENV="$isolation_shim" CDPATH="$cdpath_value" TERM=dumb NO_COLOR=1 \
      /usr/bin/script -q "$case_root/install-session.log" /bin/bash "$case_root/run-installer.sh" "$case_root/invocation/install-$harness.sh" < "$case_root/input" > "$case_root/install-stdout.log" 2>&1
  )
  installer_status="$(sed -n 's/^INSTALLER_EXIT=\([0-9][0-9]*\).*$/\1/p' "$case_root/install-session.log" | tail -n 1)"
  if [[ -z "$installer_status" ]]; then
    printf 'BLOCKED: installer exit status was not recorded: %s\n' "$case_root"
    exit 2
  fi
  printf '%s\n' "$installer_status" > "$case_root/install-status"
}

run_uninstaller() {
  (
    cd "$case_root/work" || exit 2
    printf ' \n \n' | HOME="$case_root/home" XDG_CONFIG_HOME="$case_root/xdg" TMPDIR="$case_root/tmp" \
      ELELEM_TEST_ROOT="$case_root" BASH_ENV="$isolation_shim" CDPATH= TERM=dumb NO_COLOR=1 \
      /usr/bin/script -q "$case_root/uninstall-session.log" /bin/bash "$case_root/run-uninstaller.sh" "$case_root/invocation/uninstall.sh" > "$case_root/uninstall-stdout.log" 2>&1
  )
  uninstall_status="$(sed -n 's/^UNINSTALLER_EXIT=\([0-9][0-9]*\).*$/\1/p' "$case_root/uninstall-session.log" | tail -n 1)"
  if [[ -z "$uninstall_status" ]]; then
    printf 'BLOCKED: uninstaller exit status was not recorded: %s\n' "$case_root"
    exit 2
  fi
  printf '%s\n' "$uninstall_status" > "$case_root/uninstall-status"
}

expected_base() {
  case "$1" in
    claude) printf '%s/.claude' "$2" ;;
    opencode) printf '%s/.opencode' "$2" ;;
    codex) printf '%s' "$2" ;;
  esac
}

assert_selected_common_rules_are_installed() {
  local harness="$1" base="$2" source entry heading count=0
  if [[ "$harness" == codex ]]; then
    awk '/^<!-- elelem:codex:start -->$/ { inside=1; next } /^<!-- elelem:codex:end -->$/ { inside=0 } inside' "$base/AGENTS.md" > "$case_root/managed-block" || return 1
  fi
  for source in "$case_root/invocation/rules/common/"*.md; do
    [[ -f "$source" ]] || continue
    count=$((count + 1))
    entry="rules/common/${source##*/}"
    if [[ "$harness" == codex ]]; then
      IFS= read -r heading < "$source"
      if ! grep -Fxq "## $entry" "$case_root/managed-block" || ! grep -Fxq "$heading" "$case_root/managed-block"; then
        printf 'selected common rule is absent from the Codex managed block: %s\n' "$entry"
        return 1
      fi
    elif [[ ! -f "$base/$entry" ]] || ! grep -Fxq "$entry" "$manifest"; then
      printf 'selected common rule is not installed or recorded: %s\n' "$entry"
      return 1
    fi
  done
  if [[ "$count" -eq 0 ]]; then
    printf 'BLOCKED: no common rules discovered: %s\n' "$case_root"
    exit 2
  fi
}

assert_selected_skills_are_installed() {
  local harness="$1" base="$2" source entry prefix count=0
  local skills_source="$case_root/invocation/skills"
  case "$harness" in
    claude|opencode) prefix=skills ;;
    codex) prefix=.agents/skills ;;
  esac
  while IFS= read -r -d '' source; do
    count=$((count + 1))
    entry="$prefix/${source#"$skills_source"/}"
    if [[ ! -f "$base/$entry" ]] || ! grep -Fxq "$entry" "$manifest"; then
      printf 'selected skill file is not installed or recorded: %s\n' "$entry"
      return 1
    fi
  done < <(find "$skills_source" -type f -print0)
  if [[ "$count" -eq 0 ]]; then
    printf 'BLOCKED: no skill files discovered: %s\n' "$case_root"
    exit 2
  fi
}

test_relative_install_uninstall() {
  local harness="$1" base agent_directory source notice entry count=0
  prepare_case "relative-$harness" "$harness" || return 1
  base="$(expected_base "$harness" "$case_root/work/project")"
  case "$harness" in
    claude|opencode) agent_directory="$base/agents"; notice="$base/agents.LICENSE" ;;
    codex) agent_directory="$base/.codex/agents"; notice="$base/.codex/agents.LICENSE" ;;
  esac
  run_installer "$harness" project
  if [[ "$installer_status" -ne 0 || ! -f "$manifest" ]] || ! cmp -s "$case_root/invocation/agents/LICENSE" "$notice"; then
    printf 'installer did not install the selected bundle: %s\n' "$case_root"
    return 1
  fi
  for source in "$case_root/invocation/agents/$harness/"*; do
    [[ -f "$source" ]] || continue
    count=$((count + 1))
    if ! cmp -s "$source" "$agent_directory/${source##*/}"; then
      printf 'installed agent differs from its source: %s\n' "$case_root"
      return 1
    fi
  done
  if [[ "$count" -ne 11 ]]; then
    printf 'BLOCKED: expected 11 source agents: %s\n' "$case_root"
    exit 2
  fi
  assert_selected_common_rules_are_installed "$harness" "$base" || return 1
  assert_selected_skills_are_installed "$harness" "$base" || return 1
  cp "$manifest" "$case_root/installed-manifest" || return 1
  sed '1d' "$case_root/installed-manifest" > "$case_root/installed-entries" || return 1
  while IFS= read -r entry; do
    if [[ -z "$entry" || ! -f "$base/$entry" ]]; then
      printf 'manifest-listed file was not installed: %s/%s\n' "$base" "$entry"
      return 1
    fi
  done < "$case_root/installed-entries"
  if [[ "$harness" == codex ]] &&
    { ! grep -Fq '<!-- elelem:codex:start -->' "$base/AGENTS.md" ||
      ! grep -Fq '<!-- elelem:codex:end -->' "$base/AGENTS.md"; }; then
    printf 'Codex managed block was not installed: %s\n' "$case_root"
    return 1
  fi
  run_uninstaller
  if [[ "$uninstall_status" -ne 0 || -e "$notice" || -e "$manifest" ]]; then
    printf 'relative install was not removed by actual uninstall: %s\n' "$case_root"
    return 1
  fi
  for source in "$case_root/invocation/agents/$harness/"*; do
    if [[ -f "$source" && -e "$agent_directory/${source##*/}" ]]; then
      printf 'actual uninstall left an installed agent: %s\n' "$case_root"
      return 1
    fi
  done
  while IFS= read -r entry; do
    if [[ -e "$base/$entry" || -L "$base/$entry" ]]; then
      printf 'actual uninstall left a manifest-listed file: %s/%s\n' "$base" "$entry"
      return 1
    fi
  done < "$case_root/installed-entries"
  if [[ "$harness" == codex && -f "$base/AGENTS.md" ]] &&
    grep -Eq '<!-- elelem:codex:(start|end) -->' "$base/AGENTS.md"; then
    printf 'actual uninstall left the Codex managed block: %s\n' "$case_root"
    return 1
  fi
  if [[ "$harness" == codex && ( -e "$base/AGENTS.md" || -L "$base/AGENTS.md" ) ]]; then
    printf 'actual uninstall left the Codex instructions file: %s\n' "$case_root"
    return 1
  fi
}

test_existing_relative_manifest_is_refused() {
  local harness="$1" old_base
  prepare_case "manifest-$harness" "$harness" || return 1
  old_base="$(expected_base "$harness" project)"
  printf '%s\n%s\n' "$old_base" 'retained-file' > "$manifest"
  cp "$manifest" "$case_root/original-manifest"
  run_installer "$harness" project
  if [[ "$installer_status" -eq 0 ]] || ! grep -Fq 'refusing to change install scope' "$case_root/install-session.log" ||
    ! cmp -s "$case_root/original-manifest" "$manifest" || [[ -n "$(ls -A "$case_root/work/project")" ]]; then
    printf 'existing relative manifest was not refused unchanged before writes: %s\n' "$case_root"
    return 1
  fi
}

test_relative_symlink_uses_physical_base() {
  local harness="$1" base actual
  prepare_case "symlink-$harness" "$harness" || return 1
  ln -s "$case_root/work/project" "$case_root/work/link"
  base="$(expected_base "$harness" "$case_root/work/project")"
  run_installer "$harness" link
  actual="$(head -n 1 "$manifest" 2>/dev/null)"
  if [[ "$installer_status" -ne 0 || "$actual" != "$base" ]]; then
    printf 'relative symlink did not use physical manifest base: %s\n' "$case_root"
    return 1
  fi
}

test_project_directory_named_dash_uses_physical_base() {
  local harness="$1" base actual agent
  prepare_case "dash-$harness" "$harness" || return 1
  mkdir "$case_root/work/-" || return 1
  base="$(expected_base "$harness" "$case_root/work/-")"
  case "$harness" in
    claude|opencode) agent="$base/agents/architect-reviewer.md" ;;
    codex) agent="$base/.codex/agents/architect-reviewer.toml" ;;
  esac
  run_installer "$harness" -
  if [[ "$installer_status" -ne 0 ]]; then
    printf "project directory '-' was rejected: installer exit %s, fixture %s\n" "$installer_status" "$case_root"
    return 1
  fi
  actual="$(head -n 1 "$manifest" 2>/dev/null)"
  if [[ "$actual" != "$base" || ! -f "$agent" ]] || ! awk 'NR > 1 && /^\// { exit 1 }' "$manifest"; then
    printf "project directory '-' did not produce the physical manifest base: %s\n" "$case_root"
    return 1
  fi
  run_uninstaller
  if [[ "$uninstall_status" -ne 0 || -e "$agent" || -e "$manifest" ]]; then
    printf "project directory '-' installation was not removed: %s\n" "$case_root"
    return 1
  fi
}

test_cdpath_does_not_contaminate_base() {
  local harness="$1" base actual cd_output
  prepare_case "cdpath-$harness" "$harness" || return 1
  cd_output="$(cd "$case_root/work" && CDPATH="$case_root/work" cd project)"
  if [[ "$cd_output" != "$case_root/work/project" ]]; then
    printf 'BLOCKED: CDPATH fixture did not cause cd to print its destination: %s\n' "$case_root"
    exit 2
  fi
  printf 'CDPATH precondition: cd printed %s\n' "$cd_output"
  base="$(expected_base "$harness" "$case_root/work/project")"
  run_installer "$harness" project "$case_root/work"
  actual="$(head -n 1 "$manifest" 2>/dev/null)"
  if [[ "$installer_status" -ne 0 || "$actual" != "$base" ]]; then
    printf 'CDPATH did not produce an uncontaminated physical base: %s\n' "$case_root"
    return 1
  fi
  if ! awk 'NR > 1 && /^\// { exit 1 }' "$manifest"; then
    printf 'CDPATH introduced an absolute manifest entry: %s\n' "$case_root"
    return 1
  fi
}

test_unsafe_physical_path_is_rejected() {
  local harness="$1" kind="$2" target
  prepare_case "$kind-$harness" "$harness" || return 1
  case "$kind" in
    double-dot) target="$case_root/work/unsafe..name" ;;
    newline) target="$case_root/work/unsafe"$'\n'"name" ;;
    trailing-newline) target="$case_root/work/unsafe"$'\n' ;;
  esac
  mkdir -p "$target"
  ln -s "$target" "$case_root/work/link"
  run_installer "$harness" link
  if [[ "$installer_status" -eq 0 || -e "$manifest" || -n "$(ls -A "$target")" ]] ||
    ! grep -Eiq 'Error:.*(path|directory)' "$case_root/install-session.log" ||
    ! grep -Eiq 'Error:.*(cannot|unable|invalid|unsafe|contains|refus)' "$case_root/install-session.log" ||
    ! grep -Eq 'Error:.*choose another directory\.' "$case_root/install-session.log"; then
    printf 'unsafe physical path was not rejected before installer writes: %s\n' "$case_root"
    return 1
  fi
}

test_failed_physical_resolution_is_rejected() {
  local harness="$1" target original_mode
  prepare_case "inaccessible-$harness" "$harness" || return 1
  target="$case_root/work/locked"
  mkdir "$target"
  original_mode="$(stat -f %Lp "$target")"
  trap 'chmod "$original_mode" "$target"' EXIT
  chmod 000 "$target"
  if [[ ! -d "$target" ]] || (CDPATH= cd "$target") 2>/dev/null; then
    chmod "$original_mode" "$target" || exit 2
    trap - EXIT
    printf 'BLOCKED: inaccessible fixture does not meet the required precondition: %s\n' "$case_root"
    return 2
  fi
  printf 'Resolution precondition: directory exists but traversal fails: %s\n' "$target"
  run_installer "$harness" locked
  chmod "$original_mode" "$target" || exit 2
  trap - EXIT
  printf 'Restored directory mode: %s\n' "$(stat -f %Lp "$target")"
  if [[ "$installer_status" -eq 0 || -e "$manifest" || -n "$(ls -A "$target")" ]] ||
    ! grep -Eiq 'Error:.*(resolv|access|search)' "$case_root/install-session.log" ||
    ! grep -Eq 'Error:.*ensure it exists and is searchable\.' "$case_root/install-session.log"; then
    printf 'failed physical resolution was not rejected before installer writes: %s\n' "$case_root"
    return 1
  fi
}

test_noncanonical_absolute_input_is_preserved() {
  local harness="$1" base actual
  prepare_case "absolute-$harness" "$harness" || return 1
  base="$(expected_base "$harness" "$case_root/work/project/.")"
  run_installer "$harness" "$case_root/work/project/."
  actual="$(head -n 1 "$manifest" 2>/dev/null)"
  if [[ "$installer_status" -ne 0 || "$actual" != "$base" ]]; then
    printf 'noncanonical absolute manifest base changed: %s\n' "$case_root"
    return 1
  fi
}

test_user_scope_is_preserved() {
  local harness="$1" base actual
  prepare_case "user-$harness" "$harness" || return 1
  case "$harness" in
    claude) base="$case_root/home/.claude" ;;
    opencode) base="$case_root/home/.config/opencode" ;;
    codex) base="$case_root/home" ;;
  esac
  run_installer "$harness" '' '' user
  actual="$(head -n 1 "$manifest" 2>/dev/null)"
  if [[ "$installer_status" -ne 0 || "$actual" != "$base" ]]; then
    printf 'user-scope manifest base changed: %s\n' "$case_root"
    return 1
  fi
}

test_codex_rejects_a_relative_symlink_to_home() {
  prepare_case home-symlink codex || return 1
  ln -s "$case_root/home" "$case_root/work/link"
  run_installer codex link
  if [[ "$installer_status" -eq 0 || -e "$manifest" || -n "$(ls -A "$case_root/home")" ]] ||
    ! grep -Fq 'project path resolves to HOME; refusing' "$case_root/install-session.log"; then
    printf 'Codex did not reject a relative symlink to HOME before writes: %s\n' "$case_root"
    return 1
  fi
}

run_case() {
  local case_name="$1" harness="$2" status=0
  case "$case_name" in
    relative) test_relative_install_uninstall "$harness" || status=$? ;;
    manifest) test_existing_relative_manifest_is_refused "$harness" || status=$? ;;
    symlink) test_relative_symlink_uses_physical_base "$harness" || status=$? ;;
    dash) test_project_directory_named_dash_uses_physical_base "$harness" || status=$? ;;
    cdpath) test_cdpath_does_not_contaminate_base "$harness" || status=$? ;;
    double-dot|newline|trailing-newline) test_unsafe_physical_path_is_rejected "$harness" "$case_name" || status=$? ;;
    inaccessible) test_failed_physical_resolution_is_rejected "$harness" || status=$? ;;
    absolute) test_noncanonical_absolute_input_is_preserved "$harness" || status=$? ;;
    user) test_user_scope_is_preserved "$harness" || status=$? ;;
    home-symlink) test_codex_rejects_a_relative_symlink_to_home || status=$? ;;
    *) printf 'Unknown case: %s\n' "$case_name"; return 2 ;;
  esac
  if [[ "$status" -eq 0 ]]; then
    printf '[PASS] %s %s\n' "$harness" "$case_name"
    passed=$((passed + 1))
  else
    printf '[FAIL] %s %s status=%s\n' "$harness" "$case_name" "$status"
    failed=$((failed + 1))
    [[ "$status" -ne 2 ]] || exit 2
  fi
}

if [[ $# -gt 0 ]]; then
  run_case "$1" "${2:?Specify harness}"
else
  for harness in claude opencode codex; do
    for case_name in relative manifest symlink dash cdpath double-dot newline trailing-newline inaccessible absolute user; do
      run_case "$case_name" "$harness"
    done
  done
  run_case home-symlink codex
fi
printf 'Passed: %s Failed: %s\n' "$passed" "$failed"
[[ "$failed" -eq 0 ]]
