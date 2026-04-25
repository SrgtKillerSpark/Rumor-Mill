## test_npc_dialogue_panel.gd — Unit tests for NpcDialoguePanel (SPA-1057).
##
## Covers:
##   • Layout constants: PANEL_W, PORTRAIT_W, PORTRAIT_H, PORTRAIT_COLS, _EAVESDROP_RANGE
##   • Palette constants: alpha values for C_BG, C_BORDER, faction-colour constants
##   • Initial state: all runtime refs null (_world_ref, _intel_store, _rumor_panel_ref,
##     _portrait_tex, _canvas, _panel, _current_npc); _dialogue_data is empty dict
##   • _faction_colour(): merchant, noble, clergy return their named constants; unknown → fallback
##   • _faction_drape_colour(): merchant, noble, clergy return their drape constants; unknown → C_DRAPE_DEFAULT
##   • _state_to_dialogue_category(): EVALUATING→"hear", BELIEVE→"believe", SPREAD→"spread",
##     ACT→"act", REJECT→"reject", DEFENDING→"defending"; UNAWARE/EXPIRED → ""
##   • _belief_state_hint(): non-empty for EVALUATING, BELIEVE, SPREAD, ACT, REJECT,
##     DEFENDING, CONTRADICTED; empty string for UNAWARE
##   • _pick_greeting(): unknown faction with empty _dialogue_data → FALLBACK_DEFAULT ("…")
##   • _pick_greeting(): known faction with empty _dialogue_data → non-empty line
##   • FALLBACK_GREETINGS contains keys "merchant", "noble", "clergy"
##   • FALLBACK_DEFAULT equals ["…"]
##
## NpcDialoguePanel extends Node. It has no _ready() method so none of the scene-tree
## setup (canvas creation, resource loading) runs when the script is instantiated orphaned.
## Only pure-data and pure-logic methods are tested here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestNpcDialoguePanel
extends RefCounted

