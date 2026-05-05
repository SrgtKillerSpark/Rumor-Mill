## test_spa1822_end_screen_ship_regression.gd — Regression guard for the four
## end-screen fixes that shipped on 2026-05-05 (SPA-1822).
##
## Coverage matrix:
##   SPA-1804 (commit 2cd2c48)  Defeat CTA renamed "Play Again" → "Try Again";
##                               victory path keeps "Play Again".
##                               • _build_ui() creates _btn_again with "Play Again"
##                                 text and Vector2(150, 40) min-size (victory path).
##                               • Defeat-path font-size override (18) is accepted
##                                 by the Button node.
##                               Note: the defeat text/min-size path lives inside
##                               _on_scenario_resolved which uses `await` + scene
##                               tree and cannot be executed headlessly.
##
##   SPA-1805 (commit cf676eb)  Escape dismisses confirm dialog before slot picker
##                               before pause toggle.
##                               • _on_confirm_no() hides _confirm_container and
##                                 restores _main_container; leaves _slot_container
##                                 unchanged (priority isolation).
##                               • _hide_slot_picker() hides _slot_container and
##                                 restores _main_container.
##                               Note: the full _unhandled_input path calls
##                               get_viewport() and cannot run headlessly; the
##                               individual priority-branch handlers are exercised
##                               with stub containers.
##
##   SPA-1806 (commit 0109ca2)  All three end-screen navigation handlers
##                               (_on_play_again, _on_next_scenario, _on_main_menu)
##                               exist and are connected to the correct buttons.
##                               • has_method() guard for all three handlers.
##                               • Button-to-handler signal wiring verified after
##                                 _build_ui().
##                               Note: each handler contains `await
##                               TransitionManager.fade_out(0.35)` followed by
##                               get_tree().reload_current_scene() — the full
##                               call sequence cannot be asserted headlessly.
##
##   SPA-1809 (commit 53c2795)  End-screen panel is centered via anchor=0.5
##                               offsets so it stays on-screen at 720p, 1080p,
##                               and ultrawide.  Pause-menu responsive constants
##                               produce within-bounds widths at all three target
##                               viewport sizes.
##                               • PANEL_W / PANEL_H constants.
##                               • All four anchors == 0.5 after _build_ui().
##                               • Offsets == ±PANEL_W/2 and ±PANEL_H/2.
##                               • UILayoutConstants.clamp_to_viewport() returns
##                                 a value ≥ min and ≤ max for 720p / 1080p /
##                                 ultrawide pause-panel widths.
##
## Convention follows test_end_screen.gd (SPA-1024):
##   EndScreen is created via EndScreenScript.new() — _ready() is NOT called,
##   so _build_ui() is invoked explicitly where needed (safe: no await, no
##   get_viewport() call inside end_screen._build_ui()).
##   PauseMenu containers (_confirm_container, _main_container, _slot_container)
##   are stub-constructed manually because _ready()/_build_ui() requires a
##   live viewport.

class_name TestSpa1822EndScreenShipRegression
extends RefCounted

