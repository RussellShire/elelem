#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/elelem-policy-installation.XXXXXX")"
trap 'rm -rf "$TEST_TMP"' EXIT

passed=0
failed=0

_pass() {
  printf '[PASS] %s\n' "$1"
  ((passed += 1))
}

_fail() {
  printf '[FAIL] %s: %s\n' "$1" "$2"
  ((failed += 1))
}

_manifest_has_unsupported_skill_entries() {
  awk -F/ '$1 == "skills" && !(NF >= 3 && $2 ~ /^elelem-language-[[:alnum:]_-]+$/ && $3 != "") { found = 1 } END { exit !found }' "$1"
}

_copy_install_source() {
  local source="$1"
  mkdir -p "$source"
  cp "$REPO_ROOT/_install-common.sh" "$REPO_ROOT/install-claude.sh" "$REPO_ROOT/install-opencode.sh" "$REPO_ROOT/install-codex.sh" "$source/"
  cp -R "$REPO_ROOT/rules" "$REPO_ROOT/skills" "$REPO_ROOT/agents" "$source/"
}

_run_pty_installer() {
  local source="$1" harness="$2" home="$3" invocation="$4" input="$5"
  local deadline_seconds="${6:-45}" cleanup_grace_seconds="${7:-0.5}"
  python3 - "$source/install-$harness.sh" "$home" "$invocation" "$TEST_TMP" "$input" "$deadline_seconds" "$cleanup_grace_seconds" <<'PY'
import errno
import os
import pty
import select
import signal
import sys
import time

installer, home, invocation, test_root, input_text, deadline_seconds, cleanup_grace_seconds = sys.argv[1:]
process_id, terminal = pty.fork()
if process_id == 0:
    os.chdir(invocation)
    environment = os.environ.copy()
    environment.update({
        "HOME": home,
        "XDG_CONFIG_HOME": os.path.join(test_root, "xdg"),
        "CODEX_HOME": os.path.join(test_root, "codex"),
        "TMPDIR": os.path.join(test_root, "tmp"),
        "TERM": "dumb",
        "NO_COLOR": "1",
        "PYTHONDONTWRITEBYTECODE": "1",
    })
    os.execve("/bin/bash", ["bash", installer], environment)

os.set_blocking(terminal, False)
output = bytearray()

def collect_output() -> None:
    try:
        while True:
            data = os.read(terminal, 4096)
            if not data:
                return
            output.extend(data)
    except OSError as error:
        if error.errno not in (errno.EIO, errno.EAGAIN):
            raise

def remaining_grace_timeout(grace_deadline: float, current_time: float) -> float:
    return max(0.0, min(0.05, grace_deadline - current_time))

def stop_child() -> int:
    try:
        os.kill(process_id, signal.SIGTERM)
    except ProcessLookupError:
        pass
    grace_deadline = time.monotonic() + float(cleanup_grace_seconds)
    while True:
        collect_output()
        waited_pid, wait_status = os.waitpid(process_id, os.WNOHANG)
        if waited_pid:
            return wait_status
        wait_timeout = remaining_grace_timeout(grace_deadline, time.monotonic())
        if wait_timeout == 0:
            break
        select.select([terminal], [], [], wait_timeout)
    try:
        os.kill(process_id, signal.SIGKILL)
    except ProcessLookupError:
        pass
    while True:
        try:
            _, wait_status = os.waitpid(process_id, 0)
            return wait_status
        except InterruptedError:
            continue

child_reaped = False
try:
    input_index = 0
    while input_index < len(input_text):
        if input_text.startswith("\x1b[", input_index):
            chunk = input_text[input_index:input_index + 3]
            input_index += 3
            delay = 0.15
        else:
            chunk = input_text[input_index]
            input_index += 1
            delay = 0.15 if chunk == "\n" else 0.03
        os.write(terminal, chunk.encode())
        readable, _, _ = select.select([terminal], [], [], delay)
        if readable:
            collect_output()

    deadline = time.monotonic() + float(deadline_seconds)
    while True:
        readable, _, _ = select.select([terminal], [], [], 0.05)
        if readable:
            collect_output()
        waited_pid, wait_status = os.waitpid(process_id, os.WNOHANG)
        if waited_pid:
            child_reaped = True
            break
        if time.monotonic() >= deadline:
            stop_child()
            child_reaped = True
            collect_output()
            sys.stderr.write(output.decode(errors="replace"))
            print("Timed out waiting for installer completion", file=sys.stderr)
            raise SystemExit(124)

    collect_output()
    sys.stdout.write(output.decode(errors="replace"))
    raise SystemExit(os.waitstatus_to_exitcode(wait_status))
except Exception:
    if not child_reaped:
        stop_child()
        child_reaped = True
    collect_output()
    sys.stderr.write(output.decode(errors="replace"))
    raise
finally:
    try:
        if not child_reaped:
            stop_child()
    finally:
        os.close(terminal)
PY
}

