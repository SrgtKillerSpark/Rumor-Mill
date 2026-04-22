## mid_game_event_agent.gd — Data-driven mid-game narrative events with player choice.
##
## Ghost system: no sprite, no movement. Reads event definitions from the
## "midGameEvents" array in scenarios.json and fires them during their day
## windows with a probability roll.  Each event presents two choices; the
## player picks one and the effects are applied immediately.
##
## Event lifecycle:
##   1. World loads midGameEvents from scenarios.json and passes them here.
##   2. Each day tick, the agent checks unfired events whose window contains
##      the current day.  A random roll against `probability` decides if the
##      event fires.  If the window passes without firing, the event is skipped
##      for this playthrough (replayability).
##   3. When an event fires, `event_presented` is emitted.  Main.gd shows
##      the choice UI and calls `resolve_choice(event_id, choice_index)`.
##   4. Effects are applied via World's public APIs.
##
## Integration:
##   - World creates MidGameEventAgent and calls load_events() + activate().
##   - World._on_day_changed() calls mid_game_event_agent.tick(day, self).
##   - Main.gd connects event_presented → choice UI, then calls resolve_choice.

class_name MidGameEventAgent

## Emitted when an event fires and needs a player choice.
## event_data: the full event Dictionary from scenarios.json.
signal event_presented(event_data: Dictionary)

## Emitted after the player resolves a choice.
## event_id: String, choice_index: int, outcome_text: String.
signal event_resolved(event_id: String, choice_index: int, outcome_text: String)


var _active: bool = false

## All event definitions for the current scenario (loaded from scenarios.json).
var _events: Array = []

## Set of event ids that have already fired or been skipped.
var _resolved_ids: Dictionary = {}

## Set of event ids that were rolled and missed (window still open).
var _rolled_days: Dictionary = {}  # event_id → last day we rolled

## Pending event awaiting player choice (null if none).
var _pending_event: Dictionary = {}

## References injected by World for applying effects.
var _world: Node = null

## Injected agent references for cross-agent effects.
var rival_agent_ref = null       # RivalAgent (S3)
var inquisitor_agent_ref = null  # InquisitorAgent (S4)
var illness_agent_ref = null     # IllnessEscalationAgent (S2)

## Pending delayed rumor injections from decision events.
## Each entry: { claimType, subjectNpcId, intensity, triggerDay, triggerCondition }
var _delayed_rumors: Array = []


func load_events(events: Array) -> void:
	_events = events


func activate() -> void:
	_active = true


## Called once per in-game day from World._on_day_changed().
func tick(current_day: int, world: Node) -> void:
	if not _active:
		return
	_world = world

	# Revert rival intensity bonus when its duration expires.
	if rival_agent_ref != null and rival_agent_ref.has_meta("intensity_revert_day"):
		if current_day >= int(rival_agent_ref.get_meta("intensity_revert_day")):
			var amt: int = int(rival_agent_ref.get_meta("intensity_revert_amount"))
			rival_agent_ref.cooldown_offset += amt
			rival_agent_ref.remove_meta("intensity_revert_day")
			rival_agent_ref.remove_meta("intensity_revert_amount")

	# Process delayed rumor injections (e.g. s3_forgers_offer forgery discovered).
	_tick_delayed_rumors(current_day, world)

	# Don't present a new event while one is pending player choice.
	if not _pending_event.is_empty():
		return

	for ev in _events:
		var ev_id: String = ev.get("id", "")
		if _resolved_ids.has(ev_id):
			continue

		var win_start: int = int(ev.get("dayWindowStart", 0))
		var win_end:   int = int(ev.get("dayWindowEnd", 0))

		# Past the window — mark as skipped.
		if current_day > win_end:
			_resolved_ids[ev_id] = true
			continue

		# Not yet in window.
		if current_day < win_start:
			continue

		# In window — roll once per day.
		var last_roll: int = _rolled_days.get(ev_id, -1)
		if last_roll == current_day:
			continue
		_rolled_days[ev_id] = current_day

		var prob: float = float(ev.get("probability", 0.5))
		if randf() < prob:
			_pending_event = ev
			_resolved_ids[ev_id] = true
			event_presented.emit(ev)
			return  # Only one event per day.


