## test_visual_affordances.gd — Unit tests for visual_affordances.gd (SPA-1042).
##
## Covers:
##   • Palette constants: C_NPC_GLOW, C_BUILDING_GLOW, C_NEXT_STEP
##   • FADE_OUT_ACTIONS, FADE_OUT_DAY constants
##   • Initial state: refs null, _enabled=true, counters at zero
##
## Run from the Godot editor: Scene → Run Script.

class_name TestVisualAffordances
extends RefCounted

const VisualAffordancesScript := preload("res://scripts/visual_affordances.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_va() -> CanvasLayer:
	return VisualAffordancesScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_npc_glow_very_subtle",
		"test_c_next_step_brighter_than_npc",
		# Constants
		"test_fade_out_actions",
		"test_fade_out_day",
		# Initial state
		"test_initial_world_ref_null",
		"test_initial_day_night_ref_null",
		"test_initial_action_count_zero",
		"test_initial_enabled_true",
		"test_initial_pulse_phase_zero",
		"test_initial_npc_rings_empty",
		"test_initial_fading_out_false",
		"test_initial_single_target_poly_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nVisualAffordances tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_npc_glow_very_subtle() -> bool:
	var va := _make_va()
	# very subtle: very low alpha (≤0.20)
	var ok := va.C_NPC_GLOW.a <= 0.20
	va.free()
	return ok


static func test_c_next_step_brighter_than_npc() -> bool:
	var va := _make_va()
	# next-step glow should be more opaque than base NPC glow
	var ok := va.C_NEXT_STEP.a > va.C_NPC_GLOW.a
	va.free()
	return ok


# ── Constants ─────────────────────────────────────────────────────────────────

static func test_fade_out_actions() -> bool:
	var va := _make_va()
	var ok := va.FADE_OUT_ACTIONS == 5
	va.free()
	return ok


static func test_fade_out_day() -> bool:
	var va := _make_va()
	var ok := va.FADE_OUT_DAY == 4
	va.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_world_ref_null() -> bool:
	var va := _make_va()
	var ok := va._world_ref == null
	va.free()
	return ok


static func test_initial_day_night_ref_null() -> bool:
	var va := _make_va()
	var ok := va._day_night_ref == null
	va.free()
	return ok


static func test_initial_action_count_zero() -> bool:
	var va := _make_va()
	var ok := va._action_count == 0
	va.free()
	return ok


static func test_initial_enabled_true() -> bool:
	var va := _make_va()
	var ok := va._enabled == true
	va.free()
	return ok


static func test_initial_pulse_phase_zero() -> bool:
	var va := _make_va()
	var ok := va._pulse_phase == 0.0
	va.free()
	return ok


static func test_initial_npc_rings_empty() -> bool:
	var va := _make_va()
	var ok := va._npc_rings.is_empty()
	va.free()
	return ok


static func test_initial_fading_out_false() -> bool:
	var va := _make_va()
	var ok := va._fading_out == false
	va.free()
	return ok


static func test_initial_single_target_poly_null() -> bool:
	var va := _make_va()
	var ok := va._single_target_poly == null
	va.free()
	return ok
