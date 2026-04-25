## test_main_menu_settings_panel.gd — Unit tests for main_menu_settings_panel.gd (SPA-1042).
##
## Covers:
##   • Palette constants
##   • Initial state: panel null, all label/button refs null
##
## Run from the Godot editor: Scene → Run Script.

class_name TestMainMenuSettingsPanel
extends RefCounted


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_sp() -> MainMenuSettingsPanel:
	return MainMenuSettingsPanel.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_panel_bg_dark_brown",
		"test_c_panel_border_amber",
		"test_c_btn_text_near_white",
		# Initial state
		"test_initial_panel_null",
		"test_initial_lbl_master_val_null",
		"test_initial_lbl_music_val_null",
		"test_initial_lbl_ambient_val_null",
		"test_initial_lbl_sfx_val_null",
		"test_initial_lbl_speed_val_null",
		"test_initial_btn_resolution_null",
		"test_initial_btn_window_mode_null",
		"test_initial_btn_window_scale_null",
		"test_initial_btn_ui_scale_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nMainMenuSettingsPanel tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_panel_bg_dark_brown() -> bool:
	var sp := _make_sp()
	var ok := sp.C_PANEL_BG.r > sp.C_PANEL_BG.b and sp.C_PANEL_BG.r < 0.25
	sp.free()
	return ok


static func test_c_panel_border_amber() -> bool:
	var sp := _make_sp()
	# amber-brown border: moderate r, low-moderate g, low b
	var ok := sp.C_PANEL_BORDER.r > 0.45 and sp.C_PANEL_BORDER.b < 0.25
	sp.free()
	return ok


static func test_c_btn_text_near_white() -> bool:
	var sp := _make_sp()
	var ok := sp.C_BTN_TEXT.r > 0.90 and sp.C_BTN_TEXT.g > 0.85 and sp.C_BTN_TEXT.b > 0.75
	sp.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_panel_null() -> bool:
	var sp := _make_sp()
	var ok := sp.panel == null
	sp.free()
	return ok


static func test_initial_lbl_master_val_null() -> bool:
	var sp := _make_sp()
	var ok := sp._lbl_master_val == null
	sp.free()
	return ok


static func test_initial_lbl_music_val_null() -> bool:
	var sp := _make_sp()
	var ok := sp._lbl_music_val == null
	sp.free()
	return ok


static func test_initial_lbl_ambient_val_null() -> bool:
	var sp := _make_sp()
	var ok := sp._lbl_ambient_val == null
	sp.free()
	return ok


static func test_initial_lbl_sfx_val_null() -> bool:
	var sp := _make_sp()
	var ok := sp._lbl_sfx_val == null
	sp.free()
	return ok


static func test_initial_lbl_speed_val_null() -> bool:
	var sp := _make_sp()
	var ok := sp._lbl_speed_val == null
	sp.free()
	return ok


static func test_initial_btn_resolution_null() -> bool:
	var sp := _make_sp()
	var ok := sp._btn_resolution == null
	sp.free()
	return ok


static func test_initial_btn_window_mode_null() -> bool:
	var sp := _make_sp()
	var ok := sp._btn_window_mode == null
	sp.free()
	return ok


static func test_initial_btn_window_scale_null() -> bool:
	var sp := _make_sp()
	var ok := sp._btn_window_scale == null
	sp.free()
	return ok


static func test_initial_btn_ui_scale_null() -> bool:
	var sp := _make_sp()
	var ok := sp._btn_ui_scale == null
	sp.free()
	return ok