## Called by Main.gd when the player picks a choice.
func resolve_choice(event_id: String, choice_index: int) -> void:
	if _pending_event.is_empty():
		return
	if _pending_event.get("id", "") != event_id:
		push_warning("MidGameEventAgent: resolve_choice id mismatch")
		return

	var choices: Array = _pending_event.get("choices", [])
	if choice_index < 0 or choice_index >= choices.size():
		push_warning("MidGameEventAgent: invalid choice_index %d" % choice_index)
		_pending_event = {}
		return

	var choice: Dictionary = choices[choice_index]
	var effects: Dictionary = choice.get("effects", {})
	var outcome_text: String = choice.get("outcomeText", "")

	_apply_effects(effects)

	event_resolved.emit(event_id, choice_index, outcome_text)
	_pending_event = {}


## Returns true if an event is waiting for player input.
func has_pending_event() -> bool:
	return not _pending_event.is_empty()


## Returns the pending event data (empty dict if none).
func get_pending_event() -> Dictionary:
	return _pending_event


## Serialise state for save/load.
func to_data() -> Dictionary:
	return {
		"resolved_ids":   _resolved_ids.duplicate(),
		"rolled_days":    _rolled_days.duplicate(),
		"pending_event":  _pending_event.duplicate(),
		"delayed_rumors": _delayed_rumors.duplicate(true),
	}


## Restore state from save data.
func restore_from_data(d: Dictionary) -> void:
	_resolved_ids  = d.get("resolved_ids", {}).duplicate()
	_rolled_days   = d.get("rolled_days", {}).duplicate()
	_pending_event = d.get("pending_event", {}).duplicate()
	_delayed_rumors = []
	for entry in d.get("delayed_rumors", []):
		if not entry is Dictionary:
			push_warning("MidGameEventAgent: delayed_rumors entry is not a Dictionary — skipped")
			continue
		if not (entry.has("claimType") and entry.has("subjectNpcId") and entry.has("triggerDay")):
			push_warning("MidGameEventAgent: delayed_rumors entry missing required keys (claimType/subjectNpcId/triggerDay) — skipped")
			continue
		_delayed_rumors.append(entry.duplicate())


# ---------------------------------------------------------------------------
# Effect application
# ---------------------------------------------------------------------------

