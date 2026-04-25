## test_game_input_handler.gd — Unit tests for GameInputHandler initial state
## and setup wiring (SPA-1065).
##
## Covers:
##   • Initial state: _game_started false, _tab_npc_index -1, _tab_npc_list empty
##   • All external refs null before setup()
##   • setup() stores all passed references and sets _game_started true
##   • signal objective_recall_requested is declared
##
## Strategy: GameInputHandler extends Node. .new() does not call _ready()
## (none defined), so no scene tree is needed. setup() stores refs directly
## without touching scene nodes.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestGameInputHandler
extends RefCounted

const GameInputHandlerScript := preload("res://scripts/game_input_handler.gd")


static func _make_gih() -> GameInputHandler:
	return GameInputHandlerScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── initial state ──
		"test_initial_game_started_false",
		"test_initial_tab_npc_index_minus_one",
		"test_initial_tab_npc_list_empty",
		"test_initial_world_null",
		"test_initial_camera_null",
		"test_initial_day_night_null",
		"test_initial_rumor_panel_null",
		"test_initial_journal_null",
		"test_initial_social_graph_overlay_null",
		"test_initial_npc_info_panel_null",
		"test_initial_tutorial_banner_null",
		"test_initial_context_controls_null",

		# ── setup() wiring ──
		"test_setup_sets_game_started",
		"test_setup_stores_world_ref",

		# ── signal declared ──
		"test_has_objective_recall_signal",
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
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_game_started_false() -> bool:
	var gih := _make_gih()
	var ok := gih._game_started == false
	gih.free()
	return ok


func test_initial_tab_npc_index_minus_one() -> bool:
	var gih := _make_gih()
	var ok := gih._tab_npc_index == -1
	gih.free()
	return ok


func test_initial_tab_npc_list_empty() -> bool:
	var gih := _make_gih()
	var ok := gih._tab_npc_list.is_empty()
	gih.free()
	return ok


func test_initial_world_null() -> bool:
	var gih := _make_gih()
	var ok := gih._world == null
	gih.free()
	return ok


func test_initial_camera_null() -> bool:
	var gih := _make_gih()
	var ok := gih._camera == null
	gih.free()
	return ok


func test_initial_day_night_null() -> bool:
	var gih := _make_gih()
	var ok := gih._day_night == null
	gih.free()
	return ok


func test_initial_rumor_panel_null() -> bool:
	var gih := _make_gih()
	var ok := gih._rumor_panel == null
	gih.free()
	return ok


func test_initial_journal_null() -> bool:
	var gih := _make_gih()
	var ok := gih._journal == null
	gih.free()
	return ok


func test_initial_social_graph_overlay_null() -> bool:
	var gih := _make_gih()
	var ok := gih._social_graph_overlay == null
	gih.free()
	return ok


func test_initial_npc_info_panel_null() -> bool:
	var gih := _make_gih()
	var ok := gih._npc_info_panel == null
	gih.free()
	return ok


func test_initial_tutorial_banner_null() -> bool:
	var gih := _make_gih()
	var ok := gih._tutorial_banner == null
	gih.free()
	return ok


func test_initial_context_controls_null() -> bool:
	var gih := _make_gih()
	var ok := gih._context_controls == null
	gih.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# setup() wiring
# ══════════════════════════════════════════════════════════════════════════════

func test_setup_sets_game_started() -> bool:
	var gih := _make_gih()
	# Pass all nulls — setup() assigns refs unconditionally; _game_started is set last.
	gih.setup(null, null, null, null, null, null, null, null, null)
	var ok := gih._game_started == true
	gih.free()
	return ok


func test_setup_stores_world_ref() -> bool:
	var gih := _make_gih()
	var fake_world := Node2D.new()
	gih.setup(fake_world, null, null, null, null, null, null, null, null)
	var ok := gih._world == fake_world
	gih.free()
	fake_world.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# Signal declaration
# ══════════════════════════════════════════════════════════════════════════════

func test_has_objective_recall_signal() -> bool:
	var gih := _make_gih()
	var ok := gih.has_signal("objective_recall_requested")
	gih.free()
	return ok
