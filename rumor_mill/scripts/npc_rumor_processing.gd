## npc_rumor_processing.gd — Rumor state machine, β-spread, ACT, and defender
## logic for NPC (SPA-1009).  Extracted from npc.gd.
## All mutable state (rumor_slots, _is_defending, etc.) lives on the parent NPC
## and is accessed via the _npc back-reference.
## Call setup() from npc.init_from_data().

class_name NpcRumorProcessing
extends Node

## Minimum ticks an NPC must spend in EVALUATING before the believe/reject roll
## fires.  Gives corroboration time to arrive.
const _MIN_EVAL_TICKS: int = 3

var _npc: Node2D = null


func setup(npc: Node2D) -> void:
	_npc = npc


# ── Per-tick entry ────────────────────────────────────────────────────────────

## Drive one tick of the rumor state machine.  Called from npc.on_tick().
func process_rumor_slots(tick: int) -> void:
	var npc_name: String = _npc.npc_data.get("name", "?")
	var faction:  String = _npc.npc_data.get("faction", "")

	for rid in _npc.rumor_slots.keys():
		var slot: Rumor.NpcRumorSlot = _npc.rumor_slots[rid]
		slot.ticks_in_state += 1

		# ── Shelf-life expiry ────────────────────────────────────────────────
		if slot.rumor.is_expired() and slot.state not in [
				Rumor.RumorState.REJECT, Rumor.RumorState.ACT, Rumor.RumorState.EXPIRED]:
			slot.state = Rumor.RumorState.EXPIRED
			slot.ticks_in_state = 0
			_npc._slot_diagnostics[rid] = \
				"Shelf-life elapsed after %d ticks" % slot.rumor.shelf_life_ticks
			_npc._worst_state_dirty = true
			continue

		match slot.state:
			Rumor.RumorState.EVALUATING:
				_tick_evaluating(slot, npc_name, faction, rid, tick)
			Rumor.RumorState.BELIEVE:
				_tick_believe(slot, npc_name, faction, rid, tick)
			Rumor.RumorState.SPREAD:
				_tick_spread(slot, faction, rid, tick)
			Rumor.RumorState.REJECT, Rumor.RumorState.ACT, \
			Rumor.RumorState.CONTRADICTED, Rumor.RumorState.EXPIRED:
				pass  # terminal states

	# ── Post-pass: detect CONTRADICTED (conflicting sentiments for same subject) ─
	var active_by_subject: Dictionary = {}  # subject_npc_id → Array[NpcRumorSlot]
	for rid in _npc.rumor_slots.keys():
		var slot: Rumor.NpcRumorSlot = _npc.rumor_slots[rid]
		if slot.state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD]:
			var sid: String = slot.rumor.subject_npc_id
			if not active_by_subject.has(sid):
				active_by_subject[sid] = []
			active_by_subject[sid].append(slot)

	for sid in active_by_subject:
		var slots_for_subject: Array = active_by_subject[sid]
		var has_positive := false
		var has_negative := false
		for sl in slots_for_subject:
			if Rumor.is_positive_claim(sl.rumor.claim_type):
				has_positive = true
			else:
				has_negative = true
		if has_positive and has_negative:
			var newest: Rumor.NpcRumorSlot = slots_for_subject[0]
			for sl in slots_for_subject:
				if sl.rumor.created_tick > newest.rumor.created_tick:
					newest = sl
			if newest.state != Rumor.RumorState.CONTRADICTED:
				newest.state = Rumor.RumorState.CONTRADICTED
				newest.ticks_in_state = 0
				var subj_name: String = sid
				var subj_node = _npc._npc_id_dict.get(sid, null)
				if subj_node != null:
					subj_name = subj_node.npc_data.get("name", sid)
				_npc._slot_diagnostics[newest.rumor.id] = \
					"Contradicted: opposing claims about %s cancel out" % subj_name
				_npc._worst_state_dirty = true


# ── State transitions ─────────────────────────────────────────────────────────

