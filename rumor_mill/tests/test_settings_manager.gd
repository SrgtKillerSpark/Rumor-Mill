## test_settings_manager.gd — Unit tests for SettingsManager constants and
## pure-logic methods (SPA-1065).
##
## Covers:
##   • DEFAULT_* volume/speed/mode constants
##   • UI_SCALE_PRESETS (count, index-2 == 1.0)
##   • TEXT_SIZE_LABELS (count == 3, index-1 == "Medium")
##   • TEXT_SIZE_SCALE_INDICES maps Small/Medium/Large to scale preset indices
##   • GAME_SPEED_LABELS (count == 3, index-1 == "1×")
##   • GAME_SPEED_PRESETS (count == 3, 1× == 1.0)
##   • WINDOW_* mode constants
##   • BASE_RESOLUTIONS — 4 entries, first is 1280×720
##   • _to_db() — 0.0 → -80, 100.0 → 0 dB
##   • get_ui_scale_label() — default instance returns "100%"
##   • get_text_size_label() — default text_size_index=1 → "Medium"
##   • get_game_speed_label() — default game_speed_index=1 → "1×"
##   • get_window_mode_label() — default window_mode=0 → "Windowed"
##   • set_text_size_index() — syncs ui_scale_index and ui_scale
##
## Strategy: SettingsManager extends Node. _ready() calls DisplayServer and
## AudioManager — .new() does NOT call _ready(), so constants and pure methods
## are safe to test without a scene tree.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSettingsManager
extends RefCounted

const SettingsManagerScript := preload("res://scripts/settings_manager.gd")


