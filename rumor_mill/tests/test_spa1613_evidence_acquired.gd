## test_spa1613_evidence_acquired.gd — Regression tests for SPA-1613.
##
## Verifies that AnalyticsManager.log_evidence_acquired emits an `evidence_acquired`
## event with the correct NDJSON field shape for all three fire-site evidence types:
##   forged_document        / observe_building  (observe-building fire site 1)
##   incriminating_artifact / observe_building  (observe-building fire site 2)
##   witness_account        / eavesdrop_npc     (eavesdrop fire site)
##
## Strategy:
##   • _SpyLogger extends AnalyticsLogger — inherits the real log_event() guard
##     (if not SettingsManager.analytics_enabled: return) but overrides _append_line()
##     with an in-memory JSON accumulator so no file I/O occurs during tests.
##   • Tests set SettingsManager.analytics_enabled = true so the gate passes.
##   • Every test that mutates analytics_enabled restores the original value on exit.
##
## Mutation sensitivity:
##   Removing any required field from the log_event() call in
##   AnalyticsManager.log_evidence_acquired() causes the corresponding field-presence
##   test to fail. Changing the evidence_type or source_action string to the wrong
##   value causes the per-fire-site value tests to fail.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpa1613EvidenceAcquired
extends RefCounted

const AnalyticsManagerScript := preload("res://scripts/analytics_manager.gd")


## Spy: inherits the real log_event() analytics-enabled gate; replaces file I/O
## with an in-memory accumulator. last_entry holds the most recent parsed NDJSON
## object; call_count tracks total _append_line() invocations.
class _SpyLogger extends AnalyticsLogger:
	var last_entry: Dictionary = {}
	var call_count: int = 0

	func _append_line(line: String) -> void:
		call_count += 1
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			last_entry = parsed


## Returns [AnalyticsManager, _SpyLogger] with the spy pre-wired as the live logger
## and _analytics_scenario_id set to "scenario_1" for field-value assertions.
func _make_manager_with_spy() -> Array:
	var mgr: AnalyticsManager = AnalyticsManagerScript.new()
	var spy := _SpyLogger.new()
	mgr._analytics_logger = spy
	mgr._analytics_scenario_id = "scenario_1"
	return [mgr, spy]


## Convenience: enable analytics, fire one acquisition, restore state.
## Returns [AnalyticsManager, _SpyLogger].
func _acquire(evidence_type: String, source_action: String) -> Array:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var pair: Array = _make_manager_with_spy()
	(pair[0] as AnalyticsManager).log_evidence_acquired(evidence_type, source_action)
	SettingsManager.analytics_enabled = saved
	return pair


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── NDJSON event type for each fire site ──
		"test_forged_doc_event_type",
		"test_artifact_event_type",
		"test_witness_event_type",

		# ── evidence_type field value ──
		"test_forged_doc_evidence_type_field",
		"test_artifact_evidence_type_field",
		"test_witness_evidence_type_field",

		# ── source_action field value ──
		"test_forged_doc_source_action_field",
		"test_artifact_source_action_field",
		"test_witness_source_action_field",

		# ── required context fields present (day / scenario_id / difficulty) ──
		"test_has_day_field",
		"test_has_scenario_id_field",
		"test_has_difficulty_field",

		# ── no double-emission: two acquisition calls produce two separate events ──
		"test_two_calls_emit_two_events",

		# ── pre-setup queuing: args preserved for all 3 fire-site combinations ──
		"test_pre_setup_queue_forged_document_args",
		"test_pre_setup_queue_incriminating_artifact_args",
		"test_pre_setup_queue_witness_account_args",
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
# NDJSON event type
# ══════════════════════════════════════════════════════════════════════════════

func test_forged_doc_event_type() -> bool:
	var pair: Array = _acquire("forged_document", "observe_building")
	return (pair[1] as _SpyLogger).last_entry.get("type", "") == "evidence_acquired"


func test_artifact_event_type() -> bool:
	var pair: Array = _acquire("incriminating_artifact", "observe_building")
	return (pair[1] as _SpyLogger).last_entry.get("type", "") == "evidence_acquired"


func test_witness_event_type() -> bool:
	var pair: Array = _acquire("witness_account", "eavesdrop_npc")
	return (pair[1] as _SpyLogger).last_entry.get("type", "") == "evidence_acquired"


# ══════════════════════════════════════════════════════════════════════════════
# evidence_type field
# ══════════════════════════════════════════════════════════════════════════════

