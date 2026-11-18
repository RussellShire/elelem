set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
passed=0
failed=0

check_contract() {
  local name="$1" relative="$2" content pattern
  shift 2
  if ! content="$(tr '\n' ' ' < "$REPO_ROOT/$relative" | tr -s '[:space:]' ' ')"; then
    printf '[FAIL] %s: could not read %s\n' "$name" "$relative"
    (( failed++ )) || true
    return 0
  fi
  for pattern in "$@"; do
    if ! grep -Eiq "$pattern" <<< "$content"; then
      printf '[FAIL] %s: missing contract in %s: %s\n' "$name" "$relative" "$pattern"
      (( failed++ )) || true
      return 0
    fi
  done
  printf '[PASS] %s\n' "$name"
  (( passed++ )) || true
}

dispatch=skills/_shared/subagent-dispatch.md
briefs=skills/_shared/task-briefs.md
artefacts=skills/_shared/workflow-artifacts.md

check_contract implementation_uses_lowest_capable_named_tier "$dispatch" \
  'Implementation tiers are `low`, `medium` and `high`' \
  'lowest capable.{0,80}short.{0,40}rationale' \
  'specialist.{0,80}independent of.{0,80}model'

check_contract opencode_resolves_effective_provider_alias "$dispatch" \
  'providers\.<provider>\.models\.<tier>\.modelID' \
  'GET /api/config.{0,100}array.{0,60}Config.Entry' \
  'scope.{0,60}precedence.{0,180}unique effective provider.{0,40}alias' \
  'disabled.{0,60}inactive.{0,100}ambiguity'

check_contract opencode_keeps_api_target_opaque "$dispatch" \
  'modelID.{0,80}opaque provider-local.{0,80}slashes' \
  'not.{0,60}cross-provider redirect.{0,60}alias chaining' \
  'provider/alias\[#variant\]'

check_contract opencode_requires_alias_own_metadata "$dispatch" \
  'GET /api/model' \
  'own capabilities, limits and variants' \
  'not assume.{0,80}inherit.{0,80}target' \
  '#variant.{0,60}not.{0,40}tier'

check_contract claude_uses_native_slots_not_concrete_call_ids "$dispatch" \
  'low=haiku.{0,40}medium=sonnet.{0,40}high=opus' \
  'ANTHROPIC_DEFAULT_HAIKU_MODEL.{0,80}ANTHROPIC_DEFAULT_SONNET_MODEL.{0,80}ANTHROPIC_DEFAULT_OPUS_MODEL' \
  'settings.env.{0,80}environment' \
  'actual.{0,40}enum.{0,100}not.{0,60}full model ID'

check_contract claude_checks_effective_resolution "$dispatch" \
  'same-family.{0,80}override.{0,80}restrictions' \
  'reasoning.{0,80}metadata.{0,80}schema' \
  'shared alias.{0,80}effects'

check_contract codex_profiles_are_source_only "$dispatch" \
  '\$CODEX_HOME/<tier>.config.toml' \
  'source only.{0,120}model.{0,80}effort.{0,80}provider compatibility' \
  'not.{0,80}--profile.{0,80}child' \
  'not.{0,80}change the parent'

check_contract codex_checks_independent_native_fields "$dispatch" \
  '0.163.{0,160}agent_type.{0,60}model.{0,60}reasoning_effort' \
  'V2.{0,100}gated.{0,100}actual.{0,60}schema' \
  'specialist.{0,80}overrides.{0,100}inherited provider.{0,100}blockers'

check_contract exact_model_request_is_live_and_task_scoped "$dispatch" \
  'live model-override instruction' \
  'exact model/variant request' \
  'named task' \
  'in-scope corrections' \
  'configuration, tier.{0,40}design approval'

check_contract configuration_faults_require_an_explicit_alternative "$dispatch" \
  'configuration fault.{0,100}block' \
  'user explicitly requests that exact selection' \
  'not an automatic fallback' \
  'identified contingency'

