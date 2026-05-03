## save_manager.gd — Mid-scenario save/load for Rumor Mill (SPA-177, SPA-220, SPA-227).
##
## Saves to user://saves/<scenario_id>_slotN.json  (manual slots 1–3)
##        or user://saves/<scenario_id>_auto.json   (auto-save, slot 0)
## Serializes: tick, day, social graph edges, live rumors with NPC belief slots,
## NPC memory (credulity, rumor history, avoidance, defender state),
## reputation overrides, player intel (recon budget, heat, evidence),
## scenario state, journal timeline, rival agent state (S3),
## inquisitor agent state (S4), s4 faction shift agent state (S4),
## illness escalation agent state (S2), guild defense agent state (S6).
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


## Returns true if any save file exists across all scenarios and slots.
static func has_any_save() -> bool:
	var dir := DirAccess.open("user://saves")
	if dir == null:
		return false
	dir.list_dir_begin()
	var found := false
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".json"):
			found = true
			break
		fname = dir.get_next()
	dir.list_dir_end()
	return found


## Returns the most recent save across all scenarios and slots.
## Returns {} if no saves exist.
## Returns {"scenario_id": String, "slot": int, "day": int, "tick": int,
##          "scenario_title": String} for the newest save (by file modification time).
static func get_most_recent_save(scenario_list: Array = []) -> Dictionary:
	var best: Dictionary = {}
	var best_time: int = -1
	# Build scenario id list — use provided list or scan save dir for ids.
	var ids: Array = []
	if scenario_list.size() > 0:
		for sc in scenario_list:
			ids.append(sc.get("scenarioId", ""))
	else:
		for i in range(1, 7):
			ids.append("scenario_%d" % i)
	for sid in ids:
		for slot in range(0, SLOT_COUNT + 1):
			var path := save_path(sid, slot)
			if not FileAccess.file_exists(path):
				continue
			var mod_time: int = FileAccess.get_modified_time(path)
			if mod_time > best_time:
				best_time = mod_time
				var info := get_save_info(sid, slot)
				best = {
					"scenario_id": sid,
					"slot": slot,
					"day": info.get("day", 1),
					"tick": info.get("tick", 0),
				}
	# Attach scenario title from the list if available.
	if not best.is_empty() and scenario_list.size() > 0:
		for sc in scenario_list:
			if sc.get("scenarioId", "") == best["scenario_id"]:
				best["scenario_title"] = sc.get("title", best["scenario_id"])
				break
	return best


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
		"selected_difficulty": GameState.selected_difficulty,
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
		"mid_game_event_agent":      _serialize_mid_game_event_agent(world.mid_game_event_agent),
		"guild_defense_agent":       _serialize_guild_defense_agent(world.guild_defense_agent),
		"faction_event_system":      _serialize_faction_event_system(world.faction_event_system),
		"socially_dead_ids":    world._socially_dead_ids.keys(),
		"timeline":             timeline,
		"milestone_log":        journal.get_milestone_log() if journal != null and journal.has_method("get_milestone_log") else [],
		"tutorial_progress":    _serialize_tutorial(tutorial_sys),
		"milestone_fired":      world.milestone_tracker._fired.duplicate() if world.milestone_tracker != null else {},
		"daily_planning":       _serialize_daily_planning(world),
	}

	var path := save_path(world.active_scenario_id, slot)
	var tmp_path := path + ".tmp"
	var bak_path := path + ".bak"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return "Failed to open '%s' for writing (error %d)." % [
			tmp_path, FileAccess.get_open_error()]
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	# Atomically replace the save file so a crash during write cannot corrupt the slot.
	dir = DirAccess.open("user://")
	if dir == null:
		return "Failed to open user:// for atomic rename (error %d)." % DirAccess.get_open_error()
	# Keep a .bak of the previous save so it can be recovered if the new write is corrupt.
	if FileAccess.file_exists(path):
		# Best-effort: backup failure should not block saving.
		var _bak_err := dir.rename(path, bak_path)
		if _bak_err != OK:
			push_warning("save_manager: could not create backup '%s' (error %d) — continuing" % [bak_path, _bak_err])
	var rename_err := dir.rename(tmp_path, path)
	if rename_err != OK:
		return "Failed to rename temp save to '%s' (error %d)." % [path, rename_err]
	return ""


