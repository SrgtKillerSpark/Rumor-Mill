## test_journal.gd — Unit tests for journal.gd coordinator (SPA-1024).
##
## Covers:
##   • Palette constants: C_PARCHMENT, C_PANEL_BG, C_HEADING, C_BODY
##   • Section enum values and SECTION_LABELS array length
##   • MAX_MILESTONE_ENTRIES constant
##   • Initial instance state: _is_open, _current_section, _scroll_positions,
##     _milestone_log, _notification_pending, _last_opened_tick
##   • Section modules null before _ready()
##   • push_milestone_event(): appends entry, respects cap, sets _notification_pending
##   • get_milestone_log(): returns duplicate (mutating original doesn't affect copy)
##   • restore_milestones(): replaces _milestone_log
##   • push_milestone_event cap: log capped at MAX_MILESTONE_ENTRIES
##
## Journal extends CanvasLayer.  @onready scene-node refs (_notif_dot, etc.) are
## null without the scene tree — methods that reach them guard with null checks.
## toggle(), open_to_timeline(), _build_sidebar() all touch @onready nodes and
## are not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestJournal
extends RefCounted

const JournalScript := preload("res://scripts/journal.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_j() -> CanvasLayer:
	return JournalScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette constants
		"test_c_parchment_is_warm_beige",
		"test_c_panel_bg_is_dark",
		"test_c_heading_is_golden",
		"test_c_body_is_warm",
		# Section enum + label table
		"test_section_rumors_is_zero",
		"test_section_intelligence_is_one",
		"test_section_factions_is_two",
		"test_section_timeline_is_three",
		"test_section_objectives_is_four",
		"test_section_milestones_is_five",
		"test_section_labels_count_is_six",
		# Constants
		"test_max_milestone_entries_is_100",
		# Initial state
		"test_initial_is_open_false",
		"test_initial_current_section_is_rumors",
		"test_initial_scroll_positions_empty",
		"test_initial_milestone_log_empty",
		"test_initial_notification_pending_false",
		"test_initial_last_opened_tick_minus_one",
		# Section modules null
		"test_initial_rumors_section_null",
		"test_initial_intel_section_null",
		"test_initial_factions_section_null",
		"test_initial_timeline_section_null",
		"test_initial_objectives_section_null",
		# push_milestone_event()
		"test_push_milestone_event_appends_entry",
		"test_push_milestone_event_stores_text",
		"test_push_milestone_event_stores_reward",
		"test_push_milestone_event_sets_notification_pending",
		# get_milestone_log()
		"test_get_milestone_log_returns_copy",
		"test_get_milestone_log_mutation_does_not_affect_internal",
		# restore_milestones()
		"test_restore_milestones_replaces_log",
		# push_milestone_event cap
		"test_push_milestone_event_cap_at_max",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nJournal tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

## C_PARCHMENT should be a warm beige with high r/g, lower b.
static func test_c_parchment_is_warm_beige() -> bool:
	var c: Color = _make_j().C_PARCHMENT
	return c.r > 0.75 and c.g > 0.65 and c.b < 0.70


## C_PANEL_BG should be very dark.
static func test_c_panel_bg_is_dark() -> bool:
	var c: Color = _make_j().C_PANEL_BG
	return c.r < 0.20 and c.g < 0.15 and c.b < 0.10


## C_HEADING should be golden (high r+g, low b).
static func test_c_heading_is_golden() -> bool:
	var c: Color = _make_j().C_HEADING
	return c.r > 0.80 and c.g > 0.65 and c.b < 0.20


## C_BODY should be a warm mid-range colour.
static func test_c_body_is_warm() -> bool:
	var c: Color = _make_j().C_BODY
	return c.r > 0.65 and c.g > 0.60 and c.b < 0.65


# ── Section enum ──────────────────────────────────────────────────────────────

static func test_section_rumors_is_zero() -> bool:
	return int(JournalScript.Section.RUMORS) == 0


static func test_section_intelligence_is_one() -> bool:
	return int(JournalScript.Section.INTELLIGENCE) == 1


static func test_section_factions_is_two() -> bool:
	return int(JournalScript.Section.FACTIONS) == 2


static func test_section_timeline_is_three() -> bool:
	return int(JournalScript.Section.TIMELINE) == 3


static func test_section_objectives_is_four() -> bool:
	return int(JournalScript.Section.OBJECTIVES) == 4


static func test_section_milestones_is_five() -> bool:
	return int(JournalScript.Section.MILESTONES) == 5


## SECTION_LABELS must have an entry for each Section value (6 total).
static func test_section_labels_count_is_six() -> bool:
	var count: int = JournalScript.SECTION_LABELS.size()
	if count != 6:
		push_error("test_section_labels_count_is_six: expected 6, got %d" % count)
		return false
	return true


# ── Constants ─────────────────────────────────────────────────────────────────

static func test_max_milestone_entries_is_100() -> bool:
	if _make_j().MAX_MILESTONE_ENTRIES != 100:
		push_error("test_max_milestone_entries_is_100: got %d" % _make_j().MAX_MILESTONE_ENTRIES)
		return false
	return true


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_is_open_false() -> bool:
	return not _make_j()._is_open


static func test_initial_current_section_is_rumors() -> bool:
	return _make_j()._current_section == JournalScript.Section.RUMORS


static func test_initial_scroll_positions_empty() -> bool:
	return _make_j()._scroll_positions.is_empty()


static func test_initial_milestone_log_empty() -> bool:
	return _make_j()._milestone_log.is_empty()


static func test_initial_notification_pending_false() -> bool:
	return not _make_j()._notification_pending


static func test_initial_last_opened_tick_minus_one() -> bool:
	return _make_j()._last_opened_tick == -1


# ── Section modules null ──────────────────────────────────────────────────────

static func test_initial_rumors_section_null() -> bool:
	return _make_j()._rumors_section == null


static func test_initial_intel_section_null() -> bool:
	return _make_j()._intel_section == null


static func test_initial_factions_section_null() -> bool:
	return _make_j()._factions_section == null


static func test_initial_timeline_section_null() -> bool:
	return _make_j()._timeline_section == null


static func test_initial_objectives_section_null() -> bool:
	return _make_j()._objectives_section == null


# ── push_milestone_event() ────────────────────────────────────────────────────

## A new entry should appear in the log.
static func test_push_milestone_event_appends_entry() -> bool:
	var j := _make_j()
	j.push_milestone_event("Test milestone", Color.WHITE)
	return j._milestone_log.size() == 1


## The stored text must match the argument.
static func test_push_milestone_event_stores_text() -> bool:
	var j := _make_j()
	j.push_milestone_event("Reached 50 believers", Color.WHITE)
	var entry: Dictionary = j._milestone_log[0]
	return entry.get("text", "") == "Reached 50 believers"


## reward_text must be stored in the entry when provided.
static func test_push_milestone_event_stores_reward() -> bool:
	var j := _make_j()
	j.push_milestone_event("First victory", Color.WHITE, "+1 bribe charge")
	var entry: Dictionary = j._milestone_log[0]
	return entry.get("reward_text", "") == "+1 bribe charge"


## When journal is closed, pushing an event must set _notification_pending true.
static func test_push_milestone_event_sets_notification_pending() -> bool:
	var j := _make_j()
	j._is_open = false
	j.push_milestone_event("Event", Color.WHITE)
	return j._notification_pending


# ── get_milestone_log() ───────────────────────────────────────────────────────

## get_milestone_log() must return an array equal to the internal log.
static func test_get_milestone_log_returns_copy() -> bool:
	var j := _make_j()
	j.push_milestone_event("A", Color.WHITE)
	var log_copy: Array = j.get_milestone_log()
	return log_copy.size() == 1


## Mutating the returned copy must not alter the internal _milestone_log.
static func test_get_milestone_log_mutation_does_not_affect_internal() -> bool:
	var j := _make_j()
	j.push_milestone_event("A", Color.WHITE)
	var log_copy: Array = j.get_milestone_log()
	log_copy.clear()
	return j._milestone_log.size() == 1


# ── restore_milestones() ──────────────────────────────────────────────────────

## restore_milestones() must replace _milestone_log with the given entries.
static func test_restore_milestones_replaces_log() -> bool:
	var j := _make_j()
	j.push_milestone_event("Old", Color.WHITE)
	var new_entries: Array = [{"text": "Restored", "color_packed": "", "reward_text": ""}]
	j.restore_milestones(new_entries)
	return j._milestone_log.size() == 1 and j._milestone_log[0].get("text", "") == "Restored"


# ── cap enforcement ───────────────────────────────────────────────────────────

## After MAX_MILESTONE_ENTRIES + 5 pushes the log must not exceed the cap.
static func test_push_milestone_event_cap_at_max() -> bool:
	var j := _make_j()
	var cap: int = j.MAX_MILESTONE_ENTRIES
	for i in range(cap + 5):
		j.push_milestone_event("Entry %d" % i, Color.WHITE)
	if j._milestone_log.size() > cap:
		push_error("test_push_milestone_event_cap_at_max: log size %d exceeds cap %d" % [
			j._milestone_log.size(), cap])
		return false
	return true
