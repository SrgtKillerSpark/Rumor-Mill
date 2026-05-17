## test_event_aftermath_screen.gd — Unit tests for event_aftermath_screen.gd (SPA-2745, SPA-2920).
##
## Covers:
##   • Palette constants (C_BACKDROP, C_STAT_UP, C_STAT_DOWN, C_ITEM_GAIN, C_ITEM_COST,
##                         C_HEADER, C_BTN_BG)
##   • Panel/timing constants (PANEL_W, PANEL_H, REVEAL_TIME)
##   • Signal declaration (aftermath_dismissed)
##   • Initial node refs null (before _ready / scene-tree entry)
##   • Initial state (_world null)
##   • _format_effects(): empty dict returns "", reputation/heat deltas, suspicion freeze,
##                         4-line cap with overflow note
##   • SPA-2920 causality strings: each effect type, no-world fallback, graceful omission

class_name TestEventAftermathScreen
extends RefCounted

const EventAftermathScript := preload("res://scripts/event_aftermath_screen.gd")


static func _make_eas() -> CanvasLayer:
	return EventAftermathScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette constants
		"test_c_backdrop_near_black",
		"test_c_stat_up_forest_green",
		"test_c_stat_down_rust_red",
		"test_c_item_gain_gold",
		"test_c_item_cost_muted",
		"test_c_header_dark_brown",
		"test_c_btn_bg_dark",
		# Panel/timing constants
		"test_panel_w",
		"test_panel_h",
		"test_reveal_time",
		# Signal
		"test_aftermath_dismissed_signal_declared",
		# Initial node refs null
		"test_initial_backdrop_null",
		"test_initial_panel_null",
		"test_initial_title_lbl_null",
		"test_initial_outcome_lbl_null",
		"test_initial_deltas_lbl_null",
		"test_initial_continue_btn_null",
		# Initial state
		"test_initial_world_null",
		# _format_effects
		"test_format_effects_empty_dict",
		"test_format_effects_reputation_increase",
		"test_format_effects_reputation_decrease",
		"test_format_effects_heat_increase",
		"test_format_effects_suspicion_freeze",
		"test_format_effects_max_4_lines_cap",
		# SPA-2920 causality helpers — no-world fallback
		"test_causality_reputation_no_world_returns_empty",
		"test_causality_heat_no_world_returns_empty",
		"test_causality_instant_believers_no_world_returns_empty",
		# SPA-2920 causality helpers — with mocked world
		"test_causality_reputation_with_believers",
		"test_causality_reputation_no_believers_omitted",
		"test_causality_reputation_multiple_rumors_other_factors",
		"test_causality_heat_counts_faction_rumors",
		"test_causality_heat_no_rumors_omitted",
		"test_causality_instant_believers_with_spreader",
		"test_causality_heat_ceiling_uses_event_name",
		"test_causality_ability_bonuses_uses_event_name",
		# SPA-2920 format_effects output includes causality sub-line
		"test_format_effects_causality_subline_present",
		"test_format_effects_causality_omitted_when_no_world",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nEventAftermathScreen tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_backdrop_near_black() -> bool:
	var eas := _make_eas()
	# Near-black with ~0.78 alpha
	var ok: bool = eas.C_BACKDROP.r < 0.05 and eas.C_BACKDROP.a > 0.70 and eas.C_BACKDROP.a < 0.90
	eas.free()
	return ok


static func test_c_stat_up_forest_green() -> bool:
	var eas := _make_eas()
	# #2D6A4F forest green: g is the highest channel
	var ok: bool = eas.C_STAT_UP.g > eas.C_STAT_UP.r and eas.C_STAT_UP.g > eas.C_STAT_UP.b
	eas.free()
	return ok


static func test_c_stat_down_rust_red() -> bool:
	var eas := _make_eas()
	# #8B3A2E rust red: r is the highest channel
	var ok: bool = eas.C_STAT_DOWN.r > eas.C_STAT_DOWN.g and eas.C_STAT_DOWN.r > eas.C_STAT_DOWN.b
	eas.free()
	return ok


