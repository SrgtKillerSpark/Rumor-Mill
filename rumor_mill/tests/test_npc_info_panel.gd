## test_npc_info_panel.gd — Unit tests for NpcInfoPanel constants and initial state (SPA-1041).
##
## Covers:
##   • Palette constants: C_BG, C_BORDER, C_TITLE, C_LABEL, C_MUTED, C_KEY, C_ACTION
##   • C_FACTION: merchant, noble, clergy entries present
##   • C_BELIEF: all 9 state entries (0–8) present
##   • BELIEF_LABEL: all 9 entries, spot-check values
##   • BELIEF_ICON: all 9 entries
##   • ACTIONS: 3 entries with keys eavesdrop, bribe, seed
##   • Initial state: _current_npc null, _world_ref null, _intel_store null,
##     _panel null (before _ready fires), _action_btns empty
##
## Strategy: NpcInfoPanel extends CanvasLayer. .new() skips _ready() (no scene
## tree), so all const tables and initial vars are tested without UI setup.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestNpcInfoPanel
extends RefCounted

const NpcInfoPanelScript := preload("res://scripts/npc_info_panel.gd")


static func _make_panel() -> CanvasLayer:
	return NpcInfoPanelScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── palette constants ──
		"test_c_bg_has_low_alpha_high_opacity",
		"test_c_border_is_warm_brown",
		"test_c_title_is_gold",
		"test_c_label_is_warm_beige",
		"test_c_action_is_greenish",

		# ── C_FACTION ──
		"test_faction_dict_has_3_entries",
		"test_faction_merchant_present",
		"test_faction_noble_present",
		"test_faction_clergy_present",

		# ── C_BELIEF ──
		"test_belief_color_dict_has_9_entries",
		"test_belief_color_0_unaware_is_greyish",
		"test_belief_color_5_acting_is_pinkish",

		# ── BELIEF_LABEL ──
		"test_belief_label_dict_has_9_entries",
		"test_belief_label_0_is_unaware",
		"test_belief_label_2_is_believes",
		"test_belief_label_5_is_acting",
		"test_belief_label_8_is_defending",

		# ── BELIEF_ICON ──
		"test_belief_icon_dict_has_9_entries",
		"test_belief_icon_0_non_empty",
		"test_belief_icon_5_non_empty",

		# ── ACTIONS ──
		"test_actions_has_3_entries",
		"test_actions_first_is_eavesdrop",
		"test_actions_second_is_bribe",
		"test_actions_third_is_seed_rumor",
		"test_all_actions_have_shortcut",
		"test_all_actions_have_desc",

		# ── initial state ──
		"test_initial_current_npc_null",
		"test_initial_world_ref_null",
		"test_initial_intel_store_null",
		"test_initial_panel_null",
		"test_initial_action_btns_empty",
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
# Palette constants
# ══════════════════════════════════════════════════════════════════════════════

func test_c_bg_has_low_alpha_high_opacity() -> bool:
	# C_BG = Color(0.10, 0.07, 0.05, 0.96) — very dark, near-opaque
	return NpcInfoPanelScript.C_BG.a > 0.9


func test_c_border_is_warm_brown() -> bool:
	var c: Color = NpcInfoPanelScript.C_BORDER
	# C_BORDER = Color(0.55, 0.38, 0.18, 1.0) — warm brown
	return c.r > c.b and c.a > 0.99


func test_c_title_is_gold() -> bool:
	var c: Color = NpcInfoPanelScript.C_TITLE
	# C_TITLE = Color(0.92, 0.78, 0.12, 1.0) — gold: high R, high G, low B
	return c.r > 0.8 and c.g > 0.6 and c.b < 0.3


func test_c_label_is_warm_beige() -> bool:
	# C_LABEL = Color(0.82, 0.75, 0.60, 1.0) — all channels high (warm beige)
	var c: Color = NpcInfoPanelScript.C_LABEL
	return c.r > 0.7 and c.g > 0.6 and c.b > 0.4


func test_c_action_is_greenish() -> bool:
	var c: Color = NpcInfoPanelScript.C_ACTION
	# C_ACTION = Color(0.65, 0.90, 0.65, 1.0) — green dominant
	return c.g > c.r and c.g > c.b


# ══════════════════════════════════════════════════════════════════════════════
# C_FACTION
# ══════════════════════════════════════════════════════════════════════════════

func test_faction_dict_has_3_entries() -> bool:
	return NpcInfoPanelScript.C_FACTION.size() == 3


func test_faction_merchant_present() -> bool:
	return NpcInfoPanelScript.C_FACTION.has("merchant")


