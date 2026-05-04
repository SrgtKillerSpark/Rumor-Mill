## smoke_phase2_evidence.gd — Phase 2 telemetry-capture smoke harness (SPA-1617)
##
## QA smoke test: boots a known scenario seed (S2 Sister Maren on Apprentice) and drives
## one of each evidence acquisition type plus one evidence usage, then asserts each
## resulting NDJSON event has the required SPA-1522 fields.
##
## Coverage:
##   evidence_acquired — forged_document / observe_building        (fire site 1)
##   evidence_acquired — incriminating_artifact / observe_building  (fire site 2)
##   evidence_acquired — witness_account / eavesdrop_npc            (fire site 3)
##   evidence_used     — forged_document / SCANDAL                  (rumor seed with evidence)
##
## Fails loudly (push_error) if any event is missing or if any required field drifts
## from the SPA-1522 spec. Intended to run after SPA-1613 + SPA-1614 land.
##
## Run headless:
##   godot --headless --path rumor_mill --script tests/smoke_phase2_evidence.gd
##
## NDJSON sample captured to: tools/analytics/fixtures/smoke_capture_phase2.ndjson

class_name SmokePhase2Evidence
extends RefCounted

const AnalyticsManagerScript := preload("res://scripts/analytics_manager.gd")

## SPA-1522 required fields per event type.
const ACQUIRED_REQUIRED_FIELDS: Array[String] = [
	"evidence_type", "source_action", "day", "scenario_id", "difficulty"
]
const USED_REQUIRED_FIELDS: Array[String] = [
	"evidence_type", "claim_id", "seed_target", "subject", "day", "scenario_id", "difficulty"
]

## Scenario seed fixture: S2 Sister Maren on Apprentice (stable fixture, SPA-1617).
const SCENARIO_ID := "scenario_2"
const DIFFICULTY  := "apprentice"


## Multi-line capturing spy — accumulates every NDJSON line emitted without file I/O.
class _CaptureLogger extends AnalyticsLogger:
	var lines: Array[Dictionary] = []
	var raw_lines: Array[String] = []

	func _append_line(line: String) -> void:
		raw_lines.append(line)
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			lines.append(parsed)


## Returns [AnalyticsManager, _CaptureLogger] seeded with SCENARIO_ID/DIFFICULTY.
func _make_manager() -> Array:
	var mgr: AnalyticsManager = AnalyticsManagerScript.new()
	var cap := _CaptureLogger.new()
	mgr._analytics_logger = cap
	mgr._analytics_scenario_id = SCENARIO_ID
	return [mgr, cap]


var _passed: int = 0
var _failed: int = 0