func _apply_effects(effects: Dictionary) -> void:
	if _world == null:
		return

	# Reputation changes: [{ npcId, delta }]
	var rep_changes: Array = effects.get("reputationChanges", [])
	for rc in rep_changes:
		var npc_id: String = _resolve_npc_id(str(rc.get("npcId", "")))
		var delta: int = int(rc.get("delta", 0))
		if _world.reputation_system != null and not npc_id.is_empty():
			_world.reputation_system.apply_score_delta(npc_id, delta)

	# Heat changes: [{ npcId, delta }]
	var heat_changes: Array = effects.get("heatChanges", [])
	for hc in heat_changes:
		var npc_id: String = str(hc.get("npcId", ""))
		var delta: float = float(hc.get("delta", 0.0))
		if _world.intel_store != null and not npc_id.is_empty():
			_world.intel_store.add_heat(npc_id, delta)

	# Personality (trait) changes: [{ npcId, trait, delta }]
	var pers_changes: Array = effects.get("personalityChanges", [])
	for pc in pers_changes:
		var npc_id: String = str(pc.get("npcId", ""))
		var trait_name: String = str(pc.get("trait", ""))
		var delta: float = float(pc.get("delta", 0.0))
		_apply_personality_delta(npc_id, trait_name, delta)

	# Credulity changes: [{ npcId, delta }]
	var cred_changes: Array = effects.get("credulityChanges", [])
	for cc in cred_changes:
		var npc_id: String = str(cc.get("npcId", ""))
		var delta: float = float(cc.get("delta", 0.0))
		_apply_personality_delta(npc_id, "credulity", delta)

	# Bonus recon actions (temporary).
	var bonus_actions: int = int(effects.get("bonusReconActions", 0))
	var bonus_days: int = int(effects.get("bonusReconDays", 0))
	if bonus_actions > 0 and _world.intel_store != null:
		_world.intel_store.recon_actions_remaining += bonus_actions
		# bonusReconDays is informational — the extra actions are granted now;
		# replenish() will restore the normal cap on subsequent days.

	# Instant illness believers (S2): { subjectNpcId, count, pool }
	var instant_believers: Dictionary = effects.get("instantBelievers", {})
	if not instant_believers.is_empty():
		_apply_instant_believers(instant_believers)

	# Recover believers (S2): { subjectNpcId, count }
	var recover: Dictionary = effects.get("recoverBelievers", {})
	if not recover.is_empty():
		_apply_recover_believers(recover)

	# Illness escalation cooldown delta (S2).
	var illness_cd: int = int(effects.get("illnessEscalationCooldownDelta", 0))
	if illness_cd != 0 and illness_agent_ref != null:
		illness_agent_ref.cooldown_offset += illness_cd
	elif illness_cd != 0:
		push_warning("MidGameEventAgent: illnessEscalationCooldownDelta requested but illness_agent_ref is null — effect skipped")

	# Rival intensity bonus (S3): { delta, durationDays }
	var rival_bonus: Dictionary = effects.get("rivalIntensityBonus", {})
	if not rival_bonus.is_empty() and rival_agent_ref != null:
		rival_agent_ref.cooldown_offset -= int(rival_bonus.get("delta", 0))
		# Duration tracking: rival will revert after durationDays — stored as metadata.
		rival_agent_ref.set_meta("intensity_revert_day",
			_get_current_day() + int(rival_bonus.get("durationDays", 0)))
		rival_agent_ref.set_meta("intensity_revert_amount",
			int(rival_bonus.get("delta", 0)))
	elif not rival_bonus.is_empty():
		push_warning("MidGameEventAgent: rivalIntensityBonus requested but rival_agent_ref is null — effect skipped")

	# Rival cooldown bonus (S3): flat days added to rival cooldown.
	var rival_cd: int = int(effects.get("rivalCooldownBonus", 0))
	if rival_cd != 0 and rival_agent_ref != null:
		rival_agent_ref.cooldown_offset += rival_cd
	elif rival_cd != 0:
		push_warning("MidGameEventAgent: rivalCooldownBonus requested but rival_agent_ref is null — effect skipped")

	# Inject a rumor (S3): { claimType, subjectNpcId, intensity, targetFaction }
	var inject: Dictionary = effects.get("injectRumor", {})
	if not inject.is_empty():
		_apply_inject_rumor(inject)

	# Inquisitor cooldown delta (S4).
	var inq_cd: int = int(effects.get("inquisitorCooldownDelta", 0))
	if inq_cd != 0 and inquisitor_agent_ref != null:
		inquisitor_agent_ref.cooldown_offset += inq_cd
	elif inq_cd != 0:
		push_warning("MidGameEventAgent: inquisitorCooldownDelta requested but inquisitor_agent_ref is null — effect skipped")

	# Inquisitor focus target (S4): { npcId, durationDays }
	var focus: Dictionary = effects.get("inquisitorFocusTarget", {})
	if not focus.is_empty() and inquisitor_agent_ref != null:
		var focus_id: String = _resolve_npc_id(str(focus.get("npcId", "")))
		inquisitor_agent_ref.set_meta("focus_target_id", focus_id)
		inquisitor_agent_ref.set_meta("focus_until_day",
			_get_current_day() + int(focus.get("durationDays", 3)))
	elif not focus.is_empty():
		push_warning("MidGameEventAgent: inquisitorFocusTarget requested but inquisitor_agent_ref is null — effect skipped")

	# Free quarantine charges (S2): int.
	var free_quarantine: int = int(effects.get("freeQuarantineCharges", 0))
	if free_quarantine > 0 and _world != null and _world.intel_store != null:
		_world.intel_store.free_quarantine_charges += free_quarantine

	# Bonus disrupt charges (S3): int.
	var bonus_disrupt: int = int(effects.get("bonusDisruptCharges", 0))
	if bonus_disrupt > 0 and rival_agent_ref != null:
		rival_agent_ref.disrupt_charges_remaining += bonus_disrupt
	elif bonus_disrupt > 0:
		push_warning("MidGameEventAgent: bonusDisruptCharges requested but rival_agent_ref is null — effect skipped")

	# Delayed rumor injection (S3): { claimType, subjectNpcId, intensity, triggerDay, triggerCondition }
	var delayed: Dictionary = effects.get("delayedRumor", {})
	if not delayed.is_empty():
		_delayed_rumors.append(delayed.duplicate())

	# Recon action cost (S4): int — deduct recon actions immediately.
	var recon_cost: int = int(effects.get("reconActionCost", 0))
	if recon_cost > 0 and _world != null and _world.intel_store != null:
		_world.intel_store.recon_actions_remaining = \
			maxi(0, _world.intel_store.recon_actions_remaining - recon_cost)

	# Free campaign charges (S5): int.
	var free_campaign: int = int(effects.get("freeCampaignCharges", 0))
	if free_campaign > 0 and _world != null and _world.intel_store != null:
		_world.intel_store.free_campaign_charges += free_campaign

	# Bonus expose uses (S6): int.
	var bonus_expose: int = int(effects.get("bonusExposeCharges", 0))
	if bonus_expose > 0 and _world != null and _world.intel_store != null:
		_world.intel_store.bonus_expose_uses += bonus_expose

	# Heat ceiling override (S6): { newCeiling, durationDays }
	var heat_override: Dictionary = effects.get("heatCeilingOverride", {})
	if not heat_override.is_empty() and _world != null and _world.scenario_manager != null:
		_world.scenario_manager.apply_heat_ceiling_override(
			float(heat_override.get("newCeiling", 70)),
			int(heat_override.get("durationDays", 4)),
			_get_current_day())

	# Consume all bribe charges (S6): bool.
	if effects.get("consumeAllBribeCharges", false) and _world != null and _world.intel_store != null:
		_world.intel_store.bribe_charges = 0


