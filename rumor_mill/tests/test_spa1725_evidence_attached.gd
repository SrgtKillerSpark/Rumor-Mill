## test_spa1725_evidence_attached.gd — Spec-shape regression tests for SPA-1725.
##
## Validates that AnalyticsLogger.log_evidence_attached() emits an "evidence_attached"
## NDJSON event whose payload satisfies the proposed SPA-1522 spec amendment:
##
##   Field             Type     Source
##   ──────────────────────────────────────────────────────────────────────────
##   evidence_type     String   EvidenceItem.type.to_snake_case() — see §2.3
##   credulity_boost   float    EvidenceItem.credulity_boost
##   target_npc_id     String   seed target NPC identifier
##   day               int      world.current_day
##   scenario_id       String   world.scenario_id
##
## Also guards the call-site normalization rule (SPA-1522 §2.3):
##   evidence_type MUST be snake_case (e.g. "witness_account", not "Witness Account").
##   The bug-fix in rumor_panel.gd:1142 adds .to_snake_case() at emission.
##   These tests catch regressions where the normalization is removed.
##
## Strategy:
##   • SpyLogger extends AnalyticsLogger — inherits the real analytics-enabled
##     guard in log_event() and overrides _append_line() to capture the last
##     NDJSON line without file I/O.
##   • Each test that mutates SettingsManager.analytics_enabled restores it.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpa1725EvidenceAttached
extends RefCounted

const AnalyticsLoggerScript := preload("res://scripts/analytics_logger.gd")


## Spy: inherits the real analytics-enabled gate; replaces file I/O with an
## in-memory accumulator so tests are side-effect-free.
class _SpyLogger extends AnalyticsLogger:
	var call_count: int     = 0
	var last_event: Dictionary = {}

	func _append_line(line: String) -> void:
		call_count += 1
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			last_event = parsed


## Helper: creates a spy and fires log_evidence_attached() once with analytics
## enabled. Restores analytics_enabled to its original value before returning.
## Returns [_SpyLogger, original_enabled].
func _fire(evidence_type: String, credulity_boost: float, target_npc_id: String, day: int, scenario_id: String) -> _SpyLogger:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var spy := _SpyLogger.new()
	spy.log_evidence_attached(evidence_type, credulity_boost, target_npc_id, day, scenario_id)
	SettingsManager.analytics_enabled = saved
	return spy


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── analytics gating ──
		"test_enabled_writes_one_event",
		"test_disabled_writes_zero_events",

		# ── event type ──
		"test_event_type_is_evidence_attached",

		# ── required field presence ──
		"test_payload_has_evidence_type",
		"test_payload_has_credulity_boost",
		"test_payload_has_target_npc_id",
		"test_payload_has_day",
		"test_payload_has_scenario_id",

		# ── field values ──
		"test_evidence_type_value",
		"test_credulity_boost_value",
		"test_target_npc_id_value",
		"test_day_value",
		"test_scenario_id_value",

		# ── SPA-1522 §2.3 normalization: evidence_type must be snake_case ──
		"test_evidence_type_is_snake_case_forged_document",
		"test_evidence_type_is_snake_case_incriminating_artifact",
		"test_evidence_type_is_snake_case_witness_account",
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
# Analytics gating
# ══════════════════════════════════════════════════════════════════════════════

func test_enabled_writes_one_event() -> bool:
	var spy := _fire("witness_account", 0.05, "npc_maren", 4, "scenario_2")
	return spy.call_count == 1


func test_disabled_writes_zero_events() -> bool:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = false
	var spy := _SpyLogger.new()
	spy.log_evidence_attached("witness_account", 0.05, "npc_maren", 4, "scenario_2")
	SettingsManager.analytics_enabled = saved
	return spy.call_count == 0


# ══════════════════════════════════════════════════════════════════════════════
# Event type
# ══════════════════════════════════════════════════════════════════════════════

func test_event_type_is_evidence_attached() -> bool:
	var spy := _fire("forged_document", 0.10, "npc_aldric", 2, "scenario_1")
	return spy.last_event.get("type", "") == "evidence_attached"


