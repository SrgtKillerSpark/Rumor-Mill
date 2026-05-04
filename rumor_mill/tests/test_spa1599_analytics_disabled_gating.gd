## test_spa1599_analytics_disabled_gating.gd — Integration tests for A4 acceptance criterion (SPA-1599).
##
## Asserts that when analytics is disabled in settings, acquiring evidence emits
## NO evidence_acquired event; and that re-enabling analytics allows the event to fire.
##
## A4 from docs/phase2-acceptance-tests.md:
##   Acquire evidence with analytics disabled in settings → no evidence_acquired event.
##
## Strategy:
##   • _SpyLogger extends AnalyticsLogger — inherits the real log_event() guard
##     (if not SettingsManager.analytics_enabled: return) but overrides _append_line()
##     with an in-memory counter so no file I/O occurs during tests.
##   • Tests set SettingsManager.analytics_enabled via the autoload before calling
##     AnalyticsManager.log_evidence_acquired() and verify the spy call count.
##   • Every test that mutates analytics_enabled restores the original value on exit.
##
## Mutation sensitivity: removing the `if not SettingsManager.analytics_enabled: return`
## guard from AnalyticsLogger.log_event() causes _append_line() to be called when
## disabled — test_disabled_acquire_writes_zero_events fails (count 1, expected 0).
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpa1599AnalyticsDisabledGating
extends RefCounted

const AnalyticsManagerScript := preload("res://scripts/analytics_manager.gd")


## Spy subclass: inherits the real log_event() guard; replaces file I/O with counter.
## _append_line() is only reached when SettingsManager.analytics_enabled is true,
## so append_count stays 0 under the analytics-disabled gate.
class _SpyLogger extends AnalyticsLogger:
	var append_count: int = 0
	func _append_line(_line: String) -> void:
		append_count += 1


## Returns [AnalyticsManager, _SpyLogger] with the spy pre-wired as the live logger.
## _analytics_logger != null so handlers call log_event() directly (no pre-setup queue).
func _make_manager_with_spy() -> Array:
	var mgr: AnalyticsManager = AnalyticsManagerScript.new()
	var spy := _SpyLogger.new()
	mgr._analytics_logger = spy
	return [mgr, spy]


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── A4: disabled → no event ──
		"test_disabled_acquire_writes_zero_events",
		"test_disabled_all_three_evidence_types_suppressed",

		# ── Positive control: enabled → event fires ──
		"test_enabled_acquire_writes_one_event",

		# ── Round-trip: disable then re-enable on same manager instance ──
		"test_reenable_after_disable_resumes_logging",
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
# A4: analytics disabled — no evidence_acquired event written
# ══════════════════════════════════════════════════════════════════════════════

## Core A4 assertion: with analytics disabled, log_evidence_acquired() must not
## reach _append_line(). The gate is AnalyticsLogger.log_event()'s opening guard:
##   if not SettingsManager.analytics_enabled: return
## Removing that guard causes this test to fail (append_count becomes 1, not 0).
func test_disabled_acquire_writes_zero_events() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = false

	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _SpyLogger = pair[1]

	mgr.log_evidence_acquired("forged_document", "observe_building")

	SettingsManager.analytics_enabled = saved
	return spy.append_count == 0


## All three in-game evidence types must be suppressed when analytics is disabled.
## Each triggers the same log_event() call, so all three must see count == 0.
func test_disabled_all_three_evidence_types_suppressed() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = false

	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _SpyLogger = pair[1]

	mgr.log_evidence_acquired("forged_document", "observe_building")
	mgr.log_evidence_acquired("incriminating_artifact", "observe_building")
	mgr.log_evidence_acquired("witness_account", "eavesdrop_npc")

	SettingsManager.analytics_enabled = saved
	return spy.append_count == 0


# ══════════════════════════════════════════════════════════════════════════════
# Positive control: analytics enabled — evidence_acquired event fires
# ══════════════════════════════════════════════════════════════════════════════

## Positive control: with analytics enabled the gate passes and _append_line()
## is called exactly once. This ensures the test would catch a broken emission
## path (count == 0 when it should be 1) in addition to false suppression.
func test_enabled_acquire_writes_one_event() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true

	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _SpyLogger = pair[1]

	mgr.log_evidence_acquired("witness_account", "eavesdrop_npc")

	SettingsManager.analytics_enabled = saved
	return spy.append_count == 1


# ══════════════════════════════════════════════════════════════════════════════
# Round-trip: disable then re-enable on the same manager instance
# ══════════════════════════════════════════════════════════════════════════════

## Toggles analytics off (acquisition is suppressed) then on (acquisition fires)
## on the same AnalyticsManager+_SpyLogger instance. Verifies the gate is driven
## entirely by the live SettingsManager.analytics_enabled value, not cached state.
func test_reenable_after_disable_resumes_logging() -> bool:
	var saved: bool = SettingsManager.analytics_enabled

	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _SpyLogger = pair[1]

	# Phase 1 — disabled: no event.
	SettingsManager.analytics_enabled = false
	mgr.log_evidence_acquired("forged_document", "observe_building")
	if spy.append_count != 0:
		SettingsManager.analytics_enabled = saved
		return false

	# Phase 2 — re-enabled: event fires.
	SettingsManager.analytics_enabled = true
	mgr.log_evidence_acquired("witness_account", "eavesdrop_npc")

	SettingsManager.analytics_enabled = saved
	return spy.append_count == 1
