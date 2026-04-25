## test_npc.gd — Unit tests for the Npc coordinator constants and initial state
## (SPA-1065).
##
## Covers:
##   • Grid constants: TILE_W == 64, TILE_H == 32, SPREAD_RADIUS == 8
##   • Defender constants: _DEFENDER_PENALTY, _DEFENDER_DURATION, _DEFENSE_PENALTY_CAP,
##     _DEFENSE_MOD_DURATION
##   • Credulity modifier bounds: _CREDULITY_MODIFIER_FLOOR, _CREDULITY_MODIFIER_CEILING,
##     _CREDULITY_ACT_GAIN, _CREDULITY_REJECT_PENALTY
##   • Initial state: npc_data {}, rumor_slots {}, rumor_history [],
##     _avoided_subject_ids [], _defense_modifiers {}, _defense_modifier_ticks {},
##     _is_defending false, _worst_state_dirty true, _credulity_modifier 0.0,
##     mood_speed_scale 1.0
##   • Personality defaults: _credulity, _sociability, _loyalty, _temperament == 0.5
##   • Subsystem refs null before _ready()
##   • Signal declarations present
##
## Strategy: Npc extends Node2D. .new() does not call _ready(); @onready vars
## that require $Sprite etc. remain at their declared defaults (null). The
## archetype field references NpcSchedule.ScheduleArchetype which is a
## registered global class — safe to access.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestNpc
extends RefCounted

const NpcScript := preload("res://scripts/npc.gd")


static func _make_npc() -> Node2D:
	return NpcScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── grid constants ──
		"test_tile_w_is_64",
		"test_tile_h_is_32",
		"test_spread_radius_is_8",

		# ── defender constants ──
		"test_defender_penalty_value",
		"test_defender_duration_is_5",
		"test_defense_penalty_cap",
		"test_defense_mod_duration_is_3",

		# ── credulity modifier bounds ──
		"test_credulity_modifier_floor",
		"test_credulity_modifier_ceiling",
		"test_credulity_act_gain",
		"test_credulity_reject_penalty",

		# ── initial state ──
		"test_initial_npc_data_empty",
		"test_initial_rumor_slots_empty",
		"test_initial_rumor_history_empty",
		"test_initial_avoided_subject_ids_empty",
		"test_initial_defense_modifiers_empty",
		"test_initial_defense_modifier_ticks_empty",
		"test_initial_is_defending_false",
		"test_initial_worst_state_dirty_true",
		"test_initial_credulity_modifier_zero",
		"test_initial_mood_speed_scale_one",

		# ── personality defaults ──
		"test_initial_credulity_half",
		"test_initial_sociability_half",
		"test_initial_loyalty_half",
		"test_initial_temperament_half",

		# ── subsystem module refs null ──
		"test_initial_movement_null",
		"test_initial_dialogue_null",
		"test_initial_visuals_null",
		"test_initial_rumor_processing_null",

		# ── signal declarations ──
		"test_has_rumor_state_changed_signal",
		"test_has_rumor_transmitted_signal",
		"test_has_npc_hovered_signal",
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
# Grid constants
# ══════════════════════════════════════════════════════════════════════════════

func test_tile_w_is_64() -> bool:
	return NpcScript.TILE_W == 64


func test_tile_h_is_32() -> bool:
	return NpcScript.TILE_H == 32


func test_spread_radius_is_8() -> bool:
	return NpcScript.SPREAD_RADIUS == 8


# ══════════════════════════════════════════════════════════════════════════════
# Defender constants
# ══════════════════════════════════════════════════════════════════════════════

func test_defender_penalty_value() -> bool:
	return absf(NpcScript._DEFENDER_PENALTY - 0.15) < 0.0001


func test_defender_duration_is_5() -> bool:
	return NpcScript._DEFENDER_DURATION == 5


func test_defense_penalty_cap() -> bool:
	return absf(NpcScript._DEFENSE_PENALTY_CAP - 0.30) < 0.0001


func test_defense_mod_duration_is_3() -> bool:
	return NpcScript._DEFENSE_MOD_DURATION == 3


# ══════════════════════════════════════════════════════════════════════════════
# Credulity modifier bounds
# ══════════════════════════════════════════════════════════════════════════════

