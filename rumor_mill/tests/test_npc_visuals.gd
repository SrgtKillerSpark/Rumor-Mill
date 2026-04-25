## test_npc_visuals.gd — Unit tests for NpcVisuals sub-module (SPA-1027).
##
## Covers:
##   • Sprite sheet layout constants: SPRITE_W, SPRITE_H, FACTION_ROW, ARCHETYPE_ROW
##   • STATE_TINT — entry count and each RumorState has a defined tint
##   • STATE_EMOTES — 6 entries; EVALUATING, BELIEVE, SPREAD, ACT, REJECT, DEFENDING
##   • NPC_HOVER_TINT constant
##   • COMMONER_ROLES — non-empty array
##   • CLOTHING_VAR_BASE — merchant, noble, clergy keys present
##   • Initial state: _npc, _sprite, _name_label, _faction_badge, _selection_ring,
##                    _thought_bubble are null; _hovered is false
##
## Strategy: preload npc_visuals.gd as an orphaned Node. setup() is never called so
## all @onready and init vars remain null. Only constants and initial field values
## are inspected — no scene-tree operations.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestNpcVisuals
extends RefCounted

const NpcVisualsScript := preload("res://scripts/npc_visuals.gd")


# ── helpers ───────────────────────────────────────────────────────────────────

static func _make_visuals() -> Node:
	return NpcVisualsScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Sprite layout constants
		"test_sprite_w_constant",
		"test_sprite_h_constant",
		"test_faction_row_merchant",
		"test_faction_row_noble",
		"test_faction_row_clergy",
		"test_archetype_row_has_guard_civic",
		"test_archetype_row_has_spy",
		"test_commoner_roles_nonempty",
		"test_clothing_var_base_has_merchant",
		"test_clothing_var_base_has_noble",
		"test_clothing_var_base_has_clergy",

		# STATE_TINT
		"test_state_tint_has_nine_entries",
		"test_state_tint_unaware_is_white",
		"test_state_tint_evaluating_defined",
		"test_state_tint_believe_defined",
		"test_state_tint_spread_defined",
		"test_state_tint_act_defined",
		"test_state_tint_reject_defined",
		"test_state_tint_contradicted_defined",
		"test_state_tint_expired_defined",
		"test_state_tint_defending_defined",

		# STATE_EMOTES
		"test_state_emotes_has_six_entries",
		"test_state_emotes_evaluating_nonempty",
		"test_state_emotes_believe_nonempty",
		"test_state_emotes_spread_nonempty",
		"test_state_emotes_act_nonempty",
		"test_state_emotes_reject_nonempty",
		"test_state_emotes_defending_nonempty",

		# NPC_HOVER_TINT
		"test_npc_hover_tint_defined",

		# Initial state
		"test_initial_npc_null",
		"test_initial_hovered_false",
		"test_initial_ripple_radius_zero",
		"test_initial_ripple_alpha_zero",
		"test_initial_cached_state_tint_white",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nNpcVisuals tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Sprite layout constants
# ══════════════════════════════════════════════════════════════════════════════

func test_sprite_w_constant() -> bool:
	var v := _make_visuals()
	var ok := v.SPRITE_W == 64
	v.free()
	return ok


func test_sprite_h_constant() -> bool:
	var v := _make_visuals()
	var ok := v.SPRITE_H == 96
	v.free()
	return ok


func test_faction_row_merchant() -> bool:
	var v := _make_visuals()
	var ok := v.FACTION_ROW.has("merchant") and v.FACTION_ROW["merchant"] == 0
	v.free()
	return ok


func test_faction_row_noble() -> bool:
	var v := _make_visuals()
	var ok := v.FACTION_ROW.has("noble") and v.FACTION_ROW["noble"] == 1
	v.free()
	return ok


func test_faction_row_clergy() -> bool:
	var v := _make_visuals()
	var ok := v.FACTION_ROW.has("clergy") and v.FACTION_ROW["clergy"] == 2
	v.free()
	return ok


func test_archetype_row_has_guard_civic() -> bool:
	var v := _make_visuals()
	var ok := v.ARCHETYPE_ROW.has("guard_civic")
	v.free()
	return ok


func test_archetype_row_has_spy() -> bool:
	var v := _make_visuals()
	var ok := v.ARCHETYPE_ROW.has("spy")
	v.free()
	return ok


func test_commoner_roles_nonempty() -> bool:
	var v := _make_visuals()
	var ok := not (v.COMMONER_ROLES as Array).is_empty()
	v.free()
	return ok


func test_clothing_var_base_has_merchant() -> bool:
	var v := _make_visuals()
	var ok := v.CLOTHING_VAR_BASE.has("merchant")
	v.free()
	return ok


func test_clothing_var_base_has_noble() -> bool:
	var v := _make_visuals()
	var ok := v.CLOTHING_VAR_BASE.has("noble")
	v.free()
	return ok


func test_clothing_var_base_has_clergy() -> bool:
	var v := _make_visuals()
	var ok := v.CLOTHING_VAR_BASE.has("clergy")
	v.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# STATE_TINT
