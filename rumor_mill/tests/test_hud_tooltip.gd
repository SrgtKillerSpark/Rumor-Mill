## test_hud_tooltip.gd — Unit tests for hud_tooltip.gd (SPA-1026).
##
## Covers:
##   • Color palette constants: C_BG, C_BORDER, C_TITLE, C_BODY, C_MUTED, C_OUTLINE
##   • Layout constants: TOOLTIP_MAX_WIDTH, CURSOR_OFFSET, FADE_IN_SEC, HOVER_DELAY_SEC
##   • Initial instance state (before _ready()): _panel, _current_text, _hover_time,
##     _showing, _hovered_control, _fade_tween, _title_label, _body_label, _vbox
##   • _hide_tooltip(): _panel null guard — sets _showing=false and _current_text=""
##     without crashing when called on a bare instance
##
## hud_tooltip.gd extends CanvasLayer (no class_name — loaded via preload).
## _ready() is NOT called (node not added to scene tree) so all nodes built by
## _build_panel() remain null.  _process() polling requires a live viewport and is
## not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestHudTooltip
extends RefCounted

const HudTooltipScript := preload("res://scripts/hud_tooltip.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_ht() -> CanvasLayer:
	return HudTooltipScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Color constants
		"test_c_bg_colour",
		"test_c_border_colour",
		"test_c_title_colour",
		"test_c_body_colour",
		"test_c_muted_colour",
		"test_c_outline_colour",
		# Layout constants
		"test_tooltip_max_width",
		"test_cursor_offset",
		"test_fade_in_sec",
		"test_hover_delay_sec",
		# Initial state (before _ready())
		"test_initial_panel_null",
		"test_initial_title_label_null",
		"test_initial_body_label_null",
		"test_initial_vbox_null",
		"test_initial_fade_tween_null",
		"test_initial_current_text_empty",
		"test_initial_hover_time_zero",
		"test_initial_showing_false",
		"test_initial_hovered_control_null",
		# _hide_tooltip() null panel guard
		"test_hide_tooltip_null_panel_sets_showing_false",
		"test_hide_tooltip_null_panel_clears_current_text",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nHudTooltip tests: %d passed, %d failed" % [passed, failed])


# ── Color constants ───────────────────────────────────────────────────────────

static func test_c_bg_colour() -> bool:
	return _make_ht().C_BG == Color(0.10, 0.07, 0.05, 0.95)


static func test_c_border_colour() -> bool:
	return _make_ht().C_BORDER == Color(0.55, 0.38, 0.18, 1.0)


static func test_c_title_colour() -> bool:
	return _make_ht().C_TITLE == Color(0.92, 0.78, 0.12, 1.0)


static func test_c_body_colour() -> bool:
	return _make_ht().C_BODY == Color(0.82, 0.75, 0.60, 1.0)


static func test_c_muted_colour() -> bool:
	return _make_ht().C_MUTED == Color(0.65, 0.58, 0.45, 0.85)


static func test_c_outline_colour() -> bool:
	return _make_ht().C_OUTLINE == Color(0, 0, 0, 0.7)


# ── Layout constants ──────────────────────────────────────────────────────────

static func test_tooltip_max_width() -> bool:
	if _make_ht().TOOLTIP_MAX_WIDTH != 320.0:
		push_error("test_tooltip_max_width: expected 320, got %.1f" % _make_ht().TOOLTIP_MAX_WIDTH)
		return false
	return true


static func test_cursor_offset() -> bool:
	return _make_ht().CURSOR_OFFSET == Vector2(16, -12)


static func test_fade_in_sec() -> bool:
	return absf(_make_ht().FADE_IN_SEC - 0.10) < 0.001


static func test_hover_delay_sec() -> bool:
	return absf(_make_ht().HOVER_DELAY_SEC - 0.35) < 0.001


# ── Initial state (before _ready()) ──────────────────────────────────────────

static func test_initial_panel_null() -> bool:
	return _make_ht()._panel == null


static func test_initial_title_label_null() -> bool:
	return _make_ht()._title_label == null


static func test_initial_body_label_null() -> bool:
	return _make_ht()._body_label == null


static func test_initial_vbox_null() -> bool:
	return _make_ht()._vbox == null


static func test_initial_fade_tween_null() -> bool:
	return _make_ht()._fade_tween == null


static func test_initial_current_text_empty() -> bool:
	return _make_ht()._current_text == ""


static func test_initial_hover_time_zero() -> bool:
	return absf(_make_ht()._hover_time) < 0.001


static func test_initial_showing_false() -> bool:
	return _make_ht()._showing == false


static func test_initial_hovered_control_null() -> bool:
	return _make_ht()._hovered_control == null


# ── _hide_tooltip() null panel guard ─────────────────────────────────────────

## _hide_tooltip() has an "if _panel != null" guard so it is safe to call
## on a bare instance.  It must set _showing = false without crashing.
static func test_hide_tooltip_null_panel_sets_showing_false() -> bool:
	var ht := _make_ht()
	ht._showing = true
	ht._hide_tooltip()
	return ht._showing == false


static func test_hide_tooltip_null_panel_clears_current_text() -> bool:
	var ht := _make_ht()
	ht._current_text = "some tooltip"
	ht._hide_tooltip()
	return ht._current_text == ""
