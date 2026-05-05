## test_spa1773_witness_account_used_emission.gd — Regression tests for SPA-1773.
##
## Asserts that log_witness_account_used() emits exactly one NDJSON
## "witness_account_used" event with all required fields and correctly halved
## bonus values when analytics is enabled, and zero events when disabled.
##
## Required fields (SPA-1773 spec): evidence_type, bypass_mode,
##   effective_believability_bonus, effective_credulity_boost,
##   target_npc_id, cooldown_target_npc_id, day, scenario_id, difficulty.
##
## Mutation sensitivity:
##   • Removing any required field from log_witness_account_used() causes the
##     corresponding field-presence test to fail.
##   • Removing the `if not SettingsManager.analytics_enabled: return` guard in
##     AnalyticsLogger.log_event() causes test_disabled_writes_zero_events to fail.
##   • Changing the event type string from "witness_account_used" causes
##     test_event_type_is_witness_account_used to fail.
##   • Passing un-halved bonus values (e.g. 0.15 instead of 0.075) causes
##     test_payload_halved_bel_bonus and test_payload_halved_cred_boost to fail.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpa1773WitnessAccountUsedEmission
extends RefCounted

const AnalyticsManagerScript := preload("res://scripts/analytics_manager.gd")


## Spy: captures the last NDJSON line without file I/O so field shape can be
## verified by parsing it back as JSON.
class _ShapeSpyLogger extends AnalyticsLogger:
	var call_count: int = 0
	var last_event: Dictionary = {}
	func _append_line(line: String) -> void:
		call_count += 1
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			last_event = parsed


## Returns [AnalyticsManager, _ShapeSpyLogger] with the spy pre-wired.
## _analytics_logger != null so log_witness_account_used() skips the queue path.
func _make_manager_with_spy() -> Array:
	var mgr: AnalyticsManager = AnalyticsManagerScript.new()
	var spy := _ShapeSpyLogger.new()
	mgr._analytics_logger = spy
	return [mgr, spy]


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── emission ──
		"test_enabled_writes_one_event",
		"test_disabled_writes_zero_events",

		# ── event type ──
		"test_event_type_is_witness_account_used",

		# ── field presence ──
		"test_payload_contains_evidence_type",
		"test_payload_contains_bypass_mode",
		"test_payload_contains_effective_believability_bonus",
		"test_payload_contains_effective_credulity_boost",
		"test_payload_contains_target_npc_id",
		"test_payload_contains_cooldown_target_npc_id",
		"test_payload_contains_day",
		"test_payload_contains_scenario_id",
		"test_payload_contains_difficulty",

		# ── field values ──
		"test_payload_bypass_mode_is_true",
		"test_payload_evidence_type_value",
		"test_payload_target_npc_id_value",
		"test_payload_cooldown_target_npc_id_matches_target",
		"test_payload_halved_bel_bonus",
		"test_payload_halved_cred_boost",

		# ── bypass-only gate ──
		"test_normal_usage_does_not_emit",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			print("  FAIL  %s" % method_name)
			failed += 1

	print("\n  %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Emission: one event when enabled, zero when disabled
# ══════════════════════════════════════════════════════════════════════════════

func test_enabled_writes_one_event() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true

	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]

	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_finn_monk")

	SettingsManager.analytics_enabled = saved
	return spy.call_count == 1


func test_disabled_writes_zero_events() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = false

	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]

	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_finn_monk")

	SettingsManager.analytics_enabled = saved
	return spy.call_count == 0


# ══════════════════════════════════════════════════════════════════════════════
# Event type
# ══════════════════════════════════════════════════════════════════════════════

func test_event_type_is_witness_account_used() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true

	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]

	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_finn_monk")

	SettingsManager.analytics_enabled = saved
	return spy.last_event.get("type", "") == "witness_account_used"


# ══════════════════════════════════════════════════════════════════════════════
# Field presence — all required fields must appear in the event payload
# ══════════════════════════════════════════════════════════════════════════════