_run_opencode_reinstall_with_testing_deselected() {
  local source="$1" home="$2" invocation="$3"
  local prompt_timeout_seconds="${4:-20}" deadline_seconds="${5:-45}" cleanup_grace_seconds="${6:-0.5}"
  python3 - "$source/install-opencode.sh" "$home" "$invocation" "$TEST_TMP" "$prompt_timeout_seconds" "$deadline_seconds" "$cleanup_grace_seconds" <<'PY'
import errno
import os
import pty
import select
import signal
import sys
import time

installer, home, invocation, test_root, prompt_timeout_seconds, deadline_seconds, cleanup_grace_seconds = sys.argv[1:]
process_id, terminal = pty.fork()
if process_id == 0:
    os.chdir(invocation)
    environment = os.environ.copy()
    environment.update({
        "HOME": home,
        "XDG_CONFIG_HOME": os.path.join(test_root, "xdg"),
        "CODEX_HOME": os.path.join(test_root, "codex"),
        "TMPDIR": os.path.join(test_root, "tmp"),
        "TERM": "dumb",
        "NO_COLOR": "1",
        "PYTHONDONTWRITEBYTECODE": "1",
    })
    os.execve("/bin/bash", ["bash", installer], environment)

os.set_blocking(terminal, False)
output = bytearray()

def collect_output() -> None:
    try:
        while True:
            data = os.read(terminal, 4096)
            if not data:
                return
            output.extend(data)
    except OSError as error:
        if error.errno not in (errno.EIO, errno.EAGAIN):
            raise

def remaining_grace_timeout(grace_deadline: float, current_time: float) -> float:
    return max(0.0, min(0.05, grace_deadline - current_time))

def wait_for(marker: bytes) -> None:
    global child_reaped
    deadline = time.monotonic() + float(prompt_timeout_seconds)
    while marker not in output:
        waited_pid, wait_status = os.waitpid(process_id, os.WNOHANG)
        if waited_pid:
            child_reaped = True
            collect_output()
            if marker in output:
                return
            exit_code = os.waitstatus_to_exitcode(wait_status)
            raise ChildProcessError(f"Installer exited with status {exit_code} before prompt: {marker.decode(errors='replace')}")
        readable, _, _ = select.select([terminal], [], [], 0.05)
        if readable:
            collect_output()
        if time.monotonic() >= deadline:
            raise TimeoutError(marker.decode(errors="replace"))

def send(value: bytes) -> None:
    os.write(terminal, value)
    readable, _, _ = select.select([terminal], [], [], 0.1)
    if readable:
        collect_output()

def stop_child() -> int:
    try:
        os.kill(process_id, signal.SIGTERM)
    except ProcessLookupError:
        pass
    grace_deadline = time.monotonic() + float(cleanup_grace_seconds)
    while True:
        collect_output()
        waited_pid, wait_status = os.waitpid(process_id, os.WNOHANG)
        if waited_pid:
            return wait_status
        wait_timeout = remaining_grace_timeout(grace_deadline, time.monotonic())
        if wait_timeout == 0:
            break
        select.select([terminal], [], [], wait_timeout)
    try:
        os.kill(process_id, signal.SIGKILL)
    except ProcessLookupError:
        pass
    while True:
        try:
            _, wait_status = os.waitpid(process_id, 0)
            return wait_status
        except InterruptedError:
            continue

child_reaped = False
try:
    try:
        wait_for(b"Install scope:")
        send(b"\n")
        wait_for(b"Common instruction files to install:")
        for rule_name in (
            b"code-organisation", b"code-review", b"coding-style", b"consistency",
            b"debugging", b"documentation", b"errors", b"git", b"language",
            b"performance", b"security", b"skills-policy", b"subagents", b"testing",
        ):
            send(b"\x1b[B")
            wait_for(b"> [x] " + rule_name)
        send(b" ")
        wait_for(b"> [ ] testing")
        send(b"\n")
        wait_for(b"Skills (target:")
        send(b" ")
        wait_for(b"> [ ] Install skills")
        send(b"\n")
        wait_for(b"Optional agent bundle:")
        send(b" ")
        wait_for(b"> [x] Elelem agent bundle (11 agents)")
        send(b"\n")

        deadline = time.monotonic() + float(deadline_seconds)
        while True:
            readable, _, _ = select.select([terminal], [], [], 0.05)
            if readable:
                collect_output()
            waited_pid, wait_status = os.waitpid(process_id, os.WNOHANG)
            if waited_pid:
                child_reaped = True
                break
            if time.monotonic() >= deadline:
                stop_child()
                child_reaped = True
                collect_output()
                sys.stderr.write(output.decode(errors="replace"))
                print("Timed out waiting for installer completion", file=sys.stderr)
                raise SystemExit(124)

        collect_output()
        sys.stdout.write(output.decode(errors="replace"))
        raise SystemExit(os.waitstatus_to_exitcode(wait_status))
    except TimeoutError as error:
        stop_child()
        child_reaped = True
        collect_output()
        sys.stderr.write(output.decode(errors="replace"))
        print(f"Timed out waiting for installer prompt: {error}", file=sys.stderr)
        raise SystemExit(124)
except Exception:
    if not child_reaped:
        stop_child()
        child_reaped = True
    collect_output()
    sys.stderr.write(output.decode(errors="replace"))
    raise
finally:
    try:
        if not child_reaped:
            stop_child()
    finally:
        os.close(terminal)
PY
}

