## test_settings_menu.gd — Unit tests for settings_menu.gd (SPA-1015).
##
## Covers:
##   • Color palette constants: C_OVERLAY, C_PANEL_BG, C_BORDER, C_TITLE,
##                              C_LABEL, C_VALUE, C_BTN_NORMAL, C_BTN_HOVER,
##                              C_BTN_BORDER
##   • Initial widget refs: all button and slider member vars are null before
##                          _ready() / _build_ui() run
##   • _close(): sets visible = false
##   • _close(): emits the closed signal
##
## settings_menu.gd extends CanvasLayer. _ready() is NOT called (node not
## added to the scene tree), so all nodes built by _build_ui() remain null.
## Only constants, initial state, and the close behaviour are exercised.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSettingsMenu
extends RefCounted

const SettingsMenuScript := preload("res://scripts/settings_menu.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_sm() -> Node:
	return SettingsMenuScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Color constants
		"test_c_overlay_colour",
		"test_c_panel_bg_colour",
		"test_c_border_colour",
		"test_c_title_colour",
		"test_c_label_colour",
		"test_c_value_colour",
		"test_c_btn_normal_colour",
		"test_c_btn_hover_colour",
		"test_c_btn_border_colour",
		# Initial widget refs (all null before _ready)
		"test_initial_btn_resolution_null",
		"test_initial_btn_window_mode_null",
		"test_initial_btn_ui_scale_null",
		"test_initial_btn_window_scale_null",
		"test_initial_btn_text_size_null",
		"test_initial_btn_game_speed_null",
		"test_initial_slider_master_null",
		"test_initial_slider_music_null",
		"test_initial_slider_ambient_null",
		"test_initial_slider_sfx_null",
		"test_initial_lbl_master_val_null",
		"test_initial_lbl_music_val_null",
		"test_initial_lbl_ambient_val_null",
		"test_initial_lbl_sfx_val_null",
		"test_initial_btn_controls_null",
		# _close() behaviour
		"test_close_sets_visible_false",
		"test_close_emits_closed_signal",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSettingsMenu tests: %d passed, %d failed" % [passed, failed])


# ── Color constants ───────────────────────────────────────────────────────────

static func test_c_overlay_colour() -> bool:
	var sm := _make_sm()
	return sm.C_OVERLAY == Color(0.0, 0.0, 0.0, 0.55)


static func test_c_panel_bg_colour() -> bool:
	var sm := _make_sm()
	return sm.C_PANEL_BG == Color(0.12, 0.08, 0.05, 1.0)


static func test_c_border_colour() -> bool:
	var sm := _make_sm()
	return sm.C_BORDER == Color(0.65, 0.55, 0.35, 1.0)


static func test_c_title_colour() -> bool:
	var sm := _make_sm()
	return sm.C_TITLE == Color(0.92, 0.78, 0.12, 1.0)


static func test_c_label_colour() -> bool:
	var sm := _make_sm()
	return sm.C_LABEL == Color(0.80, 0.75, 0.60, 1.0)


static func test_c_value_colour() -> bool:
	var sm := _make_sm()
	return sm.C_VALUE == Color(0.95, 0.91, 0.80, 1.0)


static func test_c_btn_normal_colour() -> bool:
	var sm := _make_sm()
	return sm.C_BTN_NORMAL == Color(0.30, 0.18, 0.07, 1.0)


static func test_c_btn_hover_colour() -> bool:
	var sm := _make_sm()
	return sm.C_BTN_HOVER == Color(0.50, 0.30, 0.10, 1.0)


static func test_c_btn_border_colour() -> bool:
	var sm := _make_sm()
	return sm.C_BTN_BORDER == Color(0.55, 0.38, 0.18, 1.0)


# ── Initial widget refs (null until _build_ui runs inside _ready) ─────────────

static func test_initial_btn_resolution_null() -> bool:
	var sm := _make_sm()
	return sm._btn_resolution == null


static func test_initial_btn_window_mode_null() -> bool:
	var sm := _make_sm()
	return sm._btn_window_mode == null


static func test_initial_btn_ui_scale_null() -> bool:
	var sm := _make_sm()
	return sm._btn_ui_scale == null


static func test_initial_btn_window_scale_null() -> bool:
	var sm := _make_sm()
	return sm._btn_window_scale == null


static func test_initial_btn_text_size_null() -> bool:
	var sm := _make_sm()
	return sm._btn_text_size == null


static func test_initial_btn_game_speed_null() -> bool:
	var sm := _make_sm()
	return sm._btn_game_speed == null


static func test_initial_slider_master_null() -> bool:
	var sm := _make_sm()
	return sm._slider_master == null


static func test_initial_slider_music_null() -> bool:
	var sm := _make_sm()
	return sm._slider_music == null


static func test_initial_slider_ambient_null() -> bool:
	var sm := _make_sm()
	return sm._slider_ambient == null


static func test_initial_slider_sfx_null() -> bool:
	var sm := _make_sm()
	return sm._slider_sfx == null


static func test_initial_lbl_master_val_null() -> bool:
	var sm := _make_sm()
	return sm._lbl_master_val == null


static func test_initial_lbl_music_val_null() -> bool:
	var sm := _make_sm()
	return sm._lbl_music_val == null


static func test_initial_lbl_ambient_val_null() -> bool:
	var sm := _make_sm()
	return sm._lbl_ambient_val == null


static func test_initial_lbl_sfx_val_null() -> bool:
	var sm := _make_sm()
	return sm._lbl_sfx_val == null


static func test_initial_btn_controls_null() -> bool:
	var sm := _make_sm()
	return sm._btn_controls == null


# ── _close() behaviour ────────────────────────────────────────────────────────

## _close() must set visible = false.  The node starts visible = false by
## default; force it to true first so the transition is observable.
static func test_close_sets_visible_false() -> bool:
	var sm := _make_sm()
	sm.visible = true
	sm._close()
	return sm.visible == false


## _close() must emit the closed signal so callers (pause_menu) can react.
static func test_close_emits_closed_signal() -> bool:
	var sm := _make_sm()
	var fired := false
	sm.closed.connect(func() -> void: fired = true)
	sm._close()
	return fired