# ══════════════════════════════════════════════════════════════════════════════

func test_state_tint_has_nine_entries() -> bool:
	var v := _make_visuals()
	var ok := (v.STATE_TINT as Dictionary).size() == 9
	v.free()
	return ok


func test_state_tint_unaware_is_white() -> bool:
	var v := _make_visuals()
	var ok := v.STATE_TINT[Rumor.RumorState.UNAWARE] == Color.WHITE
	v.free()
	return ok


func test_state_tint_evaluating_defined() -> bool:
	var v := _make_visuals()
	var ok := v.STATE_TINT.has(Rumor.RumorState.EVALUATING)
	v.free()
	return ok


func test_state_tint_believe_defined() -> bool:
	var v := _make_visuals()
	var ok := v.STATE_TINT.has(Rumor.RumorState.BELIEVE)
	v.free()
	return ok


func test_state_tint_spread_defined() -> bool:
	var v := _make_visuals()
	var ok := v.STATE_TINT.has(Rumor.RumorState.SPREAD)
	v.free()
	return ok


func test_state_tint_act_defined() -> bool:
	var v := _make_visuals()
	var ok := v.STATE_TINT.has(Rumor.RumorState.ACT)
	v.free()
	return ok


func test_state_tint_reject_defined() -> bool:
	var v := _make_visuals()
	var ok := v.STATE_TINT.has(Rumor.RumorState.REJECT)
	v.free()
	return ok


func test_state_tint_contradicted_defined() -> bool:
	var v := _make_visuals()
	var ok := v.STATE_TINT.has(Rumor.RumorState.CONTRADICTED)
	v.free()
	return ok


func test_state_tint_expired_defined() -> bool:
	var v := _make_visuals()
	var ok := v.STATE_TINT.has(Rumor.RumorState.EXPIRED)
	v.free()
	return ok


func test_state_tint_defending_defined() -> bool:
	var v := _make_visuals()
	var ok := v.STATE_TINT.has(Rumor.RumorState.DEFENDING)
	v.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# STATE_EMOTES
# ══════════════════════════════════════════════════════════════════════════════

func test_state_emotes_has_six_entries() -> bool:
	var v := _make_visuals()
	var ok := (v.STATE_EMOTES as Dictionary).size() == 6
	v.free()
	return ok


func test_state_emotes_evaluating_nonempty() -> bool:
	var v := _make_visuals()
	var ok := v.STATE_EMOTES.has("EVALUATING") and not (v.STATE_EMOTES["EVALUATING"] as String).is_empty()
	v.free()
	return ok


func test_state_emotes_believe_nonempty() -> bool:
	var v := _make_visuals()
	var ok := v.STATE_EMOTES.has("BELIEVE") and not (v.STATE_EMOTES["BELIEVE"] as String).is_empty()
	v.free()
	return ok


func test_state_emotes_spread_nonempty() -> bool:
	var v := _make_visuals()
	var ok := v.STATE_EMOTES.has("SPREAD") and not (v.STATE_EMOTES["SPREAD"] as String).is_empty()
	v.free()
	return ok


func test_state_emotes_act_nonempty() -> bool:
	var v := _make_visuals()
	var ok := v.STATE_EMOTES.has("ACT") and not (v.STATE_EMOTES["ACT"] as String).is_empty()
	v.free()
	return ok


func test_state_emotes_reject_nonempty() -> bool:
	var v := _make_visuals()
	var ok := v.STATE_EMOTES.has("REJECT") and not (v.STATE_EMOTES["REJECT"] as String).is_empty()
	v.free()
	return ok


func test_state_emotes_defending_nonempty() -> bool:
	var v := _make_visuals()
	var ok := v.STATE_EMOTES.has("DEFENDING") and not (v.STATE_EMOTES["DEFENDING"] as String).is_empty()
	v.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# NPC_HOVER_TINT
# ══════════════════════════════════════════════════════════════════════════════

func test_npc_hover_tint_defined() -> bool:
	var v := _make_visuals()
	# Hover tint should be a super-bright colour — all components > 1 in at least one channel.
	var tint: Color = v.NPC_HOVER_TINT
	var ok := tint.r > 1.0 or tint.g > 1.0 or tint.b > 1.0
	v.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_npc_null() -> bool:
	var v := _make_visuals()
	var ok := v._npc == null
	v.free()
	return ok


func test_initial_hovered_false() -> bool:
	var v := _make_visuals()
	var ok := v._hovered == false
	v.free()
	return ok


func test_initial_ripple_radius_zero() -> bool:
	var v := _make_visuals()
	var ok := is_equal_approx(v._ripple_radius, 0.0)
	v.free()
	return ok


func test_initial_ripple_alpha_zero() -> bool:
	var v := _make_visuals()
	var ok := is_equal_approx(v._ripple_alpha, 0.0)
	v.free()
	return ok


func test_initial_cached_state_tint_white() -> bool:
	var v := _make_visuals()
	var ok := v._cached_state_tint == Color.WHITE
	v.free()
	return ok