static func test_c_item_gain_gold() -> bool:
	var eas := _make_eas()
	# #B8860B gold: high r, moderate g, very low b
	var ok: bool = eas.C_ITEM_GAIN.r > 0.65 and eas.C_ITEM_GAIN.b < 0.10
	eas.free()
	return ok


static func test_c_item_cost_muted() -> bool:
	var eas := _make_eas()
	# #7A6B5D muted warm grey: mid-tone r channel
	var ok: bool = eas.C_ITEM_COST.r > 0.40 and eas.C_ITEM_COST.r < 0.60
	eas.free()
	return ok


static func test_c_header_dark_brown() -> bool:
	var eas := _make_eas()
	# #3B2712 dark brown: all channels low
	var ok: bool = eas.C_HEADER.r < 0.30 and eas.C_HEADER.g < 0.20 and eas.C_HEADER.b < 0.10
	eas.free()
	return ok


static func test_c_btn_bg_dark() -> bool:
	var eas := _make_eas()
	# Button background: dark with high alpha
	var ok: bool = eas.C_BTN_BG.r < 0.40 and eas.C_BTN_BG.a > 0.80
	eas.free()
	return ok


# ── Panel/timing constants ────────────────────────────────────────────────────

static func test_panel_w() -> bool:
	var eas := _make_eas()
	var ok: bool = eas.PANEL_W == 560.0
	eas.free()
	return ok


static func test_panel_h() -> bool:
	var eas := _make_eas()
	var ok: bool = eas.PANEL_H == 440.0
	eas.free()
	return ok


static func test_reveal_time() -> bool:
	var eas := _make_eas()
	var ok: bool = eas.REVEAL_TIME == 0.3
	eas.free()
	return ok


# ── Signal ────────────────────────────────────────────────────────────────────

static func test_aftermath_dismissed_signal_declared() -> bool:
	var eas := _make_eas()
	var ok: bool = eas.has_signal("aftermath_dismissed")
	eas.free()
	return ok


# ── Initial node refs null ────────────────────────────────────────────────────

static func test_initial_backdrop_null() -> bool:
	var eas := _make_eas()
	var ok: bool = eas._backdrop == null
	eas.free()
	return ok


static func test_initial_panel_null() -> bool:
	var eas := _make_eas()
	var ok: bool = eas._panel == null
	eas.free()
	return ok


static func test_initial_title_lbl_null() -> bool:
	var eas := _make_eas()
	var ok: bool = eas._title_lbl == null
	eas.free()
	return ok


static func test_initial_outcome_lbl_null() -> bool:
	var eas := _make_eas()
	var ok: bool = eas._outcome_lbl == null
	eas.free()
	return ok


static func test_initial_deltas_lbl_null() -> bool:
	var eas := _make_eas()
	var ok: bool = eas._deltas_lbl == null
	eas.free()
	return ok


static func test_initial_continue_btn_null() -> bool:
	var eas := _make_eas()
	var ok: bool = eas._continue_btn == null
	eas.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_world_null() -> bool:
	var eas := _make_eas()
	var ok: bool = eas._world == null
	eas.free()
	return ok


# ── _format_effects ───────────────────────────────────────────────────────────

static func test_format_effects_empty_dict() -> bool:
	var eas := _make_eas()
	var result: String = eas._format_effects({})
	var ok: bool = result.is_empty()
	eas.free()
	return ok


static func test_format_effects_reputation_increase() -> bool:
	var eas := _make_eas()
	# delta > 0 → forest-green ^ marker with "+N" suffix
	var effects := {
		"reputationChanges": [{ "npcId": "edric_fenn", "delta": 15 }]
	}
	var result: String = eas._format_effects(effects)
	var ok: bool = result.contains("^") and result.contains("+15")
	eas.free()
	return ok


