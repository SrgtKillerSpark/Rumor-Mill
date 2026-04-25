## test_end_screen_summary.gd — Unit tests for end_screen_summary.gd (SPA-1026).
##
## Covers:
##   • WHAT_WENT_WRONG: 7 known entries, unknown-key fallback
##   • SUMMARY_TEXT: 6 scenario keys present, win + fail keys per scenario
##   • SUMMARY_FALLBACK: timeout, exposed, contradicted keys present
##   • Initial instance state: _world_ref, _day_night_ref
##   • setup(): stores world and day_night refs
##   • infer_fail_reason(): null world_ref → always "timeout"
##   • get_what_went_wrong(): known key returns text; unknown key returns fallback
##   • get_summary_text(): table hits and final fallback with null world_ref
##
## EndScreenSummary extends RefCounted — safe to instantiate without scene tree.
## infer_fail_reason() branches that inspect scenario_manager require a live world
## and are not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestEndScreenSummary
extends RefCounted

const EndScreenSummaryScript := preload("res://scripts/end_screen_summary.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_ess() -> RefCounted:
	return EndScreenSummaryScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# WHAT_WENT_WRONG table
		"test_what_went_wrong_has_seven_entries",
		"test_what_went_wrong_exposed_key",
		"test_what_went_wrong_timeout_key",
		"test_what_went_wrong_contradicted_key",
		"test_what_went_wrong_calder_implicated_key",
		"test_what_went_wrong_aldric_destroyed_key",
		"test_what_went_wrong_marta_silenced_key",
		"test_what_went_wrong_reputation_collapsed_key",
		# SUMMARY_TEXT table structure
		"test_summary_text_has_six_scenario_keys",
		"test_summary_text_scenario_1_has_win",
		"test_summary_text_scenario_1_has_timeout",
		"test_summary_text_scenario_2_has_contradicted",
		"test_summary_text_scenario_3_has_calder_implicated",
		"test_summary_text_scenario_4_has_reputation_collapsed",
		"test_summary_text_scenario_5_has_aldric_destroyed",
		"test_summary_text_scenario_6_has_marta_silenced",
		"test_summary_text_scenario_6_has_exposed",
		# SUMMARY_FALLBACK keys
		"test_summary_fallback_has_timeout",
		"test_summary_fallback_has_exposed",
		"test_summary_fallback_has_contradicted",
		# Initial state
		"test_initial_world_ref_null",
		"test_initial_day_night_ref_null",
		# setup()
		"test_setup_stores_world_ref",
		"test_setup_stores_day_night_ref",
		# infer_fail_reason() — null world path
		"test_infer_fail_reason_null_world_returns_timeout",
		# get_what_went_wrong()
		"test_get_what_went_wrong_known_key_not_empty",
		"test_get_what_went_wrong_unknown_key_fallback",
		# get_summary_text()
		"test_get_summary_text_scenario_1_win",
		"test_get_summary_text_scenario_1_timeout",
		"test_get_summary_text_unknown_scenario_won_fallback",
		"test_get_summary_text_unknown_scenario_timeout_uses_fallback_text",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nEndScreenSummary tests: %d passed, %d failed" % [passed, failed])


# ── WHAT_WENT_WRONG table ─────────────────────────────────────────────────────

static func test_what_went_wrong_has_seven_entries() -> bool:
	var count := _make_ess().WHAT_WENT_WRONG.size()
	if count != 7:
		push_error("test_what_went_wrong_has_seven_entries: expected 7, got %d" % count)
		return false
	return true


static func test_what_went_wrong_exposed_key() -> bool:
	return _make_ess().WHAT_WENT_WRONG.has("exposed")


static func test_what_went_wrong_timeout_key() -> bool:
	return _make_ess().WHAT_WENT_WRONG.has("timeout")


static func test_what_went_wrong_contradicted_key() -> bool:
	return _make_ess().WHAT_WENT_WRONG.has("contradicted")


static func test_what_went_wrong_calder_implicated_key() -> bool:
	return _make_ess().WHAT_WENT_WRONG.has("calder_implicated")


static func test_what_went_wrong_aldric_destroyed_key() -> bool:
	return _make_ess().WHAT_WENT_WRONG.has("aldric_destroyed")


static func test_what_went_wrong_marta_silenced_key() -> bool:
	return _make_ess().WHAT_WENT_WRONG.has("marta_silenced")


static func test_what_went_wrong_reputation_collapsed_key() -> bool:
	return _make_ess().WHAT_WENT_WRONG.has("reputation_collapsed")


# ── SUMMARY_TEXT table structure ──────────────────────────────────────────────

static func test_summary_text_has_six_scenario_keys() -> bool:
	var count := _make_ess().SUMMARY_TEXT.size()
	if count != 6:
		push_error("test_summary_text_has_six_scenario_keys: expected 6, got %d" % count)
		return false
	return true


static func test_summary_text_scenario_1_has_win() -> bool:
	return _make_ess().SUMMARY_TEXT[1].has("win")


static func test_summary_text_scenario_1_has_timeout() -> bool:
	return _make_ess().SUMMARY_TEXT[1].has("timeout")


static func test_summary_text_scenario_2_has_contradicted() -> bool:
	return _make_ess().SUMMARY_TEXT[2].has("contradicted")


static func test_summary_text_scenario_3_has_calder_implicated() -> bool:
	return _make_ess().SUMMARY_TEXT[3].has("calder_implicated")


static func test_summary_text_scenario_4_has_reputation_collapsed() -> bool:
	return _make_ess().SUMMARY_TEXT[4].has("reputation_collapsed")


static func test_summary_text_scenario_5_has_aldric_destroyed() -> bool:
	return _make_ess().SUMMARY_TEXT[5].has("aldric_destroyed")


static func test_summary_text_scenario_6_has_marta_silenced() -> bool:
	return _make_ess().SUMMARY_TEXT[6].has("marta_silenced")


static func test_summary_text_scenario_6_has_exposed() -> bool:
	return _make_ess().SUMMARY_TEXT[6].has("exposed")


# ── SUMMARY_FALLBACK keys ─────────────────────────────────────────────────────

static func test_summary_fallback_has_timeout() -> bool:
	return _make_ess().SUMMARY_FALLBACK.has("timeout")


static func test_summary_fallback_has_exposed() -> bool:
	return _make_ess().SUMMARY_FALLBACK.has("exposed")


static func test_summary_fallback_has_contradicted() -> bool:
	return _make_ess().SUMMARY_FALLBACK.has("contradicted")


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_world_ref_null() -> bool:
	return _make_ess()._world_ref == null


static func test_initial_day_night_ref_null() -> bool:
	return _make_ess()._day_night_ref == null


# ── setup() ───────────────────────────────────────────────────────────────────

static func test_setup_stores_world_ref() -> bool:
	var ess := _make_ess()
	var stub := Node2D.new()
	ess.setup(stub, null)
	var ok := ess._world_ref == stub
	stub.free()
	return ok


static func test_setup_stores_day_night_ref() -> bool:
	var ess := _make_ess()
	var stub := Node.new()
	ess.setup(null, stub)
	var ok := ess._day_night_ref == stub
	stub.free()
	return ok


# ── infer_fail_reason() — null world path ────────────────────────────────────

## When _world_ref is null the method immediately returns "timeout".
static func test_infer_fail_reason_null_world_returns_timeout() -> bool:
	var ess := _make_ess()
	return ess.infer_fail_reason(1) == "timeout"


# ── get_what_went_wrong() ─────────────────────────────────────────────────────

static func test_get_what_went_wrong_known_key_not_empty() -> bool:
	var ess := _make_ess()
	return not ess.get_what_went_wrong("exposed").is_empty()


## Unknown key must return the fallback "Your scheme unravelled."
static func test_get_what_went_wrong_unknown_key_fallback() -> bool:
	var ess := _make_ess()
	return ess.get_what_went_wrong("totally_unknown_reason") == "Your scheme unravelled."


# ── get_summary_text() ────────────────────────────────────────────────────────

## Scenario 1 win: table hit — must return a non-empty string.
static func test_get_summary_text_scenario_1_win() -> bool:
	var ess := _make_ess()
	return not ess.get_summary_text(1, true, "").is_empty()


## Scenario 1 timeout: table hit — must return a non-empty string.
static func test_get_summary_text_scenario_1_timeout() -> bool:
	var ess := _make_ess()
	return not ess.get_summary_text(1, false, "timeout").is_empty()


## Unknown scenario + won=true: no table entry, SUMMARY_FALLBACK has no "win" key
## → final fallback "Your scheme ran its course."
static func test_get_summary_text_unknown_scenario_won_fallback() -> bool:
	var ess := _make_ess()
	return ess.get_summary_text(999, true, "") == "Your scheme ran its course."


## Unknown scenario + timeout: no table entry, SUMMARY_FALLBACK["timeout"] exists.
static func test_get_summary_text_unknown_scenario_timeout_uses_fallback_text() -> bool:
	var ess := _make_ess()
	var result := ess.get_summary_text(999, false, "timeout")
	return not result.is_empty() and result != "Your scheme unravelled."
