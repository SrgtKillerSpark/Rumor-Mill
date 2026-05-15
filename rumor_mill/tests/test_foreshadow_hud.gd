## test_foreshadow_hud.gd — Unit tests for foreshadow_hud.gd (SPA-2745).
##
## Covers:
##   • Palette constants (C_BG, C_BORDER, C_TEXT, C_SUBTEXT, C_ICON)
##   • Layout/timing constants (BANNER_H, BANNER_PAD_X, REVEAL_TIME, HOLD_TIME, HIDE_TIME)
##   • Initial node refs null (before _ready / scene-tree entry)
##   • Initial state: _world null, _day_night null, _shown_event_ids empty
##   • setup(): assigns _world and handles null day_night without crash
##   • _on_day_changed() with null world: no hints → early return → no crash

class_name TestForeshadowHud
extends RefCounted

const ForeshadowHudScript := preload("res://scripts/foreshadow_hud.gd")


static func _make_hud() -> CanvasLayer:
	return ForeshadowHudScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette constants
		"test_c_bg_parchment_tan",
		"test_c_border_dark_sepia",
		"test_c_text_dark_brown",
		"test_c_subtext_muted",
		"test_c_icon_dark_sepia_with_alpha",
		# Layout/timing constants
		"test_banner_h",
		"test_banner_pad_x",
		"test_reveal_time",
		"test_hold_time",
		"test_hide_time",
		# Initial node refs null
		"test_initial_container_null",
		"test_initial_icon_rect_null",
		"test_initial_text_label_null",
		"test_initial_subtext_label_null",
		# Initial state vars
		"test_initial_world_null",
		"test_initial_day_night_null",
		"test_initial_shown_event_ids_empty",
		# setup()
		"test_setup_assigns_world",
		"test_setup_handles_null_day_night",
		# _on_day_changed with null world: early return, no crash
		"test_on_day_changed_null_world_no_crash",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nForeshadowHud tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_bg_parchment_tan() -> bool:
	var hud := _make_hud()
	# #F5E6C8: high r, high g, moderate-high b — warm parchment tan
	var ok: bool = hud.C_BG.r > 0.95 and hud.C_BG.g > 0.88 and hud.C_BG.b > 0.75 and hud.C_BG.a == 1.0
	hud.free()
	return ok


static func test_c_border_dark_sepia() -> bool:
	var hud := _make_hud()
	# Dark sepia border: all channels low, r slightly highest
	var ok: bool = hud.C_BORDER.r < 0.30 and hud.C_BORDER.g < 0.20 and hud.C_BORDER.b < 0.10
	hud.free()
	return ok


static func test_c_text_dark_brown() -> bool:
	var hud := _make_hud()
	# #3B2712 dark brown: all channels low, a = 1.0
	var ok: bool = hud.C_TEXT.r < 0.30 and hud.C_TEXT.g < 0.20 and hud.C_TEXT.b < 0.10 and hud.C_TEXT.a == 1.0
	hud.free()
	return ok


static func test_c_subtext_muted() -> bool:
	var hud := _make_hud()
	# #7A6B5D muted: mid-tone warm grey — moderate r channel
	var ok: bool = hud.C_SUBTEXT.r > 0.40 and hud.C_SUBTEXT.r < 0.60
	hud.free()
	return ok


static func test_c_icon_dark_sepia_with_alpha() -> bool:
	var hud := _make_hud()
	# Icon dot: same sepia hue as border but partial alpha (~0.85)
	var ok: bool = hud.C_ICON.r < 0.30 and hud.C_ICON.a > 0.80 and hud.C_ICON.a < 0.95
	hud.free()
	return ok


# ── Layout/timing constants ───────────────────────────────────────────────────

static func test_banner_h() -> bool:
	var hud := _make_hud()
	var ok: bool = hud.BANNER_H == 48.0
	hud.free()
	return ok


static func test_banner_pad_x() -> bool:
	var hud := _make_hud()
	var ok: bool = hud.BANNER_PAD_X == 20.0
	hud.free()
	return ok


static func test_reveal_time() -> bool:
	var hud := _make_hud()
	var ok: bool = hud.REVEAL_TIME == 0.4
	hud.free()
	return ok


static func test_hold_time() -> bool:
	var hud := _make_hud()
	# Spec: 6-second auto-dismiss hold
	var ok: bool = hud.HOLD_TIME == 6.0
	hud.free()
	return ok


static func test_hide_time() -> bool:
	var hud := _make_hud()
	var ok: bool = hud.HIDE_TIME == 0.3
	hud.free()
	return ok


# ── Initial node refs null ────────────────────────────────────────────────────

static func test_initial_container_null() -> bool:
	var hud := _make_hud()
	var ok: bool = hud._container == null
	hud.free()
	return ok


static func test_initial_icon_rect_null() -> bool:
	var hud := _make_hud()
	var ok: bool = hud._icon_rect == null
	hud.free()
	return ok


static func test_initial_text_label_null() -> bool:
	var hud := _make_hud()
	var ok: bool = hud._text_label == null
	hud.free()
	return ok


static func test_initial_subtext_label_null() -> bool:
	var hud := _make_hud()
	var ok: bool = hud._subtext_label == null
	hud.free()
	return ok


# ── Initial state vars ────────────────────────────────────────────────────────

static func test_initial_world_null() -> bool:
	var hud := _make_hud()
	var ok: bool = hud._world == null
	hud.free()
	return ok


static func test_initial_day_night_null() -> bool:
	var hud := _make_hud()
	var ok: bool = hud._day_night == null
	hud.free()
	return ok


static func test_initial_shown_event_ids_empty() -> bool:
	var hud := _make_hud()
	var ok: bool = hud._shown_event_ids.is_empty()
	hud.free()
	return ok


# ── setup() ──────────────────────────────────────────────────────────────────

static func test_setup_assigns_world() -> bool:
	var hud := _make_hud()
	var mock_world := Node.new()
	hud.setup(mock_world, null)
	var ok: bool = hud._world == mock_world
	mock_world.free()
	hud.free()
	return ok


static func test_setup_handles_null_day_night() -> bool:
	# setup() with null day_night must skip signal connect without crash
	var hud := _make_hud()
	hud.setup(null, null)
	var ok: bool = hud._world == null and hud._day_night == null
	hud.free()
	return ok


# ── _on_day_changed with null world ──────────────────────────────────────────

static func test_on_day_changed_null_world_no_crash() -> bool:
	# With no world set, hints stays empty and the method returns early before
	# any label access — reaching this return without crash is the assertion.
	var hud := _make_hud()
	hud._on_day_changed(5)
	hud.free()
	return true
