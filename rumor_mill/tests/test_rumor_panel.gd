## test_rumor_panel.gd — Unit tests for RumorPanel (SPA-1012).
##
## Covers:
##   • Panel index constants: PANEL_SUBJECT, PANEL_CLAIM, PANEL_SEED
##   • TITLES / HINTS arrays — length and non-empty entries
##   • Portrait atlas constants: PORTRAIT_W, PORTRAIT_H, PORTRAIT_COLS
##   • CLAIM_ICON_INDEX — accusation→0, praise→4, unknown→-1
##   • Static colour helpers: _faction_color, _claim_type_color, _intensity_color
##   • Initial state: _current_panel, _selected_subject, _selected_claim_id,
##                    _selected_seed_npc, _confirm_pending, _panel_seed_shown_fired,
##                    _evidence_tutorial_fired
##   • _estimate_believability — null world uses default intensity 3 → value ≈ 0.60
##   • _estimate_believability — same-faction bonus adds 0.15
##   • _estimate_believability — high-intensity claim (5) raises base to 1.0
##   • _estimate_believability — heat ≥ 75 subtracts 0.30 penalty
##   • _estimate_believability — value is clamped to [0.0, 1.0]
##   • _estimate_spread — null world returns 0.0
##   • _estimate_spread — NPCs outside radius 8 contribute nothing
##   • _estimate_spread — NPC within radius contributes sociability to count
##
## RumorPanel extends CanvasLayer. @onready vars remain null (not added to scene tree).
## Static colour helpers and data-field methods are safe to call on bare instances.
## _world_ref and _intel_store_ref are injected manually where needed.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestRumorPanel
extends RefCounted

const RumorPanelScript := preload("res://scripts/rumor_panel.gd")


# ── Mock helpers ──────────────────────────────────────────────────────────────

## Minimal NPC node mock: npc_data dict + current_cell Vector2i.
class MockNpc:
	extends Node2D
	var npc_data: Dictionary = {}
	var current_cell: Vector2i = Vector2i(0, 0)


## Minimal world mock: npcs list + get_claims().
class MockWorld:
	extends Node2D
	var npcs: Array = []
	var _claims: Array = []
	func get_claims() -> Array:
		return _claims


## Build a MockNpc with id, faction, sociability, and grid cell.
static func _make_npc(
		npc_id: String,
		faction: String,
		cell: Vector2i = Vector2i(0, 0),
		sociability: float = 0.5
) -> MockNpc:
	var npc := MockNpc.new()
	npc.npc_data = {
		"id": npc_id,
		"faction": faction,
		"name": npc_id,
		"sociability": sociability,
	}
	npc.current_cell = cell
	return npc


## Build a MockWorld with an NPC list and an optional claims list.
static func _make_world(npcs: Array = [], claims: Array = []) -> MockWorld:
	var w := MockWorld.new()
	w.npcs = npcs
	w._claims = claims
	return w


## Return a fresh RumorPanel instance (not added to scene tree).
static func _make_panel() -> CanvasLayer:
	return RumorPanelScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Panel index constants
		"test_panel_subject_is_zero",
		"test_panel_claim_is_one",
		"test_panel_seed_is_two",
		# TITLES / HINTS
		"test_titles_has_three_entries",
		"test_hints_has_three_entries",
		"test_titles_entries_nonempty",
		# Portrait atlas constants
		"test_portrait_w_constant",
		"test_portrait_h_constant",
		"test_portrait_cols_constant",
		# CLAIM_ICON_INDEX
		"test_claim_icon_accusation_mapped",
		"test_claim_icon_praise_mapped",
		"test_claim_icon_unknown_not_in_index",
		# _faction_color
		"test_faction_color_merchant",
		"test_faction_color_noble",
		"test_faction_color_clergy",
		"test_faction_color_unknown_is_white",
		# _claim_type_color
		"test_claim_type_color_accusation",
		"test_claim_type_color_scandal",
		"test_claim_type_color_heresy",
		"test_claim_type_color_unknown_is_white",
		# _intensity_color
		"test_intensity_color_one_is_low",
		"test_intensity_color_two_is_low",
		"test_intensity_color_three_is_med",
		"test_intensity_color_four_is_high",
		"test_intensity_color_five_is_high",
		"test_intensity_color_zero_is_white",
		# Initial state
		"test_initial_current_panel_is_subject",
		"test_initial_selected_subject_empty",
		"test_initial_selected_claim_id_empty",
		"test_initial_selected_seed_npc_empty",
		"test_initial_confirm_pending_false",
		"test_initial_panel_seed_shown_fired_false",
		"test_initial_evidence_tutorial_fired_false",
		# _estimate_believability
		"test_believability_null_world_default_intensity",
		"test_believability_same_faction_bonus",
		"test_believability_high_intensity_claim",
		"test_believability_heat_penalty_high",
		"test_believability_value_clamped_to_one",
		# _estimate_spread
		"test_spread_null_world_returns_zero",
		"test_spread_no_nearby_npcs_returns_zero",
		"test_spread_nearby_npc_contributes",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nRumorPanel tests: %d passed, %d failed" % [passed, failed])


