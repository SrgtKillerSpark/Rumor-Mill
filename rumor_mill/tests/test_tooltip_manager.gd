## test_tooltip_manager.gd — Unit tests for tooltip_manager.gd (SPA-1042).
##
## Covers:
##   • Palette constants: C_BG, C_BORDER, C_TITLE, C_BODY
##   • Layout constants: FADE_IN_SEC, FADE_OUT_SEC, PANEL_W, OFFSET
##   • Initial state: refs null, _visible_flag=false, _data empty
##
## NOTE: _ready() calls _load_data() (file I/O) and _build_panel() (adds nodes).
## We test without calling _ready() to avoid scene-tree dependencies.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestTooltipManager
extends RefCounted

const TooltipManagerScript := preload("res://scripts/tooltip_manager.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_tm() -> CanvasLayer:
	return TooltipManagerScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_bg_dark",
		"test_c_border_amber",
		"test_c_title_gold",
		"test_c_body_parchment",
		# Layout constants
		"test_fade_in_sec",
		"test_fade_out_sec",
		"test_panel_w",
		"test_offset_x_positive",
		"test_offset_y_negative",
		# Initial state
		"test_initial_panel_null",
		"test_initial_title_lbl_null",
		"test_initial_body_lbl_null",
		"test_initial_visible_flag_false",
		"test_initial_data_empty",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nTooltipManager tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_bg_dark() -> bool:
	var tm := _make_tm()
	var ok := tm.C_BG.r < 0.15 and tm.C_BG.a > 0.88
	tm.free()
	return ok


static func test_c_border_amber() -> bool:
	var tm := _make_tm()
	var ok := tm.C_BORDER.r > 0.45 and tm.C_BORDER.b < 0.25
	tm.free()
	return ok


static func test_c_title_gold() -> bool:
	var tm := _make_tm()
	var ok := tm.C_TITLE.r > 0.85 and tm.C_TITLE.g > 0.70 and tm.C_TITLE.b < 0.20
	tm.free()
	return ok


static func test_c_body_parchment() -> bool:
	var tm := _make_tm()
	var ok := tm.C_BODY.r > 0.75 and tm.C_BODY.g > 0.68
	tm.free()
	return ok


# ── Layout constants ──────────────────────────────────────────────────────────

static func test_fade_in_sec() -> bool:
	var tm := _make_tm()
	var ok := abs(tm.FADE_IN_SEC - 0.12) < 0.001
	tm.free()
	return ok


static func test_fade_out_sec() -> bool:
	var tm := _make_tm()
	var ok := abs(tm.FADE_OUT_SEC - 0.10) < 0.001
	tm.free()
	return ok


static func test_panel_w() -> bool:
	var tm := _make_tm()
	var ok := tm.PANEL_W == 280
	tm.free()
	return ok


static func test_offset_x_positive() -> bool:
	var tm := _make_tm()
	var ok := tm.OFFSET.x > 0
	tm.free()
	return ok


static func test_offset_y_negative() -> bool:
	var tm := _make_tm()
	var ok := tm.OFFSET.y < 0
	tm.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_panel_null() -> bool:
	var tm := _make_tm()
	var ok := tm._panel == null
	tm.free()
	return ok


static func test_initial_title_lbl_null() -> bool:
	var tm := _make_tm()
	var ok := tm._title_lbl == null
	tm.free()
	return ok


static func test_initial_body_lbl_null() -> bool:
	var tm := _make_tm()
	var ok := tm._body_lbl == null
	tm.free()
	return ok


static func test_initial_visible_flag_false() -> bool:
	var tm := _make_tm()
	var ok := tm._visible_flag == false
	tm.free()
	return ok


static func test_initial_data_empty() -> bool:
	var tm := _make_tm()
	var ok := tm._data.is_empty()
	tm.free()
	return ok
