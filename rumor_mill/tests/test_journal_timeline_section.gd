## test_journal_timeline_section.gd — Unit tests for JournalTimelineSection (SPA-1027).
##
## Covers:
##   • MAX_TIMELINE_ENTRIES constant
##   • Initial state: _timeline_log, _pending_events empty; _filter_text empty;
##                    _sort_newest false; _today_filter false
##   • push_event() — appends to _pending_events, not _timeline_log
##   • flush_pending_events() — moves events to _timeline_log, clears pending
##   • flush_pending_events() — no-op when pending is empty
##   • flush_pending_events() — trims _timeline_log to MAX_TIMELINE_ENTRIES
##   • restore() — replaces _timeline_log, clears _pending_events
##   • set_open_filters() — sets _filter_text, _today_filter; today=true forces _sort_newest
##   • has_new_entries_since() — false when since_tick < 0
##   • has_new_entries_since() — false when log is empty
##   • has_new_entries_since() — true when event tick > since_tick
##   • has_new_entries_since() — false when all ticks ≤ since_tick
##   • _tick_to_day_str() — tick 0 → "Day 1, 12:00 AM"; tick 13 → "Day 1, 01:00 PM"
##
## Run from the Godot editor: Scene → Run Script.

class_name TestJournalTimelineSection
extends RefCounted

const _Klass := preload("res://scripts/journal_timeline_section.gd")


static func _make() -> JournalTimelineSection:
	return _Klass.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Constant
		"test_max_timeline_entries",

		# Initial state
		"test_initial_timeline_log_empty",
		"test_initial_pending_events_empty",
		"test_initial_filter_text_empty",
		"test_initial_sort_newest_false",
		"test_initial_today_filter_false",

		# push_event()
		"test_push_event_adds_to_pending",
		"test_push_event_not_in_timeline_log",
		"test_push_event_stores_correct_fields",

		# flush_pending_events()
		"test_flush_moves_to_timeline",
		"test_flush_clears_pending",
		"test_flush_noop_when_empty",
		"test_flush_trims_to_max",

		# restore()
		"test_restore_replaces_log",
		"test_restore_clears_pending",

		# set_open_filters()
		"test_set_open_filters_assigns_text",
		"test_set_open_filters_assigns_today",
		"test_set_open_filters_today_sets_sort_newest",

		# has_new_entries_since()
		"test_has_new_entries_negative_since",
		"test_has_new_entries_empty_log",
		"test_has_new_entries_true_when_newer_event",
		"test_has_new_entries_false_when_all_older",

		# _tick_to_day_str()
		"test_tick_to_day_str_tick_0",
		"test_tick_to_day_str_tick_13",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nJournalTimelineSection tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# MAX_TIMELINE_ENTRIES
# ══════════════════════════════════════════════════════════════════════════════

func test_max_timeline_entries() -> bool:
	var s := _make()
	return s.MAX_TIMELINE_ENTRIES == 200


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_timeline_log_empty() -> bool:
	var s := _make()
	return s._timeline_log.is_empty()


func test_initial_pending_events_empty() -> bool:
	var s := _make()
	return s._pending_events.is_empty()


func test_initial_filter_text_empty() -> bool:
	var s := _make()
	return s._filter_text == ""


func test_initial_sort_newest_false() -> bool:
	var s := _make()
	return s._sort_newest == false


func test_initial_today_filter_false() -> bool:
	var s := _make()
	return s._today_filter == false


# ══════════════════════════════════════════════════════════════════════════════
# push_event()
# ══════════════════════════════════════════════════════════════════════════════

func test_push_event_adds_to_pending() -> bool:
	var s := _make()
	s.push_event(10, "Test event")
	return s._pending_events.size() == 1


func test_push_event_not_in_timeline_log() -> bool:
	var s := _make()
	s.push_event(10, "Test event")
	return s._timeline_log.is_empty()