func _tick_evaluating(
		slot: Rumor.NpcRumorSlot,
		npc_name: String,
		faction: String,
		rid: String,
		tick: int
) -> void:
	if slot.ticks_in_state < _MIN_EVAL_TICKS:
		return

	var rumor: Rumor = slot.rumor
	var effective_credulity: float = _npc._credulity
	var subject_id: String = rumor.subject_npc_id
	if _npc._defense_modifiers.has(subject_id):
		effective_credulity = maxf(effective_credulity - _npc._defense_modifiers[subject_id], 0.0)

	var believe_chance: float = effective_credulity * rumor.current_believability
	if slot.source_faction == faction:
		believe_chance += 0.15
	var extra: int = min(slot.heard_from_count - 1, 3)
	believe_chance += extra * 0.10
	believe_chance = clamp(believe_chance, 0.0, 1.0)

	if randf() < believe_chance:
		slot.state = Rumor.RumorState.BELIEVE
		slot.ticks_in_state = 0
		_npc._worst_state_dirty = true
		_npc._record_rumor_history(rumor, subject_id, "believed", tick)
		_npc._update_schedule_avoidance(rumor)
		if _npc._dialogue != null:
			_npc._dialogue.show_believe_reaction()
	else:
		slot.state = Rumor.RumorState.REJECT
		slot.ticks_in_state = 0
		_npc._worst_state_dirty = true
		if _npc._dialogue != null:
			_npc._dialogue.show_reject_reaction()
		# High-loyalty NPCs who reject a negative rumor about a close ally enter DEFENDING.
		if _npc._loyalty > 0.7 and not Rumor.is_positive_claim(rumor.claim_type) \
				and not _npc._is_defending:
			_npc._is_defending             = true
			_npc._worst_state_dirty        = true
			_npc._defender_target_npc_id   = subject_id
			_npc._defender_ticks_remaining = _npc._DEFENDER_DURATION
			if _npc._dialogue != null:
				_npc._dialogue.show_defending_icon()
			_npc.rumor_state_changed.emit(npc_name, "DEFENDING", rid, "")
		_npc._record_rumor_history(rumor, subject_id, "rejected", tick)
		_npc._apply_credulity_modifier(_npc._CREDULITY_REJECT_PENALTY)


func _tick_believe(
		slot: Rumor.NpcRumorSlot,
		_npc_name: String,
		faction: String,
		_rid: String,
		tick: int
) -> void:
	# ── γ: recovery check — NPC may forget/reject the rumor ──────────────────
	if _npc._has_engine():
		var gamma: float = _npc.propagation_engine_ref.calc_gamma(_npc._loyalty, _npc._temperament)
		if randf() < gamma:
			slot.state = Rumor.RumorState.REJECT
			slot.ticks_in_state = 0
			_npc._worst_state_dirty = true
			return

	# ── ACT threshold ────────────────────────────────────────────────────────
	var act_threshold: int = roundi(8.0 * (1.0 - _npc._temperament))
	if slot.ticks_in_state >= act_threshold:
		slot.state = Rumor.RumorState.ACT
		slot.ticks_in_state = 0
		_npc._worst_state_dirty = true
		_start_act_behavior(slot.rumor, tick)
		_npc._record_rumor_history(slot.rumor, slot.rumor.subject_npc_id, "act", tick)
		_npc._apply_credulity_modifier(_npc._CREDULITY_ACT_GAIN)
		return

	# ── β: spread attempt to each nearby neighbour ───────────────────────────
	if _spread_to_neighbours(slot, faction, tick):
		slot.state = Rumor.RumorState.SPREAD
		slot.ticks_in_state = 0
		_npc._worst_state_dirty = true
		if _npc._movement != null:
			_npc._movement.start_spread_clustering(slot.rumor)


func _tick_spread(
		slot: Rumor.NpcRumorSlot,
		faction: String,
		_rid: String,
		tick: int
) -> void:
	_spread_to_neighbours(slot, faction, tick)


# ── β spread ─────────────────────────────────────────────────────────────────