static func _make_sm() -> Node:
	return SettingsManagerScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── DEFAULT constants ──
		"test_default_master_vol",
		"test_default_music_vol",
		"test_default_ambient_vol",
		"test_default_sfx_vol",
		"test_default_game_speed",
		"test_default_analytics_enabled",
		"test_default_window_mode",
		"test_default_ui_scale",

		# ── UI_SCALE_PRESETS ──
		"test_ui_scale_presets_count",
		"test_ui_scale_presets_index2_is_1",

		# ── TEXT_SIZE_LABELS ──
		"test_text_size_labels_count",
		"test_text_size_labels_index1_medium",

		# ── TEXT_SIZE_SCALE_INDICES ──
		"test_text_size_scale_indices_count",

		# ── GAME_SPEED_LABELS / PRESETS ──
		"test_game_speed_labels_count",
		"test_game_speed_labels_index1_1x",
		"test_game_speed_presets_count",
		"test_game_speed_presets_normal_is_1",

		# ── WINDOW_* constants ──
		"test_window_windowed_is_0",
		"test_window_borderless_is_1",
		"test_window_fullscreen_is_2",

		# ── BASE_RESOLUTIONS ──
		"test_base_resolutions_count",
		"test_base_resolutions_first_is_720p",

		# ── _to_db() ──
		"test_to_db_zero_returns_minus80",
		"test_to_db_100_returns_0db",

		# ── label / index helpers ──
		"test_get_ui_scale_label_default",
		"test_get_text_size_label_default",
		"test_get_game_speed_label_default",
		"test_get_window_mode_label_windowed",

		# ── set_text_size_index() ──
		"test_set_text_size_index_small_syncs_scale",
		"test_set_text_size_index_large_syncs_scale",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			print("  FAIL  %s" % method_name)
			failed += 1

	print("\n  %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# DEFAULT constants
# ══════════════════════════════════════════════════════════════════════════════

func test_default_master_vol() -> bool:
	return absf(SettingsManagerScript.DEFAULT_MASTER_VOL - 100.0) < 0.001


func test_default_music_vol() -> bool:
	return absf(SettingsManagerScript.DEFAULT_MUSIC_VOL - 80.0) < 0.001


func test_default_ambient_vol() -> bool:
	return absf(SettingsManagerScript.DEFAULT_AMBIENT_VOL - 60.0) < 0.001


func test_default_sfx_vol() -> bool:
	return absf(SettingsManagerScript.DEFAULT_SFX_VOL - 80.0) < 0.001


func test_default_game_speed() -> bool:
	return absf(SettingsManagerScript.DEFAULT_GAME_SPEED - 1.0) < 0.001


func test_default_analytics_enabled() -> bool:
	return SettingsManagerScript.DEFAULT_ANALYTICS_ENABLED == true


func test_default_window_mode() -> bool:
	return SettingsManagerScript.DEFAULT_WINDOW_MODE == 0


func test_default_ui_scale() -> bool:
	return absf(SettingsManagerScript.DEFAULT_UI_SCALE - 1.0) < 0.001


# ══════════════════════════════════════════════════════════════════════════════
# UI_SCALE_PRESETS
# ══════════════════════════════════════════════════════════════════════════════

func test_ui_scale_presets_count() -> bool:
	return SettingsManagerScript.UI_SCALE_PRESETS.size() == 6


func test_ui_scale_presets_index2_is_1() -> bool:
	return absf(SettingsManagerScript.UI_SCALE_PRESETS[2] - 1.0) < 0.001


# ══════════════════════════════════════════════════════════════════════════════
# TEXT_SIZE_LABELS
# ══════════════════════════════════════════════════════════════════════════════

func test_text_size_labels_count() -> bool:
	return SettingsManagerScript.TEXT_SIZE_LABELS.size() == 3


func test_text_size_labels_index1_medium() -> bool:
	return SettingsManagerScript.TEXT_SIZE_LABELS[1] == "Medium"


func test_text_size_scale_indices_count() -> bool:
	return SettingsManagerScript.TEXT_SIZE_SCALE_INDICES.size() == 3


# ══════════════════════════════════════════════════════════════════════════════
# GAME_SPEED_LABELS / PRESETS
# ══════════════════════════════════════════════════════════════════════════════

func test_game_speed_labels_count() -> bool:
	return SettingsManagerScript.GAME_SPEED_LABELS.size() == 3


func test_game_speed_labels_index1_1x() -> bool:
	return SettingsManagerScript.GAME_SPEED_LABELS[1] == "1×"


func test_game_speed_presets_count() -> bool:
	return SettingsManagerScript.GAME_SPEED_PRESETS.size() == 3


func test_game_speed_presets_normal_is_1() -> bool:
	return absf(SettingsManagerScript.GAME_SPEED_PRESETS[1] - 1.0) < 0.001


# ══════════════════════════════════════════════════════════════════════════════
# WINDOW_* constants
# ══════════════════════════════════════════════════════════════════════════════

func test_window_windowed_is_0() -> bool:
	return SettingsManagerScript.WINDOW_WINDOWED == 0


func test_window_borderless_is_1() -> bool:
	return SettingsManagerScript.WINDOW_BORDERLESS == 1


func test_window_fullscreen_is_2() -> bool:
	return SettingsManagerScript.WINDOW_FULLSCREEN == 2


# ══════════════════════════════════════════════════════════════════════════════
# BASE_RESOLUTIONS
# ══════════════════════════════════════════════════════════════════════════════

func test_base_resolutions_count() -> bool:
	return SettingsManagerScript.BASE_RESOLUTIONS.size() == 4


func test_base_resolutions_first_is_720p() -> bool:
	return SettingsManagerScript.BASE_RESOLUTIONS[0] == Vector2i(1280, 720)


# ══════════════════════════════════════════════════════════════════════════════
# _to_db()
# ══════════════════════════════════════════════════════════════════════════════

func test_to_db_zero_returns_minus80() -> bool:
	var sm := _make_sm()
	var result := sm._to_db(0.0)
	sm.free()
	return absf(result - (-80.0)) < 0.001


func test_to_db_100_returns_0db() -> bool:
	var sm := _make_sm()
	# 100/100 = 1.0 linear → linear_to_db(1.0) == 0
	var result := sm._to_db(100.0)
	sm.free()
	return absf(result) < 0.001


# ══════════════════════════════════════════════════════════════════════════════
# Label helpers (default instance — no _ready() called)
# ══════════════════════════════════════════════════════════════════════════════

func test_get_ui_scale_label_default() -> bool:
	var sm := _make_sm()
	# ui_scale defaults to DEFAULT_UI_SCALE (1.0) → "100%"
	var label := sm.get_ui_scale_label()
	sm.free()
	return label == "100%"


func test_get_text_size_label_default() -> bool:
	var sm := _make_sm()
	# text_size_index defaults to 1 → TEXT_SIZE_LABELS[1] == "Medium"
	var label := sm.get_text_size_label()
	sm.free()
	return label == "Medium"


func test_get_game_speed_label_default() -> bool:
	var sm := _make_sm()
	# game_speed_index defaults to 1 → GAME_SPEED_LABELS[1] == "1×"
	var label := sm.get_game_speed_label()
	sm.free()
	return label == "1×"


func test_get_window_mode_label_windowed() -> bool:
	var sm := _make_sm()
	# window_mode defaults to 0 (WINDOW_WINDOWED) → "Windowed"
	var label := sm.get_window_mode_label()
	sm.free()
	return label == "Windowed"


# ══════════════════════════════════════════════════════════════════════════════
# set_text_size_index()
# ══════════════════════════════════════════════════════════════════════════════

func test_set_text_size_index_small_syncs_scale() -> bool:
	var sm := _make_sm()
	sm.set_text_size_index(0)  # Small → UI_SCALE_PRESETS[0] = 0.75
	var ok := sm.text_size_index == 0 \
		and sm.ui_scale_index == SettingsManagerScript.TEXT_SIZE_SCALE_INDICES[0] \
		and absf(sm.ui_scale - SettingsManagerScript.UI_SCALE_PRESETS[sm.ui_scale_index]) < 0.001
	sm.free()
	return ok


func test_set_text_size_index_large_syncs_scale() -> bool:
	var sm := _make_sm()
	sm.set_text_size_index(2)  # Large → UI_SCALE_PRESETS[TEXT_SIZE_SCALE_INDICES[2]] = 1.25
	var expected_idx: int = SettingsManagerScript.TEXT_SIZE_SCALE_INDICES[2]
	var expected_scale: float = SettingsManagerScript.UI_SCALE_PRESETS[expected_idx]
	var ok := sm.text_size_index == 2 and absf(sm.ui_scale - expected_scale) < 0.001
	sm.free()
	return ok
