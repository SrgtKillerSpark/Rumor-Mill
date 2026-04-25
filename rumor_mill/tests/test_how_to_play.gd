## test_how_to_play.gd — Unit tests for how_to_play.gd (SPA-1042).
##
## Covers:
##   • Palette constants (characteristic colour assertions)
##   • Tab enum ordinals: CONTROLS=0, MECHANICS=1, SYSTEMS=2
##   • Initial state: _current_tab=Tab.CONTROLS, _tab_buttons/content_boxes empty
##   • Initial node ref: _scroll null
##
## Run from the Godot editor: Scene → Run Script.

class_name TestHowToPlay
extends RefCounted

const HowToPlayScript := preload("res://scripts/how_to_play.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_htp() -> CanvasLayer:
	return HowToPlayScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_overlay_semi_transparent",
		"test_c_title_is_gold",
		"test_c_tab_active_amber",
		"test_c_tab_inactive_very_dark",
		# Tab enum ordinals
		"test_tab_controls_is_zero",
		"test_tab_mechanics_is_one",
		"test_tab_systems_is_two",
		# Initial state
		"test_initial_current_tab_is_controls",
		"test_initial_tab_buttons_empty",
		"test_initial_content_boxes_empty",
		"test_initial_scroll_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nHowToPlay tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_overlay_semi_transparent() -> bool:
	var h := _make_htp()
	# dark semi-transparent overlay
	var ok := h.C_OVERLAY.a > 0.40 and h.C_OVERLAY.a < 0.75 and h.C_OVERLAY.r < 0.10
	h.free()
	return ok


static func test_c_title_is_gold() -> bool:
	var h := _make_htp()
	var ok := h.C_TITLE.r > 0.85 and h.C_TITLE.g > 0.70 and h.C_TITLE.b < 0.20
	h.free()
	return ok


static func test_c_tab_active_amber() -> bool:
	var h := _make_htp()
	# amber-brown active tab: moderate r, low g, very low b
	var ok := h.C_TAB_ACTIVE.r > 0.45 and h.C_TAB_ACTIVE.b < 0.25
	h.free()
	return ok


static func test_c_tab_inactive_very_dark() -> bool:
	var h := _make_htp()
	var ok := h.C_TAB_INACTIVE.r < 0.25 and h.C_TAB_INACTIVE.g < 0.20
	h.free()
	return ok


# ── Tab enum ordinals ─────────────────────────────────────────────────────────

static func test_tab_controls_is_zero() -> bool:
	var ok := HowToPlayScript.Tab.CONTROLS == 0
	return ok


static func test_tab_mechanics_is_one() -> bool:
	var ok := HowToPlayScript.Tab.MECHANICS == 1
	return ok


static func test_tab_systems_is_two() -> bool:
	var ok := HowToPlayScript.Tab.SYSTEMS == 2
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_current_tab_is_controls() -> bool:
	var h := _make_htp()
	var ok := h._current_tab == HowToPlayScript.Tab.CONTROLS
	h.free()
	return ok


static func test_initial_tab_buttons_empty() -> bool:
	var h := _make_htp()
	var ok := h._tab_buttons.is_empty()
	h.free()
	return ok


static func test_initial_content_boxes_empty() -> bool:
	var h := _make_htp()
	var ok := h._content_boxes.is_empty()
	h.free()
	return ok


static func test_initial_scroll_null() -> bool:
	var h := _make_htp()
	var ok := h._scroll == null
	h.free()
	return ok
