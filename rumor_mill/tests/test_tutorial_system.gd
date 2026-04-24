## test_tutorial_system.gd — Unit tests for TutorialSystem (SPA-981).
##
## Covers:
##   • has_seen() / mark_seen() — initial false, set to true, idempotent
##   • get_seen_count()         — zero initially, increments per unique id
##   • get_tooltip()            — returns data for known id; empty for unknown
##   • get_hint()               — searches HINT_DATA then CONTEXT_HINT_DATA; empty for unknown
##   • set_last_hint() /        — replay returns "" with no hint set; returns id after set;
##     replay_current_hint()      un-marks seen so hint can re-fire
##   • get_whats_changed()      — returns dict for known scenario; empty for unknown
##   • Static data integrity    — TOOLTIP_DATA, HINT_DATA, CONTEXT_HINT_DATA, WHATS_CHANGED_DATA
##                                all entries have required fields
##
## TutorialSystem is a plain class (no Node); instantiated with .new() — _ready()
## is never called so there is no scene-tree or file I/O dependency.
##
## Run from the Godot editor:  Scene → Run Script (or call run() directly).

class_name TestTutorialSystem
extends RefCounted


static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# has_seen / mark_seen
		"test_has_seen_false_initially",
		"test_mark_seen_sets_seen",
		"test_mark_seen_idempotent",
		# get_seen_count
		"test_get_seen_count_zero_initially",
		"test_get_seen_count_increments_per_unique_id",
		"test_get_seen_count_does_not_double_count",
		# get_tooltip
		"test_get_tooltip_known_id_has_title_and_body",
		"test_get_tooltip_unknown_id_returns_empty",
		# get_hint (HINT_DATA + CONTEXT_HINT_DATA fallthrough)
		"test_get_hint_from_hint_data",
		"test_get_hint_from_context_hint_data",
		"test_get_hint_unknown_id_returns_empty",
		# set_last_hint / replay_current_hint
		"test_replay_current_hint_empty_initially",
		"test_replay_returns_hint_id_after_set",
		"test_replay_unmarks_seen_so_hint_can_refire",
		"test_replay_second_call_on_same_hint_works",
		# get_whats_changed
		"test_get_whats_changed_known_scenario_has_data",
		"test_get_whats_changed_unknown_scenario_returns_empty",
		"test_get_whats_changed_all_scenarios_covered",
		# Static data integrity
		"test_tooltip_data_all_have_title_and_body",
		"test_hint_data_all_have_title_body_dismiss",
		"test_context_hint_data_all_have_title_body_dismiss",
		"test_whats_changed_data_all_have_title_and_bullets",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nTutorialSystem tests: %d passed, %d failed" % [passed, failed])


# ── helpers ──────────────────────────────────────────────────────────────────

static func _make_sys() -> TutorialSystem:
	return TutorialSystem.new()


# ── has_seen / mark_seen ──────────────────────────────────────────────────────

static func test_has_seen_false_initially() -> bool:
	var sys := _make_sys()
	return not sys.has_seen("core_loop")


static func test_mark_seen_sets_seen() -> bool:
	var sys := _make_sys()
	sys.mark_seen("core_loop")
	return sys.has_seen("core_loop")


static func test_mark_seen_idempotent() -> bool:
	var sys := _make_sys()
	sys.mark_seen("navigation_controls")
	sys.mark_seen("navigation_controls")
	return sys.has_seen("navigation_controls")


# ── get_seen_count ────────────────────────────────────────────────────────────

static func test_get_seen_count_zero_initially() -> bool:
	var sys := _make_sys()
	return sys.get_seen_count() == 0


static func test_get_seen_count_increments_per_unique_id() -> bool:
	var sys := _make_sys()
	sys.mark_seen("observe")
	sys.mark_seen("eavesdrop")
	sys.mark_seen("reputation")
	if sys.get_seen_count() != 3:
		push_error("test_get_seen_count_increments_per_unique_id: expected 3, got %d" % sys.get_seen_count())
		return false
	return true


static func test_get_seen_count_does_not_double_count() -> bool:
	var sys := _make_sys()
	sys.mark_seen("observe")
	sys.mark_seen("observe")
	if sys.get_seen_count() != 1:
		push_error("test_get_seen_count_does_not_double_count: expected 1, got %d" % sys.get_seen_count())
		return false
	return true


# ── get_tooltip ───────────────────────────────────────────────────────────────

static func test_get_tooltip_known_id_has_title_and_body() -> bool:
	var sys := _make_sys()
	var tip := sys.get_tooltip("core_loop")
	if not tip.has("title") or not tip.has("body"):
		push_error("test_get_tooltip_known_id_has_title_and_body: missing title or body: %s" % str(tip))
		return false
	if tip["title"].is_empty() or tip["body"].is_empty():
		push_error("test_get_tooltip_known_id_has_title_and_body: empty title or body")
		return false
	return true


static func test_get_tooltip_unknown_id_returns_empty() -> bool:
	var sys := _make_sys()
	var tip := sys.get_tooltip("totally_fake_tooltip_xyz")
	return tip.is_empty()


# ── get_hint ──────────────────────────────────────────────────────────────────

static func test_get_hint_from_hint_data() -> bool:
	var sys := _make_sys()
	# "hint_first_action" is defined in HINT_DATA (S1-specific).
	var hint := sys.get_hint("hint_first_action")
	if hint.is_empty():
		push_error("test_get_hint_from_hint_data: expected hint data, got empty dict")
		return false
	return hint.has("title") and hint.has("body")


