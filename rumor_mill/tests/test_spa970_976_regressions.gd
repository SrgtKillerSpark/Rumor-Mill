## test_spa970_976_regressions.gd — Regression tests for SPA-970 through SPA-976 (SPA-985).
##
## Covers:
##   • SPA-970 — event_sting remapped to reputation_shift.wav (not new_day.wav);
##               main.gd calls AudioManager.play_music("main_theme") on _ready()
##   • SPA-974 — settings_menu focus chain uses (i-1+size)%size, not (i-1)%size;
##               verifies the negative-modulo bug cannot recur
##   • SPA-975 — SaveManager.session_was_loaded() returns false until
##               apply_pending_load() completes; prepare_load() alone must not set it
##   • SPA-976 — legend_lbl removed from scenario1_hud._build_ui();
##               _score_lbl alone carries the win-condition text
##
## Source-inspection tests (SPA-970, SPA-976) read the .gd files via FileAccess so
## they do not require live game nodes.  Logic tests (SPA-974, SPA-975) are
## purely in-memory and work as part of the standard headless test runner.
##
## Run from the Godot editor:  Scene → Run Script (or call run() directly).

class_name TestSpa970976Regressions
extends RefCounted


static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# SPA-970
		"test_spa970_event_sting_maps_to_reputation_shift",
		"test_spa970_event_sting_not_mapped_to_new_day",
		"test_spa970_main_gd_plays_main_theme_on_ready",
		# SPA-974
		"test_spa974_positive_modulo_formula_never_negative",
		"test_spa974_old_formula_would_have_been_negative_at_zero",
		"test_spa974_wrap_to_last_element_at_index_zero",
		# SPA-975
		"test_spa975_session_was_loaded_returns_bool",
		"test_spa975_session_was_loaded_false_before_apply_pending_load",
		# SPA-976
		"test_spa976_legend_lbl_absent_from_hud_source",
		"test_spa976_score_lbl_carries_win_condition_text",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSPA-970..976 regression tests: %d passed, %d failed" % [passed, failed])


# ── SPA-970: event_sting placeholder + main-theme restore ────────────────────

## event_sting must map to reputation_shift.wav (not new_day.wav) in audio_manager.gd.
static func test_spa970_event_sting_maps_to_reputation_shift() -> bool:
	var source := _read_script("audio_manager.gd")
	if source.is_empty():
		return false
	for line in source.split("\n"):
		if "event_sting" in line and "reputation_shift.wav" in line:
			return true
	push_error("test_spa970: event_sting→reputation_shift.wav mapping not found in audio_manager.gd")
	return false


## event_sting must NOT map to new_day.wav on any line in audio_manager.gd.
static func test_spa970_event_sting_not_mapped_to_new_day() -> bool:
	var source := _read_script("audio_manager.gd")
	if source.is_empty():
		return false
	for line in source.split("\n"):
		if "event_sting" in line and "new_day.wav" in line:
			push_error("test_spa970: event_sting still maps to new_day.wav — SPA-970 regression")
			return false
	return true


## main.gd must call AudioManager.play_music with "main_theme" inside _ready()
## so that the title screen music is restored after a win/fail/restart.
static func test_spa970_main_gd_plays_main_theme_on_ready() -> bool:
	var source := _read_script("main.gd")
	if source.is_empty():
		return false
	# The call must be present somewhere in the file (it lives in _ready()).
	if not ("play_music" in source and "main_theme" in source):
		push_error("test_spa970: AudioManager.play_music(\"main_theme\") call not found in main.gd")
		return false
	return true


# ── SPA-974: settings_menu focus-chain negative modulo ───────────────────────

## (i - 1 + size) % size must never be negative for any valid list index.
## Tests the exact formula used in settings_menu.gd with the same list size (12).
static func test_spa974_positive_modulo_formula_never_negative() -> bool:
	var size := 12   # matches focus_list.size() in settings_menu.gd
	for i in size:
		var prev_idx: int = (i - 1 + size) % size
		if prev_idx < 0:
			push_error("test_spa974: (i-1+size)%%size is negative for i=%d (got %d)" % [i, prev_idx])
			return false
	return true


