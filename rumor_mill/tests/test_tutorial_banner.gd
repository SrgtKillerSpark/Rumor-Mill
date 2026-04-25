## test_tutorial_banner.gd — Unit tests for tutorial_banner.gd (SPA-1042).
##
## Covers:
##   • Palette constants
##   • Layout constants: BANNER_WIDTH, MARGIN, ACCENT_WIDTH
##   • Initial node refs null (built in _ready — not called here)
##   • Initial state: _queue empty, _active_id=""
##
## Run from the Godot editor: Scene → Run Script.

class_name TestTutorialBanner
extends RefCounted

const TutorialBannerScript := preload("res://scripts/tutorial_banner.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_tb() -> CanvasLayer:
	return TutorialBannerScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_panel_bg_dark_semi",
		"test_c_accent_amber",
		"test_c_heading_warm_gold",
		# Layout constants
		"test_banner_width",
		"test_margin",
		"test_accent_width",
		# Initial node refs
		"test_initial_container_null",
		"test_initial_panel_bg_null",
		"test_initial_accent_null",
		"test_initial_title_label_null",
		"test_initial_body_label_null",
		"test_initial_dismiss_btn_null",
		"test_initial_dismiss_tween_null",
		# Initial state
		"test_initial_tutorial_sys_null",
		"test_initial_queue_empty",
		"test_initial_active_id_empty",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nTutorialBanner tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_panel_bg_dark_semi() -> bool:
	var tb := _make_tb()
	var ok := tb.C_PANEL_BG.r < 0.10 and tb.C_PANEL_BG.a > 0.75
	tb.free()
	return ok


static func test_c_accent_amber() -> bool:
	var tb := _make_tb()
	var ok := tb.C_ACCENT.r > 0.90 and tb.C_ACCENT.g > 0.55 and tb.C_ACCENT.b < 0.30
	tb.free()
	return ok


static func test_c_heading_warm_gold() -> bool:
	var tb := _make_tb()
	var ok := tb.C_HEADING.r > 0.90 and tb.C_HEADING.g > 0.75 and tb.C_HEADING.b < 0.50
	tb.free()
	return ok


# ── Layout constants ──────────────────────────────────────────────────────────

static func test_banner_width() -> bool:
	var tb := _make_tb()
	var ok := tb.BANNER_WIDTH == 380
	tb.free()
	return ok


static func test_margin() -> bool:
	var tb := _make_tb()
	var ok := tb.MARGIN == 24
	tb.free()
	return ok


static func test_accent_width() -> bool:
	var tb := _make_tb()
	var ok := tb.ACCENT_WIDTH == 5
	tb.free()
	return ok


# ── Initial node refs ─────────────────────────────────────────────────────────

static func test_initial_container_null() -> bool:
	var tb := _make_tb()
	var ok := tb._container == null
	tb.free()
	return ok


static func test_initial_panel_bg_null() -> bool:
	var tb := _make_tb()
	var ok := tb._panel_bg == null
	tb.free()
	return ok


static func test_initial_accent_null() -> bool:
	var tb := _make_tb()
	var ok := tb._accent == null
	tb.free()
	return ok


static func test_initial_title_label_null() -> bool:
	var tb := _make_tb()
	var ok := tb._title_label == null
	tb.free()
	return ok


static func test_initial_body_label_null() -> bool:
	var tb := _make_tb()
	var ok := tb._body_label == null
	tb.free()
	return ok


static func test_initial_dismiss_btn_null() -> bool:
	var tb := _make_tb()
	var ok := tb._dismiss_btn == null
	tb.free()
	return ok


static func test_initial_dismiss_tween_null() -> bool:
	var tb := _make_tb()
	var ok := tb._dismiss_tween == null
	tb.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_tutorial_sys_null() -> bool:
	var tb := _make_tb()
	var ok := tb._tutorial_sys == null
	tb.free()
	return ok


static func test_initial_queue_empty() -> bool:
	var tb := _make_tb()
	var ok := tb._queue.is_empty()
	tb.free()
	return ok


static func test_initial_active_id_empty() -> bool:
	var tb := _make_tb()
	var ok := tb._active_id == ""
	tb.free()
	return ok