# ── Pending load state (persists across scene reload) ────────────────────────

## Parsed save data waiting to be applied after scene reload.
static var _pending_load_data: Dictionary = {}

## Set to true once apply_pending_load() completes for this session.
## Remains true for the lifetime of the scene so tutorial_controller can
## detect that the current session was restored from a save.
static var _session_was_loaded: bool = false


## Returns true if the current game session was restored from a save file.
static func session_was_loaded() -> bool:
	return _session_was_loaded


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

	var json := JSON.new()
	var parse_err := json.parse(text)
	if parse_err != OK:
		return "Save file is corrupted (JSON parse error at line %d: %s)." % [
			json.get_error_line(), json.get_error_message()]
	var parsed: Variant = json.get_data()
	if not (parsed is Dictionary):
		return "Save file is corrupted (expected JSON object)."

	var ver: int = int(parsed.get("version", 0))
	if ver > SAVE_VERSION:
		return "Save version %d is newer than game version %d. Update the game to load this save." % [
			ver, SAVE_VERSION]
	if ver < SAVE_VERSION:
		# Back up the original file before applying migration steps so the
		# pre-migration data is recoverable if migration fails or the game crashes.
		var path := save_path(scenario_id, slot)
		var bak_dir := DirAccess.open("user://")
		if bak_dir != null:
			var bak_err := bak_dir.copy(path, path + ".bak")
			if bak_err != OK:
				push_warning("save_manager: could not create migration backup '%s.bak' (error %d) — continuing" % [path, bak_err])
		var migration_err := _migrate_save_data(parsed, ver)
		if migration_err != "":
			return "Save migration failed: " + migration_err

	# Validate that essential top-level keys exist so apply_pending_load() won't crash.
	var required_keys := ["scenario_id", "tick", "day"]
	for key in required_keys:
		if not parsed.has(key):
			return "Save file is corrupted (missing required key '%s')." % key

	# Warn if the scenario_id inside the file doesn't match what was requested.
	var file_scenario: String = str(parsed.get("scenario_id", ""))
	if file_scenario != "" and file_scenario != scenario_id:
		push_warning("save_manager: save file contains scenario_id '%s' but was loaded for '%s'" % [file_scenario, scenario_id])

	_pending_load_data = parsed
	return ""


## Migrates save data from an older version in-place, applying each step sequentially.
## Returns "" on success or a human-readable error string if migration fails.
static func _migrate_save_data(data: Dictionary, _from_version: int) -> String:
	while data.get("version", 0) < SAVE_VERSION:
		var from_ver: int = int(data.get("version", 0))
		var step_err := _migrate_step(data, from_ver)
		if step_err != "":
			return "v%d: %s" % [from_ver, step_err]
	return ""


## Applies one migration step in-place, advancing data["version"] by one.
## Add a new match arm here whenever SAVE_VERSION increments.
## Returns "" on success or a human-readable error string on failure.
static func _migrate_step(data: Dictionary, from_ver: int) -> String:
	match from_ver:
		0:
			# v0 saves (missing version field) share the same structure as v1.
			# Stamp the version so later steps can rely on it being present.
			push_warning("save_manager: migrating save from v0 to v1")
			data["version"] = 1
		_:
			return "no migration path from v%d" % from_ver
	return ""


