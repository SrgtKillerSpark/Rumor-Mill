## test_rumor_ripple_vfx.gd — Unit tests for RumorRippleVfx constants and
## initial state (SPA-1065).
##
## Covers:
##   • RING_COUNT == 3
##   • DURATION == 1.5
##   • MAX_RADIUS == 72.0
##   • LINE_WIDTH == 2.5
##   • RING_STAGGER == 0.18
##   • accent_color defaults to warm gold (r ≈ 0.92, g ≈ 0.72, b ≈ 0.18)
##   • _elapsed starts at 0.0
##
## Strategy: RumorRippleVfx extends Node2D. .new() skips _ready() (none defined).
## _process() and _draw() require a scene tree (queue_free / queue_redraw), so
## they are not exercised here — only constants and the mutable default vars are
## checked.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestRumorRippleVfx
extends RefCounted

const RumorRippleVfxScript := preload("res://scripts/rumor_ripple_vfx.gd")


static func _make_vfx() -> Node2D:
	return RumorRippleVfxScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── constants ──
		"test_ring_count_is_3",
		"test_duration_is_1p5",
		"test_max_radius_is_72",
		"test_line_width_is_2p5",
		"test_ring_stagger_is_018",

		# ── initial state ──
		"test_initial_elapsed_zero",
		"test_accent_color_default_r",
		"test_accent_color_default_g",
		"test_accent_color_default_b",
		"test_accent_color_default_alpha",

		# ── accent_color is writable ──
		"test_accent_color_can_be_set",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			print("  FAIL  %s" % method_name)
			failed += 1

	print("\n  %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

func test_ring_count_is_3() -> bool:
	return RumorRippleVfxScript.RING_COUNT == 3


func test_duration_is_1p5() -> bool:
	return absf(RumorRippleVfxScript.DURATION - 1.5) < 0.0001


func test_max_radius_is_72() -> bool:
	return absf(RumorRippleVfxScript.MAX_RADIUS - 72.0) < 0.0001


func test_line_width_is_2p5() -> bool:
	return absf(RumorRippleVfxScript.LINE_WIDTH - 2.5) < 0.0001


func test_ring_stagger_is_018() -> bool:
	return absf(RumorRippleVfxScript.RING_STAGGER - 0.18) < 0.0001


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_elapsed_zero() -> bool:
	var vfx := _make_vfx()
	var ok := absf(vfx._elapsed) < 0.0001
	vfx.free()
	return ok


func test_accent_color_default_r() -> bool:
	var vfx := _make_vfx()
	var ok := absf(vfx.accent_color.r - 0.92) < 0.01
	vfx.free()
	return ok


func test_accent_color_default_g() -> bool:
	var vfx := _make_vfx()
	var ok := absf(vfx.accent_color.g - 0.72) < 0.01
	vfx.free()
	return ok


func test_accent_color_default_b() -> bool:
	var vfx := _make_vfx()
	var ok := absf(vfx.accent_color.b - 0.18) < 0.01
	vfx.free()
	return ok


func test_accent_color_default_alpha() -> bool:
	var vfx := _make_vfx()
	var ok := absf(vfx.accent_color.a - 0.85) < 0.01
	vfx.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# accent_color is writable before add_child
# ══════════════════════════════════════════════════════════════════════════════

func test_accent_color_can_be_set() -> bool:
	var vfx := _make_vfx()
	var new_col := Color(0.45, 0.80, 1.0, 0.75)
	vfx.accent_color = new_col
	var ok := vfx.accent_color == new_col
	vfx.free()
	return ok