func test_credulity_modifier_floor() -> bool:
	return absf(NpcScript._CREDULITY_MODIFIER_FLOOR - (-0.15)) < 0.0001


func test_credulity_modifier_ceiling() -> bool:
	return absf(NpcScript._CREDULITY_MODIFIER_CEILING - 0.15) < 0.0001


func test_credulity_act_gain() -> bool:
	return absf(NpcScript._CREDULITY_ACT_GAIN - 0.10) < 0.0001


func test_credulity_reject_penalty() -> bool:
	return absf(NpcScript._CREDULITY_REJECT_PENALTY - (-0.05)) < 0.0001


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_npc_data_empty() -> bool:
	var npc := _make_npc()
	var ok := npc.npc_data.is_empty()
	npc.free()
	return ok


func test_initial_rumor_slots_empty() -> bool:
	var npc := _make_npc()
	var ok := npc.rumor_slots.is_empty()
	npc.free()
	return ok


func test_initial_rumor_history_empty() -> bool:
	var npc := _make_npc()
	var ok := npc.rumor_history.is_empty()
	npc.free()
	return ok


func test_initial_avoided_subject_ids_empty() -> bool:
	var npc := _make_npc()
	var ok := npc._avoided_subject_ids.is_empty()
	npc.free()
	return ok


func test_initial_defense_modifiers_empty() -> bool:
	var npc := _make_npc()
	var ok := npc._defense_modifiers.is_empty()
	npc.free()
	return ok


func test_initial_defense_modifier_ticks_empty() -> bool:
	var npc := _make_npc()
	var ok := npc._defense_modifier_ticks.is_empty()
	npc.free()
	return ok


func test_initial_is_defending_false() -> bool:
	var npc := _make_npc()
	var ok := npc._is_defending == false
	npc.free()
	return ok


func test_initial_worst_state_dirty_true() -> bool:
	var npc := _make_npc()
	var ok := npc._worst_state_dirty == true
	npc.free()
	return ok


func test_initial_credulity_modifier_zero() -> bool:
	var npc := _make_npc()
	var ok := absf(npc._credulity_modifier) < 0.0001
	npc.free()
	return ok


func test_initial_mood_speed_scale_one() -> bool:
	var npc := _make_npc()
	var ok := absf(npc.mood_speed_scale - 1.0) < 0.0001
	npc.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# Personality defaults
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_credulity_half() -> bool:
	var npc := _make_npc()
	var ok := absf(npc._credulity - 0.5) < 0.0001
	npc.free()
	return ok


func test_initial_sociability_half() -> bool:
	var npc := _make_npc()
	var ok := absf(npc._sociability - 0.5) < 0.0001
	npc.free()
	return ok


func test_initial_loyalty_half() -> bool:
	var npc := _make_npc()
	var ok := absf(npc._loyalty - 0.5) < 0.0001
	npc.free()
	return ok


func test_initial_temperament_half() -> bool:
	var npc := _make_npc()
	var ok := absf(npc._temperament - 0.5) < 0.0001
	npc.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# Subsystem module refs null before _ready()
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_movement_null() -> bool:
	var npc := _make_npc()
	var ok := npc._movement == null
	npc.free()
	return ok


func test_initial_dialogue_null() -> bool:
	var npc := _make_npc()
	var ok := npc._dialogue == null
	npc.free()
	return ok


func test_initial_visuals_null() -> bool:
	var npc := _make_npc()
	var ok := npc._visuals == null
	npc.free()
	return ok


func test_initial_rumor_processing_null() -> bool:
	var npc := _make_npc()
	var ok := npc._rumor_processing == null
	npc.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# Signal declarations
# ══════════════════════════════════════════════════════════════════════════════

func test_has_rumor_state_changed_signal() -> bool:
	var npc := _make_npc()
	var ok := npc.has_signal("rumor_state_changed")
	npc.free()
	return ok


func test_has_rumor_transmitted_signal() -> bool:
	var npc := _make_npc()
	var ok := npc.has_signal("rumor_transmitted")
	npc.free()
	return ok


func test_has_npc_hovered_signal() -> bool:
	var npc := _make_npc()
	var ok := npc.has_signal("npc_hovered")
	npc.free()
	return ok
