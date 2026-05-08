## test_spa1614_evidence_used_emission.gd — Regression tests for SPA-1614.
##
## Asserts that log_evidence_used() emits exactly one NDJSON "evidence_used"
## event with all SPA-1522-required fields when analytics is enabled, and
## no event when analytics is disabled.
##
## SPA-1522 required fields: evidence_type, claim_id, seed_target, subject,
##                            day, scenario_id, difficulty.
##
## Acceptance criterion: "no event fires when a rumor is seeded without evidence"
## is enforced at the call site in rumor_panel.gd — log_evidence_used() is
## called only inside the `if _selected_evidence_item != null` guard (line ~536).
## analytics_manager itself does not re-check for null evidence; the guard is
## the contract and the call-site structure is the defence.
##
## Strategy:
##   • _ShapeSpyLogger extends AnalyticsLogger — inherits the real log_event()
##     analytics-enabled guard and overrides _append_line() to capture the last
##     NDJSON JSON string without file I/O.
##   • Tests wire the spy directly into _analytics_logger so no queue path runs.
##   • Every test that mutates SettingsManager.analytics_enabled restores it.
##
## Mutation sensitivity:
##   • Removing any required field from the log_event() call in
##     analytics_manager.gd causes the corresponding field-presence test to fail.
##   • Removing the `if not SettingsManager.analytics_enabled: return` guard in
##     AnalyticsLogger.log_event() causes test_disabled_used_writes_zero_events
##     to fail (call_count becomes 1 instead of 0).
##   • Changing the event type string from "evidence_used" causes
##     test_event_type_is_evidence_used to fail.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpa1614EvidenceUsedEmission
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


## Returns [AnalyticsManager, _ShapeSpyLogger] with the spy pre-wired as the
## live logger. _analytics_logger != null so log_evidence_used() skips the
## queue path and calls log_event() directly.
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
		"test_enabled_used_writes_one_event",
		"test_disabled_used_writes_zero_events",

		# ── event type ──
		"test_event_type_is_evidence_used",

		# ── SPA-1522 field presence ──
		"test_payload_contains_evidence_type",
		"test_payload_contains_claim_id",
		"test_payload_contains_seed_target",
		"test_payload_contains_subject",
		"test_payload_contains_day",
		"test_payload_contains_scenario_id",
		"test_payload_contains_difficulty",

		# ── SPA-1522 field values ──
		"test_payload_evidence_type_value",
		"test_payload_claim_id_value",
		"test_payload_seed_target_value",
		"test_payload_subject_value",
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

## Core emission assertion: with analytics enabled, calling log_evidence_used()
## with a live logger must reach _append_line() exactly once.
func test_enabled_used_writes_one_event() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true

	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]

	mgr.log_evidence_used("forged_document", "SCANDAL", "npc_aldric_merchant", "npc_calder_noble")

	SettingsManager.analytics_enabled = saved
	return spy.call_count == 1


## Negative gate: with analytics disabled, log_evidence_used() must not reach
## _append_line(). The gate is AnalyticsLogger.log_event()'s opening guard:
##   if not SettingsManager.analytics_enabled: return
func test_disabled_used_writes_zero_events() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = false

	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]

	mgr.log_evidence_used("forged_document", "SCANDAL", "npc_aldric_merchant", "npc_calder_noble")

	SettingsManager.analytics_enabled = saved
	return spy.call_count == 0


# ══════════════════════════════════════════════════════════════════════════════
# Event type
# ══════════════════════════════════════════════════════════════════════════════

func test_event_type_is_evidence_used() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true

	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]

	mgr.log_evidence_used("witness_account", "HERESY", "npc_maren_nun", "npc_calder_noble")

	SettingsManager.analytics_enabled = saved
	return spy.last_event.get("type", "") == "evidence_used"


# ══════════════════════════════════════════════════════════════════════════════
# SPA-1522 field presence — all seven required fields must appear in the event
# ══════════════════════════════════════════════════════════════════════════════

func test_payload_contains_evidence_type() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_evidence_used("forged_document", "SCANDAL", "npc_aldric_merchant", "npc_calder_noble")
	SettingsManager.analytics_enabled = saved
	return "evidence_type" in spy.last_event


func test_payload_contains_claim_id() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_evidence_used("forged_document", "SCANDAL", "npc_aldric_merchant", "npc_calder_noble")
	SettingsManager.analytics_enabled = saved
	return "claim_id" in spy.last_event


func test_payload_contains_seed_target() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_evidence_used("forged_document", "SCANDAL", "npc_aldric_merchant", "npc_calder_noble")
	SettingsManager.analytics_enabled = saved
	return "seed_target" in spy.last_event


func test_payload_contains_subject() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_evidence_used("forged_document", "SCANDAL", "npc_aldric_merchant", "npc_calder_noble")
	SettingsManager.analytics_enabled = saved
	return "subject" in spy.last_event


func test_payload_contains_day() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_evidence_used("forged_document", "SCANDAL", "npc_aldric_merchant", "npc_calder_noble")
	SettingsManager.analytics_enabled = saved
	return "day" in spy.last_event


func test_payload_contains_scenario_id() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_evidence_used("forged_document", "SCANDAL", "npc_aldric_merchant", "npc_calder_noble")
	SettingsManager.analytics_enabled = saved
	return "scenario_id" in spy.last_event


func test_payload_contains_difficulty() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_evidence_used("forged_document", "SCANDAL", "npc_aldric_merchant", "npc_calder_noble")
	SettingsManager.analytics_enabled = saved
	return "difficulty" in spy.last_event


# ══════════════════════════════════════════════════════════════════════════════
# SPA-1522 field values — caller-supplied arguments must appear verbatim
# ══════════════════════════════════════════════════════════════════════════════

func test_payload_evidence_type_value() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_evidence_used("incriminating_artifact", "TREASON", "npc_aldric_merchant", "npc_calder_noble")
	SettingsManager.analytics_enabled = saved
	return spy.last_event.get("evidence_type", "") == "incriminating_artifact"


func test_payload_claim_id_value() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_evidence_used("forged_document", "HERESY", "npc_maren_nun", "npc_calder_noble")
	SettingsManager.analytics_enabled = saved
	return spy.last_event.get("claim_id", "") == "HERESY"


func test_payload_seed_target_value() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_evidence_used("witness_account", "ACCUSATION", "npc_maren_nun", "npc_calder_noble")
	SettingsManager.analytics_enabled = saved
	return spy.last_event.get("seed_target", "") == "npc_maren_nun"


func test_payload_subject_value() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _ShapeSpyLogger = pair[1]
	mgr.log_evidence_used("forged_document", "SCANDAL", "npc_aldric_merchant", "npc_calder_noble")
	SettingsManager.analytics_enabled = saved
	return spy.last_event.get("subject", "") == "npc_calder_noble"