static func test_get_hint_from_context_hint_data() -> bool:
	var sys := _make_sys()
	# "ctx_actions_refresh" is defined in CONTEXT_HINT_DATA (cross-scenario).
	var hint := sys.get_hint("ctx_actions_refresh")
	if hint.is_empty():
		push_error("test_get_hint_from_context_hint_data: expected hint data, got empty dict")
		return false
	return hint.has("title") and hint.has("body")


static func test_get_hint_unknown_id_returns_empty() -> bool:
	var sys := _make_sys()
	return sys.get_hint("nonexistent_hint_id_abc").is_empty()


# ── set_last_hint / replay_current_hint ───────────────────────────────────────

static func test_replay_current_hint_empty_initially() -> bool:
	var sys := _make_sys()
	return sys.replay_current_hint() == ""


static func test_replay_returns_hint_id_after_set() -> bool:
	var sys := _make_sys()
	sys.set_last_hint("hint_observe")
	var result := sys.replay_current_hint()
	if result != "hint_observe":
		push_error("test_replay_returns_hint_id_after_set: expected 'hint_observe', got '%s'" % result)
		return false
	return true


static func test_replay_unmarks_seen_so_hint_can_refire() -> bool:
	var sys := _make_sys()
	sys.mark_seen("hint_observe")
	sys.set_last_hint("hint_observe")
	sys.replay_current_hint()
	# After replay, the hint should no longer be marked as seen.
	if sys.has_seen("hint_observe"):
		push_error("test_replay_unmarks_seen_so_hint_can_refire: hint still marked seen after replay")
		return false
	return true


static func test_replay_second_call_on_same_hint_works() -> bool:
	# replay_current_hint() erases the seen entry, but _last_hint_id is unchanged.
	# Calling it again should still return the same id (and erase again — idempotent).
	var sys := _make_sys()
	sys.set_last_hint("hint_journal")
	sys.mark_seen("hint_journal")
	var first := sys.replay_current_hint()
	sys.mark_seen("hint_journal")
	var second := sys.replay_current_hint()
	if first != "hint_journal" or second != "hint_journal":
		push_error("test_replay_second_call_on_same_hint_works: unexpected ids: '%s', '%s'" % [first, second])
		return false
	return true


# ── get_whats_changed ─────────────────────────────────────────────────────────

static func test_get_whats_changed_known_scenario_has_data() -> bool:
	var sys := _make_sys()
	var data := sys.get_whats_changed("scenario_2")
	if data.is_empty():
		push_error("test_get_whats_changed_known_scenario_has_data: expected data for scenario_2")
		return false
	return data.has("title") and data.has("bullets")


static func test_get_whats_changed_unknown_scenario_returns_empty() -> bool:
	var sys := _make_sys()
	return sys.get_whats_changed("scenario_99").is_empty()


static func test_get_whats_changed_all_scenarios_covered() -> bool:
	var sys := _make_sys()
	for sid in ["scenario_2", "scenario_3", "scenario_4", "scenario_5", "scenario_6"]:
		var data := sys.get_whats_changed(sid)
		if data.is_empty():
			push_error("test_get_whats_changed_all_scenarios_covered: no data for '%s'" % sid)
			return false
	return true


# ── Static data integrity ─────────────────────────────────────────────────────

static func test_tooltip_data_all_have_title_and_body() -> bool:
	for tip_id in TutorialSystem.TOOLTIP_DATA:
		var entry: Dictionary = TutorialSystem.TOOLTIP_DATA[tip_id]
		for field in ["title", "body"]:
			if not entry.has(field):
				push_error("test_tooltip_data_all_have_title_and_body: '%s' missing '%s'" % [tip_id, field])
				return false
	return true


static func test_hint_data_all_have_title_body_dismiss() -> bool:
	for hint_id in TutorialSystem.HINT_DATA:
		var entry: Dictionary = TutorialSystem.HINT_DATA[hint_id]
		for field in ["title", "body", "auto_dismiss_secs"]:
			if not entry.has(field):
				push_error("test_hint_data_all_have_title_body_dismiss: '%s' missing '%s'" % [hint_id, field])
				return false
	return true


static func test_context_hint_data_all_have_title_body_dismiss() -> bool:
	for hint_id in TutorialSystem.CONTEXT_HINT_DATA:
		var entry: Dictionary = TutorialSystem.CONTEXT_HINT_DATA[hint_id]
		for field in ["title", "body", "auto_dismiss_secs"]:
			if not entry.has(field):
				push_error("test_context_hint_data_all_have_title_body_dismiss: '%s' missing '%s'" % [hint_id, field])
				return false
	return true


static func test_whats_changed_data_all_have_title_and_bullets() -> bool:
	for sid in TutorialSystem.WHATS_CHANGED_DATA:
		var entry: Dictionary = TutorialSystem.WHATS_CHANGED_DATA[sid]
		if not entry.has("title") or not entry.has("bullets"):
			push_error("test_whats_changed_data_all_have_title_and_bullets: '%s' missing title or bullets" % sid)
			return false
		if not (entry["bullets"] is Array) or entry["bullets"].is_empty():
			push_error("test_whats_changed_data_all_have_title_and_bullets: '%s' has no bullets" % sid)
			return false
	return true
