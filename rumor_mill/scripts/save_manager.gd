## save_manager.gd — Mid-scenario save/load for Rumor Mill (SPA-177, SPA-220).
##
## Saves to user://saves/<scenario_id>_slotN.json  (manual slots 1–3)
##        or user://saves/<scenario_id>_auto.json   (auto-save, slot 0)
## Serializes: tick, day, social graph edges, live rumors with NPC belief slots,
## player intel (recon budget, heat, evidence), scenario state, journal timeline,
## rival agent state (S3), inquisitor agent state (S4).
##
## Load flow:
##   1. prepare_load(scenario_id, slot) validates file and stores data in _pending_load_data.
##   2. Caller sets PauseMenu._pending_restart_id and reloads the scene.
##   3. After all systems init, main.gd calls apply_pending_load() to restore state.
##
## Edge cases:
##   • Corrupted JSON  → prepare_load() returns a non-empty error string.
##   • Version mismatch → prepare_load() returns a non-empty error string.
##   • Missing save     → prepare_load() returns a non-empty error string.

class_name SaveManager

const SAVE_VERSION := 1
const SAVE_DIR     := "user://saves/"
const SLOT_COUNT   := 3   ## Manual save slots (1–3)
const AUTO_SLOT    := 0   ## Slot 0 = auto-save (written at start of each new day)


## Returns the save file path for a given scenario id and slot.
static func save_path(scenario_id: String, slot: int) -> String:
	if slot == AUTO_SLOT:
		return SAVE_DIR + scenario_id + "_auto.json"
	return SAVE_DIR + scenario_id + "_slot%d.json" % slot


## Returns true if a save exists for the given scenario_id and slot.
static func has_save(scenario_id: String, slot: int) -> bool:
	return FileAccess.file_exists(save_path(scenario_id, slot))