## SPA-1544: Reset per-session static state at the start of a fresh New Game.
## Clears any leftover pending-load data and resets the session-was-loaded flag
## so TutorialController and similar consumers see a clean new-game session.
## Must be called from main.gd before scenario data loads.
static func clear_new_game_statics() -> void:
	_session_was_loaded = false
	_pending_load_data  = {}


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

	GameState.selected_difficulty = data.get("selected_difficulty", "master")
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
	_restore_mid_game_event_agent(world.mid_game_event_agent, data.get("mid_game_event_agent", {}))
	_restore_guild_defense_agent(world.guild_defense_agent, data.get("guild_defense_agent", {}))
	_restore_faction_event_system(world.faction_event_system, data.get("faction_event_system", {}))
	world._socially_dead_ids.clear()
	for npc_id in data.get("socially_dead_ids", []):
		if npc_id == null:
			push_warning("save_manager: socially_dead_ids contains null — skipped")
			continue
		world._socially_dead_ids[str(npc_id)] = true
	var _timeline_data: Variant = data.get("timeline", [])
	if journal != null and journal.has_method("restore_timeline") and _timeline_data is Array:
		journal.restore_timeline(_timeline_data)
	var _milestone_data: Variant = data.get("milestone_log", [])
	if journal != null and journal.has_method("restore_milestones") and _milestone_data is Array:
		journal.restore_milestones(_milestone_data)
	_restore_tutorial(tutorial_sys, data.get("tutorial_progress", {}))
	if world.milestone_tracker != null:
		var _mf_raw: Variant = data.get("milestone_fired", {})
		if _mf_raw is Dictionary:
			world.milestone_tracker._fired = _mf_raw.duplicate()
		else:
			push_warning("save_manager: milestone_fired is not a Dictionary — using empty default")
			world.milestone_tracker._fired = {}
	_restore_daily_planning(world, data.get("daily_planning", {}))
	# Rebuild reputation cache after all systems (including FactionEventSystem) are
	# restored so that active event bonuses (e.g. religious_festival +10) are included.
	world.reputation_system.recalculate_all(world.npcs, day_night.current_tick)
	_session_was_loaded = true
	_pending_load_data = {}


# ── Serialisation ─────────────────────────────────────────────────────────────

static func _serialize_social_graph(sg: SocialGraph) -> Dictionary:
	if sg == null:
		return {}
	return {
		"edges":          sg.edges.duplicate(true),
		"mutation_log":   sg._mutation_log.duplicate(true),
		"mutation_count": sg._mutation_count.duplicate(true),
	}


static func _serialize_propagation(pe: PropagationEngine) -> Dictionary:
	if pe == null:
		return {}
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
		"mutation_counter":          pe._mutation_counter,
	}


static func _serialize_npc_slots(npcs: Array) -> Dictionary:
	if npcs == null:
		return {}
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
	if store == null:
		return {}
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
		"free_quarantine_charges":  store.free_quarantine_charges,
		"free_campaign_charges":    store.free_campaign_charges,
		"bonus_expose_uses":        store.bonus_expose_uses,
		"blackmail_uses_count":     store.blackmail_uses_count,
	}


static func _serialize_reputation(rs: ReputationSystem) -> Dictionary:
	if rs == null:
		return {}
	return {
		"base_overrides":            rs._base_overrides.duplicate(),
		"faction_sentiment_bonuses": rs._faction_sentiment_bonuses.duplicate(),
	}


static func _serialize_scenario_manager(sm: ScenarioManager) -> Dictionary:
	if sm == null:
		return {}
	return {
		"scenario_1_state":        int(sm.scenario_1_state),
		"scenario_2_state":        int(sm.scenario_2_state),
		"scenario_3_state":        int(sm.scenario_3_state),
		"scenario_4_state":        int(sm.scenario_4_state),
		"scenario_5_state":        int(sm.scenario_5_state),
		"scenario_6_state":        int(sm.scenario_6_state),
		"calder_score_start":      sm.calder_score_start,
		"calder_score_final":      sm.calder_score_final,
		"deadline_warnings_fired": sm._deadline_warnings_fired.duplicate(),
		"s5_endorsement_fired":    sm._s5_endorsement_fired,
		"s5_endorsed_candidate":   sm.s5_endorsed_candidate,
		"s2_maren_first_reject_tick":        sm._s2_maren_first_reject_tick,
		"s2_maren_carrier_name":             sm.s2_maren_carrier_name,
		"heat_ceiling_override":             sm._heat_ceiling_override,
		"heat_ceiling_override_expires_day": sm._heat_ceiling_override_expires_day,
		"s1_first_blood_fired":              sm._s1_first_blood_fired,
	}


static func _serialize_rival_agent(ra: RivalAgent) -> Dictionary:
	if ra == null:
		return {}
	return {
		"active":                       ra._active,
		"last_seed_day":                ra._last_seed_day,
		"alternate_flag":               ra._alternate_flag,
		"cooldown_offset":              ra.cooldown_offset,
		"disrupt_charges_remaining":    ra.disrupt_charges_remaining,
		"disruption_days_remaining":    ra._disruption_days_remaining,
	}


