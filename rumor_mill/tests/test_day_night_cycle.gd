## test_day_night_cycle.gd — Unit tests for DayNightCycle (SPA-1017).
##
## Covers:
##   • Initial state         — current_tick=0, current_day=1, days_allowed=30,
##                             ticks_per_day=24, tick_duration_seconds=1.0,
##                             _transition_paused=false, _current_phase_name=""
##   • TIME_COLORS constant  — 10-entry structure; noon is white; midnight is dark
##   • Phase detection       — _get_phase_name() for all boundaries:
##                             Night (0–5), Morning (6–11), Afternoon (12–15),
##                             Evening (16–19), Night (20–23)
##   • Shadow null guard     — _update_shadow_direction() early-returns safely
##                             when _shadow_mat is null (no scene tree needed)
##   • skip_to_next_day dawn — at tick 0 the function returns immediately;
##                             current_tick and current_day are unchanged
##   • Color interpolation   — _apply_time_of_day(hour, instant:=true) sets
##                             canvas_modulate.color exactly: exact keyframe hit,
##                             mid-span lerp, midnight keyframe
##   • Signal API            — game_tick, day_changed, day_transition_started defined
##
## DayNightCycle extends Node.  All tests instantiate it without adding it to the
## scene tree; _ready() is NOT called so @onready vars (tick_timer,
## canvas_modulate) remain null by default.  Tests that call _apply_time_of_day
## manually assign a CanvasModulate and populate _time_keys.  Tween paths and
## timer paths are not exercised here — those require the full scene tree and are
## validated by manual/integration testing.
##
## Run from the Godot editor:  Scene → Run Script (or call run() from any autoload).

class_name TestDayNightCycle
extends RefCounted

const DayNightCycleScript := preload("res://scripts/day_night_cycle.gd")


# ── Test runner ───────────────────────────────────────────────────────────────

static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Initial state
		"test_initial_current_tick_is_zero",
		"test_initial_current_day_is_one",
		"test_initial_days_allowed",
		"test_initial_ticks_per_day",
		"test_initial_tick_duration_seconds",
		"test_initial_transition_paused_is_false",
		"test_initial_current_phase_name_is_empty",
		# TIME_COLORS constant
		"test_time_colors_has_midnight_key",
		"test_time_colors_has_noon_key",
		"test_time_colors_noon_is_white",
		"test_time_colors_has_ten_entries",
		"test_time_colors_midnight_is_dark",
		# Phase detection — Night (pre-dawn)
		"test_get_phase_name_hour_0_is_night",
		"test_get_phase_name_hour_4_is_night",
		"test_get_phase_name_hour_5_is_night",
		# Phase detection — Morning
		"test_get_phase_name_hour_6_is_morning",
		"test_get_phase_name_hour_11_is_morning",
		# Phase detection — Afternoon
		"test_get_phase_name_hour_12_is_afternoon",
		"test_get_phase_name_hour_15_is_afternoon",
		# Phase detection — Evening
		"test_get_phase_name_hour_16_is_evening",
		"test_get_phase_name_hour_19_is_evening",
		# Phase detection — Night (late)
		"test_get_phase_name_hour_20_is_night",
		"test_get_phase_name_hour_23_is_night",
		# Shadow null guard
		"test_update_shadow_direction_null_mat_guard",
		# skip_to_next_day — at dawn
		"test_skip_to_next_day_noop_at_dawn",
		# Color interpolation — instant path
		"test_apply_time_of_day_exact_keyframe_noon",
		"test_apply_time_of_day_exact_keyframe_midnight",
		"test_apply_time_of_day_mid_span_lerp_hour_8",
		# Signal API
		"test_signal_game_tick_defined",
		"test_signal_day_changed_defined",
		"test_signal_day_transition_started_defined",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nDayNightCycle tests: %d passed, %d failed" % [passed, failed])


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns a bare DayNightCycle without scene-tree attachment; _ready() not called.
static func _make_dnc() -> Node:
	return DayNightCycleScript.new()