test_opencode_user_install_delivers_selected_rules_and_installed_contracts() {
  local name='opencode_user_install_delivers_selected_rules_and_installed_contracts'
  local source="$TEST_TMP/source"
  local home="$TEST_TMP/home"
  local invocation="$TEST_TMP/opencode-user"
  local install_base="$home/.config/opencode"
  local installer_output
  mkdir -p "$home" "$invocation" "$TEST_TMP/tmp" "$TEST_TMP/xdg" "$TEST_TMP/codex"
  _copy_install_source "$source"
  if ! installer_output="$(_run_pty_installer "$source" opencode "$home" "$invocation" $'\n\n\n\n\n')"; then
    _fail "$name" 'OpenCode user-scope installer did not complete'
    return
  fi
  if ! grep -Fq 'rules/common/workflow.md' "$install_base/AGENTS.md"; then
    _fail "$name" 'installer did not deliver the generated rule index'
    return
  fi
  local installed_skill="$install_base/skills/subagent-driven-development/SKILL.md"
  local installed_worker_contract="$install_base/skills/_shared/worker-contract.md"
  if [[ ! -f "$installed_worker_contract" ]] || ! grep -Fq '../_shared/worker-contract.md' "$installed_skill" || [[ ! -f "$(dirname "$installed_skill")/../_shared/worker-contract.md" ]] || ! grep -Fq 'skills/_shared/worker-contract.md' "$source/.elelem-manifest-opencode"; then
    _fail "$name" 'installed skill did not resolve and manifest its source-derived contract at the active path'
    return
  fi
  printf 'Unmanaged skill content\n' > "$install_base/skills/user-note.md"
  printf 'Managed stale reviewer prompt\n' > "$install_base/skills/fast-path-implementation/fast-path-reviewer-prompt.md"
  printf 'skills/fast-path-implementation/fast-path-reviewer-prompt.md\n' >> "$source/.elelem-manifest-opencode"
  if ! installer_output="$(_run_opencode_reinstall_with_testing_deselected "$source" "$home" "$invocation")"; then
    _fail "$name" 'OpenCode reinstall did not complete'
    return
  fi
  if [[ ! -f "$source/rules/common/testing.md" ]] || grep -Fq 'rules/common/testing.md' "$install_base/AGENTS.md" || [[ -e "$install_base/rules/common/testing.md" || -e "$install_base/skills/debugging/SKILL.md" || -e "$install_base/skills/fast-path-implementation/fast-path-reviewer-prompt.md" || ! -f "$install_base/skills/user-note.md" ]] || grep -Fq 'skills/fast-path-implementation/fast-path-reviewer-prompt.md' "$source/.elelem-manifest-opencode" || grep -Fq 'rules/common/testing.md' "$source/.elelem-manifest-opencode"; then
    _fail "$name" 'reinstall did not prune deselected files and retain unmanaged skill content'
    return
  fi
  if [[ ! -f "$install_base/agents/architect-reviewer.md" ]] || grep -Eiq 'skills/|SKILL\.md' "$install_base/agents/architect-reviewer.md"; then
    _fail "$name" 'standalone agent bundle depends on optional skill installation'
    return
  fi
  _pass "$name"
}

