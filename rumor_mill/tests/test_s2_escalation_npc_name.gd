## test_s2_escalation_npc_name.gd — Regression tests for SPA-1708.
##
## Verifies that the S2 auto-spread escalation path names the seeded NPC so
## the player can gauge proximity-to-Maren risk without inspecting the social graph.
##
## Covers:
##   Agent side (IllnessEscalationAgent):
##     • illness_escalated signal carries a non-empty seed_npc_name when a
##       valid NPC exists in the world at the time of seeding.
##     • seed_npc_location is the NPC's current_location_code at seed time.
##     • seed_npc_name falls back to capitalize(id) when npc_data["name"] is absent.
##
##   HUD side (Scenario2Hud.notify_illness_escalated):
##     • _escalation_lbl.text includes the NPC name when seed_npc_name is non-empty.
##     • _escalation_lbl.text includes the location tag when seed_npc_location is non-empty.
##     • _escalation_lbl.text omits the NPC tag entirely when seed_npc_name is empty
##       (backward-compatible path, preserves the existing "quiet so far" fallback).
##
## Run from the Godot editor: Scene → Run Script.

class_name TestS2EscalationNpcName
extends RefCounted

const IllnessEscalationAgentScript := preload("res://scripts/illness_escalation_agent.gd")
const Scenario2HudScript           := preload("res://scripts/scenario2_hud.gd")


# ── Signal capture helper ─────────────────────────────────────────────────────

## Binds to illness_escalated and records the last emission.
class _SignalCapture:
	extends RefCounted
	var last_day:      int    = -1
	var last_name:     String = ""
	var last_location: String = ""
	var fired:         bool   = false

	func on_escalated(
			day: int, _claim: String, _subj: String,
			npc_name: String, npc_loc: String
	) -> void:
		last_day      = day
		last_name     = npc_name
		last_location = npc_loc
		fired         = true


# ── Mock world ────────────────────────────────────────────────────────────────

## Minimal world stub: exposes npcs array and inject_rumor(); intel_store is null.
## Extends Node to satisfy IllnessEscalationAgent._seed_illness_rumor(world: Node) type constraint.
class _MockWorld:
	extends Node
	var npcs:        Array = []
	var intel_store: Object = null

	func inject_rumor(
			_npc_id: String, _claim: String, _intensity: int,
			_subject: String, _source: String
	) -> String:
		return "r_mock_001"


## Minimal NPC stub: npc_data dict + current_location_code.
class _MockNpc:
	extends RefCounted
	var npc_data:             Dictionary = {}
	var current_location_code: String    = ""


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_agent() -> IllnessEscalationAgent:
	var agent: IllnessEscalationAgent = IllnessEscalationAgentScript.new()
	agent.activate()
	return agent


static func _make_world_with_npc(
		npc_id: String, npc_name: String, location: String
) -> _MockWorld:
	var world := _MockWorld.new()
	var npc   := _MockNpc.new()
	npc.npc_data             = {"id": npc_id, "name": npc_name, "credulity": 0.9}
	npc.current_location_code = location
	world.npcs               = [npc]
	return world


## Create a Scenario2Hud with _escalation_lbl injected so notify_illness_escalated
## can write to it without requiring a full scene-tree build.
static func _make_hud_with_label() -> Dictionary:
	var hud: Node   = Scenario2HudScript.new()
	var lbl: Label  = Label.new()
	# Inject the label directly — mirrors what _build_ui() would create.
	hud.set("_escalation_lbl", lbl)
	return {"hud": hud, "lbl": lbl}


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Agent — signal carries NPC name
		"test_signal_includes_npc_name_when_npc_exists",
		"test_signal_includes_location_when_npc_at_market",
		"test_signal_name_falls_back_to_capitalised_id_when_name_absent",
		# HUD — label text formatting
		"test_label_contains_npc_name",
		"test_label_contains_location_tag",
		"test_label_omits_npc_tag_when_name_empty",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nS2EscalationNpcName tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Agent — signal payload
# ══════════════════════════════════════════════════════════════════════════════

func test_signal_includes_npc_name_when_npc_exists() -> bool:
	var agent  := _make_agent()
	var cap    := _SignalCapture.new()
	agent.illness_escalated.connect(cap.on_escalated)

	var world := _make_world_with_npc("tomas_reeve", "Tomas Reeve", "market")
	agent._seed_illness_rumor(8, world)

	return cap.fired and not cap.last_name.is_empty()


func test_signal_includes_location_when_npc_at_market() -> bool:
	var agent := _make_agent()
	var cap   := _SignalCapture.new()
	agent.illness_escalated.connect(cap.on_escalated)

	var world := _make_world_with_npc("tomas_reeve", "Tomas Reeve", "market")
	agent._seed_illness_rumor(8, world)

	return cap.fired and cap.last_location == "market"


func test_signal_name_falls_back_to_capitalised_id_when_name_absent() -> bool:
	## When npc_data has no "name" key, the agent should derive a display name
	## from the id (replace underscores → spaces, capitalize).
	var agent := _make_agent()
	var cap   := _SignalCapture.new()
	agent.illness_escalated.connect(cap.on_escalated)

	var world := _MockWorld.new()
	var npc   := _MockNpc.new()
	npc.npc_data              = {"id": "calder_miller", "credulity": 0.8}  # no "name" key
	npc.current_location_code = "tavern"
	world.npcs                = [npc]

	agent._seed_illness_rumor(8, world)

	# Fallback: id.replace("_", " ").capitalize() → "Calder Miller"
	return cap.fired and cap.last_name == "Calder Miller"


# ══════════════════════════════════════════════════════════════════════════════
# HUD — notify_illness_escalated label text
# ══════════════════════════════════════════════════════════════════════════════

func test_label_contains_npc_name() -> bool:
	var parts := _make_hud_with_label()
	var hud: Node  = parts["hud"]
	var lbl: Label = parts["lbl"]

	hud.notify_illness_escalated(8, "illness", "alys_herbwife", "Tomas Reeve", "market")

	return "Tomas Reeve" in lbl.text


func test_label_contains_location_tag() -> bool:
	var parts := _make_hud_with_label()
	var hud: Node  = parts["hud"]
	var lbl: Label = parts["lbl"]

	hud.notify_illness_escalated(12, "illness", "alys_herbwife", "Finn Cooper", "tavern")

	return "tavern" in lbl.text


func test_label_omits_npc_tag_when_name_empty() -> bool:
	## Backward-compatible path: empty name should not append " — reached  · "
	var parts := _make_hud_with_label()
	var hud: Node  = parts["hud"]
	var lbl: Label = parts["lbl"]

	hud.notify_illness_escalated(8, "illness", "alys_herbwife", "", "")

	# Must contain day, must NOT contain "reached"
	return ("Day 8" in lbl.text) and ("reached" not in lbl.text)
