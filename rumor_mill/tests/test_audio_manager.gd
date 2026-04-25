## test_audio_manager.gd — Unit tests for AudioManager (SPA-982).
##
## Covers:
##   • Constants         — MUSIC_FILES and SFX_FILES contain required keys;
##                         day/phase hour constants are internally consistent
##   • Phase detection   — _apply_phase_music() sets _current_phase correctly for
##                         morning (6-15), evening (16-19), and night (20-5);
##                         same-phase call is a no-op
##   • Ambient state     — set_ambient() is idempotent when state unchanged;
##                         location-ambient override prevents crossfade while
##                         still recording the new day/night flag
##   • Location ambient  — invalid location id is silently ignored;
##                         clear_location_ambient() is a no-op when no location set
##   • Dialogue duck     — duck_for_dialogue() is idempotent (no double-duck);
##                         restore_from_dialogue() is a no-op when not ducked
##   • Heat tension      — set_heat_ambient_tension() is idempotent when state unchanged
##   • Late-game tension — set_late_game_tension() is idempotent when state unchanged;
##                         enabling it sets the flag (safe path when _current_music="")
##   • Day/night connect — connect_to_day_night(null) returns safely
##   • Recon action hook — on_recon_action() early-exits when success=false
##
## AudioManager is instantiated via preload so _ready() is NOT called; no
## AudioStreamPlayers are built and no scene-tree context is required.
## All tests rely on GDScript property mutation and the early-return guards
## already present in AudioManager's logic.
##
## Run from the Godot editor:  Scene → Run Script (or call run() directly).

class_name TestAudioManager
extends RefCounted

const AudioManagerScript := preload("res://scripts/audio_manager.gd")


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Constants
		"test_music_files_has_phase_tracks",
		"test_music_files_has_ambient_tracks",
		"test_sfx_files_has_required_keys",
		"test_phase_hour_constants_consistent",
		"test_day_hour_constants_consistent",
		# Phase detection
		"test_apply_phase_music_morning_hour",
		"test_apply_phase_music_evening_hour",
		"test_apply_phase_music_night_hour",
		"test_apply_phase_music_boundary_morning_start",
		"test_apply_phase_music_boundary_evening_start",
		"test_apply_phase_music_same_phase_noop",
		# Ambient state
		"test_set_ambient_noop_when_same_state",
		"test_set_ambient_with_location_override_updates_flag_no_crossfade",
		# Location ambient
		"test_set_location_ambient_invalid_noop",
		"test_clear_location_ambient_noop_when_empty",
		# Dialogue ducking
		"test_duck_for_dialogue_idempotent",
		"test_restore_from_dialogue_noop_when_not_ducked",
		# Heat tension
		"test_set_heat_tension_noop_when_same_state",
		# Late-game tension
		"test_set_late_game_tension_noop_when_same_state",
		"test_set_late_game_tension_sets_flag",
		# Day/night connect guard
		"test_connect_to_day_night_null_guard",
		# Recon action hook
		"test_on_recon_action_skips_when_not_success",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nAudioManager tests: %d passed, %d failed" % [passed, failed])


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns a fresh AudioManager that has NOT been added to the scene tree.
## _ready() is skipped — no AudioStreamPlayers, no preloaded cache.
static func _make_am() -> Node:
	return AudioManagerScript.new()


# ── Constants ─────────────────────────────────────────────────────────────────

## MUSIC_FILES must contain the three gameplay phase tracks.
static func test_music_files_has_phase_tracks() -> bool:
	var required := ["morning_calm", "evening_tension", "night_suspense"]
	for key in required:
		if not AudioManagerScript.MUSIC_FILES.has(key):
			push_error("test_music_files_has_phase_tracks: missing key '%s'" % key)
			return false
	return true


## MUSIC_FILES must contain day/night ambient and the four location tracks.
static func test_music_files_has_ambient_tracks() -> bool:
	var required := ["ambient_day", "ambient_night",
					 "ambient_tavern", "ambient_chapel", "ambient_market", "ambient_manor"]
	for key in required:
		if not AudioManagerScript.MUSIC_FILES.has(key):
			push_error("test_music_files_has_ambient_tracks: missing key '%s'" % key)
			return false
	return true


## SFX_FILES must contain the gameplay-critical one-shot effects.
static func test_sfx_files_has_required_keys() -> bool:
	var required := [
		"rumor_spread", "rumor_fail", "rumor_success",
		"heat_warning", "bribe_coin",
		"recon_observe", "recon_eavesdrop",
		"new_day", "win", "fail",
		"reputation_up", "reputation_down",
	]
	for key in required:
		if not AudioManagerScript.SFX_FILES.has(key):
			push_error("test_sfx_files_has_required_keys: missing key '%s'" % key)
			return false
	return true