test_pty_installer_timeout_reports_output_and_reaps_term_ignoring_child() {
  local name='pty_installer_timeout_reports_output_and_reaps_term_ignoring_child'
  local source="$TEST_TMP/timeout-source"
  local home="$TEST_TMP/timeout-home"
  local invocation="$TEST_TMP/timeout-invocation"
  local pid_file="$TEST_TMP/timeout-child.pid"
  local output status child_pid
  mkdir -p "$source" "$home" "$invocation"
  cat > "$source/install-fixture.sh" <<EOF
#!/usr/bin/env bash
trap '' TERM
printf '%s\\n' "\$\$" > '$pid_file'
printf 'fixture waiting for input\\n'
while IFS= read -r input; do :; done
EOF
  if output="$(_run_pty_installer "$source" fixture "$home" "$invocation" '' 2 0.15 2>&1)"; then
    status=0
  else
    status=$?
  fi
  child_pid="$(cat "$pid_file")"
  if [[ "$status" -ne 124 ]] || ! grep -Fq 'Timed out waiting for installer completion' <<< "$output" || ! grep -Fq 'fixture waiting for input' <<< "$output" || kill -0 "$child_pid" 2>/dev/null; then
    printf '%s\n' "$output"
    _fail "$name" 'timeout did not report diagnostics and reap its child'
    return
  fi
  _pass "$name"
}

test_opencode_missing_prompt_timeout_reports_output_and_reaps_term_ignoring_child() {
  local name='opencode_missing_prompt_timeout_reports_output_and_reaps_term_ignoring_child'
  local source="$TEST_TMP/missing-prompt-source"
  local home="$TEST_TMP/missing-prompt-home"
  local invocation="$TEST_TMP/missing-prompt-invocation"
  local pid_file="$TEST_TMP/missing-prompt-child.pid"
  local output status child_pid
  mkdir -p "$source" "$home" "$invocation"
  cat > "$source/install-opencode.sh" <<EOF
#!/usr/bin/env bash
trap '' TERM
printf '%s\\n' "\$\$" > '$pid_file'
printf 'Install scope:\\n'
IFS= read -r answer
printf 'fixture stopped before common rules\\n'
while IFS= read -r answer; do :; done
EOF
  if output="$(_run_opencode_reinstall_with_testing_deselected "$source" "$home" "$invocation" 0.3 1 0.15 2>&1)"; then
    status=0
  else
    status=$?
  fi
  child_pid="$(cat "$pid_file")"
  if [[ "$status" -ne 124 ]] || ! grep -Fq 'Timed out waiting for installer prompt: Common instruction files to install:' <<< "$output" || ! grep -Fq 'fixture stopped before common rules' <<< "$output" || kill -0 "$child_pid" 2>/dev/null; then
    printf '%s\n' "$output"
    _fail "$name" 'missing prompt did not report diagnostics and reap its child'
    return
  fi
  _pass "$name"
}

