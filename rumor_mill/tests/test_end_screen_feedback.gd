## test_end_screen_feedback.gd — Unit tests for end_screen_feedback.gd (SPA-1026).
##
## Covers:
##   • FEEDBACK_PRESETS: 4-item list with expected strings
##   • Dimension constants: FEEDBACK_PANEL_W, FEEDBACK_PANEL_H, FEEDBACK_CHAR_LIMIT
##   • Color palette constants
##   • Initial instance state: _parent, _btn_again, _feedback_selected_preset,
##     _feedback_preset_btns, overlay node refs
##   • setup(): stores parent and btn_again refs
##
## EndScreenFeedback extends RefCounted — safe to instantiate without scene tree.
## show_prompt() requires a live CanvasLayer in scene and is not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestEndScreenFeedback
extends RefCounted

const EndScreenFeedbackScript := preload("res://scripts/end_screen_feedback.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_esf() -> RefCounted:
	return EndScreenFeedbackScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# FEEDBACK_PRESETS
		"test_feedback_presets_count",
		"test_feedback_presets_first_entry",
		"test_feedback_presets_last_entry",
		# Dimension constants
		"test_feedback_panel_w",
		"test_feedback_panel_h",
		"test_feedback_char_limit",
		# Color constants
		"test_c_win_colour",
		"test_c_panel_bg_colour",
		"test_c_panel_border_colour",
		"test_c_preset_normal_colour",
		"test_c_preset_selected_colour",
		# Initial state
		"test_initial_parent_null",
		"test_initial_btn_again_null",
		"test_initial_selected_preset_minus_one",
		"test_initial_preset_btns_empty",
		"test_initial_feedback_backdrop_null",
		"test_initial_feedback_panel_null",
		"test_initial_feedback_text_edit_null",
		"test_initial_feedback_char_lbl_null",
		# setup()
		"test_setup_stores_parent",
		"test_setup_stores_btn_again",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nEndScreenFeedback tests: %d passed, %d failed" % [passed, failed])


# ── FEEDBACK_PRESETS ──────────────────────────────────────────────────────────

static func test_feedback_presets_count() -> bool:
	var esf := _make_esf()
	if esf.FEEDBACK_PRESETS.size() != 4:
		push_error("test_feedback_presets_count: expected 4, got %d" % esf.FEEDBACK_PRESETS.size())
		return false
	return true


static func test_feedback_presets_first_entry() -> bool:
	var esf := _make_esf()
	return esf.FEEDBACK_PRESETS[0] == "Understanding the social graph"


static func test_feedback_presets_last_entry() -> bool:
	var esf := _make_esf()
	return esf.FEEDBACK_PRESETS[3] == "Knowing which NPCs to target"


# ── Dimension constants ───────────────────────────────────────────────────────

static func test_feedback_panel_w() -> bool:
	return _make_esf().FEEDBACK_PANEL_W == 500


static func test_feedback_panel_h() -> bool:
	return _make_esf().FEEDBACK_PANEL_H == 360


static func test_feedback_char_limit() -> bool:
	return _make_esf().FEEDBACK_CHAR_LIMIT == 200


# ── Color constants ───────────────────────────────────────────────────────────

static func test_c_win_colour() -> bool:
	return _make_esf().C_WIN == Color(0.92, 0.78, 0.12, 1.0)


static func test_c_panel_bg_colour() -> bool:
	return _make_esf().C_PANEL_BG == Color(0.13, 0.09, 0.07, 1.0)


static func test_c_panel_border_colour() -> bool:
	return _make_esf().C_PANEL_BORDER == Color(0.55, 0.38, 0.18, 1.0)


static func test_c_preset_normal_colour() -> bool:
	return _make_esf().C_PRESET_NORMAL == Color(0.22, 0.15, 0.10, 1.0)


static func test_c_preset_selected_colour() -> bool:
	return _make_esf().C_PRESET_SELECTED == Color(0.55, 0.38, 0.18, 1.0)


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_parent_null() -> bool:
	return _make_esf()._parent == null


static func test_initial_btn_again_null() -> bool:
	return _make_esf()._btn_again == null


static func test_initial_selected_preset_minus_one() -> bool:
	return _make_esf()._feedback_selected_preset == -1


static func test_initial_preset_btns_empty() -> bool:
	return _make_esf()._feedback_preset_btns.is_empty()


static func test_initial_feedback_backdrop_null() -> bool:
	return _make_esf()._feedback_backdrop == null


static func test_initial_feedback_panel_null() -> bool:
	return _make_esf()._feedback_panel == null


static func test_initial_feedback_text_edit_null() -> bool:
	return _make_esf()._feedback_text_edit == null


static func test_initial_feedback_char_lbl_null() -> bool:
	return _make_esf()._feedback_char_lbl == null


# ── setup() ───────────────────────────────────────────────────────────────────

static func test_setup_stores_parent() -> bool:
	var esf := _make_esf()
	var layer := CanvasLayer.new()
	esf.setup(layer, null)
	var ok := esf._parent == layer
	layer.free()
	return ok


static func test_setup_stores_btn_again() -> bool:
	var esf := _make_esf()
	var btn := Button.new()
	esf.setup(null, btn)
	var ok := esf._btn_again == btn
	btn.free()
	return ok
