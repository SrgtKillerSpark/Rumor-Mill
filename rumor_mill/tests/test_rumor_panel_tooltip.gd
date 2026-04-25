## test_rumor_panel_tooltip.gd — Unit tests for RumorPanelTooltip (SPA-1027).
##
## Covers:
##   • PERSIST_KEY constant
##   • TOOLTIP_WIDTH, TOOLTIP_HEIGHT constants
##   • STEPS array: size == 3; each step has "title", "body", "anchor" keys
##   • _current_step == 0 before _ready fires (node not added to scene tree)
##
## _build_ui(), show_walkthrough(), _advance(), and is_dismissed() all depend on
## the scene tree or SettingsManager and are not tested here.
## The script extends CanvasLayer with no class_name; tests access it via preload.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestRumorPanelTooltip
extends RefCounted

const _Klass := preload("res://scripts/rumor_panel_tooltip.gd")


## Instantiate without adding to the scene tree so _ready() does not fire.
static func _make() -> CanvasLayer:
	return _Klass.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Constants
		"test_persist_key",
		"test_tooltip_width",
		"test_tooltip_height",

		# STEPS array
		"test_steps_count",
		"test_step_0_has_title",
		"test_step_0_has_body",
		"test_step_0_has_anchor",
		"test_step_1_has_title",
		"test_step_1_has_body",
		"test_step_1_has_anchor",
		"test_step_2_has_title",
		"test_step_2_has_body",
		"test_step_2_has_anchor",

		# Initial state (before _ready)
		"test_initial_current_step_zero",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nRumorPanelTooltip tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

func test_persist_key() -> bool:
	var s := _make()
	return s.PERSIST_KEY == "rumor_panel_walkthrough"


func test_tooltip_width() -> bool:
	var s := _make()
	return s.TOOLTIP_WIDTH == 380


func test_tooltip_height() -> bool:
	var s := _make()
	return s.TOOLTIP_HEIGHT == 220


# ══════════════════════════════════════════════════════════════════════════════
# STEPS array
# ══════════════════════════════════════════════════════════════════════════════

func test_steps_count() -> bool:
	var s := _make()
	return s.STEPS.size() == 3


func test_step_0_has_title() -> bool:
	var s := _make()
	return s.STEPS[0].has("title")


func test_step_0_has_body() -> bool:
	var s := _make()
	return s.STEPS[0].has("body")


func test_step_0_has_anchor() -> bool:
	var s := _make()
	return s.STEPS[0].has("anchor")


func test_step_1_has_title() -> bool:
	var s := _make()
	return s.STEPS[1].has("title")


func test_step_1_has_body() -> bool:
	var s := _make()
	return s.STEPS[1].has("body")


func test_step_1_has_anchor() -> bool:
	var s := _make()
	return s.STEPS[1].has("anchor")


func test_step_2_has_title() -> bool:
	var s := _make()
	return s.STEPS[2].has("title")


func test_step_2_has_body() -> bool:
	var s := _make()
	return s.STEPS[2].has("body")


func test_step_2_has_anchor() -> bool:
	var s := _make()
	return s.STEPS[2].has("anchor")


# ══════════════════════════════════════════════════════════════════════════════
# Initial state (node not yet in scene tree, _ready not called)
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_current_step_zero() -> bool:
	var s := _make()
	return s._current_step == 0