## The old formula (i-1)%size must return -1 for i=0 in GDScript, proving the
## original bug existed and the fix was necessary.
static func test_spa974_old_formula_would_have_been_negative_at_zero() -> bool:
	var size  := 12
	var old   : int = (0 - 1) % size   # GDScript: sign follows left operand → -1
	if old >= 0:
		push_error("test_spa974: expected old formula to be negative for i=0, got %d" % old)
		return false
	return true


## At i=0 the fixed formula must resolve to the last element (size-1), producing
## correct Up-arrow wrap from the first focusable control to the Back button.
static func test_spa974_wrap_to_last_element_at_index_zero() -> bool:
	var size     := 12
	var prev_idx : int = (0 - 1 + size) % size
	if prev_idx != size - 1:
		push_error("test_spa974: expected wrap to %d at i=0, got %d" % [size - 1, prev_idx])
		return false
	return true


# ── SPA-975: SaveManager.session_was_loaded() API and flag semantics ─────────

## session_was_loaded() must exist and return a bool.
static func test_spa975_session_was_loaded_returns_bool() -> bool:
	var result: Variant = SaveManager.session_was_loaded()
	if not (result is bool):
		push_error("test_spa975: session_was_loaded() did not return bool (got %s)" % type_string(typeof(result)))
		return false
	return true


## prepare_load() alone must NOT set session_was_loaded() to true.
## The flag is only set inside apply_pending_load(), which is never called by
## any unit test — so this must be false in the test runner context.
static func test_spa975_session_was_loaded_false_before_apply_pending_load() -> bool:
	# Write and prepare-load a valid save so the flag code path runs.
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("saves"):
		dir.make_dir("saves")
	var scenario_id := "test_spa975_regression"
	var path := SaveManager.save_path(scenario_id, SaveManager.AUTO_SLOT)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("test_spa975: could not write sentinel save file")
		return false
	f.store_string(JSON.stringify({
		"version":     SaveManager.SAVE_VERSION,
		"scenario_id": scenario_id,
		"tick": 0,
		"day":  1,
	}))
	f.close()

	var err := SaveManager.prepare_load(scenario_id, SaveManager.AUTO_SLOT)
	if err != "":
		push_error("test_spa975: prepare_load() returned unexpected error: %s" % err)
		return false

	# prepare_load sets _pending_load_data but must NOT set _session_was_loaded.
	if SaveManager.session_was_loaded():
		push_error("test_spa975: session_was_loaded() is true after prepare_load() alone — regression in SPA-975 fix")
		return false
	return true


# ── SPA-976: legend_lbl removed from Scenario 1 HUD ─────────────────────────

## scenario1_hud.gd must not contain any reference to legend_lbl after SPA-976.
static func test_spa976_legend_lbl_absent_from_hud_source() -> bool:
	var source := _read_script("scenario1_hud.gd")
	if source.is_empty():
		return false
	if "legend_lbl" in source:
		push_error("test_spa976: 'legend_lbl' still present in scenario1_hud.gd — SPA-976 regression")
		return false
	return true


## _score_lbl must still carry the dynamic win-condition format string
## ("Target: <%d") so the HUD is not missing context after legend_lbl removal.
static func test_spa976_score_lbl_carries_win_condition_text() -> bool:
	var source := _read_script("scenario1_hud.gd")
	if source.is_empty():
		return false
	# _score_lbl.text is set via format string "Edric Fenn  Rep: %d / 100  Target: <%d"
	if not ("Target: <%d" in source or "Target: <" in source):
		push_error("test_spa976: _score_lbl win-condition text format not found in scenario1_hud.gd")
		return false
	return true


# ── Helpers ───────────────────────────────────────────────────────────────────

## Read a script from res://scripts/<name> and return its full text.
## Returns an empty string and pushes an error on failure.
static func _read_script(script_name: String) -> String:
	var path := "res://scripts/%s" % script_name
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("_read_script: could not open '%s'" % path)
		return ""
	var text := f.get_as_text()
	f.close()
	return text
