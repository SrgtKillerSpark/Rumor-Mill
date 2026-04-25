class_name RumorPanelEstimates
extends RefCounted

## rumor_panel_estimates.gd — Spread and believability prediction helpers.
##
## Extracted from rumor_panel.gd (SPA-1014). Pure computation — no UI.
## Mirrors the heat-modifier path in propagation_engine.calc_beta so
## displayed percentages match actual adoption probability (fixes SPA-594).

var _world_ref:       Node2D           = null
var _intel_store_ref: PlayerIntelStore = null


func setup(world: Node2D, intel_store: PlayerIntelStore) -> void:
	_world_ref       = world
	_intel_store_ref = intel_store


## Rough spread estimate: count of NPCs within the 8-tile spread radius,
## weighted by their average sociability.
## Returns {value: float, reason: String} — reason cites the dominant factor.
func estimate_spread(seed_npc: Node2D) -> Dictionary:
	if _world_ref == null:
		return {"value": 0.0, "reason": "No world data"}
	const SPREAD_RADIUS := 8
	var count: float = 0.0
	var high_soc: int = 0
	for npc in _world_ref.npcs:
		if npc == seed_npc:
			continue
		var dist: int = abs((npc.current_cell as Vector2i).x - (seed_npc.current_cell as Vector2i).x) \
		              + abs((npc.current_cell as Vector2i).y - (seed_npc.current_cell as Vector2i).y)
		if dist <= SPREAD_RADIUS:
			var soc: float = float(npc.npc_data.get("sociability", 0.5))
			count += soc
			if soc >= 0.7:
				high_soc += 1
	var reason: String
	if count >= 4.0:
		reason = "Social hub — wide reach" if high_soc >= 2 else "Crowded area — wide reach"
	elif count >= 2.0:
		reason = "Some neighbors nearby"
	else:
		reason = "Sparse area — low reach"
	return {"value": count, "reason": reason}


## Believability estimate: claim base + same-faction bonus, adjusted for heat.
## npc_name is optional; when supplied it personalises the reason line (SPA-849).
## Returns {value: float, reason: String} — reason cites the dominant factor.
func estimate_believability(
		seed_npc_id:       String,
		selected_claim_id: String,
		selected_subject:  String,
		npc_name:          String = ""
) -> Dictionary:
	var claim_intensity: int = 3
	if _world_ref != null:
		for c in _world_ref.get_claims():
			if c.get("id", "") == selected_claim_id:
				claim_intensity = int(c.get("intensity", 3))
				break

	var base: float = float(claim_intensity) / 5.0

	# Same-faction bonus mirrors NPC credulity logic in npc.gd.
	var subj_faction: String = _get_npc_faction(selected_subject)
	var seed_faction: String = _get_npc_faction(seed_npc_id)
	var same_faction: bool = not subj_faction.is_empty() and subj_faction == seed_faction
	if same_faction:
		base += 0.15

	# Heat modifier mirrors propagation_engine.calc_beta:
	#   heat >= 75 → effective credulity -0.30
	#   heat >= 50 → effective credulity -0.15
	var heat_penalty: float = 0.0
	if _intel_store_ref != null and _intel_store_ref.heat_enabled:
		var heat_val: float = _intel_store_ref.get_heat(seed_npc_id)
		if heat_val >= 75.0:
			base -= 0.30
			heat_penalty = 0.30
		elif heat_val >= 50.0:
			base -= 0.15
			heat_penalty = 0.15

	var label: String = npc_name if not npc_name.is_empty() else "NPC"
	var reason: String
	if heat_penalty >= 0.30:
		reason = "%s — under scrutiny" % label
	elif heat_penalty >= 0.15:
		reason = "Moderate heat — belief reduced"
	elif same_faction:
		reason = "%s shares %s ties" % [label, seed_faction.capitalize()]
	elif claim_intensity >= 4:
		reason = "Strong claim — high credibility"
	elif claim_intensity <= 2:
		reason = "Weak claim — low believability"
	else:
		reason = "No shared bonds — base belief"

	return {"value": clampf(base, 0.0, 1.0), "reason": reason}


func _get_npc_faction(npc_id: String) -> String:
	if _world_ref == null:
		return ""
	for npc in _world_ref.npcs:
		if npc.npc_data.get("id", "") == npc_id:
			return npc.npc_data.get("faction", "")
	return ""