# ── Panel index constants ─────────────────────────────────────────────────────

static func test_panel_subject_is_zero() -> bool:
	var rp := _make_panel()
	return rp.PANEL_SUBJECT == 0


static func test_panel_claim_is_one() -> bool:
	var rp := _make_panel()
	return rp.PANEL_CLAIM == 1


static func test_panel_seed_is_two() -> bool:
	var rp := _make_panel()
	return rp.PANEL_SEED == 2


# ── TITLES / HINTS ────────────────────────────────────────────────────────────

static func test_titles_has_three_entries() -> bool:
	var rp := _make_panel()
	return rp.TITLES.size() == 3


static func test_hints_has_three_entries() -> bool:
	var rp := _make_panel()
	return rp.HINTS.size() == 3


static func test_titles_entries_nonempty() -> bool:
	var rp := _make_panel()
	for title in rp.TITLES:
		if (title as String).is_empty():
			return false
	return true


# ── Portrait atlas constants ──────────────────────────────────────────────────

static func test_portrait_w_constant() -> bool:
	var rp := _make_panel()
	return rp.PORTRAIT_W == 64


static func test_portrait_h_constant() -> bool:
	var rp := _make_panel()
	return rp.PORTRAIT_H == 80


static func test_portrait_cols_constant() -> bool:
	var rp := _make_panel()
	return rp.PORTRAIT_COLS == 6


# ── CLAIM_ICON_INDEX ──────────────────────────────────────────────────────────

static func test_claim_icon_accusation_mapped() -> bool:
	var rp := _make_panel()
	return rp.CLAIM_ICON_INDEX.has("accusation") and rp.CLAIM_ICON_INDEX["accusation"] == 0


static func test_claim_icon_praise_mapped() -> bool:
	var rp := _make_panel()
	return rp.CLAIM_ICON_INDEX.has("praise") and rp.CLAIM_ICON_INDEX["praise"] == 4


static func test_claim_icon_unknown_not_in_index() -> bool:
	var rp := _make_panel()
	return not rp.CLAIM_ICON_INDEX.has("completely_unknown_type")


# ── _faction_color ────────────────────────────────────────────────────────────

static func test_faction_color_merchant() -> bool:
	var rp := _make_panel()
	return rp._faction_color("merchant") == rp.C_FACTION_MERCHANT


static func test_faction_color_noble() -> bool:
	var rp := _make_panel()
	return rp._faction_color("noble") == rp.C_FACTION_NOBLE


static func test_faction_color_clergy() -> bool:
	var rp := _make_panel()
	return rp._faction_color("clergy") == rp.C_FACTION_CLERGY


static func test_faction_color_unknown_is_white() -> bool:
	var rp := _make_panel()
	return rp._faction_color("unknown_faction") == Color.WHITE


# ── _claim_type_color ─────────────────────────────────────────────────────────

static func test_claim_type_color_accusation() -> bool:
	var rp := _make_panel()
	return rp._claim_type_color("accusation") == rp.C_CLAIM_ACCUSATION


static func test_claim_type_color_scandal() -> bool:
	var rp := _make_panel()
	return rp._claim_type_color("scandal") == rp.C_CLAIM_SCANDAL


static func test_claim_type_color_heresy() -> bool:
	var rp := _make_panel()
	return rp._claim_type_color("heresy") == rp.C_CLAIM_HERESY


static func test_claim_type_color_unknown_is_white() -> bool:
	var rp := _make_panel()
	return rp._claim_type_color("totally_unknown") == Color.WHITE


# ── _intensity_color ──────────────────────────────────────────────────────────

static func test_intensity_color_one_is_low() -> bool:
	var rp := _make_panel()
	return rp._intensity_color(1) == rp.C_INTENSITY_LOW


static func test_intensity_color_two_is_low() -> bool:
	var rp := _make_panel()
	return rp._intensity_color(2) == rp.C_INTENSITY_LOW


static func test_intensity_color_three_is_med() -> bool:
	var rp := _make_panel()
	return rp._intensity_color(3) == rp.C_INTENSITY_MED


static func test_intensity_color_four_is_high() -> bool:
	var rp := _make_panel()
	return rp._intensity_color(4) == rp.C_INTENSITY_HIGH


static func test_intensity_color_five_is_high() -> bool:
	var rp := _make_panel()
	return rp._intensity_color(5) == rp.C_INTENSITY_HIGH


## Default match arm — value 0 has no explicit case → Color.WHITE.
static func test_intensity_color_zero_is_white() -> bool:
	var rp := _make_panel()
	return rp._intensity_color(0) == Color.WHITE


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_current_panel_is_subject() -> bool:
	var rp := _make_panel()
	return rp._current_panel == rp.PANEL_SUBJECT


static func test_initial_selected_subject_empty() -> bool:
	var rp := _make_panel()
	return rp._selected_subject == ""


static func test_initial_selected_claim_id_empty() -> bool:
	var rp := _make_panel()
	return rp._selected_claim_id == ""


