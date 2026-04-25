## test_rumor_panel_estimates.gd — Unit tests for RumorPanelEstimates (SPA-1027).
##
## Covers:
##   • estimate_spread() — null world → value 0.0
##   • estimate_spread() — NPC outside radius 8 contributes nothing
##   • estimate_spread() — NPC within radius contributes sociability
##   • estimate_spread() — "reason" key is always present
##   • estimate_believability() — null world, no claim match → default intensity 3 → 0.60
##   • estimate_believability() — same faction → +0.15 bonus
##   • estimate_believability() — intensity 5 → base 1.0, clamped at 1.0
##   • estimate_believability() — heat >= 75 → -0.30 penalty
##   • estimate_believability() — heat >= 50 but < 75 → -0.15 penalty
##   • estimate_believability() — value clamped to [0.0, 1.0]
##   • estimate_believability() — "reason" key always present
##
## Avoids duplicating test_rumor_panel.gd (which tests rumor_panel.gd's internal
## _estimate_believability / _estimate_spread helpers with different signatures).
## This file targets the public API of the extracted sub-module.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestRumorPanelEstimates
extends RefCounted

const _Klass := preload("res://scripts/rumor_panel_estimates.gd")


# ── Mocks ─────────────────────────────────────────────────────────────────────

class MockNpc:
	extends Node2D
	var npc_data: Dictionary = {}
	var current_cell: Vector2i = Vector2i(0, 0)


class MockWorld:
	extends Node2D
	var npcs: Array = []
	var _claims: Array = []
	func get_claims() -> Array:
		return _claims


static func _make_npc(
		npc_id: String,
		faction: String,
		cell: Vector2i = Vector2i(0, 0),
		sociability: float = 0.5
) -> MockNpc:
	var npc := MockNpc.new()
	npc.npc_data = {"id": npc_id, "faction": faction, "sociability": sociability}
	npc.current_cell = cell
	return npc


static func _make_world(npcs: Array = [], claims: Array = []) -> MockWorld:
	var w := MockWorld.new()
	w.npcs    = npcs
	w._claims = claims
	return w


static func _make_estimates() -> RumorPanelEstimates:
	return _Klass.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# estimate_spread()
		"test_spread_null_world_is_zero",
		"test_spread_far_npc_no_contribution",
		"test_spread_nearby_npc_contributes",
		"test_spread_result_has_reason_key",

		# estimate_believability()
		"test_believability_default_intensity_three",
		"test_believability_same_faction_bonus",
		"test_believability_intensity_five",
		"test_believability_heat_75_penalty",
		"test_believability_heat_50_penalty",
		"test_believability_value_clamped_to_one",
		"test_believability_result_has_reason_key",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nRumorPanelEstimates tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# estimate_spread()
# ══════════════════════════════════════════════════════════════════════════════

func test_spread_null_world_is_zero() -> bool:
	var e    := _make_estimates()
	var seed := _make_npc("seed", "merchant")
	var res: Dictionary = e.estimate_spread(seed)
	seed.free()
	return is_equal_approx(res["value"], 0.0)


func test_spread_far_npc_no_contribution() -> bool:
	var e    := _make_estimates()
	var seed := _make_npc("seed", "merchant", Vector2i(0, 0))
	var far  := _make_npc("far",  "noble",    Vector2i(10, 10), 0.8)
	var world := _make_world([seed, far])
	e.setup(world, null)
	var res: Dictionary = e.estimate_spread(seed)
	# Manhattan dist = 20 > SPREAD_RADIUS 8 → contribution = 0
	var ok := is_equal_approx(res["value"], 0.0)
	seed.free()
	far.free()
	world.free()
	return ok


func test_spread_nearby_npc_contributes() -> bool:
	var e    := _make_estimates()
	var seed := _make_npc("seed", "merchant", Vector2i(0, 0))
	var near := _make_npc("near", "noble",    Vector2i(3, 2), 0.7)
	var world := _make_world([seed, near])
	e.setup(world, null)
	var res: Dictionary = e.estimate_spread(seed)
	# dist = |3|+|2| = 5 ≤ 8 → count += 0.7
	var ok := res["value"] > 0.0
	seed.free()
	near.free()
	world.free()
	return ok


func test_spread_result_has_reason_key() -> bool:
	var e    := _make_estimates()
	var seed := _make_npc("seed", "merchant")
	var res: Dictionary = e.estimate_spread(seed)
	seed.free()
	return res.has("reason")


# ══════════════════════════════════════════════════════════════════════════════
# estimate_believability()
# ══════════════════════════════════════════════════════════════════════════════

func test_believability_default_intensity_three() -> bool:
	var e := _make_estimates()
	# null world → intensity defaults to 3 → base = 3/5 = 0.60, no faction bonus, no heat
	var res: Dictionary = e.estimate_believability("seed_npc", "any_claim", "any_subject")
	return is_equal_approx(res["value"], 0.60)


func test_believability_same_faction_bonus() -> bool:
	var e      := _make_estimates()
	var npc_a  := _make_npc("npc_a", "merchant")
	var npc_b  := _make_npc("npc_b", "merchant")
	var world  := _make_world([npc_a, npc_b], [{"id": "claim_1", "type": "scandal", "intensity": 3}])
	e.setup(world, null)
	var res: Dictionary = e.estimate_believability("npc_b", "claim_1", "npc_a")
	# base 0.60 + same-faction 0.15 = 0.75
	var ok := is_equal_approx(res["value"], 0.75)
	npc_a.free()
	npc_b.free()
	world.free()
	return ok


func test_believability_intensity_five() -> bool:
	var e     := _make_estimates()
	var world := _make_world([], [{"id": "claim_hi", "type": "accusation", "intensity": 5}])
	e.setup(world, null)
	var res: Dictionary = e.estimate_believability("seed", "claim_hi", "subject")
	# base = 5/5 = 1.0, clamped at 1.0
	var ok := is_equal_approx(res["value"], 1.0)
	world.free()
	return ok


func test_believability_heat_75_penalty() -> bool:
	var e     := _make_estimates()
	var store := PlayerIntelStore.new()
	store.heat_enabled  = true
	store.heat["seed_a"] = 80.0
	e.setup(null, store)
	var res: Dictionary = e.estimate_believability("seed_a", "unused_claim", "subj")
	# base 0.60 − heat penalty 0.30 = 0.30
	return is_equal_approx(res["value"], 0.30)


func test_believability_heat_50_penalty() -> bool:
	var e     := _make_estimates()
	var store := PlayerIntelStore.new()
	store.heat_enabled  = true
	store.heat["seed_b"] = 60.0
	e.setup(null, store)
	var res: Dictionary = e.estimate_believability("seed_b", "unused_claim", "subj")
	# base 0.60 − heat penalty 0.15 = 0.45
	return is_equal_approx(res["value"], 0.45)


func test_believability_value_clamped_to_one() -> bool:
	var e      := _make_estimates()
	var npc_a  := _make_npc("npc_a", "noble")
	var npc_b  := _make_npc("npc_b", "noble")
	var world  := _make_world([npc_a, npc_b], [{"id": "top", "type": "accusation", "intensity": 5}])
	e.setup(world, null)
	var res: Dictionary = e.estimate_believability("npc_b", "top", "npc_a")
	# base 1.0 + faction bonus 0.15 → clamped to 1.0
	var ok := res["value"] <= 1.0 and res["value"] > 0.9
	npc_a.free()
	npc_b.free()
	world.free()
	return ok


func test_believability_result_has_reason_key() -> bool:
	var e := _make_estimates()
	var res: Dictionary = e.estimate_believability("x", "y", "z")
	return res.has("reason")
