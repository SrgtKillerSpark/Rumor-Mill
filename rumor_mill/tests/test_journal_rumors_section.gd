## test_journal_rumors_section.gd — Unit tests for JournalRumorsSection (SPA-1027).
##
## Covers:
##   • Initial state: _expanded_rumors, _rumor_last_status, _changed_rumor_ids,
##                    _transition_summary all empty; _filter_text empty;
##                    _status_filter empty; _sort_newest true
##   • setup() — assigns _world_ref and _day_night_ref
##   • has_status_transitions() — false when world_ref is null
##   • has_status_transitions() — false when _rumor_last_status is empty
##   • on_journal_close() — clears _changed_rumor_ids and _transition_summary
##   • _rumor_journal_status() — EXPIRED when believability < 0.05
##   • _rumor_journal_status() — CONTRADICTED when is_contradicted=true and spreaders>0
##   • _rumor_journal_status() — SPREADING when spreaders > 0
##   • _rumor_journal_status() — STALLING when believers > 0, no spreaders
##   • _rumor_journal_status() — EVALUATING when no spreaders or believers
##   • _rumor_status_color() — correct colour per status string
##   • _is_positive_transition() — SPREADING and EVALUATING are positive; others are not
##   • _tick_to_day_str() — tick 0 → "Day 1, 12:00 AM"; tick 12 → "Day 1, 12:00 PM"
##
## Run from the Godot editor: Scene → Run Script.

class_name TestJournalRumorsSection
extends RefCounted

const _Klass := preload("res://scripts/journal_rumors_section.gd")


static func _make() -> JournalRumorsSection:
	return _Klass.new()


## Build a minimal Rumor with only current_believability set.
static func _make_rumor_with_believability(bel: float) -> Rumor:
	var r := Rumor.create("r_test", "subj", Rumor.ClaimType.ACCUSATION, 3, 0.1, 0, 330)
	r.current_believability = bel
	return r


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Initial state
		"test_initial_expanded_rumors_empty",
		"test_initial_rumor_last_status_empty",
		"test_initial_changed_rumor_ids_empty",
		"test_initial_transition_summary_empty",
		"test_initial_filter_text_empty",
		"test_initial_status_filter_empty",
		"test_initial_sort_newest_true",

		# setup()
		"test_setup_assigns_refs",

		# has_status_transitions()
		"test_has_transitions_false_without_world",
		"test_has_transitions_false_when_last_status_empty",

		# on_journal_close()
		"test_close_clears_changed_ids",
		"test_close_clears_transition_summary",

		# _rumor_journal_status()
		"test_status_expired_when_low_believability",
		"test_status_contradicted",
		"test_status_spreading",
		"test_status_stalling",
		"test_status_evaluating",

		# _rumor_status_color()
		"test_status_color_evaluating",
		"test_status_color_spreading",
		"test_status_color_stalling",
		"test_status_color_contradicted",
		"test_status_color_expired",

		# _is_positive_transition()
		"test_positive_transition_spreading",
		"test_positive_transition_evaluating",
		"test_positive_transition_stalling_is_false",
		"test_positive_transition_contradicted_is_false",

		# _tick_to_day_str()
		"test_tick_to_day_str_tick_0",
		"test_tick_to_day_str_tick_12",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nJournalRumorsSection tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_expanded_rumors_empty() -> bool:
	var s := _make()
	return s._expanded_rumors.is_empty()


func test_initial_rumor_last_status_empty() -> bool:
	var s := _make()
	return s._rumor_last_status.is_empty()


func test_initial_changed_rumor_ids_empty() -> bool:
	var s := _make()
	return s._changed_rumor_ids.is_empty()


func test_initial_transition_summary_empty() -> bool:
	var s := _make()
	return s._transition_summary.is_empty()


func test_initial_filter_text_empty() -> bool:
	var s := _make()
	return s._filter_text == ""


func test_initial_status_filter_empty() -> bool:
	var s := _make()
	return s._status_filter == ""


func test_initial_sort_newest_true() -> bool:
	var s := _make()
	return s._sort_newest == true


# ══════════════════════════════════════════════════════════════════════════════
# setup()
# ══════════════════════════════════════════════════════════════════════════════

