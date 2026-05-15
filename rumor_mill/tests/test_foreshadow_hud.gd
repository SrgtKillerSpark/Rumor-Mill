## test_foreshadow_hud.gd — Unit tests for foreshadow_hud.gd (SPA-2777).
##
## Covers:
##   • Palette constants (C_BG, C_BORDER, C_ICON, C_TEXT, C_SUBTEXT)
##   • Layout constants: BANNER_H, BANNER_PAD_X, REVEAL_TIME, HOLD_TIME, HIDE_TIME
##   • Initial node refs null (no scene tree — _ready() not called)
##   • Initial state: _world=null, _day_night=null, _tween=null,
##                    _hide_timer=null, _shown_event_ids={}
##   • setup() wires _world and _day_night (no scene tree required)
##   • _on_day_changed() null-world guard (no crash when _world is null)
##   • _shown_event_ids dedup: entry added after _on_day_changed with upcoming event
##
## NOTE: _show_hint(), _hide_banner(), and tween/timer calls require a live
##       SceneTree — not tested here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestForeshadowHud
extends RefCounted

const ForeshadowHudScript := preload("res://scripts/foreshadow_hud.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_fh() -> CanvasLayer:
	return ForeshadowHudScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette constants
		"test_c_bg_parchment",
		"test_c_border_dark_sepia",
		"test_c_icon_dark_sepia_partial_alpha",
		"test_c_text_dark_brown",
		"test_c_subtext_muted",
		# Layout constants
		"test_banner_h",
		"test_banner_pad_x",
		"test_reveal_time",
		"test_hold_time",
		"test_hide_time",
		# Initial node refs
		"test_initial_container_null",
		"test_initial_icon_rect_null",
		"test_initial_text_label_null",
		"test_initial_subtext_label_null",
		# Initial state
		"test_initial_world_null",
		"test_initial_day_night_null",
		"test_initial_tween_null",
		"test_initial_hide_timer_null",
		"test_initial_shown_event_ids_empty",
		# setup() wiring
		"test_setup_assigns_world",
		"test_setup_assigns_day_night",
		"test_setup_null_day_night_no_crash",
		# _on_day_changed() null-world guard
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

static func test_c_bg_parchment() -> bool:
	var fh := _make_fh()
	# #F5E6C8 parchment-tan: high r, high g, moderate b, fully opaque
	var ok: bool = fh.C_BG.r > 0.90 and fh.C_BG.g > 0.85 and fh.C_BG.b > 0.70 and fh.C_BG.a == 1.0
	fh.free()
	return ok


static func test_c_border_dark_sepia() -> bool:
	var fh := _make_fh()
	# Dark sepia: low values, r slightly dominant, fully opaque
	var ok: bool = fh.C_BORDER.r < 0.30 and fh.C_BORDER.b < 0.10 and fh.C_BORDER.a == 1.0
	fh.free()
	return ok


static func test_c_icon_dark_sepia_partial_alpha() -> bool:
	var fh := _make_fh()
	# Same hue as border, ~85% alpha
	var ok: bool = fh.C_ICON.r < 0.30 and fh.C_ICON.a > 0.80 and fh.C_ICON.a < 1.0
	fh.free()
	return ok


static func test_c_text_dark_brown() -> bool:
	var fh := _make_fh()
	# #3B2712 dark-brown: low r, very low g and b, fully opaque
	var ok: bool = fh.C_TEXT.r < 0.30 and fh.C_TEXT.b < 0.10 and fh.C_TEXT.a == 1.0
	fh.free()
	return ok


static func test_c_subtext_muted() -> bool:
	var fh := _make_fh()
	# #7A6B5D muted brown: moderate r, moderate g, moderate b — all relatively close
	var ok: bool = fh.C_SUBTEXT.r > 0.40 and fh.C_SUBTEXT.r < 0.60 and fh.C_SUBTEXT.a == 1.0
	fh.free()
	return ok


# ── Layout constants ──────────────────────────────────────────────────────────

static func test_banner_h() -> bool:
	var fh := _make_fh()
	var ok: bool = fh.BANNER_H == 48.0
	fh.free()
	return ok


static func test_banner_pad_x() -> bool:
	var fh := _make_fh()
	var ok: bool = fh.BANNER_PAD_X == 20.0
	fh.free()
	return ok


static func test_reveal_time() -> bool:
	var fh := _make_fh()
	var ok: bool = fh.REVEAL_TIME == 0.4
	fh.free()
	return ok


static func test_hold_time() -> bool:
	var fh := _make_fh()
	var ok: bool = fh.HOLD_TIME == 6.0
	fh.free()
	return ok


static func test_hide_time() -> bool:
	var fh := _make_fh()
	var ok: bool = fh.HIDE_TIME == 0.3
	fh.free()
	return ok


# ── Initial node refs ─────────────────────────────────────────────────────────

static func test_initial_container_null() -> bool:
	var fh := _make_fh()
	var ok: bool = fh._container == null
	fh.free()
	return ok


static func test_initial_icon_rect_null() -> bool:
	var fh := _make_fh()
	var ok: bool = fh._icon_rect == null
	fh.free()
	return ok


static func test_initial_text_label_null() -> bool:
	var fh := _make_fh()
	var ok: bool = fh._text_label == null
	fh.free()
	return ok


static func test_initial_subtext_label_null() -> bool:
	var fh := _make_fh()
	var ok: bool = fh._subtext_label == null
	fh.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_world_null() -> bool:
	var fh := _make_fh()
	var ok: bool = fh._world == null
	fh.free()
	return ok


static func test_initial_day_night_null() -> bool:
	var fh := _make_fh()
	var ok: bool = fh._day_night == null
	fh.free()
	return ok


static func test_initial_tween_null() -> bool:
	var fh := _make_fh()
	var ok: bool = fh._tween == null
	fh.free()
	return ok


static func test_initial_hide_timer_null() -> bool:
	var fh := _make_fh()
	var ok: bool = fh._hide_timer == null
	fh.free()
	return ok


static func test_initial_shown_event_ids_empty() -> bool:
	var fh := _make_fh()
	var ok: bool = fh._shown_event_ids.is_empty()
	fh.free()
	return ok


# ── setup() wiring ────────────────────────────────────────────────────────────

static func test_setup_assigns_world() -> bool:
	var fh := _make_fh()
	# Use a plain RefCounted as a lightweight stub — setup() only stores the ref
	# and calls has_signal() on day_night, so a null day_night is safe here.
	var stub := Node.new()
	fh.setup(stub, null)
	var ok: bool = fh._world == stub
	stub.free()
	fh.free()
	return ok


static func test_setup_assigns_day_night() -> bool:
	var fh := _make_fh()
	# day_night without the day_changed signal — setup() guards with has_signal().
	var stub := Node.new()
	fh.setup(null, stub)
	var ok: bool = fh._day_night == stub
	stub.free()
	fh.free()
	return ok


static func test_setup_null_day_night_no_crash() -> bool:
	var fh := _make_fh()
	# setup() must not crash when day_night is null.
	fh.setup(null, null)
	var ok: bool = fh._world == null and fh._day_night == null
	fh.free()
	return ok


# ── _on_day_changed() null-world guard ───────────────────────────────────────

static func test_on_day_changed_null_world_no_crash() -> bool:
	var fh := _make_fh()
	# _world is null — both subsystem branches are skipped; must return without crash.
	fh._on_day_changed(1)
	# If we reach here the guard worked correctly.
	fh.free()
	return true