check_contract missing_inspection_evidence_is_not_a_mapping_fault "$dispatch" \
  'inability to inspect.{0,80}missing evidence' \
  'not.{0,60}configuration fault' \
  'block.{0,80}dispatch'

check_contract native_selector_and_resolved_target_are_both_presented "$dispatch" \
  'native selector' \
  'resolved.{0,40}(provider|API).{0,40}target' \
  'task.{0,40}scope' \
  'settings'

check_contract runtime_failures_do_not_trigger_config_fallback "$dispatch" \
  'disabled.{0,80}unavailable.{0,160}configuration-resolution' \
  'execution failure.{0,120}distinct blockers.{0,80}not configuration-fallback' \
  'valid but incapable mapping.{0,80}unsupported required effort.{0,80}unsupported route' \
  'Do not search for an arbitrary working model.{0,80}omitted-model defaults.{0,80}silently escalate'

check_contract implementation_selection_distinguishes_candidate_and_actual_pin "$briefs" \
  'actual dispatch pin.{0,60}distinct from the preflight candidate' \
  'actual dispatch pin.{0,200}only after final.{0,200}immediately before the call' \
  'preflight revision' \
  'request source.{0,100}exact named task/correction scope' \
  'effort or variant.{0,40}explicitly absent' \
  'observed runtime evidence.{0,80}separate from both candidate and pin'

check_contract implementation_selection_retains_submitted_invocation_evidence "$briefs" \
  'retain.{0,100}(actual submitted call arguments|captured tool-call evidence reference)' \
  'actual submitted call arguments.{0,160}model.{0,100}effort/variant.{0,100}specialist controls' \
  'unsupported or absent.{0,100}evidence' \
  'distinct from the preflight candidate, authorised pin and observed runtime evidence'

check_contract implementation_selection_retains_request_and_route_evidence "$briefs" \
  'configured source/revision' \
  'current tool schema' \
  'catalogue/capability' \
  'routing evidence' \
  'fallback flag.{0,60}reason.{0,60}warning.{0,100}historical' \
  'never as authority'

check_contract corrections_reuse_pin_and_material_drift_renews_consent "$dispatch" \
  'unchanged.{0,80}correction.{0,80}retained actual pin' \
  'target, variant, required effort, selector identity.{0,100}task-scope change' \
  'invalidates the affected consent and preflight' \
  'source revision change demonstrated.{0,180}reuse existing evidence' \
  'legacy.{0,80}fallback.{0,100}no inferred consent'

check_contract caller_retains_submitted_invocation_evidence skills/subagent-driven-development/SKILL.md \
  'retain.{0,100}(actual submitted call arguments|captured tool-call evidence reference)' \
  'model, effort/variant and specialist controls.{0,100}actually submitted' \
  'unsupported or absent.{0,100}evidence'

check_contract external_runtime_plugins_remain_outside_policy "$dispatch" \
  'external.{0,80}runtime retries.{0,60}model switches.{0,100}outside.{0,60}policy' \
  'not.{0,60}disable.{0,60}block.{0,80}plugin' \
  'not claim.{0,80}pins prevent.{0,80}runtime changes' \
  'requested workflow selection.{0,80}observed.{0,80}execution' \
  'self-report.{0,80}not.{0,60}routing proof'

check_contract existing_task_record_retains_pin_provenance "$artefacts" \
  'load.{0,80}task-briefs.md.{0,80}nested implementation selection record' \
  'preflight candidate.{0,80}actual dispatch pin' \
  'original provenance'

check_contract readme_explains_tier_setup_without_installing_models README.md \
  'lowest capable tier.{0,100}rationale' \
  'specialist.{0,80}independent' \
  'no automatic.{0,80}configuration.{0,80}default.{0,80}model writes' \
  'preparation and reviewer.{0,60}unchanged'