static func test_initial_selected_seed_npc_empty() -> bool:
	var rp := _make_panel()
	return rp._selected_seed_npc == ""


static func test_initial_confirm_pending_false() -> bool:
	var rp := _make_panel()
	return rp._confirm_pending == false


static func test_initial_panel_seed_shown_fired_false() -> bool:
	var rp := _make_panel()
	return rp._panel_seed_shown_fired == false


static func test_initial_evidence_tutorial_fired_false() -> bool:
	var rp := _make_panel()
	return rp._evidence_tutorial_fired == false


# ── _estimate_believability ───────────────────────────────────────────────────

## Null world → default claim intensity (3), no faction bonus, no heat → value == 0.60.
static func test_believability_null_world_default_intensity() -> bool:
	var rp := _make_panel()
	# Both _world_ref and _intel_store_ref are null.
	var result: Dictionary = rp._estimate_believability("any_seed")
	return is_equal_approx(result["value"], 0.60)


## Subject and seed share the same faction → base + 0.15 bonus.
## Intensity 3 → base = 0.60 + 0.15 = 0.75.
static func test_believability_same_faction_bonus() -> bool:
	var rp := _make_panel()
	var npc_a := _make_npc("npc_a", "merchant")
	var npc_b := _make_npc("npc_b", "merchant")
	var world := _make_world(
		[npc_a, npc_b],
		[{"id": "claim_1", "type": "scandal", "intensity": 3}]
	)
	rp._world_ref        = world
	rp._selected_subject  = "npc_a"
	rp._selected_claim_id = "claim_1"
	var result: Dictionary = rp._estimate_believability("npc_b")
	return is_equal_approx(result["value"], 0.75)


## Intensity 5 → base = 5/5 = 1.0, clamped at 1.0.
static func test_believability_high_intensity_claim() -> bool:
	var rp := _make_panel()
	var world := _make_world(
		[],
		[{"id": "claim_high", "type": "accusation", "intensity": 5}]
	)
	rp._world_ref        = world
	rp._selected_claim_id = "claim_high"
	var result: Dictionary = rp._estimate_believability("any_seed")
	return is_equal_approx(result["value"], 1.0)


## Heat ≥ 75 on the seed NPC → 0.30 penalty applied → 0.60 - 0.30 = 0.30.
static func test_believability_heat_penalty_high() -> bool:
	var rp := _make_panel()
	var store := PlayerIntelStore.new()
	store.heat_enabled    = true
	store.heat["seed_a"]  = 80.0
	rp._intel_store_ref   = store
	# _world_ref is null → claim intensity defaults to 3, no faction bonus.
	var result: Dictionary = rp._estimate_believability("seed_a")
	return is_equal_approx(result["value"], 0.30)


## Intensity 5 + same faction: raw = 1.0 + 0.15 = 1.15 → clamped to 1.0.
static func test_believability_value_clamped_to_one() -> bool:
	var rp := _make_panel()
	var npc_a := _make_npc("npc_a", "noble")
	var npc_b := _make_npc("npc_b", "noble")
	var world := _make_world(
		[npc_a, npc_b],
		[{"id": "claim_top", "type": "accusation", "intensity": 5}]
	)
	rp._world_ref        = world
	rp._selected_subject  = "npc_a"
	rp._selected_claim_id = "claim_top"
	var result: Dictionary = rp._estimate_believability("npc_b")
	return result["value"] <= 1.0 and result["value"] > 0.9


# ── _estimate_spread ──────────────────────────────────────────────────────────

## Null world → returns 0.0 immediately.
static func test_spread_null_world_returns_zero() -> bool:
	var rp := _make_panel()
	var seed := _make_npc("seed", "merchant")
	# _world_ref is null.
	var result: Dictionary = rp._estimate_spread(seed)
	return is_equal_approx(result["value"], 0.0)


## Seed at (0,0); only other NPC is at (10,10) — Manhattan distance 20 > radius 8.
static func test_spread_no_nearby_npcs_returns_zero() -> bool:
	var rp := _make_panel()
	var seed    := _make_npc("seed", "merchant", Vector2i(0, 0))
	var far_npc := _make_npc("far",  "noble",    Vector2i(10, 10))
	var world   := _make_world([seed, far_npc])
	rp._world_ref = world
	var result: Dictionary = rp._estimate_spread(seed)
	# seed is skipped (same object); far_npc distance = |10|+|10| = 20 > 8.
	return is_equal_approx(result["value"], 0.0)


## Seed at (0,0); NPC at (3,2) — Manhattan distance 5, within radius 8.
## sociability = 0.7 contributes 0.7 to the count.
static func test_spread_nearby_npc_contributes() -> bool:
	var rp := _make_panel()
	var seed     := _make_npc("seed", "merchant", Vector2i(0, 0))
	var near_npc := _make_npc("near", "noble",    Vector2i(3, 2), 0.7)
	var world    := _make_world([seed, near_npc])
	rp._world_ref = world
	var result: Dictionary = rp._estimate_spread(seed)
	return result["value"] > 0.0
