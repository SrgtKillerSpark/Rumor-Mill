## save_manager.gd — Mid-scenario save/load for Rumor Mill (SPA-177, SPA-220, SPA-227).
##
## Saves to user://saves/<scenario_id>_slotN.json  (manual slots 1–3)
##        or user://saves/<scenario_id>_auto.json   (auto-save, slot 0)
## Serializes: tick, day, social graph edges, live rumors with NPC belief slots,
## NPC memory (credulity, rumor history, avoidance, defender state),
## reputation overrides, player intel (recon budget, heat, evidence),
## scenario state, journal timeline, rival agent state (S3),
## inquisitor agent state (S4), s4 faction shift agent state (S4),
## illness escalation agent state (S2).
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
## tutorial_sys: optional TutorialSystem reference; when provided, seen-tooltip
##               progress and last hint id are included in the save.
## Returns "" on success, or a human-readable error string on failure.
static func save_game(
		world:        Node2D,
		day_night:    Node,
		journal:      CanvasLayer,
		slot:         int = 1,
		tutorial_sys: TutorialSystem = null
) -> String:
	if slot < AUTO_SLOT or slot > SLOT_COUNT:
		return "Invalid save slot %d (must be %d–%d)." % [slot, AUTO_SLOT, SLOT_COUNT]
	# Ensure save directory exists.
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("saves"):
		dir.make_dir("saves")

	# Combine flushed log + any pending (buffered-this-tick) events.
	var timeline: Array = []
	if journal != null:
		timeline = journal._timeline_log.duplicate()
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
		"reputation":       _serialize_reputation(world.reputation_system),
		"scenario":         _serialize_scenario_manager(world.scenario_manager),
		"rival_agent":               _serialize_rival_agent(world.rival_agent),
		"inquisitor_agent":          _serialize_inquisitor_agent(world.inquisitor_agent),
		"s4_faction_shift_agent":    _serialize_s4_faction_shift_agent(world.s4_faction_shift_agent),
		"illness_escalation_agent":  _serialize_illness_escalation_agent(world.illness_escalation_agent),
		"faction_event_system":      _serialize_faction_event_system(world.faction_event_system),
		"socially_dead_ids":    world._socially_dead_ids.keys(),
		"timeline":             timeline,
		"tutorial_progress":    _serialize_tutorial(tutorial_sys),
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
## tutorial_sys: optional TutorialSystem reference; when provided, seen-tooltip
##               progress and last hint id are restored from the save.
static func apply_pending_load(
		world:        Node2D,
		day_night:    Node,
		journal:      CanvasLayer,
		tutorial_sys: TutorialSystem = null
) -> void:
	if _pending_load_data.is_empty():
		return
	var data := _pending_load_data

	_restore_day_night(day_night, data)
	_restore_social_graph(world.social_graph, data.get("social_graph", {}))
	_restore_propagation(world.propagation_engine, data.get("propagation", {}))
	_restore_npc_slots(world.npcs, world.propagation_engine, data.get("npc_slots", {}))
	_restore_intel_store(world.intel_store, data.get("intel_store", {}))
	_restore_reputation(world.reputation_system, data.get("reputation", {}))
	_restore_scenario_manager(world.scenario_manager, data.get("scenario", {}))
	_restore_rival_agent(world.rival_agent, data.get("rival_agent", {}))
	_restore_inquisitor_agent(world.inquisitor_agent, data.get("inquisitor_agent", {}))
	_restore_s4_faction_shift_agent(world.s4_faction_shift_agent, data.get("s4_faction_shift_agent", {}))
	_restore_illness_escalation_agent(world.illness_escalation_agent, data.get("illness_escalation_agent", {}))
	_restore_faction_event_system(world.faction_event_system, data.get("faction_event_system", {}))
	world._socially_dead_ids.clear()
	for npc_id in data.get("socially_dead_ids", []):
		world._socially_dead_ids[npc_id] = true
	var _timeline_data: Variant = data.get("timeline", [])
	if journal != null and journal.has_method("restore_timeline") and _timeline_data is Array:
		journal.restore_timeline(_timeline_data)
	_restore_tutorial(tutorial_sys, data.get("tutorial_progress", {}))
	# Rebuild reputation cache after all systems (including FactionEventSystem) are
	# restored so that active event bonuses (e.g. religious_festival +10) are included.
	world.reputation_system.recalculate_all(world.npcs, day_night.current_tick)
	_pending_load_data = {}


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
		"live_rumors":               rumors,
		"lineage":                   pe.lineage.duplicate(true),
		"contradiction_count":       pe.contradiction_count,
		"time_pressure_bonus":       pe.time_pressure_bonus,
		"target_shift_excluded_ids": pe.target_shift_excluded_ids.duplicate(),
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
		out[npc_id] = {
			"slots":                    slots,
			"rumor_history":            npc.rumor_history.duplicate(),
			"_credulity_modifier":      npc._credulity_modifier,
			"_avoided_subject_ids":     npc._avoided_subject_ids.duplicate(),
			"_is_defending":            npc._is_defending,
			"_defender_target_npc_id":  npc._defender_target_npc_id,
			"_defender_ticks_remaining": npc._defender_ticks_remaining,
			"_defense_modifiers":       npc._defense_modifiers.duplicate(),
			"_defense_modifier_ticks":  npc._defense_modifier_ticks.duplicate(),
		}
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