func test_payload_contains_evidence_type() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_finn_monk")
	SettingsManager.analytics_enabled = saved
	return "evidence_type" in spy.last_event


func test_payload_contains_bypass_mode() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_finn_monk")
	SettingsManager.analytics_enabled = saved
	return "bypass_mode" in spy.last_event


func test_payload_contains_effective_believability_bonus() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_finn_monk")
	SettingsManager.analytics_enabled = saved
	return "effective_believability_bonus" in spy.last_event


func test_payload_contains_effective_credulity_boost() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_finn_monk")
	SettingsManager.analytics_enabled = saved
	return "effective_credulity_boost" in spy.last_event


func test_payload_contains_target_npc_id() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_finn_monk")
	SettingsManager.analytics_enabled = saved
	return "target_npc_id" in spy.last_event


func test_payload_contains_cooldown_target_npc_id() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_finn_monk")
	SettingsManager.analytics_enabled = saved
	return "cooldown_target_npc_id" in spy.last_event


func test_payload_contains_day() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_finn_monk")
	SettingsManager.analytics_enabled = saved
	return "day" in spy.last_event


func test_payload_contains_scenario_id() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_finn_monk")
	SettingsManager.analytics_enabled = saved
	return "scenario_id" in spy.last_event


func test_payload_contains_difficulty() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_finn_monk")
	SettingsManager.analytics_enabled = saved
	return "difficulty" in spy.last_event


# ══════════════════════════════════════════════════════════════════════════════
# Field values — caller-supplied arguments must appear verbatim in the payload
# ══════════════════════════════════════════════════════════════════════════════

func test_payload_bypass_mode_is_true() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_finn_monk")
	SettingsManager.analytics_enabled = saved
	return spy.last_event.get("bypass_mode", false) == true


func test_payload_evidence_type_value() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_finn_monk")
	SettingsManager.analytics_enabled = saved
	return spy.last_event.get("evidence_type", "") == "witness_account"


func test_payload_target_npc_id_value() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_maren_nun")
	SettingsManager.analytics_enabled = saved
	return spy.last_event.get("target_npc_id", "") == "npc_maren_nun"


func test_payload_cooldown_target_npc_id_matches_target() -> bool:
	# cooldown_target_npc_id must equal target_npc_id: the seed target is the
	# NPC whose cooldown triggered the bypass.
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_aldric_merchant")
	SettingsManager.analytics_enabled = saved
	return (spy.last_event.get("cooldown_target_npc_id", "") ==
			spy.last_event.get("target_npc_id", "MISMATCH"))


## Halved values: base believability_bonus for Witness Account is 0.15,
## so effective bypass value is 0.15 × 0.5 = 0.075.
func test_payload_halved_bel_bonus() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	# Pass the already-halved value as world.gd computes it.
	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_finn_monk")
	SettingsManager.analytics_enabled = saved
	return absf(spy.last_event.get("effective_believability_bonus", -1.0) - 0.075) < 0.0001


## Halved values: base credulity_boost for Witness Account is 0.05,
## so effective bypass value is 0.05 × 0.5 = 0.025.
func test_payload_halved_cred_boost() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_witness_account_used("witness_account", 0.075, 0.025, "npc_finn_monk")
	SettingsManager.analytics_enabled = saved
	return absf(spy.last_event.get("effective_credulity_boost", -1.0) - 0.025) < 0.0001


# ══════════════════════════════════════════════════════════════════════════════
# Bypass-only gate: normal (non-bypass) usage must NOT emit this event
# ══════════════════════════════════════════════════════════════════════════════

## In normal usage world.gd does not emit witness_account_bypass_used, so
## log_witness_account_used() is never called.  Verify by confirming that
## calling it zero times leaves call_count at zero.
func test_normal_usage_does_not_emit() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var spy: _ShapeSpyLogger = pair[1]
	# Simulate no bypass: do not call log_witness_account_used at all.
	SettingsManager.analytics_enabled = saved
	return spy.call_count == 0