static func _serialize_inquisitor_agent(ia: InquisitorAgent) -> Dictionary:
	if ia == null:
		return {}
	return {
		"active":            ia._active,
		"last_seed_day":     ia._last_seed_day,
		"target_index":      ia._target_index,
		"cooldown_offset":   ia.cooldown_offset,
		"shielded_npc_ids":  ia._shielded_npc_ids.keys(),
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


static func _serialize_guild_defense_agent(gda: GuildDefenseAgent) -> Dictionary:
	if gda == null:
		return {}
	return {
		"active":           gda._active,
		"last_defense_day": gda._last_defense_day,
		"cooldown_offset":  gda.cooldown_offset,
	}


# ── Restoration ───────────────────────────────────────────────────────────────

static func _restore_day_night(dn: Node, data: Dictionary) -> void:
	if dn == null:
		return
	dn.current_tick = int(data.get("tick", 0))
	dn.current_day  = int(data.get("day",  1))


static func _restore_social_graph(sg: SocialGraph, d: Dictionary) -> void:
	if sg == null or d.is_empty():
		return
	var _edges: Variant = d.get("edges", {})
	sg.edges           = (_edges if _edges is Dictionary else {}).duplicate(true)
	var _mlog: Variant = d.get("mutation_log", [])
	sg._mutation_log   = (_mlog if _mlog is Array else []).duplicate(true)
	var _mcount: Variant = d.get("mutation_count", {})
	sg._mutation_count = (_mcount if _mcount is Dictionary else {}).duplicate(true)


static func _restore_propagation(pe: PropagationEngine, d: Dictionary) -> void:
	if pe == null or d.is_empty():
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
	pe._mutation_counter   = int(d.get("mutation_counter", 0))


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
		var _npc_raw: Variant = d[npc_id]
		if not _npc_raw is Dictionary:
			push_error("save_manager: npc_slots[%s] is not a Dictionary — skipped" % npc_id)
			continue
		var npc_data: Dictionary = _npc_raw
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
	if store == null or d.is_empty():
		return
	store.recon_actions_remaining  = int(d.get("recon_actions_remaining",  PlayerIntelStore.MAX_DAILY_ACTIONS))
	store.whisper_tokens_remaining = int(d.get("whisper_tokens_remaining", PlayerIntelStore.MAX_DAILY_WHISPERS))
	store.heat                     = d.get("heat", {}).duplicate()
	store.heat_enabled             = bool(d.get("heat_enabled", false))
	store.bribe_charges            = int(d.get("bribe_charges", 0))
	store.evidence_used_count      = int(d.get("evidence_used_count", 0))
	store.free_quarantine_charges  = int(d.get("free_quarantine_charges", 0))
	store.free_campaign_charges    = int(d.get("free_campaign_charges", 0))
	store.bonus_expose_uses        = int(d.get("bonus_expose_uses", 0))
	store.blackmail_uses_count     = int(d.get("blackmail_uses_count", 0))

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
		if not ed is Dictionary:
			push_error("save_manager: evidence_inventory entry is not a Dictionary — skipped")
			continue
		var item := PlayerIntelStore.EvidenceItem.new(
			ed.get("type", ""),
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
	if sm == null or d.is_empty():
		return
	sm.scenario_1_state   = int(d.get("scenario_1_state", ScenarioManager.ScenarioState.ACTIVE)) as ScenarioManager.ScenarioState
	sm.scenario_2_state   = int(d.get("scenario_2_state", ScenarioManager.ScenarioState.ACTIVE)) as ScenarioManager.ScenarioState
	sm.scenario_3_state   = int(d.get("scenario_3_state", ScenarioManager.ScenarioState.ACTIVE)) as ScenarioManager.ScenarioState
	sm.scenario_4_state   = int(d.get("scenario_4_state", ScenarioManager.ScenarioState.ACTIVE)) as ScenarioManager.ScenarioState
	sm.scenario_5_state   = int(d.get("scenario_5_state", ScenarioManager.ScenarioState.ACTIVE)) as ScenarioManager.ScenarioState
	sm.scenario_6_state   = int(d.get("scenario_6_state", ScenarioManager.ScenarioState.ACTIVE)) as ScenarioManager.ScenarioState
	sm.calder_score_start        = int(d.get("calder_score_start", -1))
	sm.calder_score_final        = int(d.get("calder_score_final", -1))
	var _raw_fired: Dictionary = d.get("deadline_warnings_fired", {})
	var _fired: Dictionary = {}
	for _k in _raw_fired:
		_fired[int(float(_k))] = _raw_fired[_k]
	sm._deadline_warnings_fired = _fired
	sm._s5_endorsement_fired       = bool(d.get("s5_endorsement_fired", false))
	sm.s5_endorsed_candidate       = str(d.get("s5_endorsed_candidate", ""))
	sm._s2_maren_first_reject_tick          = int(d.get("s2_maren_first_reject_tick", -1))
	sm.s2_maren_carrier_name               = str(d.get("s2_maren_carrier_name", ""))
	sm._heat_ceiling_override              = float(d.get("heat_ceiling_override", -1.0))
	sm._heat_ceiling_override_expires_day  = int(d.get("heat_ceiling_override_expires_day", -1))
	sm._s1_first_blood_fired               = bool(d.get("s1_first_blood_fired", false))


static func _restore_rival_agent(ra: RivalAgent, d: Dictionary) -> void:
	if ra == null or d.is_empty():
		return
	ra._active                       = bool(d.get("active", false))
	ra._last_seed_day                = int(d.get("last_seed_day", 0))
	ra._alternate_flag               = bool(d.get("alternate_flag", false))
	ra.cooldown_offset               = int(d.get("cooldown_offset", 0))
	ra.disrupt_charges_remaining     = int(d.get("disrupt_charges_remaining", RivalAgent.MAX_DISRUPT_CHARGES))
	ra._disruption_days_remaining    = int(d.get("disruption_days_remaining", 0))


static func _restore_inquisitor_agent(ia: InquisitorAgent, d: Dictionary) -> void:
	if ia == null or d.is_empty():
		return
	ia._active         = bool(d.get("active", false))
	ia._last_seed_day  = int(d.get("last_seed_day", 0))
	ia._target_index   = int(d.get("target_index", 0))
	ia.cooldown_offset = int(d.get("cooldown_offset", 0))
	ia._shielded_npc_ids.clear()
	for npc_id in d.get("shielded_npc_ids", []):
		ia._shielded_npc_ids[str(npc_id)] = true


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


static func _restore_guild_defense_agent(gda: GuildDefenseAgent, d: Dictionary) -> void:
	if gda == null or d.is_empty():
		return
	gda._active           = bool(d.get("active", false))
	gda._last_defense_day = int(d.get("last_defense_day", 0))
	gda.cooldown_offset   = int(d.get("cooldown_offset", 0))


static func _serialize_mid_game_event_agent(mgea: MidGameEventAgent) -> Dictionary:
	if mgea == null:
		return {}
	return mgea.to_data()


static func _restore_mid_game_event_agent(mgea: MidGameEventAgent, d: Dictionary) -> void:
	if mgea == null or d.is_empty():
		return
	mgea.restore_from_data(d)


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


# ── SPA-708: Daily planning overlay state ─────────────────────────────────────

static func _serialize_daily_planning(w: Node2D) -> Dictionary:
	var planning: Node = w.get_node_or_null("../DailyPlanningOverlay")
	if planning == null:
		# Fallback: check parent tree (main.gd adds it as sibling of world).
		var main_node: Node = w.get_parent()
		if main_node != null:
			planning = main_node.get_node_or_null("DailyPlanningOverlay")
	if planning != null and planning.has_method("get_save_data"):
		return planning.get_save_data()
	return {}


static func _restore_daily_planning(w: Node2D, d: Dictionary) -> void:
	if d.is_empty():
		return
	var main_node: Node = w.get_parent()
	if main_node == null:
		return
	var planning: Node = main_node.get_node_or_null("DailyPlanningOverlay")
	if planning != null and planning.has_method("apply_load_data"):
		planning.apply_load_data(d)