func run() -> void:
	_passed = 0
	_failed = 0

	print("\n── Phase 2 evidence telemetry smoke (SPA-1617) ──")
	print("   seed: %s / %s (S2 Sister Maren on Apprentice)" % [SCENARIO_ID, DIFFICULTY])

	# ── Setup ──────────────────────────────────────────────────────────────────
	var saved_analytics: bool   = SettingsManager.analytics_enabled
	var saved_difficulty: String = GameState.selected_difficulty
	SettingsManager.analytics_enabled = true
	GameState.selected_difficulty = DIFFICULTY

	var pair: Array = _make_manager()
	var mgr: AnalyticsManager = pair[0]
	var cap: _CaptureLogger   = pair[1]

	# ── Drive evidence events ──────────────────────────────────────────────────
	# 1 — forged_document via observe_building (fire site 1 in recon_controller.gd)
	mgr.log_evidence_acquired("forged_document", "observe_building")
	# 2 — incriminating_artifact via observe_building (fire site 2 in recon_controller.gd)
	mgr.log_evidence_acquired("incriminating_artifact", "observe_building")
	# 3 — witness_account via eavesdrop_npc (fire site 3 in recon_controller.gd)
	mgr.log_evidence_acquired("witness_account", "eavesdrop_npc")
	# 4 — forged_document attached to SCANDAL rumor (rumor_panel.gd fire site)
	mgr.log_evidence_used("forged_document", "SCANDAL", "npc_maren_nun", "npc_calder_noble")

	# ── Restore state ──────────────────────────────────────────────────────────
	SettingsManager.analytics_enabled = saved_analytics
	GameState.selected_difficulty = saved_difficulty

	# ── Assert event count ─────────────────────────────────────────────────────
	_chk(cap.lines.size() == 4,
		"total event count == 4  (got %d)" % cap.lines.size())

	# ── Assert evidence_acquired events (indices 0–2) ──────────────────────────
	var acquired_cases: Array = [
		{"idx": 0, "evidence_type": "forged_document",        "source_action": "observe_building"},
		{"idx": 1, "evidence_type": "incriminating_artifact", "source_action": "observe_building"},
		{"idx": 2, "evidence_type": "witness_account",        "source_action": "eavesdrop_npc"},
	]
	for c in acquired_cases:
		var idx: int = c["idx"]
		if idx >= cap.lines.size():
			_chk(false, "event at index %d exists" % idx)
			continue
		var ev: Dictionary = cap.lines[idx]
		var lbl: String = "acquired[%d] %s/%s" % [idx, c["evidence_type"], c["source_action"]]

		_chk(ev.get("type", "") == "evidence_acquired",  "%s — type == evidence_acquired" % lbl)
		for field: String in ACQUIRED_REQUIRED_FIELDS:
			_chk(ev.has(field), "%s — field '%s' present" % [lbl, field])
		_chk(ev.get("evidence_type", "") == c["evidence_type"],
			"%s — evidence_type == %s"  % [lbl, c["evidence_type"]])
		_chk(ev.get("source_action",  "") == c["source_action"],
			"%s — source_action == %s"  % [lbl, c["source_action"]])
		_chk(ev.get("scenario_id",    "") == SCENARIO_ID,
			"%s — scenario_id == %s"    % [lbl, SCENARIO_ID])
		_chk(ev.get("difficulty",     "") == DIFFICULTY,
			"%s — difficulty == %s"     % [lbl, DIFFICULTY])

	# ── Assert evidence_used event (index 3) ───────────────────────────────────
	if cap.lines.size() >= 4:
		var ev: Dictionary = cap.lines[3]
		var lbl := "used[3] forged_document/SCANDAL"

		_chk(ev.get("type", "") == "evidence_used", "%s — type == evidence_used" % lbl)
		for field: String in USED_REQUIRED_FIELDS:
			_chk(ev.has(field), "%s — field '%s' present" % [lbl, field])
		_chk(ev.get("evidence_type", "") == "forged_document",  "%s — evidence_type" % lbl)
		_chk(ev.get("claim_id",      "") == "SCANDAL",          "%s — claim_id"      % lbl)
		_chk(ev.get("seed_target",   "") == "npc_maren_nun",    "%s — seed_target"   % lbl)
		_chk(ev.get("subject",       "") == "npc_calder_noble", "%s — subject"       % lbl)
		_chk(ev.get("scenario_id",   "") == SCENARIO_ID,        "%s — scenario_id"   % lbl)
		_chk(ev.get("difficulty",    "") == DIFFICULTY,         "%s — difficulty"    % lbl)

	# ── Summary ────────────────────────────────────────────────────────────────
	print("\n  %d passed, %d failed" % [_passed, _failed])
	if _failed > 0:
		push_error(
			"SMOKE FAILED — Phase 2 evidence telemetry shape drift (%d failure(s))" % _failed
		)

	# ── Emit captured NDJSON sample to stdout (for fixture reference) ──────────
	print("\n── Captured NDJSON sample (%d lines) ──" % cap.raw_lines.size())
	for raw: String in cap.raw_lines:
		print(raw)


func _chk(condition: bool, name: String) -> void:
	if condition:
		print("  PASS  %s" % name)
		_passed += 1
	else:
		push_error("  FAIL  %s" % name)
		_failed += 1
