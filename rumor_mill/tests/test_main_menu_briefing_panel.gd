## test_main_menu_briefing_panel.gd — Unit tests for main_menu_briefing_panel.gd (SPA-1042).
##
## Covers:
##   • Portrait sprite-sheet constants: _PORTRAIT_SPRITE_W/H, _PORTRAIT_IDLE_S_COL
##   • _PORTRAIT_FACTION_ROW entries (merchant, noble, clergy)
##   • _PORTRAIT_BODY_ROW_OFFSET
##   • _PORTRAIT_CLOTHING_BASE entries
##   • _PORTRAIT_COMMONER_ROLES count
##   • Initial public refs: briefing_panel, intro_panel
##   • Initial state: _selected_scenario empty dict
##   • Initial UI refs null
##
## Run from the Godot editor: Scene → Run Script.

class_name TestMainMenuBriefingPanel
extends RefCounted


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_bp() -> MainMenuBriefingPanel:
	return MainMenuBriefingPanel.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Portrait sprite-sheet constants
		"test_portrait_sprite_w",
		"test_portrait_sprite_h",
		"test_portrait_idle_s_col",
		"test_portrait_faction_row_merchant",
		"test_portrait_faction_row_noble",
		"test_portrait_faction_row_clergy",
		"test_portrait_faction_row_count",
		"test_portrait_body_row_offset",
		"test_portrait_clothing_base_merchant",
		"test_portrait_clothing_base_noble",
		"test_portrait_clothing_base_clergy",
		"test_portrait_commoner_roles_count",
		# Initial public refs
		"test_initial_briefing_panel_null",
		"test_initial_intro_panel_null",
		# Initial state
		"test_initial_selected_scenario_empty",
		# Initial UI refs
		"test_initial_briefing_title_null",
		"test_initial_briefing_days_null",
		"test_initial_briefing_body_null",
		"test_initial_btn_begin_null",
		"test_initial_briefing_objective_null",
		"test_initial_briefing_portrait_frame_null",
		"test_initial_difficulty_buttons_empty",
		"test_initial_intro_title_null",
		"test_initial_intro_body_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nMainMenuBriefingPanel tests: %d passed, %d failed" % [passed, failed])


# ── Portrait sprite-sheet constants ──────────────────────────────────────────

static func test_portrait_sprite_w() -> bool:
	var bp := _make_bp()
	var ok := bp._PORTRAIT_SPRITE_W == 64
	bp.free()
	return ok


static func test_portrait_sprite_h() -> bool:
	var bp := _make_bp()
	var ok := bp._PORTRAIT_SPRITE_H == 96
	bp.free()
	return ok


static func test_portrait_idle_s_col() -> bool:
	var bp := _make_bp()
	var ok := bp._PORTRAIT_IDLE_S_COL == 0
	bp.free()
	return ok


static func test_portrait_faction_row_merchant() -> bool:
	var bp := _make_bp()
	var ok := bp._PORTRAIT_FACTION_ROW.get("merchant", -1) == 0
	bp.free()
	return ok


static func test_portrait_faction_row_noble() -> bool:
	var bp := _make_bp()
	var ok := bp._PORTRAIT_FACTION_ROW.get("noble", -1) == 1
	bp.free()
	return ok


static func test_portrait_faction_row_clergy() -> bool:
	var bp := _make_bp()
	var ok := bp._PORTRAIT_FACTION_ROW.get("clergy", -1) == 2
	bp.free()
	return ok


static func test_portrait_faction_row_count() -> bool:
	var bp := _make_bp()
	var ok := bp._PORTRAIT_FACTION_ROW.size() == 3
	bp.free()
	return ok


static func test_portrait_body_row_offset() -> bool:
	var bp := _make_bp()
	var ok := bp._PORTRAIT_BODY_ROW_OFFSET == 9
	bp.free()
	return ok


static func test_portrait_clothing_base_merchant() -> bool:
	var bp := _make_bp()
	var ok := bp._PORTRAIT_CLOTHING_BASE.get("merchant", -1) == 27
	bp.free()
	return ok


static func test_portrait_clothing_base_noble() -> bool:
	var bp := _make_bp()
	var ok := bp._PORTRAIT_CLOTHING_BASE.get("noble", -1) == 30
	bp.free()
	return ok


static func test_portrait_clothing_base_clergy() -> bool:
	var bp := _make_bp()
	var ok := bp._PORTRAIT_CLOTHING_BASE.get("clergy", -1) == 33
	bp.free()
	return ok


static func test_portrait_commoner_roles_count() -> bool:
	var bp := _make_bp()
	var ok := bp._PORTRAIT_COMMONER_ROLES.size() == 6
	bp.free()
	return ok


# ── Initial public refs ───────────────────────────────────────────────────────

static func test_initial_briefing_panel_null() -> bool:
	var bp := _make_bp()
	var ok := bp.briefing_panel == null
	bp.free()
	return ok


static func test_initial_intro_panel_null() -> bool:
	var bp := _make_bp()
	var ok := bp.intro_panel == null
	bp.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_selected_scenario_empty() -> bool:
	var bp := _make_bp()
	var ok := bp._selected_scenario.is_empty()
	bp.free()
	return ok


# ── Initial UI refs (null without build()) ────────────────────────────────────

static func test_initial_briefing_title_null() -> bool:
	var bp := _make_bp()
	var ok := bp._briefing_title == null
	bp.free()
	return ok


static func test_initial_briefing_days_null() -> bool:
	var bp := _make_bp()
	var ok := bp._briefing_days == null
	bp.free()
	return ok


static func test_initial_briefing_body_null() -> bool:
	var bp := _make_bp()
	var ok := bp._briefing_body == null
	bp.free()
	return ok


static func test_initial_btn_begin_null() -> bool:
	var bp := _make_bp()
	var ok := bp._btn_begin == null
	bp.free()
	return ok


static func test_initial_briefing_objective_null() -> bool:
	var bp := _make_bp()
	var ok := bp._briefing_objective == null
	bp.free()
	return ok


static func test_initial_briefing_portrait_frame_null() -> bool:
	var bp := _make_bp()
	var ok := bp._briefing_portrait_frame == null
	bp.free()
	return ok


static func test_initial_difficulty_buttons_empty() -> bool:
	var bp := _make_bp()
	var ok := bp._difficulty_buttons.is_empty()
	bp.free()
	return ok


static func test_initial_intro_title_null() -> bool:
	var bp := _make_bp()
	var ok := bp._intro_title == null
	bp.free()
	return ok


static func test_initial_intro_body_null() -> bool:
	var bp := _make_bp()
	var ok := bp._intro_body == null
	bp.free()
	return ok