check_contract readme_explains_opencode_effective_scope README.md \
  'providers\.<provider>\.models\.(low\|medium\|high)\.modelID' \
  'farthest.{0,60}closest.{0,100}\.opencode' \
  'managed.{0,60}highest precedence' \
  'GET /api/config.{0,80}array.{0,40}Config.Entry' \
  'disabled.{0,40}inactive.{0,60}ambiguity' \
  'redact.{0,60}secrets'

check_contract readme_explains_opencode_metadata_safety README.md \
  'opaque provider-local.{0,80}slashes' \
  'not.{0,40}cross-provider redirects' \
  'different providers.{0,100}unique effective mapping' \
  'own.{0,40}capabilities, limits and variants' \
  'not.{0,40}inherited.{0,40}target' \
  'numeric example values.{0,100}known actual' \
  'missing capability evidence.{0,40}blocker' \
  '#variant.{0,60}not.{0,40}tier'

check_contract readme_explains_claude_shared_effective_pins README.md \
  'low=haiku.{0,40}medium=sonnet.{0,40}high=opus' \
  '~/.claude/settings.json.{0,80}\.claude/settings.json.{0,80}\.claude/settings.local.json' \
  'managed.{0,60}command.line.{0,60}local.{0,60}project.{0,60}user' \
  'process environment' \
  'shared.{0,80}other.{0,40}uses' \
  'actual per-invoke.{0,40}enum.{0,80}not arbitrary' \
  'same-family parent.{0,80}force.{0,80}specialist.{0,80}reasoning'

check_contract readme_explains_codex_source_only_routing README.md \
  '\$CODEX_HOME/.{0,80}low.config.toml.{0,80}medium.config.toml.{0,80}high.config.toml' \
  '0.134.{0,100}top-level.{0,80}not.{0,40}\[profiles.low\]' \
  'source only.{0,100}provider compatibility' \
  'never.{0,40}--profile.{0,80}child.{0,100}unrelated settings.{0,100}parent' \
  '0.163.{0,100}agent_type.{0,40}model.{0,40}reasoning_effort' \
  'V2.{0,80}gated.{0,80}actual.{0,40}schema' \
  'inherited provider.{0,80}specialist.{0,80}overrides.{0,80}block'

check_contract readme_explains_fail_closed_alternatives_and_correction_pin README.md \
  'configuration-resolution.{0,80}missing.{0,80}malformed.{0,80}ambiguous.{0,80}disabled.{0,80}inactive.{0,80}unavailable' \
  'configuration.{0,120}fault.{0,100}blocks affected dispatch' \
  'exact model/variant request.{0,100}named task' \
  'current model.{0,100}user requests.{0,80}exact model/variant' \
  'inability to inspect or enumerate.{0,80}missing evidence.{0,40}not.{0,40}mapping fault' \
  'valid but incapable mapping.{0,80}unsupported required effort.{0,80}route mismatch' \
  'native selector.{0,100}resolved.{0,40}(provider|API).{0,40}target' \
  'corrections.{0,80}reuse.{0,80}actual pin' \
  'not reselect.{0,80}then-current' \
  'drift.{0,80}model change.{0,80}authorisation'

check_contract readme_distinguishes_runtime_evidence README.md \
  'external plugins.{0,80}runtime retries.{0,80}model-switch recovery.{0,80}outside.{0,40}policy.{0,80}unchanged' \
  'not block.{0,80}mere existence' \
  'pins do not control.{0,80}runtime' \
  'requested selection.{0,60}not.{0,40}observed runtime proof' \
  'no live runtime acceptance was authorised.{0,80}unverified, not passed' \
  'preflight candidate.{0,100}actual dispatch pin' \
  'actual invocation settings.{0,100}pin.{0,80}before sending' \
  'bash _tests/run_implementation_model_selection_tests.sh'

