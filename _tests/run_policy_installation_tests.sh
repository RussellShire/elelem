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

_copy_install_source() {
  local source="$1"
  mkdir -p "$source"
  cp "$REPO_ROOT/_install-common.sh" "$REPO_ROOT/install-claude.sh" "$REPO_ROOT/install-opencode.sh" "$REPO_ROOT/install-codex.sh" "$source/"
  cp -R "$REPO_ROOT/rules" "$REPO_ROOT/skills" "$REPO_ROOT/agents" "$source/"
}

_run_pty_installer() {
  local source="$1" harness="$2" home="$3" invocation="$4" input="$5"
  python3 - "$source/install-$harness.sh" "$home" "$invocation" "$TEST_TMP" "$input" <<'PY'
import errno
import os
import pty
import select
import signal
import sys
import time

installer, home, invocation, test_root, input_text = sys.argv[1:]
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

deadline = time.monotonic() + 45
while True:
    readable, _, _ = select.select([terminal], [], [], 0.05)
    if readable:
        collect_output()
    waited_pid, wait_status = os.waitpid(process_id, os.WNOHANG)
    if waited_pid:
        break
    if time.monotonic() >= deadline:
        os.kill(process_id, signal.SIGTERM)
        os.waitpid(process_id, 0)
        collect_output()
        sys.stdout.write(output.decode(errors="replace"))
        raise SystemExit(124)

collect_output()
sys.stdout.write(output.decode(errors="replace"))
raise SystemExit(os.waitstatus_to_exitcode(wait_status))
PY
}

_run_opencode_reinstall_with_testing_deselected() {
  local source="$1" home="$2" invocation="$3"
  python3 - "$source/install-opencode.sh" "$home" "$invocation" "$TEST_TMP" <<'PY'
import errno
import os
import pty
import select
import signal
import sys
import time

installer, home, invocation, test_root = sys.argv[1:]
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

def wait_for(marker: bytes) -> None:
    deadline = time.monotonic() + 20
    while marker not in output:
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
    wait_for(b"Language packs to install")
    send(b"\n")
    wait_for(b"Skills (target:")
    send(b" ")
    wait_for(b"> [ ] Install skills")
    send(b"\n")
    wait_for(b"Optional agent bundle:")
    send(b" ")
    wait_for(b"> [x] Elelem agent bundle (11 agents)")
    send(b"\n")
except TimeoutError as error:
    os.kill(process_id, signal.SIGTERM)
    os.waitpid(process_id, 0)
    collect_output()
    sys.stdout.write(output.decode(errors="replace"))
    print(f"Timed out waiting for installer prompt: {error}", file=sys.stderr)
    raise SystemExit(124)

deadline = time.monotonic() + 45
while True:
    readable, _, _ = select.select([terminal], [], [], 0.05)
    if readable:
        collect_output()
    waited_pid, wait_status = os.waitpid(process_id, os.WNOHANG)
    if waited_pid:
        break
    if time.monotonic() >= deadline:
        os.kill(process_id, signal.SIGTERM)
        os.waitpid(process_id, 0)
        collect_output()
        sys.stdout.write(output.decode(errors="replace"))
        raise SystemExit(124)

collect_output()
sys.stdout.write(output.decode(errors="replace"))
raise SystemExit(os.waitstatus_to_exitcode(wait_status))
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

test_claude_user_install_can_select_rules_without_skills() {
  local name='claude_user_install_can_select_rules_without_skills'
  local source="$TEST_TMP/claude-source"
  local home="$TEST_TMP/claude-home"
  local invocation="$TEST_TMP/claude-invocation"
  local input installer_output
  mkdir -p "$home" "$invocation" "$TEST_TMP/tmp" "$TEST_TMP/xdg" "$TEST_TMP/codex"
  _copy_install_source "$source"
  input=$'\n\n\n \n\n'
  if ! installer_output="$(_run_pty_installer "$source" claude "$home" "$invocation" "$input")"; then
    _fail "$name" 'Claude user-scope installer did not complete'
    return
  fi
  if [[ ! -f "$home/.claude/rules/common/testing.md" || -e "$home/.claude/skills/debugging/SKILL.md" ]] || grep -Fq 'skills/' "$source/.elelem-manifest-claude"; then
    _fail "$name" 'Claude did not preserve rules-only selection and its manifest'
    return
  fi
  _pass "$name"
}

test_opencode_user_install_delivers_selected_rules_and_installed_contracts
test_claude_user_install_can_select_rules_without_skills
printf 'Tests: %d passed, %d failed\n' "$passed" "$failed"
((failed == 0))