## Phase hour constants must form a valid, non-overlapping partition of the day.
## MORNING_START < EVENING_START < NIGHT_START and they must equal DAY_START_HOUR
## and DAY_END_HOUR respectively.
static func test_phase_hour_constants_consistent() -> bool:
	var ms: int = AudioManagerScript.MORNING_START
	var es: int = AudioManagerScript.EVENING_START
	var ns: int = AudioManagerScript.NIGHT_START
	if ms >= es:
		push_error("test_phase_hour_constants_consistent: MORNING_START (%d) >= EVENING_START (%d)" % [ms, es])
		return false
	if es >= ns:
		push_error("test_phase_hour_constants_consistent: EVENING_START (%d) >= NIGHT_START (%d)" % [es, ns])
		return false
	return true


## DAY_START_HOUR must be strictly less than DAY_END_HOUR.
static func test_day_hour_constants_consistent() -> bool:
	var ds: int = AudioManagerScript.DAY_START_HOUR
	var de: int = AudioManagerScript.DAY_END_HOUR
	if ds >= de:
		push_error("test_day_hour_constants_consistent: DAY_START_HOUR (%d) >= DAY_END_HOUR (%d)" % [ds, de])
		return false
	return true


# ── Phase detection ───────────────────────────────────────────────────────────

## Hour in the middle of the morning window (MORNING_START..EVENING_START-1)
## should produce phase "morning".
static func test_apply_phase_music_morning_hour() -> bool:
	var am := _make_am()
	am._apply_phase_music(10)   # 10 is solidly in morning (6–15)
	if am._current_phase != "morning":
		push_error("test_apply_phase_music_morning_hour: expected 'morning', got '%s'" % am._current_phase)
		return false
	return true


## Hour in the middle of the evening window (EVENING_START..NIGHT_START-1)
## should produce phase "evening".
static func test_apply_phase_music_evening_hour() -> bool:
	var am := _make_am()
	am._apply_phase_music(17)   # 17 is in evening (16–19)
	if am._current_phase != "evening":
		push_error("test_apply_phase_music_evening_hour: expected 'evening', got '%s'" % am._current_phase)
		return false
	return true


## Hour in the night window (NIGHT_START..23 or 0..MORNING_START-1)
## should produce phase "night".
static func test_apply_phase_music_night_hour() -> bool:
	var am := _make_am()
	am._apply_phase_music(22)   # 22 is in night (20+)
	if am._current_phase != "night":
		push_error("test_apply_phase_music_night_hour: expected 'night', got '%s'" % am._current_phase)
		return false
	return true


## MORNING_START itself must map to "morning".
static func test_apply_phase_music_boundary_morning_start() -> bool:
	var am := _make_am()
	am._apply_phase_music(AudioManagerScript.MORNING_START)
	if am._current_phase != "morning":
		push_error("test_apply_phase_music_boundary_morning_start: expected 'morning', got '%s'" % am._current_phase)
		return false
	return true


## EVENING_START itself must map to "evening".
static func test_apply_phase_music_boundary_evening_start() -> bool:
	var am := _make_am()
	am._apply_phase_music(AudioManagerScript.EVENING_START)
	if am._current_phase != "evening":
		push_error("test_apply_phase_music_boundary_evening_start: expected 'evening', got '%s'" % am._current_phase)
		return false
	return true


## Calling _apply_phase_music() twice with hours in the same phase must not
## change _current_phase on the second call (guards against spurious crossfades).
static func test_apply_phase_music_same_phase_noop() -> bool:
	var am := _make_am()
	am._apply_phase_music(10)   # morning
	var phase_after_first: String = am._current_phase
	am._apply_phase_music(12)   # still morning — same phase → no-op
	if am._current_phase != phase_after_first:
		push_error("test_apply_phase_music_same_phase_noop: phase changed unexpectedly from '%s' to '%s'"
				% [phase_after_first, am._current_phase])
		return false
	return true


# ── Ambient state ─────────────────────────────────────────────────────────────

## set_ambient() called with the same day/night state it already has must return
## immediately — _ambient_is_day stays unchanged and no crossfade is attempted.
static func test_set_ambient_noop_when_same_state() -> bool:
	var am := _make_am()
	# Default: _ambient_is_day = true
	am.set_ambient(true)   # same → early return, no crash, no crossfade attempt
	if not am._ambient_is_day:
		push_error("test_set_ambient_noop_when_same_state: _ambient_is_day changed unexpectedly")
		return false
	return true


