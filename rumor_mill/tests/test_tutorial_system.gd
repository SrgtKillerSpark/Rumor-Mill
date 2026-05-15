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
##   • Phase 2.5 (SPA-2452):   — hint_second_visit in CONTEXT_HINT_DATA (12s, Witness Account body)
##                              — action-gate conditions: observe, eavesdrop, craft_rumor, read_the_room
##                              — soft-nudge sequence: observe/journal/rumor exist with 9s dismiss
##                              — gtut_day1_eavesdrop_nudge exists, 999s, no action_gate (SPA-2434)
##
## TutorialSystem is a plain class (no Node); instantiated with .new() — _ready()
## is never called so there is no scene-tree or file I/O dependency.
##
## Run from the Godot editor:  Scene → Run Script (or call run() directly).

class_name TestTutorialSystem
extends RefCounted


func run() -> void:
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
		# Phase 2.5: hint_second_visit in CONTEXT_HINT_DATA (SPA-2452)
		"test_hint_second_visit_in_context_hint_data",
		"test_hint_second_visit_dismiss_is_12s",
		"test_hint_second_visit_body_mentions_witness_account",
		# Phase 2.5: action-gate trigger conditions (SPA-2452)
		"test_hint_first_action_gate_is_observe",
		"test_hint_target_npc_gate_is_eavesdrop",
		"test_hint_rumour_panel_gate_is_craft_rumor",
		"test_gtut_explore_gate_is_read_the_room",
		# Phase 2.5: soft-nudge sequence (SPA-2081)
		"test_soft_nudge_observe_in_context_hint_data",
		"test_soft_nudge_journal_in_context_hint_data",
		"test_soft_nudge_rumor_in_context_hint_data",
		"test_soft_nudge_observe_dismiss_is_9s",
		"test_soft_nudge_journal_dismiss_is_9s",
		"test_soft_nudge_rumor_dismiss_is_9s",
		# Phase 2.5: Day-1 eavesdrop nudge (SPA-2434)
		"test_gtut_day1_eavesdrop_nudge_in_hint_data",
		"test_gtut_day1_eavesdrop_nudge_dismiss_is_999s",
		"test_gtut_day1_eavesdrop_nudge_has_no_action_gate",
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


# ── Phase 2.5: hint_second_visit (SPA-2452) ──────────────────────────────────

static func test_hint_second_visit_in_context_hint_data() -> bool:
	return TutorialSystem.CONTEXT_HINT_DATA.has("hint_second_visit")


## Auto-dismiss must be 12 s as per SPA-2452 spec.
static func test_hint_second_visit_dismiss_is_12s() -> bool:
	if not TutorialSystem.CONTEXT_HINT_DATA.has("hint_second_visit"):
		push_error("test_hint_second_visit_dismiss_is_12s: key missing")
		return false
	return TutorialSystem.CONTEXT_HINT_DATA["hint_second_visit"]["auto_dismiss_secs"] == 12


## Body must reference "Witness Account" so the player knows what they are unlocking.
static func test_hint_second_visit_body_mentions_witness_account() -> bool:
	if not TutorialSystem.CONTEXT_HINT_DATA.has("hint_second_visit"):
		push_error("test_hint_second_visit_body_mentions_witness_account: key missing")
		return false
	var body: String = TutorialSystem.CONTEXT_HINT_DATA["hint_second_visit"]["body"]
	return "Witness Account" in body


# ── Phase 2.5: action-gate trigger conditions ────────────────────────────────

static func test_hint_first_action_gate_is_observe() -> bool:
	if not TutorialSystem.HINT_DATA.has("hint_first_action"):
		push_error("test_hint_first_action_gate_is_observe: key missing")
		return false
	return TutorialSystem.HINT_DATA["hint_first_action"].get("action_gate", "") == "observe"


static func test_hint_target_npc_gate_is_eavesdrop() -> bool:
	if not TutorialSystem.HINT_DATA.has("hint_target_npc"):
		push_error("test_hint_target_npc_gate_is_eavesdrop: key missing")
		return false
	return TutorialSystem.HINT_DATA["hint_target_npc"].get("action_gate", "") == "eavesdrop"