static func _serialize_reputation(rs: ReputationSystem) -> Dictionary:
	if rs == null:
		return {}
	return {
		"base_overrides":            rs._base_overrides.duplicate(),
		"faction_sentiment_bonuses": rs._faction_sentiment_bonuses.duplicate(),
	}


static func _serialize_scenario_manager(sm: ScenarioManager) -> Dictionary:
	return {
		"scenario_1_state":        int(sm.scenario_1_state),
		"scenario_2_state":        int(sm.scenario_2_state),
		"scenario_3_state":        int(sm.scenario_3_state),
		"scenario_4_state":        int(sm.scenario_4_state),
		"calder_score_start":      sm.calder_score_start,
		"calder_score_final":      sm.calder_score_final,
		"deadline_warnings_fired": sm._deadline_warnings_fired.duplicate(),
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


static func _serialize_illness_escalation_agent(iea: IllnessEscalationAgent) -> Dictionary:
	if iea == null:
		return {}
	return {
		"active":          iea._active,
		"last_seed_day":   iea._last_seed_day,
		"cooldown_offset": iea.cooldown_offset,
	}


static func _serialize_s4_faction_shift_agent(agent: S4FactionShiftAgent) -> Dictionary:
	if agent == null:
		return {}
	return {
		"active":        agent._active,
		"phase_1_fired": agent._phase_1_fired,
		"phase_2_fired": agent._phase_2_fired,
		"phase_3_fired": agent._phase_3_fired,
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
		var rd: Variant = d["live_rumors"][rid]
		if not rd is Dictionary:
			push_error("save_manager: live_rumors[%s] is not a Dictionary — skipped" % rid)
			continue
		if not (rd.has("id") and rd.has("subject_npc_id") and rd.has("claim_type")):
			push_error("save_manager: live_rumors[%s] missing required keys — skipped" % rid)
			continue
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
	pe.time_pressure_bonus = float(d.get("time_pressure_bonus", 0.0))
	pe.target_shift_excluded_ids.assign(d.get("target_shift_excluded_ids", []))


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
		var npc_data: Dictionary = d[npc_id]
		# Support new format (slots nested under "slots" key) and legacy flat format.
		var slot_data: Dictionary = npc_data.get("slots", npc_data) as Dictionary
		npc.rumor_slots.clear()
		for rid in slot_data:
			if not pe.live_rumors.has(rid):
				push_warning("Save/load: NPC %s references missing rumor %s — slot dropped" % [npc_id, rid])
				continue
			var sd: Dictionary = slot_data[rid]
			var r: Rumor       = pe.live_rumors[rid]
			var slot           := Rumor.NpcRumorSlot.new(r, sd.get("source_faction", ""))
			var _state_raw: Variant = sd.get("state", Rumor.RumorState.EVALUATING)
			if not (_state_raw is int or _state_raw is float):
				push_warning("save_manager: slot state for rumor %s is non-numeric (%s) — using EVALUATING" % [rid, _state_raw])
				_state_raw = Rumor.RumorState.EVALUATING
			slot.state            = int(_state_raw) as Rumor.RumorState
			slot.ticks_in_state   = int(sd.get("ticks_in_state", 0))
			slot.heard_from_count = int(sd.get("heard_from_count", 1))
			npc.rumor_slots[rid]  = slot
		# Restore NPC memory state (SPA-227).
		if npc_data.has("rumor_history"):
			npc.rumor_history             = npc_data["rumor_history"].duplicate()
			npc._credulity_modifier       = float(npc_data.get("_credulity_modifier", 0.0))
			npc._avoided_subject_ids.assign(npc_data.get("_avoided_subject_ids", []))
			npc._is_defending             = bool(npc_data.get("_is_defending", false))
			npc._defender_target_npc_id   = str(npc_data.get("_defender_target_npc_id", ""))
			npc._defender_ticks_remaining = int(npc_data.get("_defender_ticks_remaining", 0))
			npc._defense_modifiers        = npc_data.get("_defense_modifiers", {}).duplicate()
			npc._defense_modifier_ticks   = npc_data.get("_defense_modifier_ticks", {}).duplicate()


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
			if not entry is Dictionary or not entry.has("location_id") or not entry.has("observed_at"):
				push_error("save_manager: malformed location_intel entry — skipped")
				continue
			var intel := PlayerIntelStore.LocationIntel.new(
				entry["location_id"], int(entry["observed_at"]))
			intel.npcs_seen = entry.get("npcs_seen", []).duplicate(true)
			store.add_location_intel(intel)

	store.relationship_intel.clear()
	for key in d.get("relationship_intel", {}):
		var rd: Variant = d["relationship_intel"][key]
		if not rd is Dictionary:
			push_error("save_manager: relationship_intel[%s] is not a Dictionary — skipped" % key)
			continue
		var _ew: Variant = rd.get("edge_weight", 0.5)
		if not rd.has("npc_a_id") or not rd.has("npc_b_id"):
			push_error("save_manager: relationship_intel[%s] missing npc_a_id/npc_b_id — skipped" % key)
			continue
		var ri := PlayerIntelStore.RelationshipIntel.new(
			rd["npc_a_id"],       rd["npc_b_id"],
			rd.get("npc_a_name", ""), rd.get("npc_b_name", ""),
			float(_ew if _ew is float or _ew is int else 0.5),
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


static func _restore_reputation(rs: ReputationSystem, d: Dictionary) -> void:
	if rs == null or d.is_empty():
		return
	rs._base_overrides            = d.get("base_overrides", {}).duplicate()
	rs._faction_sentiment_bonuses = d.get("faction_sentiment_bonuses", {}).duplicate()


static func _restore_scenario_manager(sm: ScenarioManager, d: Dictionary) -> void:
	if d.is_empty():
		return
	sm.scenario_1_state   = int(d.get("scenario_1_state", ScenarioManager.ScenarioState.ACTIVE)) as ScenarioManager.ScenarioState
	sm.scenario_2_state   = int(d.get("scenario_2_state", ScenarioManager.ScenarioState.ACTIVE)) as ScenarioManager.ScenarioState
	sm.scenario_3_state   = int(d.get("scenario_3_state", ScenarioManager.ScenarioState.ACTIVE)) as ScenarioManager.ScenarioState
	sm.scenario_4_state   = int(d.get("scenario_4_state", ScenarioManager.ScenarioState.ACTIVE)) as ScenarioManager.ScenarioState
	sm.calder_score_start        = int(d.get("calder_score_start", -1))
	sm.calder_score_final        = int(d.get("calder_score_final", -1))
	var _raw_fired: Dictionary = d.get("deadline_warnings_fired", {})
	var _fired: Dictionary = {}
	for _k in _raw_fired:
		_fired[int(float(_k))] = _raw_fired[_k]
	sm._deadline_warnings_fired = _fired


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


static func _restore_s4_faction_shift_agent(agent: S4FactionShiftAgent, d: Dictionary) -> void:
	if agent == null or d.is_empty():
		return
	agent._active        = bool(d.get("active", false))
	agent._phase_1_fired = bool(d.get("phase_1_fired", false))
	agent._phase_2_fired = bool(d.get("phase_2_fired", false))
	agent._phase_3_fired = bool(d.get("phase_3_fired", false))


static func _restore_illness_escalation_agent(iea: IllnessEscalationAgent, d: Dictionary) -> void:
	if iea == null or d.is_empty():
		return
	iea._active          = bool(d.get("active", false))
	iea._last_seed_day   = int(d.get("last_seed_day", 0))
	iea.cooldown_offset  = int(d.get("cooldown_offset", 0))


static func _serialize_faction_event_system(fes: FactionEventSystem) -> Dictionary:
	if fes == null:
		return {}
	var events: Array = []
	for ev in fes._events:
		events.append({
			"event_type":       ev.event_type,
			"trigger_day":      ev.trigger_day,
			"duration_days":    ev.duration_days,
			"affected_npc_ids": ev.affected_npc_ids.duplicate(),
			"metadata":         ev.metadata.duplicate(true),
			"is_active":        ev.is_active,
			"is_expired":       ev.is_expired,
		})
	return {
		"events":             events,
		"eavesdrop_hotspots": fes.eavesdrop_hotspots.duplicate(),
	}


static func _restore_faction_event_system(fes: FactionEventSystem, d: Dictionary) -> void:
	if fes == null or d.is_empty():
		return
	fes.restore_from_data(d)


static func _serialize_tutorial(ts: TutorialSystem) -> Dictionary:
	if ts == null:
		return {}
	return {
		"seen":         ts._seen.duplicate(),
		"last_hint_id": ts._last_hint_id,
	}


static func _restore_tutorial(ts: TutorialSystem, d: Dictionary) -> void:
	if ts == null or d.is_empty():
		return
	ts._seen         = d.get("seen", {}).duplicate()
	ts._last_hint_id = str(d.get("last_hint_id", ""))