func test_forged_doc_evidence_type_field() -> bool:
	var pair: Array = _acquire("forged_document", "observe_building")
	return (pair[1] as _SpyLogger).last_entry.get("evidence_type", "") == "forged_document"


func test_artifact_evidence_type_field() -> bool:
	var pair: Array = _acquire("incriminating_artifact", "observe_building")
	return (pair[1] as _SpyLogger).last_entry.get("evidence_type", "") == "incriminating_artifact"


func test_witness_evidence_type_field() -> bool:
	var pair: Array = _acquire("witness_account", "eavesdrop_npc")
	return (pair[1] as _SpyLogger).last_entry.get("evidence_type", "") == "witness_account"


# ══════════════════════════════════════════════════════════════════════════════
# source_action field
# ══════════════════════════════════════════════════════════════════════════════

func test_forged_doc_source_action_field() -> bool:
	var pair: Array = _acquire("forged_document", "observe_building")
	return (pair[1] as _SpyLogger).last_entry.get("source_action", "") == "observe_building"


func test_artifact_source_action_field() -> bool:
	var pair: Array = _acquire("incriminating_artifact", "observe_building")
	return (pair[1] as _SpyLogger).last_entry.get("source_action", "") == "observe_building"


func test_witness_source_action_field() -> bool:
	var pair: Array = _acquire("witness_account", "eavesdrop_npc")
	return (pair[1] as _SpyLogger).last_entry.get("source_action", "") == "eavesdrop_npc"


# ══════════════════════════════════════════════════════════════════════════════
# Required context fields — day / scenario_id / difficulty
# ══════════════════════════════════════════════════════════════════════════════

func test_has_day_field() -> bool:
	var pair: Array = _acquire("forged_document", "observe_building")
	return (pair[1] as _SpyLogger).last_entry.has("day")


func test_has_scenario_id_field() -> bool:
	var pair: Array = _acquire("forged_document", "observe_building")
	return (pair[1] as _SpyLogger).last_entry.has("scenario_id")


func test_has_difficulty_field() -> bool:
	var pair: Array = _acquire("forged_document", "observe_building")
	return (pair[1] as _SpyLogger).last_entry.has("difficulty")


# ══════════════════════════════════════════════════════════════════════════════
# No double-emission — two distinct acquisition calls emit two separate events
# ══════════════════════════════════════════════════════════════════════════════

## Guards against a hypothetical dedup that could suppress a second acquisition of
## the same evidence type in the same session. Each call must emit independently.
func test_two_calls_emit_two_events() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true

	var pair: Array = _make_manager_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _SpyLogger = pair[1]

	mgr.log_evidence_acquired("forged_document", "observe_building")
	mgr.log_evidence_acquired("forged_document", "observe_building")

	SettingsManager.analytics_enabled = saved
	return spy.call_count == 2


# ══════════════════════════════════════════════════════════════════════════════
# Pre-setup queuing — all 3 fire-site arg combinations are preserved in queue
# ══════════════════════════════════════════════════════════════════════════════

## With _analytics_logger null (pre-setup), log_evidence_acquired() must enqueue
## [evidence_type, source_action] so the event can be replayed on flush.

func test_pre_setup_queue_forged_document_args() -> bool:
	var mgr: AnalyticsManager = AnalyticsManagerScript.new()
	# _analytics_logger is null by default → enqueue path.
	mgr.log_evidence_acquired("forged_document", "observe_building")
	return mgr._event_queue.size() == 1 \
		and mgr._event_queue[0]["args"][0] == "forged_document" \
		and mgr._event_queue[0]["args"][1] == "observe_building"


func test_pre_setup_queue_incriminating_artifact_args() -> bool:
	var mgr: AnalyticsManager = AnalyticsManagerScript.new()
	mgr.log_evidence_acquired("incriminating_artifact", "observe_building")
	return mgr._event_queue.size() == 1 \
		and mgr._event_queue[0]["args"][0] == "incriminating_artifact" \
		and mgr._event_queue[0]["args"][1] == "observe_building"


func test_pre_setup_queue_witness_account_args() -> bool:
	var mgr: AnalyticsManager = AnalyticsManagerScript.new()
	mgr.log_evidence_acquired("witness_account", "eavesdrop_npc")
	return mgr._event_queue.size() == 1 \
		and mgr._event_queue[0]["args"][0] == "witness_account" \
		and mgr._event_queue[0]["args"][1] == "eavesdrop_npc"