check_contract scenarios_describe_fail_closed_selection _tests/workflow_scenarios.md \
  'Implementation model selection' \
  'optional future manual checks.{0,80}not.{0,40}completion gate' \
  'runtime acceptance.{0,80}authorised.{0,80}unverified, not passed' \
  'exact model/variant request.{0,100}named task' \
  'configuration faults block affected dispatch' \
  'current model.{0,120}requests that exact selection' \
  'external plugins.{0,80}runtime retries.{0,80}model switches.{0,80}outside.{0,40}policy' \
  'requested selection.{0,80}observed runtime' \
  'correction.{0,250}retained actual task pin'

check_contract scenarios_cover_selection_faults_and_drift _tests/workflow_scenarios.md \
  'absent exact model/variant request' \
  'missing, malformed, ambiguous, disabled/inactive and unavailable' \
  'user requests that exact selection.{0,100}specifically identified contingency' \
  'alias target.{0,60}variant' \
  'unsupported required effort' \
  'correction.{0,100}parent.{0,60}another model' \
  'legacy fallback.{0,100}no inferred consent' \
  'external.{0,40}runtime.{0,40}plugin'

check_native_example() {
  local harness="$1" index="$2"
  if python3 - "$REPO_ROOT/README.md" "$harness" "$index" <<'PY'
import json
import re
import sys
import tomllib
from pathlib import Path


def load_example(path: str, harness: str, index: int) -> dict[str, object]:
    text = Path(path).read_text()
    section = re.search(rf"^#### {harness}\n(.*?)(?=^#### |^### |\Z)", text, re.M | re.S)
    assert section is not None, f"missing {harness} native example section"
    language = "toml" if harness == "Codex" else "json"
    blocks = re.findall(rf"^```{language}\n(.*?)^```", section[1], re.M | re.S)
    assert len(blocks) == (3 if harness == "Codex" else 1), "missing native tier examples"
    return tomllib.loads(blocks[index]) if language == "toml" else json.loads(blocks[index])


def check_opencode(example: dict[str, object]) -> None:
    assert set(example) == {"$schema", "providers"}, "unexpected default or tier map"
    models = example["providers"]["<provider-id>"]["models"]
    assert set(models) == {"low", "medium", "high"}, "missing native tier aliases"
    for tier, model in models.items():
        assert model["modelID"] == f"<concrete-{tier}-api-model-id>", "non-placeholder target"
        assert model["capabilities"]["tools"] is True, "missing alias capability example"
        assert model["limit"]["context"] > model["limit"]["output"] > 0, "invalid limits"


def check_claude(example: dict[str, object]) -> None:
    assert set(example) == {"env"}, "pins must use settings.env"
    for family in ("HAIKU", "SONNET", "OPUS"):
        assert example["env"][f"ANTHROPIC_DEFAULT_{family}_MODEL"] == f"<concrete-{family.lower()}-model-id>", "missing explicit family pin"


def check_codex(example: dict[str, object], index: int) -> None:
    tier = ("low", "medium", "high")[index]
    assert set(example) == {"model", "model_reasoning_effort"}, "profile must contain top-level selection only"
    assert example["model"] == f"<concrete-{tier}-model-id>", "non-placeholder model"
    assert example["model_reasoning_effort"] in {"minimal", "low", "medium", "high", "xhigh"}, "invalid effort example"


harness, index = sys.argv[2], int(sys.argv[3])
example = load_example(sys.argv[1], harness, index)
if harness == "OpenCode":
    check_opencode(example)
elif harness == "Claude Code":
    check_claude(example)
else:
    check_codex(example, index)
PY
  then
    printf '[PASS] %s native example %s\n' "$harness" "$index"
    (( passed++ )) || true
  else
    printf '[FAIL] %s native example %s\n' "$harness" "$index"
    (( failed++ )) || true
  fi
}

check_native_example OpenCode 0
check_native_example 'Claude Code' 0
check_native_example Codex 0
check_native_example Codex 1
check_native_example Codex 2

printf 'Cases: %d, Passed: %d, Failed: %d\n' "$(( passed + failed ))" "$passed" "$failed"
(( failed == 0 ))