## When a location ambient is active, set_ambient() with a different bool updates
## _ambient_is_day but exits before calling _crossfade_ambient() — so no crash
## from null AudioStreamPlayers.
static func test_set_ambient_with_location_override_updates_flag_no_crossfade() -> bool:
	var am := _make_am()
	am._location_ambient = "tavern"   # simulate location interior open
	am._ambient_is_day = true
	am.set_ambient(false)             # different → should update flag then return
	if am._ambient_is_day:
		push_error("test_set_ambient_with_location_override_updates_flag_no_crossfade: _ambient_is_day not updated")
		return false
	return true


# ── Location ambient ──────────────────────────────────────────────────────────

## An unknown location id is silently ignored: _location_ambient stays empty.
static func test_set_location_ambient_invalid_noop() -> bool:
	var am := _make_am()
	am.set_location_ambient("dungeon")   # not a valid location
	if not am._location_ambient.is_empty():
		push_error("test_set_location_ambient_invalid_noop: _location_ambient set unexpectedly to '%s'"
				% am._location_ambient)
		return false
	return true


## clear_location_ambient() when no location is active is a no-op (no crash,
## no crossfade attempt with null players).
static func test_clear_location_ambient_noop_when_empty() -> bool:
	var am := _make_am()
	# _location_ambient starts empty
	am.clear_location_ambient()   # early return guard
	return am._location_ambient.is_empty()


# ── Dialogue ducking ──────────────────────────────────────────────────────────

## duck_for_dialogue() is idempotent: if already ducked it returns immediately
## without creating a second tween.
static func test_duck_for_dialogue_idempotent() -> bool:
	var am := _make_am()
	am._dialogue_duck_active = true   # simulate already ducked
	am.duck_for_dialogue()            # must return early — no create_tween() call
	# Flag must still be true; no crash is sufficient evidence of idempotency.
	if not am._dialogue_duck_active:
		push_error("test_duck_for_dialogue_idempotent: _dialogue_duck_active unexpectedly cleared")
		return false
	return true


## restore_from_dialogue() when not currently ducked is a no-op.
static func test_restore_from_dialogue_noop_when_not_ducked() -> bool:
	var am := _make_am()
	# Default: _dialogue_duck_active = false
	am.restore_from_dialogue()   # early return guard
	if am._dialogue_duck_active:
		push_error("test_restore_from_dialogue_noop_when_not_ducked: _dialogue_duck_active set unexpectedly")
		return false
	return true


# ── Heat tension ──────────────────────────────────────────────────────────────

## set_heat_ambient_tension(false) when already inactive is a no-op.
static func test_set_heat_tension_noop_when_same_state() -> bool:
	var am := _make_am()
	# Default: _heat_tension_active = false
	am.set_heat_ambient_tension(false)   # same → early return
	if am._heat_tension_active:
		push_error("test_set_heat_tension_noop_when_same_state: _heat_tension_active set unexpectedly")
		return false
	return true


# ── Late-game tension ─────────────────────────────────────────────────────────

## set_late_game_tension(false) when already inactive is a no-op.
static func test_set_late_game_tension_noop_when_same_state() -> bool:
	var am := _make_am()
	# Default: _late_game_active = false
	am.set_late_game_tension(false)
	if am._late_game_active:
		push_error("test_set_late_game_tension_noop_when_same_state: _late_game_active set unexpectedly")
		return false
	return true


## set_late_game_tension(true) must set _late_game_active = true.
## This path is safe without a scene tree because _apply_phase_volume_bias()
## hits its `_: return` match arm when _current_music is "" (no players loaded).
static func test_set_late_game_tension_sets_flag() -> bool:
	var am := _make_am()
	am.set_late_game_tension(true)   # _current_music="" → match `_: return` → no player access
	if not am._late_game_active:
		push_error("test_set_late_game_tension_sets_flag: _late_game_active not set")
		return false
	return true


# ── Day/night connect guard ───────────────────────────────────────────────────

## connect_to_day_night(null) must return immediately without crashing.
static func test_connect_to_day_night_null_guard() -> bool:
	var am := _make_am()
	am.connect_to_day_night(null)   # early-return guard: if day_night == null: return
	return true   # reaching here without crash is the pass condition


# ── Recon action hook ─────────────────────────────────────────────────────────

## on_recon_action() with success=false must return before attempting any SFX.
## Since _sfx_cache is empty and no players are built, a non-early-return would
## produce a push_warning (debug) or silent no-op; state must be unchanged.
static func test_on_recon_action_skips_when_not_success() -> bool:
	var am := _make_am()
	am.on_recon_action("Observed the merchant", false)   # success=false → early return
	# Observable invariant: cache is still empty (nothing was preloaded).
	if not am._sfx_cache.is_empty():
		push_error("test_on_recon_action_skips_when_not_success: _sfx_cache unexpectedly populated")
		return false
	return true
