## test_daily_planning_overlay.gd — Unit tests for DailyPlanningOverlay (SPA-982).
##
## Covers:
##   • PRIORITIES constant — 6 entries, all have required keys (id/label/eval_key/bonus_desc)
##   • MAX_SELECTIONS      — equals 3
##   • increment_counter() — basic accumulation and multi-key independence
##   • get_current_priorities() — empty by default; returns a copy (mutation isolation)
##   • get_save_data()     — returns dict with "selected_priorities" and "day_counters"
##   • apply_load_data()   — restores _current_day_priorities and _day_counters from dict;
##                           safe on empty dict and on dict with type-coerced priority ids
##   • _get_priority_def() — returns correct dict for known id; returns empty for unknown
##   • on_game_tick()      — is a pure no-op (passes through without state change)
##   • _on_dawn(day=1)     — skips _show_overlay() for day <= 1; clears state correctly
##   • _evaluate_priorities() — safe when _world is null (early-return guard in _apply_bonus)
##   • _is_showing default — false before any overlay is triggered
##
## DailyPlanningOverlay extends CanvasLayer and depends on the scene tree for its
## UI nodes and tween animations.  _ready() must NOT be called in these tests.
## Only the pure-logic methods that guard against null _world / _objective_hud
## are exercised here — those are the safe paths without a running scene tree.
##
## Run from the Godot editor:  Scene → Run Script (or call run() directly).

class_name TestDailyPlanningOverlay
extends RefCounted

const DailyPlanningScript := preload("res://scripts/daily_planning_overlay.gd")


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Static definitions
		"test_priorities_count",
		"test_priorities_have_required_keys",
		"test_max_selections_value",
		# Counter tracking
		"test_increment_counter_basic",
		"test_increment_counter_accumulates",
		"test_increment_counter_default_amount",
		"test_increment_counter_multiple_keys_independent",
		# Priority query
		"test_get_current_priorities_empty_initially",
		"test_get_current_priorities_returns_copy",
		# Serialization
		"test_get_save_data_has_required_keys",
		"test_get_save_data_reflects_state",
		"test_apply_load_data_restores_priorities",
		"test_apply_load_data_restores_counters",
		"test_apply_load_data_empty_dict_safe",
		"test_apply_load_data_type_coerces_priority_ids",
		# Priority definition lookup
		"test_get_priority_def_known_id",
		"test_get_priority_def_unknown_id_returns_empty",
		# No-op paths
		"test_on_game_tick_noop",
		"test_is_showing_default_false",
		# Dawn handling
		"test_on_dawn_day1_skips_show_overlay",
		"test_on_dawn_clears_counters_and_priorities",
		# Evaluation safe paths
		"test_evaluate_priorities_safe_with_null_world",
		"test_evaluate_priorities_any_action_key",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nDailyPlanningOverlay tests: %d passed, %d failed" % [passed, failed])


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns a fresh DailyPlanningOverlay that has NOT been added to the scene tree.
## _ready() is skipped — all UI node refs are null; pure-logic methods are safe.
static func _make_overlay() -> CanvasLayer:
	return DailyPlanningScript.new()


# ── Static definitions ────────────────────────────────────────────────────────

## PRIORITIES must contain exactly 6 entries.
static func test_priorities_count() -> bool:
	var count: int = DailyPlanningScript.PRIORITIES.size()
	if count != 6:
		push_error("test_priorities_count: expected 6, got %d" % count)
		return false
	return true


## Every entry in PRIORITIES must have the four required keys.
static func test_priorities_have_required_keys() -> bool:
	var required_keys := ["id", "label", "eval_key", "bonus_desc"]
	for i in range(DailyPlanningScript.PRIORITIES.size()):
		var entry: Dictionary = DailyPlanningScript.PRIORITIES[i]
		for key in required_keys:
			if not entry.has(key):
				push_error("test_priorities_have_required_keys: PRIORITIES[%d] missing key '%s'" % [i, key])
				return false
			if str(entry[key]).is_empty():
				push_error("test_priorities_have_required_keys: PRIORITIES[%d]['%s'] is empty" % [i, key])
				return false
	return true