# ---------------------------------------------------------------------------
# Effect helpers
# ---------------------------------------------------------------------------

func _apply_personality_delta(npc_id: String, trait_name: String, delta: float) -> void:
	if _world == null:
		return
	for npc in _world.npcs:
		if npc.npc_data.get("id", "") != npc_id:
			continue
		var current: float = float(npc.npc_data.get(trait_name, 0.5))
		var new_val: float = clampf(current + delta, 0.0, 1.0)
		npc.npc_data[trait_name] = new_val
		# Sync cached trait fields on the NPC.
		match trait_name:
			"credulity":   npc._credulity   = new_val
			"sociability": npc._sociability  = new_val
			"loyalty":     npc._loyalty      = new_val
			"temperament": npc._temperament  = new_val
		break


func _apply_instant_believers(data: Dictionary) -> void:
	var subject_id: String = str(data.get("subjectNpcId", ""))
	var count: int = int(data.get("count", 0))
	if subject_id.is_empty() or count <= 0:
		return
	# Pick credulous NPCs who don't already have an illness rumor slot for this subject.
	var candidates: Array = []
	for npc in _world.npcs:
		var npc_id: String = npc.npc_data.get("id", "")
		if npc_id == subject_id:
			continue
		if _npc_has_illness_slot(npc, subject_id):
			continue
		var cred: float = float(npc.npc_data.get("credulity", 0.5))
		if cred >= 0.40:
			candidates.append(npc)
	candidates.shuffle()
	var seeded: int = 0
	for npc in candidates:
		if seeded >= count:
			break
		var npc_id: String = npc.npc_data.get("id", "")
		_world.inject_rumor(npc_id, "illness", 3, subject_id, "mid_game_event")
		seeded += 1


func _apply_recover_believers(data: Dictionary) -> void:
	var subject_id: String = str(data.get("subjectNpcId", ""))
	var count: int = int(data.get("count", 0))
	if subject_id.is_empty() or count <= 0:
		return
	# Find current believers and force-reject their illness rumor slots.
	var believers: Array = []
	for npc in _world.npcs:
		if _npc_has_illness_belief(npc, subject_id):
			believers.append(npc)
	believers.shuffle()
	var recovered: int = 0
	for npc in believers:
		if recovered >= count:
			break
		_force_reject_illness_slot(npc, subject_id)
		recovered += 1


## Check if an NPC has any rumor slot for illness about a given subject.
func _npc_has_illness_slot(npc: Node, subject_id: String) -> bool:
	for rid in npc.rumor_slots:
		var slot = npc.rumor_slots[rid]
		if slot.rumor != null \
				and slot.rumor.claim_type == Rumor.ClaimType.ILLNESS \
				and slot.rumor.subject_npc_id == subject_id:
			return true
	return false


## Check if an NPC is in BELIEVE/SPREAD/ACT for illness about a given subject.
func _npc_has_illness_belief(npc: Node, subject_id: String) -> bool:
	for rid in npc.rumor_slots:
		var slot = npc.rumor_slots[rid]
		if slot.rumor != null \
				and slot.rumor.claim_type == Rumor.ClaimType.ILLNESS \
				and slot.rumor.subject_npc_id == subject_id \
				and slot.state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD, Rumor.RumorState.ACT]:
			return true
	return false


## Force an NPC's illness rumor slot to REJECT state.
func _force_reject_illness_slot(npc: Node, subject_id: String) -> void:
	for rid in npc.rumor_slots:
		var slot = npc.rumor_slots[rid]
		if slot.rumor != null \
				and slot.rumor.claim_type == Rumor.ClaimType.ILLNESS \
				and slot.rumor.subject_npc_id == subject_id \
				and slot.state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD, Rumor.RumorState.ACT]:
			slot.state = Rumor.RumorState.REJECT
			slot.ticks_in_state = 0
			return