## Attempt to spread slot.rumor to each nearby NPC using the β formula.
## Returns true if at least one NPC received the rumor this tick.
func _spread_to_neighbours(
		slot: Rumor.NpcRumorSlot,
		spreader_faction: String,
		tick: int
) -> bool:
	if _npc.all_npcs_ref.is_empty():
		return false
	# SPA-868: NPCs inside quarantined buildings cannot spread rumors.
	if _npc.quarantine_ref != null \
			and _npc.quarantine_ref.is_quarantined(_npc.current_location_code):
		return false

	var npc_id: String      = _npc.npc_data.get("id", "")
	var neighbours: Dictionary = {}
	if _npc.social_graph_ref != null:
		neighbours = _npc.social_graph_ref.get_neighbours(npc_id)

	var spread_happened := false

	for other in _npc.all_npcs_ref:
		if other == _npc:
			continue
		var delta: Vector2i    = _npc.current_cell - (other.current_cell as Vector2i)
		var dist_manhattan: int = absi(delta.x) + absi(delta.y)
		if dist_manhattan > _npc.SPREAD_RADIUS:
			continue
		# SPA-868: skip targets inside quarantined buildings.
		if _npc.quarantine_ref != null \
				and _npc.quarantine_ref.is_quarantined(other.current_location_code):
			continue
		var other_state: Rumor.RumorState = other.get_state_for_rumor(slot.rumor.id)
		if other_state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD,
						   Rumor.RumorState.ACT,    Rumor.RumorState.EXPIRED,
						   Rumor.RumorState.REJECT,  Rumor.RumorState.CONTRADICTED]:
			continue

		var tid:    String = other.npc_data.get("id", "")
		var edge_w: float  = neighbours.get(tid, 0.2)
		var t_credulity: float = float(other.npc_data.get("credulity", 0.5))
		var t_faction:   String = other.npc_data.get("faction", "")

		var heat_mod: float = 0.0
		if _npc._has_engine() and _npc.propagation_engine_ref.intel_store_ref != null \
				and _npc.propagation_engine_ref.intel_store_ref.heat_enabled:
			var h: float = _npc.propagation_engine_ref.intel_store_ref.get_heat(tid)
			if h >= 75.0:
				heat_mod = 0.30
			elif h >= 50.0:
				heat_mod = 0.15

		var day_phase_mod := 0.0
		var location_mod  := 0.0
		if _npc._has_engine():
			var slot_idx: int = tick % NpcSchedule.SLOTS_PER_DAY
			day_phase_mod = _npc.propagation_engine_ref.calc_day_phase_mod(slot_idx)
			location_mod  = _npc.propagation_engine_ref.calc_location_susceptibility(
				other.current_location_code
			)

		var beta: float
		if _npc._has_engine():
			beta = _npc.propagation_engine_ref.calc_beta(
				_npc._sociability, t_credulity, edge_w,
				spreader_faction, t_faction,
				heat_mod, day_phase_mod, location_mod
			)
		else:
			beta = _npc._sociability * t_credulity * edge_w * 1.8

		if randf() >= beta:
			continue

		var spread_rumor := slot.rumor
		if _npc._has_engine():
			spread_rumor = _npc.propagation_engine_ref.try_mutate(
				slot.rumor, tick, _npc.all_npcs_ref,
				_npc._temperament, _npc._loyalty, _npc._sociability
			)

		other.hear_rumor(spread_rumor, spreader_faction)
		spread_happened = true

		if _npc._has_engine():
			_npc.propagation_engine_ref.apply_relay_heat(npc_id, spread_rumor.id)

		if _npc._dialogue != null:
			_npc._dialogue.show_spread_bubble(other)
		if _npc._visuals != null:
			_npc._visuals.show_spread_ripple()
		if other._dialogue != null:
			other._dialogue.show_whisper_received()
		if other._visuals != null:
			other._visuals.show_rumor_received_glow()

		# Determine receiver state for pulse line colour (SPA-854).
		var _pulse_outcome := "evaluating"
		if other.rumor_slots.has(spread_rumor.id):
			var _rstate: int = other.rumor_slots[spread_rumor.id].state
			if _rstate in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD, Rumor.RumorState.ACT]:
				_pulse_outcome = "believed"
			elif _rstate in [Rumor.RumorState.REJECT, Rumor.RumorState.CONTRADICTED]:
				_pulse_outcome = "rejected"
		_npc.rumor_transmitted.emit(
			_npc.npc_data.get("name", "?"),
			other.npc_data.get("name", "?"),
			spread_rumor.id,
			_pulse_outcome
		)

	return spread_happened


# ── ACT behavior ──────────────────────────────────────────────────────────────

## Called when this NPC enters ACT state.  Navigates toward/away subject and
## mutates the social graph edge.
func _start_act_behavior(rumor: Rumor, tick: int) -> void:
	if _npc._dialogue != null:
		_npc._dialogue.show_act_icon()
	var positive := Rumor.is_positive_claim(rumor.claim_type)
	if _npc._movement != null:
		_npc._movement.navigate_relative_to_subject(rumor.subject_npc_id, positive)

	var delta: float = 0.0
	match rumor.claim_type:
		Rumor.ClaimType.ACCUSATION, Rumor.ClaimType.SCANDAL, \
		Rumor.ClaimType.HERESY, Rumor.ClaimType.ILLNESS, \
		Rumor.ClaimType.BLACKMAIL, Rumor.ClaimType.SECRET_ALLIANCE, \
		Rumor.ClaimType.FORBIDDEN_ROMANCE:
			delta = -0.15
		Rumor.ClaimType.PRAISE:
			delta = 0.10

	if delta != 0.0 and _npc.social_graph_ref != null:
		var actor_id: String = _npc.npc_data.get("id", "")
		_npc.social_graph_ref.mutate_edge(actor_id, rumor.subject_npc_id, delta, tick)
		_npc.social_graph_ref.mutate_edge(rumor.subject_npc_id, actor_id, delta * 0.5, tick)
		var subject_name := rumor.subject_npc_id
		var subj_node = _npc._npc_id_dict.get(rumor.subject_npc_id, null)
		if subj_node != null:
			subject_name = subj_node.npc_data.get("name", rumor.subject_npc_id)
		_npc.graph_edge_mutated.emit(_npc.npc_data.get("name", ""), subject_name, delta)