## MAX_SELECTIONS must equal 3 — the design allows up to three daily priorities.
static func test_max_selections_value() -> bool:
	if DailyPlanningScript.MAX_SELECTIONS != 3:
		push_error("test_max_selections_value: expected 3, got %d" % DailyPlanningScript.MAX_SELECTIONS)
		return false
	return true


# ── Counter tracking ──────────────────────────────────────────────────────────

## increment_counter() stores the value in _day_counters.
static func test_increment_counter_basic() -> bool:
	var ov := _make_overlay()
	ov.increment_counter("observe_count", 2)
	var val: int = ov._day_counters.get("observe_count", -1)
	if val != 2:
		push_error("test_increment_counter_basic: expected 2, got %d" % val)
		return false
	return true


## Repeated calls to increment_counter() accumulate the total.
static func test_increment_counter_accumulates() -> bool:
	var ov := _make_overlay()
	ov.increment_counter("observe_count", 1)
	ov.increment_counter("observe_count", 3)
	var val: int = ov._day_counters.get("observe_count", -1)
	if val != 4:
		push_error("test_increment_counter_accumulates: expected 4, got %d" % val)
		return false
	return true


## increment_counter() with no amount argument defaults to 1.
static func test_increment_counter_default_amount() -> bool:
	var ov := _make_overlay()
	ov.increment_counter("bribe_count")
	var val: int = ov._day_counters.get("bribe_count", -1)
	if val != 1:
		push_error("test_increment_counter_default_amount: expected 1, got %d" % val)
		return false
	return true


## Different counter keys are tracked independently.
static func test_increment_counter_multiple_keys_independent() -> bool:
	var ov := _make_overlay()
	ov.increment_counter("observe_count", 3)
	ov.increment_counter("bribe_count", 1)
	var obs: int = ov._day_counters.get("observe_count", -1)
	var bri: int = ov._day_counters.get("bribe_count", -1)
	if obs != 3:
		push_error("test_increment_counter_multiple_keys_independent: observe_count expected 3, got %d" % obs)
		return false
	if bri != 1:
		push_error("test_increment_counter_multiple_keys_independent: bribe_count expected 1, got %d" % bri)
		return false
	return true


# ── Priority query ────────────────────────────────────────────────────────────

## get_current_priorities() returns an empty array before any priorities are set.
static func test_get_current_priorities_empty_initially() -> bool:
	var ov := _make_overlay()
	var result: Array = ov.get_current_priorities()
	if not result.is_empty():
		push_error("test_get_current_priorities_empty_initially: expected empty, got %s" % str(result))
		return false
	return true


## get_current_priorities() returns a copy — mutating the result must not affect
## the internal _current_day_priorities array.
static func test_get_current_priorities_returns_copy() -> bool:
	var ov := _make_overlay()
	ov._current_day_priorities.append("gather_intel")
	var result: Array = ov.get_current_priorities()
	result.append("seed_rumor")   # mutate the copy
	# Internal array must still have only 1 entry.
	if ov._current_day_priorities.size() != 1:
		push_error("test_get_current_priorities_returns_copy: internal array mutated via returned copy")
		return false
	return true


# ── Serialization ─────────────────────────────────────────────────────────────

## get_save_data() must return a dict with the two required top-level keys.
static func test_get_save_data_has_required_keys() -> bool:
	var ov := _make_overlay()
	var data: Dictionary = ov.get_save_data()
	if not data.has("selected_priorities"):
		push_error("test_get_save_data_has_required_keys: missing 'selected_priorities'")
		return false
	if not data.has("day_counters"):
		push_error("test_get_save_data_has_required_keys: missing 'day_counters'")
		return false
	return true