## Returns a DayNightCycle with canvas_modulate pre-assigned and _time_keys
## sorted — sufficient to call _apply_time_of_day(hour, true) safely.
static func _make_dnc_with_modulate() -> Node:
	var dnc := DayNightCycleScript.new()
	dnc.canvas_modulate = CanvasModulate.new()
	dnc._time_keys = dnc.TIME_COLORS.keys()
	dnc._time_keys.sort()
	return dnc


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_current_tick_is_zero() -> bool:
	return _make_dnc().current_tick == 0


static func test_initial_current_day_is_one() -> bool:
	return _make_dnc().current_day == 1


static func test_initial_days_allowed() -> bool:
	var dnc := _make_dnc()
	if dnc.days_allowed != 30:
		push_error("test_initial_days_allowed: expected 30, got %d" % dnc.days_allowed)
		return false
	return true


static func test_initial_ticks_per_day() -> bool:
	var dnc := _make_dnc()
	if dnc.ticks_per_day != 24:
		push_error("test_initial_ticks_per_day: expected 24, got %d" % dnc.ticks_per_day)
		return false
	return true


static func test_initial_tick_duration_seconds() -> bool:
	var dnc := _make_dnc()
	if absf(dnc.tick_duration_seconds - 1.0) > 0.001:
		push_error("test_initial_tick_duration_seconds: expected 1.0, got %.3f" % dnc.tick_duration_seconds)
		return false
	return true


static func test_initial_transition_paused_is_false() -> bool:
	return not _make_dnc()._transition_paused


static func test_initial_current_phase_name_is_empty() -> bool:
	return _make_dnc()._current_phase_name == ""


# ── TIME_COLORS constant ──────────────────────────────────────────────────────

static func test_time_colors_has_midnight_key() -> bool:
	return _make_dnc().TIME_COLORS.has(0)


static func test_time_colors_has_noon_key() -> bool:
	return _make_dnc().TIME_COLORS.has(12)


## Noon (hour 12) must be defined as pure white.
static func test_time_colors_noon_is_white() -> bool:
	var noon: Color = _make_dnc().TIME_COLORS[12]
	if not noon.is_equal_approx(Color(1.0, 1.0, 1.0)):
		push_error("test_time_colors_noon_is_white: noon color is %s" % noon)
		return false
	return true


## The constant must have exactly 10 entries (matching the documented keyframes).
static func test_time_colors_has_ten_entries() -> bool:
	var count := _make_dnc().TIME_COLORS.size()
	if count != 10:
		push_error("test_time_colors_has_ten_entries: expected 10, got %d" % count)
		return false
	return true


## Midnight (hour 0) must be very dark — all channels well below 0.3.
static func test_time_colors_midnight_is_dark() -> bool:
	var midnight: Color = _make_dnc().TIME_COLORS[0]
	if midnight.r >= 0.3 or midnight.g >= 0.3 or midnight.b >= 0.3:
		push_error("test_time_colors_midnight_is_dark: midnight not dark enough: %s" % midnight)
		return false
	return true


# ── Phase detection ───────────────────────────────────────────────────────────
# _get_phase_name() boundaries:
#   Night    → hour < 6   (pre-dawn) or hour >= 20
#   Morning  → 6 <= hour < 12
#   Afternoon→ 12 <= hour < 16
#   Evening  → 16 <= hour < 20

static func test_get_phase_name_hour_0_is_night() -> bool:
	return _make_dnc()._get_phase_name(0) == "Night"

static func test_get_phase_name_hour_4_is_night() -> bool:
	return _make_dnc()._get_phase_name(4) == "Night"

static func test_get_phase_name_hour_5_is_night() -> bool:
	return _make_dnc()._get_phase_name(5) == "Night"

static func test_get_phase_name_hour_6_is_morning() -> bool:
	return _make_dnc()._get_phase_name(6) == "Morning"

static func test_get_phase_name_hour_11_is_morning() -> bool:
	return _make_dnc()._get_phase_name(11) == "Morning"

static func test_get_phase_name_hour_12_is_afternoon() -> bool:
	return _make_dnc()._get_phase_name(12) == "Afternoon"