static func test_format_effects_reputation_decrease() -> bool:
	var eas := _make_eas()
	# delta < 0 → rust-red v marker with negative delta
	var effects := {
		"reputationChanges": [{ "npcId": "aldric_vane", "delta": -10 }]
	}
	var result: String = eas._format_effects(effects)
	var ok: bool = result.contains("v") and result.contains("-10")
	eas.free()
	return ok


static func test_format_effects_heat_increase() -> bool:
	var eas := _make_eas()
	# More heat = bad for player → v marker + "Suspicion" label
	var effects := {
		"heatChanges": [{ "npcId": "guard_captain", "delta": 5 }]
	}
	var result: String = eas._format_effects(effects)
	var ok: bool = result.contains("v") and result.contains("Suspicion")
	eas.free()
	return ok


static func test_format_effects_suspicion_freeze() -> bool:
	var eas := _make_eas()
	# suspicionFreezeDays produces a ^ "frozen" line with the day count
	var effects := {
		"suspicionFreezeDays": 3
	}
	var result: String = eas._format_effects(effects)
	var ok: bool = result.contains("frozen") and result.contains("3")
	eas.free()
	return ok


static func test_format_effects_max_4_lines_cap() -> bool:
	var eas := _make_eas()
	# 6 distinct reputation entries → capped at 4 consequence lines + 1 overflow note.
	# _world is null so no causality sub-lines are added (they return "").
	var rep_changes: Array = []
	for i in range(6):
		rep_changes.append({ "npcId": "npc_%d" % i, "delta": i + 1 })
	var result: String = eas._format_effects({ "reputationChanges": rep_changes })
	var lines := result.split("\n")
	# 4 consequence lines + optional overflow note → at most 5 total lines
	var ok: bool = lines.size() <= 5
	eas.free()
	return ok


# ── SPA-2920: Causality helper tests ─────────────────────────────────────────

# ── No-world fallback ─────────────────────────────────────────────────────────

static func test_causality_reputation_no_world_returns_empty() -> bool:
	var eas := _make_eas()
	var result: String = eas._causality_reputation("any_npc")
	var ok: bool = result.is_empty()
	eas.free()
	return ok


static func test_causality_heat_no_world_returns_empty() -> bool:
	var eas := _make_eas()
	var result: String = eas._causality_heat("any_npc")
	var ok: bool = result.is_empty()
	eas.free()
	return ok


static func test_causality_instant_believers_no_world_returns_empty() -> bool:
	var eas := _make_eas()
	var result: String = eas._causality_instant_believers({"subjectNpcId": "subj", "count": 3})
	var ok: bool = result.is_empty()
	eas.free()
	return ok


# ── Mock world factories ───────────────────────────────────────────────────────

static func _make_world_node(npcs: Array, engine, social_graph) -> Node:
	var src := GDScript.new()
	src.source_code = "extends Node\nvar npcs: Array = []\nvar propagation_engine = null\nvar social_graph = null\n"
	src.reload()
	var w = src.new()
	w.set("npcs", npcs)
	w.set("propagation_engine", engine)
	w.set("social_graph", social_graph)
	return w


static func _make_engine_with_rumors(rumors: Dictionary) -> RefCounted:
	var src := GDScript.new()
	src.source_code = "extends RefCounted\nvar live_rumors: Dictionary = {}\n"
	src.reload()
	var e = src.new()
	e.set("live_rumors", rumors)
	return e


static func _make_mock_npc(id: String, faction: String, slots: Dictionary) -> RefCounted:
	var src := GDScript.new()
	src.source_code = "extends RefCounted\nvar npc_data: Dictionary = {}\nvar rumor_slots: Dictionary = {}\n"
	src.reload()
	var n = src.new()
	n.set("npc_data", {"id": id, "faction": faction})
	n.set("rumor_slots", slots)
	return n