func test_setup_assigns_refs() -> bool:
	var s         := _make()
	var world     := Node2D.new()
	var day_night := Node.new()
	s.setup(world, day_night)
	var ok := s._world_ref == world and s._day_night_ref == day_night
	world.free()
	day_night.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# has_status_transitions()
# ══════════════════════════════════════════════════════════════════════════════

func test_has_transitions_false_without_world() -> bool:
	var s := _make()
	# world_ref is null → early return false
	s._rumor_last_status["r1"] = "EVALUATING"
	return s.has_status_transitions() == false


func test_has_transitions_false_when_last_status_empty() -> bool:
	var s := _make()
	# _rumor_last_status is empty → early return false
	return s.has_status_transitions() == false


# ══════════════════════════════════════════════════════════════════════════════
# on_journal_close()
# ══════════════════════════════════════════════════════════════════════════════

func test_close_clears_changed_ids() -> bool:
	var s := _make()
	s._changed_rumor_ids["r1"] = true
	s.on_journal_close()
	return s._changed_rumor_ids.is_empty()


func test_close_clears_transition_summary() -> bool:
	var s := _make()
	s._transition_summary["SPREADING"] = 2
	s.on_journal_close()
	return s._transition_summary.is_empty()


# ══════════════════════════════════════════════════════════════════════════════
# _rumor_journal_status()
# ══════════════════════════════════════════════════════════════════════════════

func test_status_expired_when_low_believability() -> bool:
	var s := _make()
	var r := _make_rumor_with_believability(0.04)
	return s._rumor_journal_status(r, 0, 0, false) == "EXPIRED"


func test_status_contradicted() -> bool:
	var s := _make()
	var r := _make_rumor_with_believability(0.5)
	# is_contradicted=true with spreaders > 0
	return s._rumor_journal_status(r, 1, 1, true) == "CONTRADICTED"


func test_status_spreading() -> bool:
	var s := _make()
	var r := _make_rumor_with_believability(0.5)
	return s._rumor_journal_status(r, 2, 2, false) == "SPREADING"


func test_status_stalling() -> bool:
	var s := _make()
	var r := _make_rumor_with_believability(0.5)
	# believers > 0 but no spreaders
	return s._rumor_journal_status(r, 0, 1, false) == "STALLING"


func test_status_evaluating() -> bool:
	var s := _make()
	var r := _make_rumor_with_believability(0.5)
	# no believers, no spreaders
	return s._rumor_journal_status(r, 0, 0, false) == "EVALUATING"


# ══════════════════════════════════════════════════════════════════════════════
# _rumor_status_color()
# ══════════════════════════════════════════════════════════════════════════════

func test_status_color_evaluating() -> bool:
	var s := _make()
	return s._rumor_status_color("EVALUATING") == s.C_EVALUATING


func test_status_color_spreading() -> bool:
	var s := _make()
	return s._rumor_status_color("SPREADING") == s.C_SPREADING


func test_status_color_stalling() -> bool:
	var s := _make()
	return s._rumor_status_color("STALLING") == s.C_STALLING


func test_status_color_contradicted() -> bool:
	var s := _make()
	return s._rumor_status_color("CONTRADICTED") == s.C_CONTRADICTED


func test_status_color_expired() -> bool:
	var s := _make()
	return s._rumor_status_color("EXPIRED") == s.C_EXPIRED


# ══════════════════════════════════════════════════════════════════════════════
# _is_positive_transition()
# ══════════════════════════════════════════════════════════════════════════════

func test_positive_transition_spreading() -> bool:
	var s := _make()
	return s._is_positive_transition("SPREADING") == true


func test_positive_transition_evaluating() -> bool:
	var s := _make()
	return s._is_positive_transition("EVALUATING") == true


func test_positive_transition_stalling_is_false() -> bool:
	var s := _make()
	return s._is_positive_transition("STALLING") == false


func test_positive_transition_contradicted_is_false() -> bool:
	var s := _make()
	return s._is_positive_transition("CONTRADICTED") == false


# ══════════════════════════════════════════════════════════════════════════════
# _tick_to_day_str()
# ══════════════════════════════════════════════════════════════════════════════

func test_tick_to_day_str_tick_0() -> bool:
	var s := _make()
	return s._tick_to_day_str(0) == "Day 1, 12:00 AM"


func test_tick_to_day_str_tick_12() -> bool:
	var s := _make()
	return s._tick_to_day_str(12) == "Day 1, 12:00 PM"