static func test_get_phase_name_hour_15_is_afternoon() -> bool:
	return _make_dnc()._get_phase_name(15) == "Afternoon"

static func test_get_phase_name_hour_16_is_evening() -> bool:
	return _make_dnc()._get_phase_name(16) == "Evening"

static func test_get_phase_name_hour_19_is_evening() -> bool:
	return _make_dnc()._get_phase_name(19) == "Evening"

static func test_get_phase_name_hour_20_is_night() -> bool:
	return _make_dnc()._get_phase_name(20) == "Night"

static func test_get_phase_name_hour_23_is_night() -> bool:
	return _make_dnc()._get_phase_name(23) == "Night"


# ── Shadow null guard ─────────────────────────────────────────────────────────

## _update_shadow_direction() must not crash when _shadow_mat is null.
## The method starts with "if _shadow_mat == null: return" so a bare instance is safe.
static func test_update_shadow_direction_null_mat_guard() -> bool:
	var dnc := _make_dnc()
	# _shadow_mat is null (no _ready()); the guard must return cleanly.
	dnc._update_shadow_direction(12)
	return true


# ── skip_to_next_day — at dawn ────────────────────────────────────────────────

## When current_tick % ticks_per_day == 0 the method must return immediately
## without changing current_tick or current_day.
static func test_skip_to_next_day_noop_at_dawn() -> bool:
	var dnc := _make_dnc()
	dnc.current_tick = 0
	dnc.current_day  = 1
	dnc.skip_to_next_day()
	if dnc.current_day != 1:
		push_error("test_skip_to_next_day_noop_at_dawn: current_day changed to %d" % dnc.current_day)
		return false
	return dnc.current_tick == 0


# ── Color interpolation — instant path ───────────────────────────────────────
#
# _apply_time_of_day(hour, true) writes directly to canvas_modulate.color without
# creating a Tween, so it is safe to call outside the scene tree.

## An exact keyframe hour must produce exactly that keyframe's colour.
static func test_apply_time_of_day_exact_keyframe_noon() -> bool:
	var dnc := _make_dnc_with_modulate()
	dnc._apply_time_of_day(12, true)
	var got: Color      = dnc.canvas_modulate.color
	var expected: Color = dnc.TIME_COLORS[12]
	if not got.is_equal_approx(expected):
		push_error("test_apply_time_of_day_exact_keyframe_noon: got %s, expected %s" % [got, expected])
		return false
	return true


static func test_apply_time_of_day_exact_keyframe_midnight() -> bool:
	var dnc := _make_dnc_with_modulate()
	dnc._apply_time_of_day(0, true)
	var got: Color      = dnc.canvas_modulate.color
	var expected: Color = dnc.TIME_COLORS[0]
	if not got.is_equal_approx(expected):
		push_error("test_apply_time_of_day_exact_keyframe_midnight: got %s, expected %s" % [got, expected])
		return false
	return true


## Hour 8 sits between keyframes 6 (sunrise) and 10 (late morning).
## t = (8 - 6) / (10 - 6) = 0.5  →  result is the exact midpoint lerp.
static func test_apply_time_of_day_mid_span_lerp_hour_8() -> bool:
	var dnc := _make_dnc_with_modulate()
	dnc._apply_time_of_day(8, true)
	var got: Color      = dnc.canvas_modulate.color
	var expected: Color = dnc.TIME_COLORS[6].lerp(dnc.TIME_COLORS[10], 0.5)
	if not got.is_equal_approx(expected):
		push_error("test_apply_time_of_day_mid_span_lerp_hour_8: got %s, expected %s" % [got, expected])
		return false
	return true


# ── Signal API ────────────────────────────────────────────────────────────────

static func test_signal_game_tick_defined() -> bool:
	if not _make_dnc().has_signal("game_tick"):
		push_error("test_signal_game_tick_defined: game_tick signal not found")
		return false
	return true


static func test_signal_day_changed_defined() -> bool:
	return _make_dnc().has_signal("day_changed")


static func test_signal_day_transition_started_defined() -> bool:
	return _make_dnc().has_signal("day_transition_started")