# ── Defender tick ─────────────────────────────────────────────────────────────

## Advance the defending NPC's countdown and broadcast the credibility penalty.
## Also rolls for counter-rumor seeding (SPA-911).
func tick_defender(tick: int) -> void:
	if not _npc._is_defending:
		return
	_npc._defender_ticks_remaining -= 1
	if _npc._defender_ticks_remaining <= 0:
		_npc._is_defending             = false
		_npc._worst_state_dirty        = true
		_npc._defender_target_npc_id   = ""
		_npc._defender_ticks_remaining = 0
		if _npc._dialogue != null:
			_npc._dialogue.hide_defending_icon()
		return
	_broadcast_defense(tick)
	_tick_counter_rumor(tick)


## SPA-911: Roll for counter-rumor seeding from a defending NPC.
func _tick_counter_rumor(tick: int) -> void:
	if not _npc._has_engine() or _npc.propagation_engine_ref == null:
		return
	if randf() > _npc._loyalty * 0.12:
		return
	if _npc._defender_target_npc_id.is_empty() or _npc.all_npcs_ref.is_empty():
		return

	var counter_id := "cnt_%s_%d" % [_npc._defender_target_npc_id, Time.get_ticks_msec()]
	var counter_rumor := Rumor.create(
		counter_id,
		_npc._defender_target_npc_id,
		Rumor.ClaimType.PRAISE,
		2,      # low intensity
		0.08,   # low mutability
		tick,
		120,    # short shelf life
		""
	)
	_npc.propagation_engine_ref.register_rumor(counter_rumor)

	var faction: String = _npc.npc_data.get("faction", "")
	for other in _npc.all_npcs_ref:
		if other == _npc:
			continue
		var d: Vector2i = _npc.current_cell - (other.current_cell as Vector2i)
		if absi(d.x) + absi(d.y) > _npc.SPREAD_RADIUS:
			continue
		var already_knows := false
		for slot_val in other.rumor_slots.values():
			if (slot_val as Rumor.NpcRumorSlot).rumor.subject_npc_id == _npc._defender_target_npc_id:
				already_knows = true
				break
		if not already_knows and randf() < _npc._loyalty * 0.35:
			other.hear_rumor(counter_rumor, faction)


## Broadcast a credulity penalty for the defended subject to all social neighbours.
func _broadcast_defense(_tick: int) -> void:
	if _npc.social_graph_ref == null or _npc.all_npcs_ref.is_empty():
		return
	var npc_id: String    = _npc.npc_data.get("id", "")
	var neighbours: Dictionary = _npc.social_graph_ref.get_neighbours(npc_id)
	for tid in neighbours:
		var other = _npc._npc_id_dict.get(tid, null)
		if other == null or other == _npc:
			continue
		other._apply_defense_penalty(_npc._defender_target_npc_id, _npc._DEFENDER_PENALTY)


# ── Spread preview ────────────────────────────────────────────────────────────

## Returns the top-n most likely first-hop spread targets for this NPC,
## ranked by estimated β.  Used by the UI to show a spread-path preview.
func get_spread_preview(n: int = 3) -> Array[Dictionary]:
	if _npc.social_graph_ref == null or _npc.all_npcs_ref.is_empty():
		return []
	var npc_id:          String = _npc.npc_data.get("id", "")
	var spreader_faction: String = _npc.npc_data.get("faction", "")
	var top: Array = _npc.social_graph_ref.get_top_neighbours(npc_id, n + 3)
	var result: Array[Dictionary] = []
	for pair in top:
		var tid:    String = pair[0]
		var weight: float  = pair[1]
		var other_node = _npc._npc_id_dict.get(tid, null)
		if other_node == null:
			continue
		var t_credulity: float  = float(other_node.npc_data.get("credulity", 0.5))
		var t_faction:   String = other_node.npc_data.get("faction", "")
		var faction_mod := 1.2 if t_faction == spreader_faction else 1.0
		var beta_est: float = _npc._sociability * t_credulity * weight * faction_mod * 1.8
		result.append({
			"name":    other_node.npc_data.get("name", "?"),
			"faction": t_faction,
			"beta":    beta_est,
		})
		if result.size() >= n:
			break
	return result