const EndScreenScript := preload("res://scripts/end_screen.gd")
const PauseMenuScript  := preload("res://scripts/pause_menu.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_es() -> CanvasLayer:
	return EndScreenScript.new()


## EndScreen with _build_ui() already called — buttons and panel exist.
static func _make_es_with_ui() -> CanvasLayer:
	var es := EndScreenScript.new()
	es._build_ui()
	return es


static func _make_pm() -> Node:
	return PauseMenuScript.new()


## PauseMenu with stub containers sufficient for _on_confirm_no() and
## _hide_slot_picker() — no scene tree required.
static func _make_pm_with_stubs() -> Node:
	var pm               := PauseMenuScript.new()
	pm._confirm_container = VBoxContainer.new()
	pm._main_container    = VBoxContainer.new()
	pm._slot_container    = VBoxContainer.new()
	return pm


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# SPA-1804: CTA button text (victory-path default)
		"test_1804_btn_again_default_text_play_again",
		"test_1804_btn_again_default_min_size",
		"test_1804_btn_next_initial_disabled",
		"test_1804_btn_again_accepts_defeat_font_size_override",
		# SPA-1805: Escape dismissal priority — individual branch handlers
		"test_1805_confirm_no_hides_confirm_container",
		"test_1805_confirm_no_shows_main_container",
		"test_1805_confirm_no_leaves_slot_container_unchanged",
		"test_1805_hide_slot_picker_hides_slot_container",
		"test_1805_hide_slot_picker_shows_main_container",
		"test_1805_hide_slot_picker_leaves_confirm_unchanged",
		# SPA-1806: Fade-then-reload handler existence + button wiring
		"test_1806_has_method_on_play_again",
		"test_1806_has_method_on_next_scenario",
		"test_1806_has_method_on_main_menu",
		"test_1806_btn_again_connected_to_on_play_again",
		"test_1806_btn_next_connected_to_on_next_scenario",
		"test_1806_btn_main_menu_connected_to_on_main_menu",
		# SPA-1809: Responsive layout constants and panel centering
		"test_1809_panel_w_constant",
		"test_1809_panel_h_constant",
		"test_1809_panel_anchor_left_center",
		"test_1809_panel_anchor_right_center",
		"test_1809_panel_anchor_top_center",
		"test_1809_panel_anchor_bottom_center",
		"test_1809_panel_offset_left",
		"test_1809_panel_offset_right",
		"test_1809_panel_offset_top",
		"test_1809_panel_offset_bottom",
		"test_1809_pause_panel_720p_width_in_bounds",
		"test_1809_pause_panel_1080p_width_capped_at_max",
		"test_1809_pause_panel_ultrawide_width_capped_at_max",
		"test_1809_pause_panel_720p_height_in_bounds",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSPA-1822 EndScreenShipRegression tests: %d passed, %d failed" % [passed, failed])


# ── SPA-1804: CTA button text ─────────────────────────────────────────────────

## The Play Again button must start as "Play Again" — the victory-path default.
## Defeat renames it "Try Again" inside _on_scenario_resolved (requires await).
static func test_1804_btn_again_default_text_play_again() -> bool:
	var es := _make_es_with_ui()
	if es._btn_again == null:
		push_error("test_1804_btn_again_default_text_play_again: _btn_again null after _build_ui()")
		return false
	if es._btn_again.text != "Play Again":
		push_error("test_1804_btn_again_default_text_play_again: expected 'Play Again', got '%s'" % es._btn_again.text)
		return false
	return true


## Victory-path minimum size is Vector2(150, 40) — set by _make_button("Play Again", 150).
## Defeat widens it to Vector2(180, 48) inside _on_scenario_resolved.
static func test_1804_btn_again_default_min_size() -> bool:
	var es := _make_es_with_ui()
	if es._btn_again == null:
		push_error("test_1804_btn_again_default_min_size: _btn_again null")
		return false
	var expected := Vector2(150, 40)
	if es._btn_again.custom_minimum_size != expected:
		push_error("test_1804_btn_again_default_min_size: expected %s, got %s" % [expected, es._btn_again.custom_minimum_size])
		return false
	return true


## Next Scenario must be disabled on entry (no scenario won yet).
static func test_1804_btn_next_initial_disabled() -> bool:
	var es := _make_es_with_ui()
	if es._btn_next == null:
		push_error("test_1804_btn_next_initial_disabled: _btn_next null")
		return false
	if not es._btn_next.disabled:
		push_error("test_1804_btn_next_initial_disabled: _btn_next should be disabled initially")
		return false
	return true


## The defeat path sets add_theme_font_size_override("font_size", 18) on _btn_again.
## Verify the Button node correctly stores that override value (sanity: it is a
## real theme-capable node, not a stub).
static func test_1804_btn_again_accepts_defeat_font_size_override() -> bool:
	var es := _make_es_with_ui()
	if es._btn_again == null:
		push_error("test_1804_btn_again_accepts_defeat_font_size_override: _btn_again null")
		return false
	es._btn_again.add_theme_font_size_override("font_size", 18)
	var stored: int = es._btn_again.get_theme_font_size("font_size")
	if stored != 18:
		push_error("test_1804_btn_again_accepts_defeat_font_size_override: expected 18, got %d" % stored)
		return false
	return true


# ── SPA-1805: Escape dismissal priority — branch handlers ────────────────────

## _on_confirm_no(): _confirm_container.visible must become false.
static func test_1805_confirm_no_hides_confirm_container() -> bool:
	var pm := _make_pm_with_stubs()
	pm._confirm_container.visible = true
	pm._on_confirm_no()
	if pm._confirm_container.visible:
		push_error("test_1805_confirm_no_hides_confirm_container: _confirm_container still visible")
		return false
	return true


## _on_confirm_no(): _main_container.visible must become true.
static func test_1805_confirm_no_shows_main_container() -> bool:
	var pm := _make_pm_with_stubs()
	pm._main_container.visible = false
	pm._confirm_container.visible = true
	pm._on_confirm_no()
	if not pm._main_container.visible:
		push_error("test_1805_confirm_no_shows_main_container: _main_container not visible after _on_confirm_no()")
		return false
	return true


## _on_confirm_no() must NOT affect _slot_container — the slot picker is a
## separate layer of the modal stack.  Priority: confirm closes first; slot
## is untouched.
static func test_1805_confirm_no_leaves_slot_container_unchanged() -> bool:
	var pm := _make_pm_with_stubs()
	pm._confirm_container.visible = true
	pm._slot_container.visible    = true   # slot also open — confirm takes priority
	pm._on_confirm_no()
	if not pm._slot_container.visible:
		push_error("test_1805_confirm_no_leaves_slot_container_unchanged: _slot_container was incorrectly hidden")
		return false
	return true


## _hide_slot_picker(): _slot_container.visible must become false.
static func test_1805_hide_slot_picker_hides_slot_container() -> bool:
	var pm := _make_pm_with_stubs()
	pm._slot_container.visible = true
	pm._hide_slot_picker()
	if pm._slot_container.visible:
		push_error("test_1805_hide_slot_picker_hides_slot_container: _slot_container still visible")
		return false
	return true


## _hide_slot_picker(): _main_container.visible must become true.
static func test_1805_hide_slot_picker_shows_main_container() -> bool:
	var pm := _make_pm_with_stubs()
	pm._main_container.visible = false
	pm._slot_container.visible = true
	pm._hide_slot_picker()
	if not pm._main_container.visible:
		push_error("test_1805_hide_slot_picker_shows_main_container: _main_container not visible")
		return false
	return true


## _hide_slot_picker() must NOT affect _confirm_container — that panel is a
## higher-priority layer and is closed by _on_confirm_no(), not by this method.
static func test_1805_hide_slot_picker_leaves_confirm_unchanged() -> bool:
	var pm := _make_pm_with_stubs()
	pm._confirm_container.visible = false
	pm._slot_container.visible    = true
	pm._hide_slot_picker()
	if pm._confirm_container.visible:
		push_error("test_1805_hide_slot_picker_leaves_confirm_unchanged: _confirm_container was incorrectly made visible")
		return false
	return true


# ── SPA-1806: Fade-then-reload handler existence + wiring ────────────────────

## All three navigation coroutines must exist as named methods.

static func test_1806_has_method_on_play_again() -> bool:
	return _make_es().has_method("_on_play_again")


static func test_1806_has_method_on_next_scenario() -> bool:
	return _make_es().has_method("_on_next_scenario")


static func test_1806_has_method_on_main_menu() -> bool:
	return _make_es().has_method("_on_main_menu")


## Play Again button's pressed signal must be connected to _on_play_again.
static func test_1806_btn_again_connected_to_on_play_again() -> bool:
	var es := _make_es_with_ui()
	if es._btn_again == null:
		push_error("test_1806_btn_again_connected_to_on_play_again: _btn_again null")
		return false
	if not es._btn_again.pressed.is_connected(es._on_play_again):
		push_error("test_1806_btn_again_connected_to_on_play_again: pressed not connected to _on_play_again")
		return false
	return true


## Next Scenario button's pressed signal must be connected to _on_next_scenario.
static func test_1806_btn_next_connected_to_on_next_scenario() -> bool:
	var es := _make_es_with_ui()
	if es._btn_next == null:
		push_error("test_1806_btn_next_connected_to_on_next_scenario: _btn_next null")
		return false
	if not es._btn_next.pressed.is_connected(es._on_next_scenario):
		push_error("test_1806_btn_next_connected_to_on_next_scenario: pressed not connected to _on_next_scenario")
		return false
	return true


## Main Menu button's pressed signal must be connected to _on_main_menu.
static func test_1806_btn_main_menu_connected_to_on_main_menu() -> bool:
	var es := _make_es_with_ui()
	if es._btn_main_menu == null:
		push_error("test_1806_btn_main_menu_connected_to_on_main_menu: _btn_main_menu null")
		return false
	if not es._btn_main_menu.pressed.is_connected(es._on_main_menu):
		push_error("test_1806_btn_main_menu_connected_to_on_main_menu: pressed not connected to _on_main_menu")
		return false
	return true


# ── SPA-1809: Responsive layout — panel constants and centering ───────────────

## PANEL_W and PANEL_H must match the shipped spec (760 × 640 px).

static func test_1809_panel_w_constant() -> bool:
	var es := _make_es()
	if es.PANEL_W != 760:
		push_error("test_1809_panel_w_constant: expected 760, got %d" % es.PANEL_W)
		return false
	return true


static func test_1809_panel_h_constant() -> bool:
	var es := _make_es()
	if es.PANEL_H != 640:
		push_error("test_1809_panel_h_constant: expected 640, got %d" % es.PANEL_H)
		return false
	return true


## After _build_ui(), _panel must use anchor=0.5 on all sides so it stays
## viewport-centered regardless of resolution.

static func test_1809_panel_anchor_left_center() -> bool:
	var es := _make_es_with_ui()
	if es._panel == null:
		push_error("test_1809_panel_anchor_left_center: _panel null")
		return false
	if not is_equal_approx(es._panel.get_anchor(SIDE_LEFT), 0.5):
		push_error("test_1809_panel_anchor_left_center: expected 0.5, got %f" % es._panel.get_anchor(SIDE_LEFT))
		return false
	return true


static func test_1809_panel_anchor_right_center() -> bool:
	var es := _make_es_with_ui()
	if es._panel == null:
		push_error("test_1809_panel_anchor_right_center: _panel null")
		return false
	if not is_equal_approx(es._panel.get_anchor(SIDE_RIGHT), 0.5):
		push_error("test_1809_panel_anchor_right_center: expected 0.5, got %f" % es._panel.get_anchor(SIDE_RIGHT))
		return false
	return true


static func test_1809_panel_anchor_top_center() -> bool:
	var es := _make_es_with_ui()
	if es._panel == null:
		push_error("test_1809_panel_anchor_top_center: _panel null")
		return false
	if not is_equal_approx(es._panel.get_anchor(SIDE_TOP), 0.5):
		push_error("test_1809_panel_anchor_top_center: expected 0.5, got %f" % es._panel.get_anchor(SIDE_TOP))
		return false
	return true


static func test_1809_panel_anchor_bottom_center() -> bool:
	var es := _make_es_with_ui()
	if es._panel == null:
		push_error("test_1809_panel_anchor_bottom_center: _panel null")
		return false
	if not is_equal_approx(es._panel.get_anchor(SIDE_BOTTOM), 0.5):
		push_error("test_1809_panel_anchor_bottom_center: expected 0.5, got %f" % es._panel.get_anchor(SIDE_BOTTOM))
		return false
	return true


## Offsets must be ±PANEL_W/2 and ±PANEL_H/2 so the panel centres on the anchor.

static func test_1809_panel_offset_left() -> bool:
	var es := _make_es_with_ui()
	if es._panel == null:
		push_error("test_1809_panel_offset_left: _panel null")
		return false
	var expected: float = -es.PANEL_W / 2.0
	if not is_equal_approx(es._panel.get_offset(SIDE_LEFT), expected):
		push_error("test_1809_panel_offset_left: expected %f, got %f" % [expected, es._panel.get_offset(SIDE_LEFT)])
		return false
	return true


static func test_1809_panel_offset_right() -> bool:
	var es := _make_es_with_ui()
	if es._panel == null:
		push_error("test_1809_panel_offset_right: _panel null")
		return false
	var expected: float = es.PANEL_W / 2.0
	if not is_equal_approx(es._panel.get_offset(SIDE_RIGHT), expected):
		push_error("test_1809_panel_offset_right: expected %f, got %f" % [expected, es._panel.get_offset(SIDE_RIGHT)])
		return false
	return true


static func test_1809_panel_offset_top() -> bool:
	var es := _make_es_with_ui()
	if es._panel == null:
		push_error("test_1809_panel_offset_top: _panel null")
		return false
	var expected: float = -es.PANEL_H / 2.0
	if not is_equal_approx(es._panel.get_offset(SIDE_TOP), expected):
		push_error("test_1809_panel_offset_top: expected %f, got %f" % [expected, es._panel.get_offset(SIDE_TOP)])
		return false
	return true


static func test_1809_panel_offset_bottom() -> bool:
	var es := _make_es_with_ui()
	if es._panel == null:
		push_error("test_1809_panel_offset_bottom: _panel null")
		return false
	var expected: float = es.PANEL_H / 2.0
	if not is_equal_approx(es._panel.get_offset(SIDE_BOTTOM), expected):
		push_error("test_1809_panel_offset_bottom: expected %f, got %f" % [expected, es._panel.get_offset(SIDE_BOTTOM)])
		return false
	return true


## UILayoutConstants.clamp_to_viewport() must produce within-bounds pause-panel
## widths at the three target resolutions.
##
## Pause menu constants (from pause_menu.gd):
##   MIN_W = 260, MAX_W = 380, VP_W_FRACTION = 0.28
##
## Expected:
##   720p  (1280 px): clamp(1280 × 0.28 = 358, 260, 380) = 358  → within bounds
##   1080p (1920 px): clamp(1920 × 0.28 = 537, 260, 380) = 380  → capped at max
##   ultrawide (2560 px): clamp(2560 × 0.28 = 716, 260, 380) = 380 → capped at max

static func test_1809_pause_panel_720p_width_in_bounds() -> bool:
	var pm  := _make_pm()
	var w: int = UILayoutConstants.clamp_to_viewport(1280.0, pm.PAUSE_PANEL_VP_W, pm.PAUSE_PANEL_MIN_W, pm.PAUSE_PANEL_MAX_W)
	if w < pm.PAUSE_PANEL_MIN_W or w > pm.PAUSE_PANEL_MAX_W:
		push_error("test_1809_pause_panel_720p_width_in_bounds: %d not in [%d, %d]" % [w, pm.PAUSE_PANEL_MIN_W, pm.PAUSE_PANEL_MAX_W])
		return false
	# Exact expected value at 720p.
	if w != 358:
		push_error("test_1809_pause_panel_720p_width_in_bounds: expected 358, got %d" % w)
		return false
	return true


static func test_1809_pause_panel_1080p_width_capped_at_max() -> bool:
	var pm  := _make_pm()
	var w: int = UILayoutConstants.clamp_to_viewport(1920.0, pm.PAUSE_PANEL_VP_W, pm.PAUSE_PANEL_MIN_W, pm.PAUSE_PANEL_MAX_W)
	if w != pm.PAUSE_PANEL_MAX_W:
		push_error("test_1809_pause_panel_1080p_width_capped_at_max: expected %d (max), got %d" % [pm.PAUSE_PANEL_MAX_W, w])
		return false
	return true


static func test_1809_pause_panel_ultrawide_width_capped_at_max() -> bool:
	var pm  := _make_pm()
	var w: int = UILayoutConstants.clamp_to_viewport(2560.0, pm.PAUSE_PANEL_VP_W, pm.PAUSE_PANEL_MIN_W, pm.PAUSE_PANEL_MAX_W)
	if w != pm.PAUSE_PANEL_MAX_W:
		push_error("test_1809_pause_panel_ultrawide_width_capped_at_max: expected %d (max), got %d" % [pm.PAUSE_PANEL_MAX_W, w])
		return false
	return true


## Pause-panel height at 720p must be within [PAUSE_PANEL_MIN_H, PAUSE_PANEL_MAX_H].
## 720 × 0.75 = 540 → exactly at PAUSE_PANEL_MAX_H (acceptable boundary case).
static func test_1809_pause_panel_720p_height_in_bounds() -> bool:
	var pm  := _make_pm()
	var h: int = UILayoutConstants.clamp_to_viewport(720.0, pm.PAUSE_PANEL_VP_H, pm.PAUSE_PANEL_MIN_H, pm.PAUSE_PANEL_MAX_H)
	if h < pm.PAUSE_PANEL_MIN_H or h > pm.PAUSE_PANEL_MAX_H:
		push_error("test_1809_pause_panel_720p_height_in_bounds: %d not in [%d, %d]" % [h, pm.PAUSE_PANEL_MIN_H, pm.PAUSE_PANEL_MAX_H])
		return false
	return true