## Returns summary metadata for a slot, used in the pause menu slot picker.
## Returns {} if no save exists; {"day": int, "tick": int} otherwise.
static func get_save_info(scenario_id: String, slot: int) -> Dictionary:
	if not has_save(scenario_id, slot):
		return {}
	var f := FileAccess.open(save_path(scenario_id, slot), FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {}
	return {
		"day":  int(parsed.get("day",  1)),
		"tick": int(parsed.get("tick", 0)),
	}


## Save the current game state to disk.
## slot: AUTO_SLOT (0) for auto-save, 1–3 for manual slots.
## Returns "" on success, or a human-readable error string on failure.
static func save_game(
		world:     Node2D,
		day_night: Node,
		journal:   CanvasLayer,
		slot:      int = 1
) -> String:
	# Ensure save directory exists.
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("saves"):
		dir.make_dir("saves")

	# Combine flushed log + any pending (buffered-this-tick) events.
	var timeline: Array = journal._timeline_log.duplicate()
	timeline.append_array(journal._pending_events)

	var data := {
		"version":          SAVE_VERSION,
		"scenario_id":      world.active_scenario_id,
		"tick":             day_night.current_tick,
		"day":              day_night.current_day,
		"social_graph":     _serialize_social_graph(world.social_graph),
		"propagation":      _serialize_propagation(world.propagation_engine),
		"npc_slots":        _serialize_npc_slots(world.npcs),
		"intel_store":      _serialize_intel_store(world.intel_store),
		"scenario":         _serialize_scenario_manager(world.scenario_manager),
		"rival_agent":      _serialize_rival_agent(world.rival_agent),
		"inquisitor_agent": _serialize_inquisitor_agent(world.inquisitor_agent),
		"timeline":         timeline,
	}

	var path := save_path(world.active_scenario_id, slot)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "Failed to open '%s' for writing (error %d)." % [
			path, FileAccess.get_open_error()]
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return ""


# ── Pending load state (persists across scene reload) ────────────────────────

## Parsed save data waiting to be applied after scene reload.
static var _pending_load_data: Dictionary = {}


## Parse and validate a save file; store data as pending for apply_pending_load().
## Returns "" on success, or a human-readable error string on failure.
static func prepare_load(scenario_id: String, slot: int) -> String:
	if not has_save(scenario_id, slot):
		return "No save found for this scenario."

	var f := FileAccess.open(save_path(scenario_id, slot), FileAccess.READ)
	if f == null:
		return "Could not open save file."
	var text := f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return "Save file is corrupted (invalid JSON)."

	var ver: int = int(parsed.get("version", 0))
	if ver != SAVE_VERSION:
		return "Save version mismatch (file=%d, game=%d). Cannot load." % [
			ver, SAVE_VERSION]

	_pending_load_data = parsed
	return ""


## Returns true if there is pending save data waiting to be applied.
static func has_pending_load() -> bool:
	return not _pending_load_data.is_empty()


## Returns the scenario_id from pending load data.
static func pending_scenario_id() -> String:
	return _pending_load_data.get("scenario_id", "scenario_1")


## Apply the pending save data to all game systems.
## Call at the end of main.gd _on_begin_game(), after all inits complete.
static func apply_pending_load(
		world:     Node2D,
		day_night: Node,
		journal:   CanvasLayer
) -> void:
	if _pending_load_data.is_empty():
		return
	var data := _pending_load_data
	_pending_load_data = {}

	_restore_day_night(day_night, data)
	_restore_social_graph(world.social_graph, data.get("social_graph", {}))
	_restore_propagation(world.propagation_engine, data.get("propagation", {}))
	_restore_npc_slots(world.npcs, world.propagation_engine, data.get("npc_slots", {}))
	_restore_intel_store(world.intel_store, data.get("intel_store", {}))
	_restore_scenario_manager(world.scenario_manager, data.get("scenario", {}))
	_restore_rival_agent(world.rival_agent, data.get("rival_agent", {}))
	_restore_inquisitor_agent(world.inquisitor_agent, data.get("inquisitor_agent", {}))
	if journal != null and journal.has_method("restore_timeline"):
		journal.restore_timeline(data.get("timeline", []))
	print("[SaveManager] Save data applied. Tick=%d Day=%d" % [
		day_night.current_tick, day_night.current_day])


# ── Serialisation ─────────────────────────────────────────────────────────────

static func _serialize_social_graph(sg: SocialGraph) -> Dictionary:
	return {
		"edges":          sg.edges.duplicate(true),
		"mutation_log":   sg._mutation_log.duplicate(true),
		"mutation_count": sg._mutation_count.duplicate(true),
		"net_mutations":  sg._net_mutations.duplicate(true),
	}


static func _serialize_propagation(pe: PropagationEngine) -> Dictionary:
	var rumors := {}
	for rid in pe.live_rumors:
		var r: Rumor = pe.live_rumors[rid]
		rumors[rid] = {
			"id":                    r.id,
			"subject_npc_id":        r.subject_npc_id,
			"claim_type":            int(r.claim_type),
			"intensity":             r.intensity,
			"mutability":            r.mutability,
			"created_tick":          r.created_tick,
			"shelf_life_ticks":      r.shelf_life_ticks,
			"current_believability": r.current_believability,
			"lineage_parent_id":     r.lineage_parent_id,
			"bolstered_by_evidence": r.bolstered_by_evidence,
		}
	return {
		"live_rumors":         rumors,
		"lineage":             pe.lineage.duplicate(true),
		"contradiction_count": pe.contradiction_count,
	}


static func _serialize_npc_slots(npcs: Array) -> Dictionary:
	var out := {}
	for npc in npcs:
		var npc_id: String = npc.npc_data.get("id", "")
		if npc_id.is_empty():
			continue
		var slots := {}
		for rid in npc.rumor_slots:
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			slots[rid] = {
				"state":            int(slot.state),
				"ticks_in_state":   slot.ticks_in_state,
				"heard_from_count": slot.heard_from_count,
				"source_faction":   slot.source_faction,
			}
		out[npc_id] = slots
	return out


static func _serialize_intel_store(store: PlayerIntelStore) -> Dictionary:
	var loc_intel := {}
	for loc_id in store.location_intel:
		var entries: Array = []
		for intel: PlayerIntelStore.LocationIntel in store.location_intel[loc_id]:
			entries.append({
				"location_id": intel.location_id,
				"observed_at": intel.observed_at,
				"npcs_seen":   intel.npcs_seen.duplicate(true),
			})
		loc_intel[loc_id] = entries

	var rel_intel := {}
	for key in store.relationship_intel:
		var ri: PlayerIntelStore.RelationshipIntel = store.relationship_intel[key]
		rel_intel[key] = {
			"npc_a_id":         ri.npc_a_id,
			"npc_b_id":         ri.npc_b_id,
			"npc_a_name":       ri.npc_a_name,
			"npc_b_name":       ri.npc_b_name,
			"edge_weight":      ri.edge_weight,
			"observed_at":      ri.observed_at,
			"rich_context":     ri.rich_context,
			"critical_context": ri.critical_context,
		}

	var evidence: Array = []
	for item: PlayerIntelStore.EvidenceItem in store.evidence_inventory:
		evidence.append({
			"type":                item.type,
			"believability_bonus": item.believability_bonus,
			"mutability_modifier": item.mutability_modifier,
			"compatible_claims":   item.compatible_claims.duplicate(),
			"acquired_tick":       item.acquired_tick,
		})

	return {
		"recon_actions_remaining":  store.recon_actions_remaining,
		"whisper_tokens_remaining": store.whisper_tokens_remaining,
		"location_intel":           loc_intel,
		"relationship_intel":       rel_intel,
		"heat":                     store.heat.duplicate(),
		"heat_enabled":             store.heat_enabled,
		"bribe_charges":            store.bribe_charges,
		"evidence_inventory":       evidence,
		"evidence_used_count":      store.evidence_used_count,
	}


static func _serialize_scenario_manager(sm: ScenarioManager) -> Dictionary:
	return {
		"scenario_1_state":   int(sm.scenario_1_state),
		"scenario_2_state":   int(sm.scenario_2_state),
		"scenario_3_state":   int(sm.scenario_3_state),
		"scenario_4_state":   int(sm.scenario_4_state),
		"calder_score_start": sm.calder_score_start,
		"calder_score_final": sm.calder_score_final,
	}


static func _serialize_rival_agent(ra: RivalAgent) -> Dictionary:
	if ra == null:
		return {}
	return {
		"active":         ra._active,
		"last_seed_day":  ra._last_seed_day,
		"alternate_flag": ra._alternate_flag,
	}


static func _serialize_inquisitor_agent(ia: InquisitorAgent) -> Dictionary:
	if ia == null:
		return {}
	return {
		"active":        ia._active,
		"last_seed_day": ia._last_seed_day,
		"target_index":  ia._target_index,
	}


# ── Restoration ───────────────────────────────────────────────────────────────

static func _restore_day_night(dn: Node, data: Dictionary) -> void:
	dn.current_tick = int(data.get("tick", 0))
	dn.current_day  = int(data.get("day",  1))


static func _restore_social_graph(sg: SocialGraph, d: Dictionary) -> void:
	if d.is_empty():
		return
	sg.edges           = d.get("edges",          {}).duplicate(true)
	sg._mutation_log   = d.get("mutation_log",   []).duplicate(true)
	sg._mutation_count = d.get("mutation_count", {}).duplicate(true)
	sg._net_mutations  = d.get("net_mutations",  {}).duplicate(true)


static func _restore_propagation(pe: PropagationEngine, d: Dictionary) -> void:
	if d.is_empty():
		return
	pe.live_rumors.clear()
	for rid in d.get("live_rumors", {}):
		var rd: Dictionary = d["live_rumors"][rid]
		var r := Rumor.create(
			rd["id"],
			rd["subject_npc_id"],
			int(rd["claim_type"]) as Rumor.ClaimType,
			int(rd["intensity"]),
			float(rd["mutability"]),
			int(rd["created_tick"]),
			int(rd["shelf_life_ticks"]),
			rd.get("lineage_parent_id", "")
		)
		r.current_believability = float(rd.get("current_believability", r.current_believability))
		r.bolstered_by_evidence = bool(rd.get("bolstered_by_evidence", false))
		pe.live_rumors[rid] = r
	pe.lineage             = d.get("lineage", {}).duplicate(true)
	pe.contradiction_count = int(d.get("contradiction_count", 0))


static func _restore_npc_slots(
		npcs: Array,
		pe:   PropagationEngine,
		d:    Dictionary
) -> void:
	if d.is_empty():
		return
	for npc in npcs:
		var npc_id: String = npc.npc_data.get("id", "")
		if not d.has(npc_id):
			continue
		npc.rumor_slots.clear()
		for rid in d[npc_id]:
			# Skip slots whose rumor is no longer live (e.g. expired before save).
			if not pe.live_rumors.has(rid):
				continue
			var sd: Dictionary = d[npc_id][rid]
			var r: Rumor       = pe.live_rumors[rid]
			var slot           := Rumor.NpcRumorSlot.new(r, sd.get("source_faction", ""))
			slot.state            = int(sd.get("state", Rumor.RumorState.EVALUATING)) as Rumor.RumorState
			slot.ticks_in_state   = int(sd.get("ticks_in_state", 0))
			slot.heard_from_count = int(sd.get("heard_from_count", 1))
			npc.rumor_slots[rid]  = slot


static func _restore_intel_store(store: PlayerIntelStore, d: Dictionary) -> void:
	if d.is_empty():
		return
	store.recon_actions_remaining  = int(d.get("recon_actions_remaining",  PlayerIntelStore.MAX_DAILY_ACTIONS))
	store.whisper_tokens_remaining = int(d.get("whisper_tokens_remaining", PlayerIntelStore.MAX_DAILY_WHISPERS))
	store.heat                     = d.get("heat", {}).duplicate()
	store.heat_enabled             = bool(d.get("heat_enabled", false))
	store.bribe_charges            = int(d.get("bribe_charges", 0))
	store.evidence_used_count      = int(d.get("evidence_used_count", 0))

	store.location_intel.clear()
	for loc_id in d.get("location_intel", {}):
		for entry in d["location_intel"][loc_id]:
			var intel := PlayerIntelStore.LocationIntel.new(
				entry["location_id"], int(entry["observed_at"]))
			intel.npcs_seen = entry.get("npcs_seen", []).duplicate(true)
			store.add_location_intel(intel)

	store.relationship_intel.clear()
	for key in d.get("relationship_intel", {}):
		var rd: Dictionary = d["relationship_intel"][key]
		var ri := PlayerIntelStore.RelationshipIntel.new(
			rd["npc_a_id"],       rd["npc_b_id"],
			rd.get("npc_a_name", ""), rd.get("npc_b_name", ""),
			float(rd.get("edge_weight", 0.5)),
			int(rd.get("observed_at", 0))
		)
		ri.rich_context     = rd.get("rich_context", "")
		ri.critical_context = rd.get("critical_context", "")
		store.relationship_intel[key] = ri

	store.evidence_inventory.clear()
	for ed in d.get("evidence_inventory", []):
		var item := PlayerIntelStore.EvidenceItem.new(
			ed["type"],
			float(ed.get("believability_bonus", 0.0)),
			float(ed.get("mutability_modifier", 0.0)),
			ed.get("compatible_claims", []).duplicate(),
			int(ed.get("acquired_tick", 0))
		)
		store.evidence_inventory.append(item)


static func _restore_scenario_manager(sm: ScenarioManager, d: Dictionary) -> void:
	if d.is_empty():
		return
	sm.scenario_1_state   = int(d.get("scenario_1_state", ScenarioManager.ScenarioState.ACTIVE)) as ScenarioManager.ScenarioState
	sm.scenario_2_state   = int(d.get("scenario_2_state", ScenarioManager.ScenarioState.ACTIVE)) as ScenarioManager.ScenarioState
	sm.scenario_3_state   = int(d.get("scenario_3_state", ScenarioManager.ScenarioState.ACTIVE)) as ScenarioManager.ScenarioState
	sm.scenario_4_state   = int(d.get("scenario_4_state", ScenarioManager.ScenarioState.ACTIVE)) as ScenarioManager.ScenarioState
	sm.calder_score_start = int(d.get("calder_score_start", -1))
	sm.calder_score_final = int(d.get("calder_score_final", -1))


static func _restore_rival_agent(ra: RivalAgent, d: Dictionary) -> void:
	if ra == null or d.is_empty():
		return
	ra._active         = bool(d.get("active", false))
	ra._last_seed_day  = int(d.get("last_seed_day", 0))
	ra._alternate_flag = bool(d.get("alternate_flag", false))


static func _restore_inquisitor_agent(ia: InquisitorAgent, d: Dictionary) -> void:
	if ia == null or d.is_empty():
		return
	ia._active        = bool(d.get("active", false))
	ia._last_seed_day = int(d.get("last_seed_day", 0))
	ia._target_index  = int(d.get("target_index", 0))
