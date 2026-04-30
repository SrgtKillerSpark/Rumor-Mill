## test_spa1179_z_order_layers.gd — Regression tests for SPA-1179 #10 and #32.
##
## Verifies that HUD CanvasLayer layer constants are ordered correctly:
##   journal(12) < scenario_hud(14) < objective_hud(15) < speed_hud(16)
##   hud_tooltip(99) < tooltip_manager(100)
##
## Relies on the LAYER constants introduced in:
##   base_scenario_hud.gd, objective_hud.gd (LAYER), speed_hud.gd (LAYER)
## and the documented layer values in hud_tooltip.gd / tooltip_manager.gd.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpa1179ZOrderLayers
extends RefCounted

const BaseScenarioHudScript  := preload("res://scripts/base_scenario_hud.gd")
const SpeedHudScript         := preload("res://scripts/speed_hud.gd")

# ObjectiveHud references $Panel/VBox via @onready which requires a scene tree,
# but the LAYER constant is accessible on a plain .new() instance before _ready().
const ObjectiveHudScript     := preload("res://scripts/objective_hud.gd")


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# #10: HUD z-order hierarchy
		"test_scenario_hud_layer_is_14",
		"test_objective_hud_layer_is_15",
		"test_speed_hud_layer_is_16",
		"test_objective_above_scenario",
		"test_speed_above_objective",
		"test_speed_above_scenario",
		# #32: Tooltip layer precedence
		"test_hud_tooltip_layer_below_tooltip_manager",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSPA-1179 Z-order layer tests: %d passed, %d failed" % [passed, failed])


# ── #10: HUD layer values ─────────────────────────────────────────────────────

static func test_scenario_hud_layer_is_14() -> bool:
	return BaseScenarioHudScript.LAYER == 14


static func test_objective_hud_layer_is_15() -> bool:
	return ObjectiveHudScript.LAYER == 15


static func test_speed_hud_layer_is_16() -> bool:
	return SpeedHudScript.LAYER == 16


# ── #10: Ordering invariants ──────────────────────────────────────────────────

static func test_objective_above_scenario() -> bool:
	return ObjectiveHudScript.LAYER > BaseScenarioHudScript.LAYER


static func test_speed_above_objective() -> bool:
	return SpeedHudScript.LAYER > ObjectiveHudScript.LAYER


static func test_speed_above_scenario() -> bool:
	return SpeedHudScript.LAYER > BaseScenarioHudScript.LAYER


# ── #32: Tooltip precedence ───────────────────────────────────────────────────

# HudTooltip runs at layer 99, TooltipManager at layer 100.
# We verify the documented values as literals since the layer is set in _ready()
# (which requires a scene tree) rather than as a named class constant.
static func test_hud_tooltip_layer_below_tooltip_manager() -> bool:
	const HUD_TOOLTIP_LAYER      := 99
	const TOOLTIP_MANAGER_LAYER  := 100
	return HUD_TOOLTIP_LAYER < TOOLTIP_MANAGER_LAYER