## get_save_data() reflects the current in-memory state.
static func test_get_save_data_reflects_state() -> bool:
	var ov := _make_overlay()
	ov._current_day_priorities.append("eavesdrop")
	ov._day_counters["eavesdrop_count"] = 2
	var data: Dictionary = ov.get_save_data()
	var priorities: Array = data.get("selected_priorities", [])
	var counters: Dictionary = data.get("day_counters", {})
	if priorities.size() != 1 or priorities[0] != "eavesdrop":
		push_error("test_get_save_data_reflects_state: priorities mismatch %s" % str(priorities))
		return false
	if counters.get("eavesdrop_count", -1) != 2:
		push_error("test_get_save_data_reflects_state: counter mismatch %s" % str(counters))
		return false
	return true


## apply_load_data() populates _current_day_priorities from the saved array.
static func test_apply_load_data_restores_priorities() -> bool:
	var ov := _make_overlay()
	var data := {
		"selected_priorities": ["gather_intel", "bribe_npc"],
		"day_counters": {},
	}
	ov.apply_load_data(data)
	var priorities: Array = ov._current_day_priorities
	if priorities.size() != 2:
		push_error("test_apply_load_data_restores_priorities: expected 2 entries, got %d" % priorities.size())
		return false
	if not priorities.has("gather_intel") or not priorities.has("bribe_npc"):
		push_error("test_apply_load_data_restores_priorities: wrong priorities %s" % str(priorities))
		return false
	return true


## apply_load_data() populates _day_counters from the saved dict.
static func test_apply_load_data_restores_counters() -> bool:
	var ov := _make_overlay()
	var data := {
		"selected_priorities": [],
		"day_counters": {"observe_count": 3, "bribe_count": 1},
	}
	ov.apply_load_data(data)
	if ov._day_counters.get("observe_count", -1) != 3:
		push_error("test_apply_load_data_restores_counters: observe_count mismatch")
		return false
	if ov._day_counters.get("bribe_count", -1) != 1:
		push_error("test_apply_load_data_restores_counters: bribe_count mismatch")
		return false
	return true


## apply_load_data({}) on an empty dict must not crash and must leave arrays empty.
static func test_apply_load_data_empty_dict_safe() -> bool:
	var ov := _make_overlay()
	ov.apply_load_data({})   # uses .get() with defaults — no crash
	if not ov._current_day_priorities.is_empty():
		push_error("test_apply_load_data_empty_dict_safe: _current_day_priorities not empty")
		return false
	return true


## apply_load_data() coerces priority ids to String using str().
## Verifies that numeric or non-String ids loaded from disk don't break the array.
static func test_apply_load_data_type_coerces_priority_ids() -> bool:
	var ov := _make_overlay()
	var data := {
		"selected_priorities": [42, "seed_rumor"],
		"day_counters": {},
	}
	ov.apply_load_data(data)   # str(42) → "42"; str("seed_rumor") → "seed_rumor"
	if ov._current_day_priorities.size() != 2:
		push_error("test_apply_load_data_type_coerces_priority_ids: expected 2 entries, got %d"
				% ov._current_day_priorities.size())
		return false
	# Both entries are Strings after coercion.
	for p in ov._current_day_priorities:
		if typeof(p) != TYPE_STRING:
			push_error("test_apply_load_data_type_coerces_priority_ids: entry is not String: %s" % str(p))
			return false
	return true


# ── Priority definition lookup ────────────────────────────────────────────────

## _get_priority_def() returns the correct dict for a known priority id.
static func test_get_priority_def_known_id() -> bool:
	var ov := _make_overlay()
	var pdef: Dictionary = ov._get_priority_def("gather_intel")
	if pdef.is_empty():
		push_error("test_get_priority_def_known_id: returned empty for 'gather_intel'")
		return false
	if pdef.get("id") != "gather_intel":
		push_error("test_get_priority_def_known_id: wrong id '%s'" % pdef.get("id"))
		return false
	if not pdef.has("eval_key"):
		push_error("test_get_priority_def_known_id: missing 'eval_key' in returned dict")
		return false
	return true