func _apply_inject_rumor(data: Dictionary) -> void:
	var claim_type: String = str(data.get("claimType", "scandal"))
	var subject_id: String = str(data.get("subjectNpcId", ""))
	var intensity: int = int(data.get("intensity", 3))
	var target_faction: String = str(data.get("targetFaction", ""))
	if subject_id.is_empty():
		return
	# Pick a seed NPC from the target faction.
	var seed_npc_id: String = ""
	if not target_faction.is_empty():
		for npc in _world.npcs:
			if npc.npc_data.get("faction", "") == target_faction:
				seed_npc_id = npc.npc_data.get("id", "")
				break
	if seed_npc_id.is_empty():
		# Fallback: pick highest-sociability NPC.
		var best_soc: float = -1.0
		for npc in _world.npcs:
			var soc: float = float(npc.npc_data.get("sociability", 0.5))
			var npc_id: String = npc.npc_data.get("id", "")
			if npc_id != subject_id and soc > best_soc:
				best_soc = soc
				seed_npc_id = npc_id
	if not seed_npc_id.is_empty():
		_world.inject_rumor(seed_npc_id, claim_type, intensity, subject_id, "mid_game_event")


func _get_current_day() -> int:
	if _world == null or _world.day_night == null:
		return 1
	return _world.day_night.current_tick / 24 + 1


## Resolves placeholder NPC ids like __weakest_protected__ to actual NPC ids.
func _resolve_npc_id(raw_id: String) -> String:
	if not raw_id.begins_with("__"):
		return raw_id

	var protected_ids: Array = ["aldous_prior", "vera_midwife", "finn_monk"]

	match raw_id:
		"__weakest_protected__":
			return _get_protected_by_score(protected_ids, true)
		"__highest_rep_protected__":
			return _get_protected_by_score(protected_ids, false)
		"__other_protected_1__":
			var top_id: String = _get_protected_by_score(protected_ids, false)
			for npc_id in protected_ids:
				if npc_id != top_id:
					return npc_id
			return protected_ids[1] if protected_ids.size() > 1 else ""
		"__other_protected_2__":
			var top_id: String = _get_protected_by_score(protected_ids, false)
			var found_first: bool = false
			for npc_id in protected_ids:
				if npc_id == top_id:
					continue
				if not found_first:
					found_first = true
					continue
				return npc_id
			return protected_ids[2] if protected_ids.size() > 2 else ""

	return raw_id


## Process any pending delayed rumors whose trigger day has arrived.
## Checks the optional triggerCondition before injecting.
func _tick_delayed_rumors(current_day: int, world: Node) -> void:
	if _delayed_rumors.is_empty():
		return
	_world = world
	var fired: Array = []
	for dr in _delayed_rumors:
		var trigger_day: int = int(dr.get("triggerDay", -1))
		if trigger_day < 0 or current_day < trigger_day:
			continue
		# Past trigger day — check condition then fire or discard.
		fired.append(dr)
		if not _check_delayed_condition(dr.get("triggerCondition", {})):
			continue
		var inject: Dictionary = {
			"claimType":    str(dr.get("claimType", "scandal")),
			"subjectNpcId": str(dr.get("subjectNpcId", "")),
			"intensity":    int(dr.get("intensity", 3)),
		}
		_apply_inject_rumor(inject)
	for dr in fired:
		_delayed_rumors.erase(dr)


## Returns true if the condition is met (or there is no condition).
func _check_delayed_condition(cond: Dictionary) -> bool:
	if cond.is_empty():
		return true
	var ctype: String = str(cond.get("type", ""))
	match ctype:
		"rep_above":
			if _world == null or _world.reputation_system == null:
				return true
			var npc_id: String = _resolve_npc_id(str(cond.get("npcId", "")))
			var threshold: int = int(cond.get("threshold", 0))
			var snap = _world.reputation_system.get_snapshot(npc_id)
			return snap != null and snap.score > threshold
		_:
			return true


func _get_protected_by_score(ids: Array, want_lowest: bool) -> String:
	if _world == null or _world.reputation_system == null:
		return ids[0] if ids.size() > 0 else ""
	var best_id: String = ""
	var best_score: int = 999 if want_lowest else -1
	for npc_id in ids:
		var snap = _world.reputation_system.get_snapshot(npc_id)
		var score: int = snap.score if snap != null else 50
		if want_lowest and score < best_score:
			best_score = score
			best_id = npc_id
		elif not want_lowest and score > best_score:
			best_score = score
			best_id = npc_id
	return best_id