static func _make_social_graph_mock(edges: Dictionary) -> RefCounted:
	var src := GDScript.new()
	src.source_code = "extends RefCounted\nvar edges: Dictionary = {}\n"
	src.reload()
	var sg = src.new()
	sg.set("edges", edges)
	return sg


# ── Causality: reputation ─────────────────────────────────────────────────────

static func test_causality_reputation_with_believers() -> bool:
	var eas := _make_eas()
	var rumor := Rumor.create("r1", "npc_a", Rumor.ClaimType.SCANDAL, 3, 0.5, 0, 330)
	var slot_a := Rumor.NpcRumorSlot.new(rumor, "")
	slot_a.state = Rumor.RumorState.BELIEVE
	var slot_b := Rumor.NpcRumorSlot.new(rumor, "")
	slot_b.state = Rumor.RumorState.SPREAD
	var npc1 = _make_mock_npc("npc_b", "merchant", {"r1": slot_a})
	var npc2 = _make_mock_npc("npc_c", "merchant", {"r1": slot_b})
	var engine = _make_engine_with_rumors({"r1": rumor})
	var world = _make_world_node([npc1, npc2], engine, null)
	eas._world = world
	var result: String = eas._causality_reputation("npc_a")
	var ok: bool = result.contains("scandal") and result.contains("2")
	world.free()
	eas.free()
	return ok


static func test_causality_reputation_no_believers_omitted() -> bool:
	var eas := _make_eas()
	var rumor := Rumor.create("r1", "npc_a", Rumor.ClaimType.ACCUSATION, 2, 0.5, 0, 330)
	var slot := Rumor.NpcRumorSlot.new(rumor, "")
	slot.state = Rumor.RumorState.REJECT
	var npc1 = _make_mock_npc("npc_b", "noble", {"r1": slot})
	var engine = _make_engine_with_rumors({"r1": rumor})
	var world = _make_world_node([npc1], engine, null)
	eas._world = world
	var result: String = eas._causality_reputation("npc_a")
	var ok: bool = result.is_empty()
	world.free()
	eas.free()
	return ok


static func test_causality_reputation_multiple_rumors_other_factors() -> bool:
	var eas := _make_eas()
	# Two distinct rumors about npc_a, both with believers → "+ other factors".
	var rumor1 := Rumor.create("r1", "npc_a", Rumor.ClaimType.SCANDAL, 3, 0.5, 0, 330)
	var rumor2 := Rumor.create("r2", "npc_a", Rumor.ClaimType.ILLNESS, 2, 0.5, 0, 330)
	var slot1 := Rumor.NpcRumorSlot.new(rumor1, "")
	slot1.state = Rumor.RumorState.BELIEVE
	var slot2 := Rumor.NpcRumorSlot.new(rumor2, "")
	slot2.state = Rumor.RumorState.BELIEVE
	var npc_b = _make_mock_npc("npc_b", "merchant", {"r1": slot1})
	var npc_c = _make_mock_npc("npc_c", "noble", {"r2": slot2})
	var engine = _make_engine_with_rumors({"r1": rumor1, "r2": rumor2})
	var world = _make_world_node([npc_b, npc_c], engine, null)
	eas._world = world
	var result: String = eas._causality_reputation("npc_a")
	var ok: bool = result.contains("other factors")
	world.free()
	eas.free()
	return ok


# ── Causality: heat ───────────────────────────────────────────────────────────

static func test_causality_heat_counts_faction_rumors() -> bool:
	var eas := _make_eas()
	var npc_subj1 = _make_mock_npc("clergy_a", "clergy", {})
	var npc_subj2 = _make_mock_npc("clergy_b", "clergy", {})
	var rumor1 := Rumor.create("r1", "clergy_a", Rumor.ClaimType.HERESY, 3, 0.5, 0, 330)
	var rumor2 := Rumor.create("r2", "clergy_b", Rumor.ClaimType.SCANDAL, 2, 0.5, 0, 330)
	var engine = _make_engine_with_rumors({"r1": rumor1, "r2": rumor2})
	var world = _make_world_node([npc_subj1, npc_subj2], engine, null)
	eas._world = world
	var result: String = eas._causality_heat("clergy_a")
	var ok: bool = result.contains("2") and result.contains("Clergy")
	world.free()
	eas.free()
	return ok


