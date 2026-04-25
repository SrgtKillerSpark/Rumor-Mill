## test_strategic_overview.gd — Unit tests for strategic_overview.gd (SPA-1042).
##
## Covers:
##   • Palette constants
##   • AUTO_DISMISS_SEC constant
##   • Portrait sprite sheet constants
##   • Initial node refs null (no scene tree)
##   • Initial state: _brief empty dict
##
## Run from the Godot editor: Scene → Run Script.

class_name TestStrategicOverview
extends RefCounted

const StrategicOverviewScript := preload("res://scripts/strategic_overview.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_so() -> CanvasLayer:
	return StrategicOverviewScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_title_warm_gold",
		"test_c_hint_green",
		"test_c_timer_fg_amber",
		# AUTO_DISMISS_SEC
		"test_auto_dismiss_sec",
		# Portrait constants
		"test_sprite_w",
		"test_sprite_h",
		"test_idle_s_col",
		"test_faction_row_merchant",
		"test_faction_row_count",
		"test_body_type_row_offset",
		"test_clothing_var_base_merchant",
		# Initial node refs
		"test_initial_backdrop_null",
		"test_initial_card_null",
		"test_initial_vbox_null",
		"test_initial_prompt_label_null",
		"test_initial_pulse_tween_null",
		"test_initial_timer_bar_null",
		# Initial state
		"test_initial_brief_empty",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nStrategicOverview tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_title_warm_gold() -> bool:
	var so := _make_so()
	var ok := so.C_TITLE.r > 0.90 and so.C_TITLE.g > 0.75 and so.C_TITLE.b < 0.50
	so.free()
	return ok


static func test_c_hint_green() -> bool:
	var so := _make_so()
	var ok := so.C_HINT.g > 0.75 and so.C_HINT.r < 0.75
	so.free()
	return ok


static func test_c_timer_fg_amber() -> bool:
	var so := _make_so()
	# amber: high r, moderate g, low b
	var ok := so.C_TIMER_FG.r > 0.90 and so.C_TIMER_FG.g > 0.55 and so.C_TIMER_FG.b < 0.30
	so.free()
	return ok


# ── AUTO_DISMISS_SEC ──────────────────────────────────────────────────────────

static func test_auto_dismiss_sec() -> bool:
	var so := _make_so()
	var ok := so.AUTO_DISMISS_SEC == 15.0
	so.free()
	return ok


# ── Portrait sprite sheet constants ──────────────────────────────────────────

static func test_sprite_w() -> bool:
	var so := _make_so()
	var ok := so.SPRITE_W == 64
	so.free()
	return ok


static func test_sprite_h() -> bool:
	var so := _make_so()
	var ok := so.SPRITE_H == 96
	so.free()
	return ok


static func test_idle_s_col() -> bool:
	var so := _make_so()
	var ok := so._IDLE_S_COL == 0
	so.free()
	return ok


static func test_faction_row_merchant() -> bool:
	var so := _make_so()
	var ok := so._FACTION_ROW.get("merchant", -1) == 0
	so.free()
	return ok


static func test_faction_row_count() -> bool:
	var so := _make_so()
	var ok := so._FACTION_ROW.size() == 3
	so.free()
	return ok


static func test_body_type_row_offset() -> bool:
	var so := _make_so()
	var ok := so._BODY_TYPE_ROW_OFFSET == 9
	so.free()
	return ok


static func test_clothing_var_base_merchant() -> bool:
	var so := _make_so()
	var ok := so._CLOTHING_VAR_BASE.get("merchant", -1) == 27
	so.free()
	return ok


# ── Initial node refs ─────────────────────────────────────────────────────────

static func test_initial_backdrop_null() -> bool:
	var so := _make_so()
	var ok := so._backdrop == null
	so.free()
	return ok


static func test_initial_card_null() -> bool:
	var so := _make_so()
	var ok := so._card == null
	so.free()
	return ok


static func test_initial_vbox_null() -> bool:
	var so := _make_so()
	var ok := so._vbox == null
	so.free()
	return ok


static func test_initial_prompt_label_null() -> bool:
	var so := _make_so()
	var ok := so._prompt_label == null
	so.free()
	return ok


static func test_initial_pulse_tween_null() -> bool:
	var so := _make_so()
	var ok := so._pulse_tween == null
	so.free()
	return ok


static func test_initial_timer_bar_null() -> bool:
	var so := _make_so()
	var ok := so._timer_bar == null
	so.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_brief_empty() -> bool:
	var so := _make_so()
	var ok := so._brief.is_empty()
	so.free()
	return ok