## _get_priority_def() returns an empty dict for an id not in PRIORITIES.
static func test_get_priority_def_unknown_id_returns_empty() -> bool:
	var ov := _make_overlay()
	var pdef: Dictionary = ov._get_priority_def("nonexistent_priority_xyz")
	if not pdef.is_empty():
		push_error("test_get_priority_def_unknown_id_returns_empty: expected empty, got %s" % str(pdef))
		return false
	return true


# ── No-op paths ───────────────────────────────────────────────────────────────

## on_game_tick() is documented as `pass` — calling it must leave all state
## identical to before the call.
static func test_on_game_tick_noop() -> bool:
	var ov := _make_overlay()
	ov._day_counters["observe_count"] = 5
	ov.on_game_tick(42)
	# Counters must be unchanged.
	if ov._day_counters.get("observe_count", -1) != 5:
		push_error("test_on_game_tick_noop: _day_counters changed unexpectedly")
		return false
	return true


## _is_showing must be false immediately after construction (before _ready).
static func test_is_showing_default_false() -> bool:
	var ov := _make_overlay()
	if ov._is_showing:
		push_error("test_is_showing_default_false: _is_showing is true before any overlay trigger")
		return false
	return true


# ── Dawn handling ─────────────────────────────────────────────────────────────

## _on_dawn(1) skips _show_overlay (day <= 1 guard) so _is_showing stays false.
static func test_on_dawn_day1_skips_show_overlay() -> bool:
	var ov := _make_overlay()
	ov._on_dawn(1)   # day <= 1 → return before _show_overlay (which needs scene tree)
	if ov._is_showing:
		push_error("test_on_dawn_day1_skips_show_overlay: _is_showing set unexpectedly on day 1")
		return false
	return true


## _on_dawn() clears both _day_counters and _current_day_priorities regardless of day.
static func test_on_dawn_clears_counters_and_priorities() -> bool:
	var ov := _make_overlay()
	ov._day_counters["observe_count"] = 3
	ov._current_day_priorities.append("gather_intel")
	ov._on_dawn(1)   # day=1 returns early before _show_overlay but AFTER clearing
	if not ov._day_counters.is_empty():
		push_error("test_on_dawn_clears_counters_and_priorities: _day_counters not cleared")
		return false
	if not ov._current_day_priorities.is_empty():
		push_error("test_on_dawn_clears_counters_and_priorities: _current_day_priorities not cleared")
		return false
	return true


# ── Evaluation safe paths ─────────────────────────────────────────────────────

## _evaluate_priorities() must not crash when _world is null (the guard in
## _apply_bonus returns early) and _objective_hud is null (the guard in
## _evaluate_priorities returns early before HUD updates).
static func test_evaluate_priorities_safe_with_null_world() -> bool:
	var ov := _make_overlay()
	ov._current_day_priorities.append("gather_intel")
	ov._day_counters["observe_count"] = 2   # count > 0 → triggers _apply_bonus path
	# _world is null → _apply_bonus returns immediately; _objective_hud is null → HUD
	# update branch is skipped.  No crash is the pass condition.
	ov._evaluate_priorities()
	return true


## "any_action" eval_key sums observe_count + eavesdrop_count + bribe_count.
## _evaluate_priorities() correctly routes this special key — verified by confirming
## it does not crash when those keys are absent (defaults to 0).
static func test_evaluate_priorities_any_action_key() -> bool:
	var ov := _make_overlay()
	ov._current_day_priorities.append("wait_observe")   # eval_key = "any_action"
	# No counters set — sum = 0 → completed_count stays 0 → _apply_bonus not called.
	ov._evaluate_priorities()   # must not crash
	return true