test_expired_cleanup_grace_has_a_zero_select_timeout() {
  local name='expired_cleanup_grace_has_a_zero_select_timeout'
  local output
  if output="$(python3 - "$SCRIPT_DIR/run_policy_installation_tests.sh" 2>&1 <<'PY'
import re
import sys

with open(sys.argv[1], encoding="utf-8") as script_file:
    script = script_file.read()
function_bodies = re.findall(
    r"(?m)^def remaining_grace_timeout\(grace_deadline: float, current_time: float\) -> float:\n(    return .*\n)",
    script,
)
assert len(function_bodies) == 2, f"expected two embedded grace calculations, found {len(function_bodies)}"
for function_body in function_bodies:
    namespace = {}
    exec(
        "def remaining_grace_timeout(grace_deadline: float, current_time: float) -> float:\n" + function_body,
        namespace,
    )
    remaining_grace_timeout = namespace["remaining_grace_timeout"]
    assert remaining_grace_timeout(10.0, 10.0) == 0.0
    assert remaining_grace_timeout(10.0, 11.0) == 0.0
    assert remaining_grace_timeout(11.0, 10.0) == 0.05
PY
)"; then
    _pass "$name"
  else
    printf '%s\n' "$output"
    _fail "$name" 'expired cleanup grace was not clamped before select'
  fi
}

test_opencode_early_exit_preserves_output_and_error() {
  local name='opencode_early_exit_preserves_output_and_error'
  local source="$TEST_TMP/early-opencode-source"
  local home="$TEST_TMP/early-opencode-home"
  local invocation="$TEST_TMP/early-opencode-invocation"
  local pid_file="$TEST_TMP/early-opencode-child.pid"
  local output status child_pid
  mkdir -p "$source" "$home" "$invocation"
  cat > "$source/install-opencode.sh" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "\$\$" > '$pid_file'
printf 'installer exited before scope prompt\\n'
exit 7
EOF
  if output="$(_run_opencode_reinstall_with_testing_deselected "$source" "$home" "$invocation" 0.3 2 0.1 2>&1)"; then
    status=0
  else
    status=$?
  fi
  if [[ ! -s "$pid_file" ]]; then
    printf '%s\n' "$output"
    _fail "$name" 'installer fixture did not reach its exit state'
    return
  fi
  child_pid="$(cat "$pid_file")"
  if [[ "$status" -eq 0 ]] || [[ "$(grep -Fc 'installer exited before scope prompt' <<< "$output")" -ne 1 ]] || ! grep -Fq 'ChildProcessError' <<< "$output" || kill -0 "$child_pid" 2>/dev/null; then
    printf '%s\n' "$output"
    _fail "$name" 'early child exit did not preserve diagnostics and its failure'
    return
  fi
  _pass "$name"
}

test_opencode_unexpected_error_preserves_output_and_error() {
  local name='opencode_unexpected_error_preserves_output_and_error'
  local source="$TEST_TMP/unexpected-opencode-source"
  local home="$TEST_TMP/unexpected-opencode-home"
  local invocation="$TEST_TMP/unexpected-opencode-invocation"
  local pid_file="$TEST_TMP/unexpected-opencode-child.pid"
  local output status child_pid
  mkdir -p "$source" "$home" "$invocation"
  cat > "$source/install-opencode.sh" <<EOF
#!/usr/bin/env bash
printf '%s\\n' "\$\$" > '$pid_file'
printf 'Install scope:\\n'
printf 'Common instruction files to install:\\n'
printf '%s\\n' '> [x] code-organisation' '> [x] code-review' '> [x] coding-style' '> [x] consistency' '> [x] debugging' '> [x] documentation' '> [x] errors' '> [x] git' '> [x] language' '> [x] performance' '> [x] security' '> [x] skills-policy' '> [x] subagents' '> [x] testing' '> [ ] testing'
printf 'Skills (target: fixture):\\n> [ ] Install skills\\nOptional agent bundle:\\n> [x] Elelem agent bundle (11 agents)\\n'
printf 'installer output before unexpected error\\n'
while IFS= read -r answer; do :; done
EOF
  if output="$(_run_opencode_reinstall_with_testing_deselected "$source" "$home" "$invocation" 1 invalid 0.1 2>&1)"; then
    status=0
  else
    status=$?
  fi
  if [[ ! -s "$pid_file" ]]; then
    _fail "$name" 'installer fixture did not reach its ready state'
    return
  fi
  child_pid="$(cat "$pid_file")"
  if [[ "$status" -eq 0 ]] || [[ "$(grep -Fc 'installer output before unexpected error' <<< "$output")" -ne 1 ]] || ! grep -Fq 'ValueError' <<< "$output" || kill -0 "$child_pid" 2>/dev/null; then
    printf '%s\n' "$output"
    _fail "$name" 'unexpected error did not preserve diagnostics and the original error'
    return
  fi
  _pass "$name"
}

