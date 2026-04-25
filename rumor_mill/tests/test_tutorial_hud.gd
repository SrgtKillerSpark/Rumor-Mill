## test_tutorial_hud.gd — Unit tests for tutorial_hud.gd (SPA-1042).
##
## Covers:
##   • Palette constants
##   • Layout constants: PANEL_WIDTH, PANEL_HEIGHT
##   • Initial node refs null (built in _ready — not called here)
##   • Initial state: _queue empty, _active_id="", _total_queued=0
##
## Run from the Godot editor: Scene → Run Script.

class_name TestTutorialHud
extends RefCounted

const TutorialHudScript := preload("res://scripts/tutorial_hud.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_hud() -> CanvasLayer:
	return TutorialHudScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_backdrop_near_black",
		"test_c_heading_gold",
		"test_c_btn_text_warm",
		# Layout constants
		"test_panel_width",
		"test_panel_height",
		# Initial node refs
		"test_initial_backdrop_null",
		"test_initial_panel_null",
		"test_initial_title_label_null",
		"test_initial_body_label_null",
		"test_initial_dismiss_btn_null",
		"test_initial_step_label_null",
		# Initial state
		"test_initial_tutorial_sys_null",
		"test_initial_queue_empty",
		"test_initial_active_id_empty",
		"test_initial_total_queued_zero",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nTutorialHud tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_backdrop_near_black() -> bool:
	var h := _make_hud()
	var ok := h.C_BACKDROP.r < 0.10 and h.C_BACKDROP.a > 0.70
	h.free()
	return ok


static func test_c_heading_gold() -> bool:
	var h := _make_hud()
	var ok := h.C_HEADING.r > 0.85 and h.C_HEADING.g > 0.70 and h.C_HEADING.b < 0.20
	h.free()
	return ok


static func test_c_btn_text_warm() -> bool:
	var h := _make_hud()
	var ok := h.C_BTN_TEXT.r > 0.85 and h.C_BTN_TEXT.g > 0.75
	h.free()
	return ok


# ── Layout constants ──────────────────────────────────────────────────────────

static func test_panel_width() -> bool:
	var h := _make_hud()
	var ok := h.PANEL_WIDTH == 650
	h.free()
	return ok


static func test_panel_height() -> bool:
	var h := _make_hud()
	var ok := h.PANEL_HEIGHT == 340
	h.free()
	return ok


# ── Initial node refs ─────────────────────────────────────────────────────────

static func test_initial_backdrop_null() -> bool:
	var h := _make_hud()
	var ok := h._backdrop == null
	h.free()
	return ok


static func test_initial_panel_null() -> bool:
	var h := _make_hud()
	var ok := h._panel == null
	h.free()
	return ok


static func test_initial_title_label_null() -> bool:
	var h := _make_hud()
	var ok := h._title_label == null
	h.free()
	return ok


static func test_initial_body_label_null() -> bool:
	var h := _make_hud()
	var ok := h._body_label == null
	h.free()
	return ok


static func test_initial_dismiss_btn_null() -> bool:
	var h := _make_hud()
	var ok := h._dismiss_btn == null
	h.free()
	return ok


static func test_initial_step_label_null() -> bool:
	var h := _make_hud()
	var ok := h._step_label == null
	h.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_tutorial_sys_null() -> bool:
	var h := _make_hud()
	var ok := h._tutorial_sys == null
	h.free()
	return ok


static func test_initial_queue_empty() -> bool:
	var h := _make_hud()
	var ok := h._queue.is_empty()
	h.free()
	return ok


static func test_initial_active_id_empty() -> bool:
	var h := _make_hud()
	var ok := h._active_id == ""
	h.free()
	return ok


static func test_initial_total_queued_zero() -> bool:
	var h := _make_hud()
	var ok := h._total_queued == 0
	h.free()
	return ok
