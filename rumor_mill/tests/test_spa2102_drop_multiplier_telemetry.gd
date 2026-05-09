## test_spa2102_drop_multiplier_telemetry.gd — Regression tests for SPA-2102.
##
## Verifies that AnalyticsManager.log_evidence_acquired emits a `drop_multiplier_active`
## boolean field in the `evidence_acquired` NDJSON payload:
##
##   A1: explicit true  — forged_document / observe_building / true
##   A2: explicit false — witness_account / eavesdrop_npc / false
##   Default param      — forged_document / observe_building (no 3rd arg) → false
##
## Strategy:
##   • _SpyLogger extends AnalyticsLogger — same approach as test_spa1613_evidence_acquired.gd.
##     Overrides _append_line() with an in-memory accumulator; no file I/O occurs.
##   • SettingsManager.analytics_enabled = true so the enabled gate passes.
##   • State is restored after each test that mutates analytics_enabled.
##
## Mutation sensitivity:
##   Removing `drop_multiplier_active` from the log_event() call in
##   AnalyticsManager.log_evidence_acquired() causes all three tests to fail.
##   Changing the default value from false causes the default-param test to fail.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpa2102DropMultiplierTelemetry
extends RefCounted

const AnalyticsManagerScript := preload("res://scripts/analytics_manager.gd")


## Spy: inherits the real log_event() analytics-enabled gate; replaces file I/O
## with an in-memory accumulator.
class _SpyLogger extends AnalyticsLogger:
	var last_entry: Dictionary = {}

	func _append_line(line: String) -> void:
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			last_entry = parsed


## Returns [AnalyticsManager, _SpyLogger] pre-wired for emission.
func _make_manager_with_spy() -> Array:
	var mgr: AnalyticsManager = AnalyticsManagerScript.new()
	var spy := _SpyLogger.new()
	mgr._analytics_logger = spy
	mgr._analytics_scenario_id = "scenario_1"
	return [mgr, spy]


## Fire one acquisition with drop_multiplier_active and return the spy.
func _acquire(evidence_type: String, source_action: String, drop_multiplier_active: bool) -> _SpyLogger:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	(pair[0] as AnalyticsManager).log_evidence_acquired(evidence_type, source_action, drop_multiplier_active)
	SettingsManager.analytics_enabled = saved
	return pair[1] as _SpyLogger


## Fire one acquisition without a 3rd arg (default param path).
func _acquire_default(evidence_type: String, source_action: String) -> _SpyLogger:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	(pair[0] as AnalyticsManager).log_evidence_acquired(evidence_type, source_action)
	SettingsManager.analytics_enabled = saved
	return pair[1] as _SpyLogger


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_a1_drop_multiplier_active_true",
		"test_a2_drop_multiplier_active_false",
		"test_default_param_drop_multiplier_active_false",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\n  %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# A1 — drop_multiplier_active: true
# ══════════════════════════════════════════════════════════════════════════════

## Slice A row A1: multiplier active during days 4–12; field must be true.
func test_a1_drop_multiplier_active_true() -> bool:
	var spy: _SpyLogger = _acquire("forged_document", "observe_building", true)
	return spy.last_entry.get("drop_multiplier_active", null) == true


# ══════════════════════════════════════════════════════════════════════════════
# A2 — drop_multiplier_active: false
# ══════════════════════════════════════════════════════════════════════════════

## Slice A row A2: multiplier inactive (baseline days); field must be false.
func test_a2_drop_multiplier_active_false() -> bool:
	var spy: _SpyLogger = _acquire("witness_account", "eavesdrop_npc", false)
	return spy.last_entry.get("drop_multiplier_active", null) == false


# ══════════════════════════════════════════════════════════════════════════════
# Default param — omitting 3rd arg must emit drop_multiplier_active: false
# ══════════════════════════════════════════════════════════════════════════════

## Call sites that predate SPA-2102 do not pass a 3rd argument. The default
## must produce drop_multiplier_active: false so existing logs stay consistent.
func test_default_param_drop_multiplier_active_false() -> bool:
	var spy: _SpyLogger = _acquire_default("forged_document", "observe_building")
	return spy.last_entry.get("drop_multiplier_active", null) == false