test_claude_manifest_rejects_optional_skill_paths() {
  local name='claude_manifest_rejects_optional_skill_paths'
  local manifest="$TEST_TMP/optional-skill-manifest"
  printf '%s\n' 'skills/elelem-language-python/SKILL.md' > "$manifest"
  if _manifest_has_unsupported_skill_entries "$manifest"; then
    _fail "$name" 'manifest policy rejects a mandatory language pack entry'
    return
  fi
  printf '%s\n' 'skills/fast-path-implementation/SKILL.md' >> "$manifest"
  if ! _manifest_has_unsupported_skill_entries "$manifest"; then
    _fail "$name" 'manifest policy accepts a non-language optional skill entry'
    return
  fi
  _pass "$name"
}

test_claude_manifest_rejects_malformed_language_paths() {
  local name='claude_manifest_rejects_malformed_language_paths'
  local manifest="$TEST_TMP/malformed-language-manifest" path
  for path in 'skills/elelem-language-' 'skills/elelem-language-python' 'skills/elelem-language-python/'; do
    printf '%s\n' "$path" > "$manifest"
    if ! _manifest_has_unsupported_skill_entries "$manifest"; then
      _fail "$name" "manifest policy accepts malformed language path: $path"
      return
    fi
  done
  _pass "$name"
}

test_claude_user_install_can_select_rules_without_skills() {
  local name='claude_user_install_can_select_rules_without_skills'
  local source="$TEST_TMP/claude-source"
  local home="$TEST_TMP/claude-home"
  local invocation="$TEST_TMP/claude-invocation"
  local input installer_output
  mkdir -p "$home" "$invocation" "$TEST_TMP/tmp" "$TEST_TMP/xdg" "$TEST_TMP/codex"
  _copy_install_source "$source"
  input=$'\n\n \n\n'
  if ! installer_output="$(_run_pty_installer "$source" claude "$home" "$invocation" "$input")"; then
    _fail "$name" 'Claude user-scope installer did not complete'
    return
  fi
  if [[ ! -f "$home/.claude/rules/common/testing.md" || -e "$home/.claude/skills/debugging/SKILL.md" ]] || _manifest_has_unsupported_skill_entries "$source/.elelem-manifest-claude"; then
    _fail "$name" 'Claude did not preserve rules-only selection and its manifest'
    return
  fi
  _pass "$name"
}

test_opencode_user_install_delivers_selected_rules_and_installed_contracts
test_pty_installer_timeout_reports_output_and_reaps_term_ignoring_child
test_opencode_missing_prompt_timeout_reports_output_and_reaps_term_ignoring_child
test_expired_cleanup_grace_has_a_zero_select_timeout
test_opencode_early_exit_preserves_output_and_error
test_opencode_unexpected_error_preserves_output_and_error
test_claude_manifest_rejects_optional_skill_paths
test_claude_manifest_rejects_malformed_language_paths
test_claude_user_install_can_select_rules_without_skills
printf 'Tests: %d passed, %d failed\n' "$passed" "$failed"
((failed == 0))