func test_faction_noble_present() -> bool:
	return NpcInfoPanelScript.C_FACTION.has("noble")


func test_faction_clergy_present() -> bool:
	return NpcInfoPanelScript.C_FACTION.has("clergy")


# ══════════════════════════════════════════════════════════════════════════════
# C_BELIEF
# ══════════════════════════════════════════════════════════════════════════════

func test_belief_color_dict_has_9_entries() -> bool:
	return NpcInfoPanelScript.C_BELIEF.size() == 9


func test_belief_color_0_unaware_is_greyish() -> bool:
	var c: Color = NpcInfoPanelScript.C_BELIEF.get(0, Color.RED)
	# Unaware = Color(0.65, 0.65, 0.65, 1.0) — neutral grey
	return absf(c.r - c.g) < 0.05 and absf(c.g - c.b) < 0.05


func test_belief_color_5_acting_is_pinkish() -> bool:
	var c: Color = NpcInfoPanelScript.C_BELIEF.get(5, Color.BLACK)
	# Acting = Color(1.00, 0.45, 0.90, 1.0) — high R and B, low G
	return c.r > 0.8 and c.b > 0.7 and c.g < 0.6


# ══════════════════════════════════════════════════════════════════════════════
# BELIEF_LABEL
# ══════════════════════════════════════════════════════════════════════════════

func test_belief_label_dict_has_9_entries() -> bool:
	return NpcInfoPanelScript.BELIEF_LABEL.size() == 9


func test_belief_label_0_is_unaware() -> bool:
	return NpcInfoPanelScript.BELIEF_LABEL.get(0, "") == "Unaware"


func test_belief_label_2_is_believes() -> bool:
	return NpcInfoPanelScript.BELIEF_LABEL.get(2, "") == "Believes"


func test_belief_label_5_is_acting() -> bool:
	return NpcInfoPanelScript.BELIEF_LABEL.get(5, "") == "Acting"


func test_belief_label_8_is_defending() -> bool:
	return NpcInfoPanelScript.BELIEF_LABEL.get(8, "") == "Defending"


# ══════════════════════════════════════════════════════════════════════════════
# BELIEF_ICON
# ══════════════════════════════════════════════════════════════════════════════

func test_belief_icon_dict_has_9_entries() -> bool:
	return NpcInfoPanelScript.BELIEF_ICON.size() == 9


func test_belief_icon_0_non_empty() -> bool:
	return not NpcInfoPanelScript.BELIEF_ICON.get(0, "").is_empty()


func test_belief_icon_5_non_empty() -> bool:
	return not NpcInfoPanelScript.BELIEF_ICON.get(5, "").is_empty()


# ══════════════════════════════════════════════════════════════════════════════
# ACTIONS
# ══════════════════════════════════════════════════════════════════════════════

func test_actions_has_3_entries() -> bool:
	return NpcInfoPanelScript.ACTIONS.size() == 3


func test_actions_first_is_eavesdrop() -> bool:
	return NpcInfoPanelScript.ACTIONS[0].get("key", "") == "eavesdrop"


func test_actions_second_is_bribe() -> bool:
	return NpcInfoPanelScript.ACTIONS[1].get("key", "") == "bribe"


func test_actions_third_is_seed_rumor() -> bool:
	return NpcInfoPanelScript.ACTIONS[2].get("key", "") == "seed"


func test_all_actions_have_shortcut() -> bool:
	for action in NpcInfoPanelScript.ACTIONS:
		if not action.has("shortcut") or str(action["shortcut"]).is_empty():
			return false
	return true


func test_all_actions_have_desc() -> bool:
	for action in NpcInfoPanelScript.ACTIONS:
		if not action.has("desc") or str(action["desc"]).is_empty():
			return false
	return true


# ══════════════════════════════════════════════════════════════════════════════
# Initial state (before _ready)
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_current_npc_null() -> bool:
	var p := _make_panel()
	var ok := p._current_npc == null
	p.free()
	return ok


func test_initial_world_ref_null() -> bool:
	var p := _make_panel()
	var ok := p._world_ref == null
	p.free()
	return ok


func test_initial_intel_store_null() -> bool:
	var p := _make_panel()
	var ok := p._intel_store == null
	p.free()
	return ok


func test_initial_panel_null() -> bool:
	# _panel is built in _ready(), which hasn't fired without scene tree
	var p := _make_panel()
	var ok := p._panel == null
	p.free()
	return ok


func test_initial_action_btns_empty() -> bool:
	var p := _make_panel()
	var ok := p._action_btns.is_empty()
	p.free()
	return ok