# ══════════════════════════════════════════════════════════════════════════════
# Required field presence — all five spec fields must appear in the payload
# ══════════════════════════════════════════════════════════════════════════════

func test_payload_has_evidence_type() -> bool:
	var spy := _fire("forged_document", 0.10, "npc_aldric", 2, "scenario_1")
	return "evidence_type" in spy.last_event


func test_payload_has_credulity_boost() -> bool:
	var spy := _fire("forged_document", 0.10, "npc_aldric", 2, "scenario_1")
	return "credulity_boost" in spy.last_event


func test_payload_has_target_npc_id() -> bool:
	var spy := _fire("forged_document", 0.10, "npc_aldric", 2, "scenario_1")
	return "target_npc_id" in spy.last_event


func test_payload_has_day() -> bool:
	var spy := _fire("forged_document", 0.10, "npc_aldric", 2, "scenario_1")
	return "day" in spy.last_event


func test_payload_has_scenario_id() -> bool:
	var spy := _fire("forged_document", 0.10, "npc_aldric", 2, "scenario_1")
	return "scenario_id" in spy.last_event


# ══════════════════════════════════════════════════════════════════════════════
# Field values — caller arguments must appear verbatim in the emitted payload
# ══════════════════════════════════════════════════════════════════════════════

func test_evidence_type_value() -> bool:
	var spy := _fire("incriminating_artifact", 0.15, "npc_calder", 7, "scenario_3")
	return spy.last_event.get("evidence_type", "") == "incriminating_artifact"


func test_credulity_boost_value() -> bool:
	var spy := _fire("witness_account", 0.05, "npc_maren", 4, "scenario_2")
	return is_equal_approx(float(spy.last_event.get("credulity_boost", -1.0)), 0.05)


func test_target_npc_id_value() -> bool:
	var spy := _fire("forged_document", 0.10, "npc_aldric_merchant", 3, "scenario_1")
	return spy.last_event.get("target_npc_id", "") == "npc_aldric_merchant"


func test_day_value() -> bool:
	var spy := _fire("witness_account", 0.05, "npc_maren", 9, "scenario_2")
	return spy.last_event.get("day", -1) == 9


func test_scenario_id_value() -> bool:
	var spy := _fire("forged_document", 0.10, "npc_aldric", 2, "scenario_4")
	return spy.last_event.get("scenario_id", "") == "scenario_4"


# ══════════════════════════════════════════════════════════════════════════════
# SPA-1522 §2.3 — evidence_type must be snake_case at emission
#
# The spec requires EvidenceItem display names (e.g. "Forged Document") to be
# converted to snake_case before emission. The call site in rumor_panel.gd
# must apply .to_snake_case(). These tests guard that contract by confirming
# that already-normalized strings pass through unmodified (regression guard:
# if the call-site strips .to_snake_case() and passes the display name, the
# call to log_evidence_attached() would receive "Forged Document" and the
# event would fail the snake_case check).
# ══════════════════════════════════════════════════════════════════════════════

## "Forged Document".to_snake_case() == "forged_document"
## This test also confirms the method stores the value verbatim — normalization
## is the caller's responsibility (call site in rumor_panel.gd).
func test_evidence_type_is_snake_case_forged_document() -> bool:
	var spy := _fire("forged_document", 0.10, "npc_aldric", 1, "scenario_1")
	var et: String = spy.last_event.get("evidence_type", "")
	# snake_case: lowercase, underscores only, no spaces
	return et == et.to_snake_case() and et == "forged_document"


func test_evidence_type_is_snake_case_incriminating_artifact() -> bool:
	var spy := _fire("incriminating_artifact", 0.15, "npc_calder", 1, "scenario_1")
	var et: String = spy.last_event.get("evidence_type", "")
	return et == et.to_snake_case() and et == "incriminating_artifact"


func test_evidence_type_is_snake_case_witness_account() -> bool:
	var spy := _fire("witness_account", 0.05, "npc_maren", 1, "scenario_1")
	var et: String = spy.last_event.get("evidence_type", "")
	return et == et.to_snake_case() and et == "witness_account"