func test_push_event_stores_correct_fields() -> bool:
	var s := _make()
	s.push_event(42, "Hello", "diag_text")
	var ev: Dictionary = s._pending_events[0]
	return ev.get("tick") == 42 \
		and ev.get("message") == "Hello" \
		and ev.get("diagnostic") == "diag_text"


# ══════════════════════════════════════════════════════════════════════════════
# flush_pending_events()
# ══════════════════════════════════════════════════════════════════════════════

func test_flush_moves_to_timeline() -> bool:
	var s := _make()
	s.push_event(5, "A")
	s.push_event(6, "B")
	s.flush_pending_events()
	return s._timeline_log.size() == 2


func test_flush_clears_pending() -> bool:
	var s := _make()
	s.push_event(5, "A")
	s.flush_pending_events()
	return s._pending_events.is_empty()


func test_flush_noop_when_empty() -> bool:
	var s := _make()
	s.flush_pending_events()  # no events — should not crash
	return s._timeline_log.is_empty()


func test_flush_trims_to_max() -> bool:
	var s := _make()
	# Add MAX + 5 events via pending
	for i in range(s.MAX_TIMELINE_ENTRIES + 5):
		s.push_event(i, "ev%d" % i)
	s.flush_pending_events()
	return s._timeline_log.size() == s.MAX_TIMELINE_ENTRIES


# ══════════════════════════════════════════════════════════════════════════════
# restore()
# ══════════════════════════════════════════════════════════════════════════════

func test_restore_replaces_log() -> bool:
	var s := _make()
	s.push_event(1, "old")
	s.flush_pending_events()
	var fresh := [{"tick": 99, "message": "restored", "diagnostic": ""}]
	s.restore(fresh)
	return s._timeline_log.size() == 1 and s._timeline_log[0].get("tick") == 99


func test_restore_clears_pending() -> bool:
	var s := _make()
	s.push_event(1, "pending_event")
	s.restore([])
	return s._pending_events.is_empty()


# ══════════════════════════════════════════════════════════════════════════════
# set_open_filters()
# ══════════════════════════════════════════════════════════════════════════════

func test_set_open_filters_assigns_text() -> bool:
	var s := _make()
	s.set_open_filters("scout", false)
	return s._filter_text == "scout"


func test_set_open_filters_assigns_today() -> bool:
	var s := _make()
	s.set_open_filters("", true)
	return s._today_filter == true


func test_set_open_filters_today_sets_sort_newest() -> bool:
	var s := _make()
	s._sort_newest = false
	s.set_open_filters("", true)
	return s._sort_newest == true


# ══════════════════════════════════════════════════════════════════════════════
# has_new_entries_since()
# ══════════════════════════════════════════════════════════════════════════════

func test_has_new_entries_negative_since() -> bool:
	var s := _make()
	s.push_event(5, "x")
	s.flush_pending_events()
	return s.has_new_entries_since(-1) == false


func test_has_new_entries_empty_log() -> bool:
	var s := _make()
	return s.has_new_entries_since(0) == false


func test_has_new_entries_true_when_newer_event() -> bool:
	var s := _make()
	s.push_event(10, "newer")
	s.flush_pending_events()
	return s.has_new_entries_since(5) == true


func test_has_new_entries_false_when_all_older() -> bool:
	var s := _make()
	s.push_event(3, "older")
	s.flush_pending_events()
	return s.has_new_entries_since(5) == false


# ══════════════════════════════════════════════════════════════════════════════
# _tick_to_day_str()
# ══════════════════════════════════════════════════════════════════════════════

func test_tick_to_day_str_tick_0() -> bool:
	var s := _make()
	return s._tick_to_day_str(0) == "Day 1, 12:00 AM"


func test_tick_to_day_str_tick_13() -> bool:
	var s := _make()
	# tick 13: day=1, hour=13, PM, display_hour=1 → "Day 1, 01:00 PM"
	return s._tick_to_day_str(13) == "Day 1, 01:00 PM"