static func test_hint_rumour_panel_gate_is_craft_rumor() -> bool:
	if not TutorialSystem.HINT_DATA.has("hint_rumour_panel"):
		push_error("test_hint_rumour_panel_gate_is_craft_rumor: key missing")
		return false
	return TutorialSystem.HINT_DATA["hint_rumour_panel"].get("action_gate", "") == "craft_rumor"


static func test_gtut_explore_gate_is_read_the_room() -> bool:
	if not TutorialSystem.HINT_DATA.has("gtut_explore"):
		push_error("test_gtut_explore_gate_is_read_the_room: key missing")
		return false
	return TutorialSystem.HINT_DATA["gtut_explore"].get("action_gate", "") == "read_the_room"


# ── Phase 2.5: soft-nudge sequence (SPA-2081) ────────────────────────────────

static func test_soft_nudge_observe_in_context_hint_data() -> bool:
	return TutorialSystem.CONTEXT_HINT_DATA.has("soft_nudge_observe")


static func test_soft_nudge_journal_in_context_hint_data() -> bool:
	return TutorialSystem.CONTEXT_HINT_DATA.has("soft_nudge_journal")


static func test_soft_nudge_rumor_in_context_hint_data() -> bool:
	return TutorialSystem.CONTEXT_HINT_DATA.has("soft_nudge_rumor")


static func test_soft_nudge_observe_dismiss_is_9s() -> bool:
	if not TutorialSystem.CONTEXT_HINT_DATA.has("soft_nudge_observe"):
		push_error("test_soft_nudge_observe_dismiss_is_9s: key missing")
		return false
	return TutorialSystem.CONTEXT_HINT_DATA["soft_nudge_observe"]["auto_dismiss_secs"] == 9


static func test_soft_nudge_journal_dismiss_is_9s() -> bool:
	if not TutorialSystem.CONTEXT_HINT_DATA.has("soft_nudge_journal"):
		push_error("test_soft_nudge_journal_dismiss_is_9s: key missing")
		return false
	return TutorialSystem.CONTEXT_HINT_DATA["soft_nudge_journal"]["auto_dismiss_secs"] == 9


static func test_soft_nudge_rumor_dismiss_is_9s() -> bool:
	if not TutorialSystem.CONTEXT_HINT_DATA.has("soft_nudge_rumor"):
		push_error("test_soft_nudge_rumor_dismiss_is_9s: key missing")
		return false
	return TutorialSystem.CONTEXT_HINT_DATA["soft_nudge_rumor"]["auto_dismiss_secs"] == 9


# ── Phase 2.5: Day-1 eavesdrop nudge (SPA-2434) ──────────────────────────────

static func test_gtut_day1_eavesdrop_nudge_in_hint_data() -> bool:
	return TutorialSystem.HINT_DATA.has("gtut_day1_eavesdrop_nudge")


## Persistent nudge: stays on screen until the player acts (999 s timeout).
static func test_gtut_day1_eavesdrop_nudge_dismiss_is_999s() -> bool:
	if not TutorialSystem.HINT_DATA.has("gtut_day1_eavesdrop_nudge"):
		push_error("test_gtut_day1_eavesdrop_nudge_dismiss_is_999s: key missing")
		return false
	return TutorialSystem.HINT_DATA["gtut_day1_eavesdrop_nudge"]["auto_dismiss_secs"] == 999


## No action_gate: nudge is dismissed by player action, not by a gate event.
static func test_gtut_day1_eavesdrop_nudge_has_no_action_gate() -> bool:
	if not TutorialSystem.HINT_DATA.has("gtut_day1_eavesdrop_nudge"):
		push_error("test_gtut_day1_eavesdrop_nudge_has_no_action_gate: key missing")
		return false
	return not TutorialSystem.HINT_DATA["gtut_day1_eavesdrop_nudge"].has("action_gate")