static func test_causality_heat_no_rumors_omitted() -> bool:
	var eas := _make_eas()
	var npc_subj = _make_mock_npc("merchant_a", "merchant", {})
	var engine = _make_engine_with_rumors({})
	var world = _make_world_node([npc_subj], engine, null)
	eas._world = world
	var result: String = eas._causality_heat("merchant_a")
	var ok: bool = result.is_empty()
	world.free()
	eas.free()
	return ok


# ── Causality: instant believers ─────────────────────────────────────────────

static func test_causality_instant_believers_with_spreader() -> bool:
	var eas := _make_eas()
	var rumor := Rumor.create("r1", "subj", Rumor.ClaimType.ILLNESS, 3, 0.5, 0, 330)
	var slot := Rumor.NpcRumorSlot.new(rumor, "")
	slot.state = Rumor.RumorState.SPREAD
	var npc_x = _make_mock_npc("npc_x", "merchant", {"r1": slot})
	var sg = _make_social_graph_mock({"npc_x": {"ally_a": 0.5, "ally_b": 0.4}})
	var engine = _make_engine_with_rumors({"r1": rumor})
	var world = _make_world_node([npc_x], engine, sg)
	eas._world = world
	var result: String = eas._causality_instant_believers({"subjectNpcId": "subj", "count": 5})
	var ok: bool = result.contains("5") and result.contains("allies")
	world.free()
	eas.free()
	return ok


# ── Causality: event-name–based ───────────────────────────────────────────────

static func test_causality_heat_ceiling_uses_event_name() -> bool:
	var eas := _make_eas()
	eas._event_name = "The Great Fire"
	var effects := {
		"heatCeilingOverride": {"newCeiling": 60.0, "durationDays": 3}
	}
	var result: String = eas._format_effects(effects)
	var ok: bool = result.contains("Great Fire") and result.contains("public attention")
	eas.free()
	return ok


static func test_causality_ability_bonuses_uses_event_name() -> bool:
	var eas := _make_eas()
	eas._event_name = "Council Decree"
	var effects := {
		"abilityBonuses": [{"ability": "persuasion", "bonus": 2}]
	}
	var result: String = eas._format_effects(effects)
	var ok: bool = result.contains("Council Decree") and result.contains("political balance")
	eas.free()
	return ok


# ── Causality: integration with _format_effects output ───────────────────────

static func test_format_effects_causality_subline_present() -> bool:
	var eas := _make_eas()
	var rumor := Rumor.create("r1", "npc_a", Rumor.ClaimType.SCANDAL, 3, 0.5, 0, 330)
	var slot := Rumor.NpcRumorSlot.new(rumor, "")
	slot.state = Rumor.RumorState.BELIEVE
	var npc_b = _make_mock_npc("npc_b", "merchant", {"r1": slot})
	var engine = _make_engine_with_rumors({"r1": rumor})
	var world = _make_world_node([npc_b], engine, null)
	eas._world = world
	var effects := {
		"reputationChanges": [{"npcId": "npc_a", "delta": 10}]
	}
	var result: String = eas._format_effects(effects)
	# Causality sub-line should carry C_NEUTRAL colour tag and "because" text.
	var ok: bool = result.contains("#7A6B5D") and result.contains("because")
	world.free()
	eas.free()
	return ok


static func test_format_effects_causality_omitted_when_no_world() -> bool:
	var eas := _make_eas()
	# No world → causality helpers return "" → no "because" in output.
	var effects := {
		"reputationChanges": [{"npcId": "npc_a", "delta": 10}]
	}
	var result: String = eas._format_effects(effects)
	var ok: bool = not result.contains("because")
	eas.free()
	return ok