const NpcDialoguePanelScript := preload("res://scripts/npc_dialogue_panel.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_panel() -> Node:
	return NpcDialoguePanelScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Layout constants
		"test_panel_w_constant",
		"test_portrait_w_constant",
		"test_portrait_h_constant",
		"test_portrait_cols_constant",
		"test_eavesdrop_range_constant",

		# Palette alpha checks
		"test_c_bg_has_high_alpha",
		"test_c_border_alpha_one",
		"test_c_faction_merchant_alpha_one",
		"test_c_faction_noble_alpha_one",
		"test_c_faction_clergy_alpha_one",

		# Initial state
		"test_initial_world_ref_null",
		"test_initial_intel_store_null",
		"test_initial_rumor_panel_ref_null",
		"test_initial_portrait_tex_null",
		"test_initial_canvas_null",
		"test_initial_panel_null",
		"test_initial_current_npc_null",
		"test_initial_dialogue_data_empty",

		# _faction_colour
		"test_faction_colour_merchant",
		"test_faction_colour_noble",
		"test_faction_colour_clergy",
		"test_faction_colour_unknown_fallback_alpha_one",

		# _faction_drape_colour
		"test_faction_drape_colour_merchant",
		"test_faction_drape_colour_noble",
		"test_faction_drape_colour_clergy",
		"test_faction_drape_colour_unknown_returns_drape_default",

		# _state_to_dialogue_category
		"test_state_category_evaluating",
		"test_state_category_believe",
		"test_state_category_spread",
		"test_state_category_act",
		"test_state_category_reject",
		"test_state_category_defending",
		"test_state_category_unaware_empty",
		"test_state_category_expired_empty",

		# _belief_state_hint
		"test_belief_hint_evaluating_nonempty",
		"test_belief_hint_believe_nonempty",
		"test_belief_hint_spread_nonempty",
		"test_belief_hint_act_nonempty",
		"test_belief_hint_reject_nonempty",
		"test_belief_hint_defending_nonempty",
		"test_belief_hint_contradicted_nonempty",
		"test_belief_hint_unaware_empty",

		# _pick_greeting
		"test_pick_greeting_unknown_faction_returns_ellipsis",
		"test_pick_greeting_merchant_faction_nonempty",
		"test_pick_greeting_noble_faction_nonempty",
		"test_pick_greeting_clergy_faction_nonempty",

		# FALLBACK_GREETINGS and FALLBACK_DEFAULT
		"test_fallback_greetings_has_merchant_key",
		"test_fallback_greetings_has_noble_key",
		"test_fallback_greetings_has_clergy_key",
		"test_fallback_default_is_ellipsis_array",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nNpcDialoguePanel tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Layout constants
# ══════════════════════════════════════════════════════════════════════════════

static func test_panel_w_constant() -> bool:
	var p := _make_panel()
	var ok := is_equal_approx(p.PANEL_W, 260.0)
	p.free()
	return ok


static func test_portrait_w_constant() -> bool:
	var p := _make_panel()
	var ok := is_equal_approx(p.PORTRAIT_W, 56.0)
	p.free()
	return ok


static func test_portrait_h_constant() -> bool:
	var p := _make_panel()
	var ok := is_equal_approx(p.PORTRAIT_H, 70.0)
	p.free()
	return ok


static func test_portrait_cols_constant() -> bool:
	var p := _make_panel()
	var ok := p.PORTRAIT_COLS == 6
	p.free()
	return ok


static func test_eavesdrop_range_constant() -> bool:
	var p := _make_panel()
	var ok := p._EAVESDROP_RANGE == 3
	p.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# Palette alpha checks
# ══════════════════════════════════════════════════════════════════════════════

static func test_c_bg_has_high_alpha() -> bool:
	var p := _make_panel()
	# C_BG alpha is 0.96 — high but not 1.0
	var ok := p.C_BG.a > 0.9
	p.free()
	return ok


static func test_c_border_alpha_one() -> bool:
	var p := _make_panel()
	var ok := is_equal_approx(p.C_BORDER.a, 1.0)
	p.free()
	return ok


static func test_c_faction_merchant_alpha_one() -> bool:
	var p := _make_panel()
	var ok := is_equal_approx(p.C_FACTION_MERCHANT.a, 1.0)
	p.free()
	return ok


static func test_c_faction_noble_alpha_one() -> bool:
	var p := _make_panel()
	var ok := is_equal_approx(p.C_FACTION_NOBLE.a, 1.0)
	p.free()
	return ok


static func test_c_faction_clergy_alpha_one() -> bool:
	var p := _make_panel()
	var ok := is_equal_approx(p.C_FACTION_CLERGY.a, 1.0)
	p.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

static func test_initial_world_ref_null() -> bool:
	var p := _make_panel()
	var ok := p._world_ref == null
	p.free()
	return ok


static func test_initial_intel_store_null() -> bool:
	var p := _make_panel()
	var ok := p._intel_store == null
	p.free()
	return ok


static func test_initial_rumor_panel_ref_null() -> bool:
	var p := _make_panel()
	var ok := p._rumor_panel_ref == null
	p.free()
	return ok


static func test_initial_portrait_tex_null() -> bool:
	var p := _make_panel()
	var ok := p._portrait_tex == null
	p.free()
	return ok


static func test_initial_canvas_null() -> bool:
	var p := _make_panel()
	var ok := p._canvas == null
	p.free()
	return ok


static func test_initial_panel_null() -> bool:
	var p := _make_panel()
	var ok := p._panel == null
	p.free()
	return ok


static func test_initial_current_npc_null() -> bool:
	var p := _make_panel()
	var ok := p._current_npc == null
	p.free()
	return ok


static func test_initial_dialogue_data_empty() -> bool:
	var p := _make_panel()
	var ok := p._dialogue_data.is_empty()
	p.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# _faction_colour
# ══════════════════════════════════════════════════════════════════════════════

static func test_faction_colour_merchant() -> bool:
	var p := _make_panel()
	var ok := p._faction_colour("merchant") == p.C_FACTION_MERCHANT
	p.free()
	return ok


static func test_faction_colour_noble() -> bool:
	var p := _make_panel()
	var ok := p._faction_colour("noble") == p.C_FACTION_NOBLE
	p.free()
	return ok


static func test_faction_colour_clergy() -> bool:
	var p := _make_panel()
	var ok := p._faction_colour("clergy") == p.C_FACTION_CLERGY
	p.free()
	return ok


static func test_faction_colour_unknown_fallback_alpha_one() -> bool:
	var p := _make_panel()
	# Unknown faction → fallback Color(0.75, 0.70, 0.55, 1.0)
	var c: Color = p._faction_colour("bandit")
	var ok := is_equal_approx(c.a, 1.0) and is_equal_approx(c.r, 0.75)
	p.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# _faction_drape_colour
# ══════════════════════════════════════════════════════════════════════════════

static func test_faction_drape_colour_merchant() -> bool:
	var p := _make_panel()
	var ok := p._faction_drape_colour("merchant") == p.C_DRAPE_MERCHANT
	p.free()
	return ok


static func test_faction_drape_colour_noble() -> bool:
	var p := _make_panel()
	var ok := p._faction_drape_colour("noble") == p.C_DRAPE_NOBLE
	p.free()
	return ok


static func test_faction_drape_colour_clergy() -> bool:
	var p := _make_panel()
	var ok := p._faction_drape_colour("clergy") == p.C_DRAPE_CLERGY
	p.free()
	return ok


static func test_faction_drape_colour_unknown_returns_drape_default() -> bool:
	var p := _make_panel()
	var ok := p._faction_drape_colour("bandit") == p.C_DRAPE_DEFAULT
	p.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# _state_to_dialogue_category
# ══════════════════════════════════════════════════════════════════════════════

static func test_state_category_evaluating() -> bool:
	var p := _make_panel()
	var ok := p._state_to_dialogue_category(Rumor.RumorState.EVALUATING) == "hear"
	p.free()
	return ok


static func test_state_category_believe() -> bool:
	var p := _make_panel()
	var ok := p._state_to_dialogue_category(Rumor.RumorState.BELIEVE) == "believe"
	p.free()
	return ok


static func test_state_category_spread() -> bool:
	var p := _make_panel()
	var ok := p._state_to_dialogue_category(Rumor.RumorState.SPREAD) == "spread"
	p.free()
	return ok


static func test_state_category_act() -> bool:
	var p := _make_panel()
	var ok := p._state_to_dialogue_category(Rumor.RumorState.ACT) == "act"
	p.free()
	return ok


static func test_state_category_reject() -> bool:
	var p := _make_panel()
	var ok := p._state_to_dialogue_category(Rumor.RumorState.REJECT) == "reject"
	p.free()
	return ok


static func test_state_category_defending() -> bool:
	var p := _make_panel()
	var ok := p._state_to_dialogue_category(Rumor.RumorState.DEFENDING) == "defending"
	p.free()
	return ok


static func test_state_category_unaware_empty() -> bool:
	var p := _make_panel()
	var ok := p._state_to_dialogue_category(Rumor.RumorState.UNAWARE) == ""
	p.free()
	return ok


static func test_state_category_expired_empty() -> bool:
	var p := _make_panel()
	var ok := p._state_to_dialogue_category(Rumor.RumorState.EXPIRED) == ""
	p.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# _belief_state_hint
# ══════════════════════════════════════════════════════════════════════════════

static func test_belief_hint_evaluating_nonempty() -> bool:
	var p := _make_panel()
	var ok := not p._belief_state_hint(Rumor.RumorState.EVALUATING).is_empty()
	p.free()
	return ok


static func test_belief_hint_believe_nonempty() -> bool:
	var p := _make_panel()
	var ok := not p._belief_state_hint(Rumor.RumorState.BELIEVE).is_empty()
	p.free()
	return ok


static func test_belief_hint_spread_nonempty() -> bool:
	var p := _make_panel()
	var ok := not p._belief_state_hint(Rumor.RumorState.SPREAD).is_empty()
	p.free()
	return ok


static func test_belief_hint_act_nonempty() -> bool:
	var p := _make_panel()
	var ok := not p._belief_state_hint(Rumor.RumorState.ACT).is_empty()
	p.free()
	return ok


static func test_belief_hint_reject_nonempty() -> bool:
	var p := _make_panel()
	var ok := not p._belief_state_hint(Rumor.RumorState.REJECT).is_empty()
	p.free()
	return ok


static func test_belief_hint_defending_nonempty() -> bool:
	var p := _make_panel()
	var ok := not p._belief_state_hint(Rumor.RumorState.DEFENDING).is_empty()
	p.free()
	return ok


static func test_belief_hint_contradicted_nonempty() -> bool:
	var p := _make_panel()
	var ok := not p._belief_state_hint(Rumor.RumorState.CONTRADICTED).is_empty()
	p.free()
	return ok


static func test_belief_hint_unaware_empty() -> bool:
	var p := _make_panel()
	var ok := p._belief_state_hint(Rumor.RumorState.UNAWARE).is_empty()
	p.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# _pick_greeting
# ══════════════════════════════════════════════════════════════════════════════

## Unknown faction, no dialogue data → FALLBACK_DEFAULT["…"]
static func test_pick_greeting_unknown_faction_returns_ellipsis() -> bool:
	var p := _make_panel()
	# _dialogue_data is empty (setup() not called) so falls through to faction fallback.
	# Unknown faction uses FALLBACK_DEFAULT = ["…"]
	var g: String = p._pick_greeting("", "unknown_faction")
	p.free()
	return g == "…"


## Known factions with no dialogue data → returns a non-empty line from FALLBACK_GREETINGS.
static func test_pick_greeting_merchant_faction_nonempty() -> bool:
	var p := _make_panel()
	var g: String = p._pick_greeting("nobody", "merchant")
	p.free()
	return not g.is_empty()


static func test_pick_greeting_noble_faction_nonempty() -> bool:
	var p := _make_panel()
	var g: String = p._pick_greeting("nobody", "noble")
	p.free()
	return not g.is_empty()


static func test_pick_greeting_clergy_faction_nonempty() -> bool:
	var p := _make_panel()
	var g: String = p._pick_greeting("nobody", "clergy")
	p.free()
	return not g.is_empty()


# ══════════════════════════════════════════════════════════════════════════════
# FALLBACK_GREETINGS / FALLBACK_DEFAULT
# ══════════════════════════════════════════════════════════════════════════════

static func test_fallback_greetings_has_merchant_key() -> bool:
	var p := _make_panel()
	var ok := p.FALLBACK_GREETINGS.has("merchant")
	p.free()
	return ok


static func test_fallback_greetings_has_noble_key() -> bool:
	var p := _make_panel()
	var ok := p.FALLBACK_GREETINGS.has("noble")
	p.free()
	return ok


static func test_fallback_greetings_has_clergy_key() -> bool:
	var p := _make_panel()
	var ok := p.FALLBACK_GREETINGS.has("clergy")
	p.free()
	return ok


static func test_fallback_default_is_ellipsis_array() -> bool:
	var p := _make_panel()
	var ok := p.FALLBACK_DEFAULT.size() == 1 and p.FALLBACK_DEFAULT[0] == "…"
	p.free()
	return ok
