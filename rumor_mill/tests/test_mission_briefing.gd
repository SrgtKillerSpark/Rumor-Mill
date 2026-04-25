## test_mission_briefing.gd — Unit tests for mission_briefing.gd (SPA-1042).
##
## Covers:
##   • Palette constants
##   • Portrait sprite sheet constants: SPRITE_W, SPRITE_H, _IDLE_S_COL
##   • _FACTION_ROW entries, _BODY_TYPE_ROW_OFFSET, _CLOTHING_VAR_BASE
##   • Initial node refs null (no scene tree, _ready() not called)
##   • Initial data fields empty/false
##
## Run from the Godot editor: Scene → Run Script.

class_name TestMissionBriefing
extends RefCounted

const MissionBriefingScript := preload("res://scripts/mission_briefing.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_mb() -> CanvasLayer:
	return MissionBriefingScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_title_warm_gold",
		"test_c_action_green",
		"test_c_danger_red",
		# Portrait constants
		"test_sprite_w",
		"test_sprite_h",
		"test_idle_s_col",
		"test_faction_row_merchant",
		"test_faction_row_noble",
		"test_faction_row_clergy",
		"test_body_type_row_offset",
		"test_clothing_var_base_merchant",
		"test_clothing_var_base_noble",
		"test_clothing_var_base_clergy",
		# Initial node refs
		"test_initial_backdrop_null",
		"test_initial_card_null",
		"test_initial_vbox_null",
		"test_initial_prompt_label_null",
		"test_initial_begin_btn_null",
		"test_initial_pulse_tween_null",
		# Initial data
		"test_initial_objective_one_liner_empty",
		"test_initial_win_condition_line_empty",
		"test_initial_recall_mode_false",
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

	print("\nMissionBriefing tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_title_warm_gold() -> bool:
	var mb := _make_mb()
	var ok := mb.C_TITLE.r > 0.90 and mb.C_TITLE.g > 0.75 and mb.C_TITLE.b < 0.50
	mb.free()
	return ok


static func test_c_action_green() -> bool:
	var mb := _make_mb()
	var ok := mb.C_ACTION.g > 0.80 and mb.C_ACTION.r < 0.70
	mb.free()
	return ok


static func test_c_danger_red() -> bool:
	var mb := _make_mb()
	var ok := mb.C_DANGER.r > 0.85 and mb.C_DANGER.g < 0.45
	mb.free()
	return ok


# ── Portrait sprite sheet constants ──────────────────────────────────────────

static func test_sprite_w() -> bool:
	var mb := _make_mb()
	var ok := mb.SPRITE_W == 64
	mb.free()
	return ok


static func test_sprite_h() -> bool:
	var mb := _make_mb()
	var ok := mb.SPRITE_H == 96
	mb.free()
	return ok


static func test_idle_s_col() -> bool:
	var mb := _make_mb()
	var ok := mb._IDLE_S_COL == 0
	mb.free()
	return ok


static func test_faction_row_merchant() -> bool:
	var mb := _make_mb()
	var ok := mb._FACTION_ROW.get("merchant", -1) == 0
	mb.free()
	return ok


static func test_faction_row_noble() -> bool:
	var mb := _make_mb()
	var ok := mb._FACTION_ROW.get("noble", -1) == 1
	mb.free()
	return ok


static func test_faction_row_clergy() -> bool:
	var mb := _make_mb()
	var ok := mb._FACTION_ROW.get("clergy", -1) == 2
	mb.free()
	return ok


static func test_body_type_row_offset() -> bool:
	var mb := _make_mb()
	var ok := mb._BODY_TYPE_ROW_OFFSET == 9
	mb.free()
	return ok


static func test_clothing_var_base_merchant() -> bool:
	var mb := _make_mb()
	var ok := mb._CLOTHING_VAR_BASE.get("merchant", -1) == 27
	mb.free()
	return ok


static func test_clothing_var_base_noble() -> bool:
	var mb := _make_mb()
	var ok := mb._CLOTHING_VAR_BASE.get("noble", -1) == 30
	mb.free()
	return ok


static func test_clothing_var_base_clergy() -> bool:
	var mb := _make_mb()
	var ok := mb._CLOTHING_VAR_BASE.get("clergy", -1) == 33
	mb.free()
	return ok


# ── Initial node refs ─────────────────────────────────────────────────────────

static func test_initial_backdrop_null() -> bool:
	var mb := _make_mb()
	var ok := mb._backdrop == null
	mb.free()
	return ok


static func test_initial_card_null() -> bool:
	var mb := _make_mb()
	var ok := mb._card == null
	mb.free()
	return ok


static func test_initial_vbox_null() -> bool:
	var mb := _make_mb()
	var ok := mb._vbox == null
	mb.free()
	return ok


static func test_initial_prompt_label_null() -> bool:
	var mb := _make_mb()
	var ok := mb._prompt_label == null
	mb.free()
	return ok


static func test_initial_begin_btn_null() -> bool:
	var mb := _make_mb()
	var ok := mb._begin_btn == null
	mb.free()
	return ok


static func test_initial_pulse_tween_null() -> bool:
	var mb := _make_mb()
	var ok := mb._pulse_tween == null
	mb.free()
	return ok


# ── Initial data fields ───────────────────────────────────────────────────────

static func test_initial_objective_one_liner_empty() -> bool:
	var mb := _make_mb()
	var ok := mb._objective_one_liner == ""
	mb.free()
	return ok


static func test_initial_win_condition_line_empty() -> bool:
	var mb := _make_mb()
	var ok := mb._win_condition_line == ""
	mb.free()
	return ok


static func test_initial_recall_mode_false() -> bool:
	var mb := _make_mb()
	var ok := mb._recall_mode == false
	mb.free()
	return ok


static func test_initial_brief_empty() -> bool:
	var mb := _make_mb()
	var ok := mb._brief.is_empty()
	mb.free()
	return ok
