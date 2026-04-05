## reputation_system.gd — Reputation score system.
##
## Derives a 0-100 ReputationSnapshot for each NPC from the current social graph
## state each tick.  Plain class (no Node); owned by World.
##
## Formula (per design doc SPA-22#document-reputation-system):
##   score = clamp(base_score + faction_sentiment + rumor_delta, 0, 100)
##     base_score      = 50
##     faction_sentiment = -20 to +20
##     rumor_delta       = -40 to +30
##
## Sprint 7 performance pass: recalculate_all now does a single O(N×slots) scan
## to build lookup tables, eliminating the original O(N³) triple-nested loop.

class_name ReputationSystem

## Claim direction: +1 boosts reputation, -1 damages it.
## Prophecy treated as positive in vertical slice (blessing default).
const CLAIM_DIRECTION: Dictionary = {
	Rumor.ClaimType.PRAISE:            1,
	Rumor.ClaimType.PROPHECY:          1,
	Rumor.ClaimType.ACCUSATION:       -1,
	Rumor.ClaimType.SCANDAL:          -1,
	Rumor.ClaimType.ILLNESS:          -1,
	Rumor.ClaimType.DEATH:            -1,
	Rumor.ClaimType.HERESY:           -1,
	Rumor.ClaimType.BLACKMAIL:        -1,
	Rumor.ClaimType.SECRET_ALLIANCE:  -1,
	Rumor.ClaimType.FORBIDDEN_ROMANCE:-1,
}

## SOCIALLY_DEAD edge case thresholds.
const SOCIALLY_DEAD_BELIEVABILITY := 0.6
const SOCIALLY_DEAD_MIN_BELIEVERS := 5

## States that count as "actively believing" a rumor.
const _BELIEVER_STATES: Array = [
	Rumor.RumorState.BELIEVE,
	Rumor.RumorState.SPREAD,
	Rumor.RumorState.ACT,
]


# ---------------------------------------------------------------------------
# ReputationSnapshot — output of one calculate pass for one NPC.
# ---------------------------------------------------------------------------
class ReputationSnapshot:
	var npc_id:               String
	var score:                int     ## 0-100, clamped final value
	var base_score:           int     ## always 50 in vertical slice
	var faction_sentiment:    float   ## -20 to +20
	var rumor_delta:          float   ## -40 to +30
	var last_calculated_tick: int
	var is_socially_dead:     bool    ## reputation locked when true


# ---------------------------------------------------------------------------
# Starting reputation overrides: npc_id → base_score (set by scenario loader).
# ---------------------------------------------------------------------------
var _base_overrides: Dictionary = {}


## Override the base score for a specific NPC (used by scenario starting states).
func set_base_override(npc_id: String, base_score: int) -> void:
	_base_overrides[npc_id] = clampi(base_score, 0, 100)


## Apply a delta to an NPC's base score (e.g. +5 or -3 from mid-game events).
## Reads the current base (override or default 50) and adjusts it.
func apply_score_delta(npc_id: String, delta: int) -> void:
	var current: int = _base_overrides.get(npc_id, 50)
	# If a snapshot exists, use its score as the more accurate current value.
	var snap: ReputationSnapshot = _cache.get(npc_id, null) as ReputationSnapshot
	if snap != null:
		current = snap.score
	_base_overrides[npc_id] = clampi(current + delta, 0, 100)


## Remove all base score overrides (e.g. when loading a new scenario).
func clear_base_overrides() -> void:
	_base_overrides.clear()


# ---------------------------------------------------------------------------
# Faction sentiment bonuses: npc_id → float bonus (set by FactionEventSystem).
# Applied on top of the computed faction_sentiment in the final score.
# ---------------------------------------------------------------------------
var _faction_sentiment_bonuses: Dictionary = {}


## Set a flat sentiment bonus for an NPC (e.g. +10 during religious festival).
func set_faction_sentiment_bonus(npc_id: String, bonus: float) -> void:
	_faction_sentiment_bonuses[npc_id] = bonus


## Remove the sentiment bonus for an NPC when the event expires.
func clear_faction_sentiment_bonus(npc_id: String) -> void:
	_faction_sentiment_bonuses.erase(npc_id)


# ---------------------------------------------------------------------------
# Cache: npc_id → ReputationSnapshot (refreshed once per tick).
# ---------------------------------------------------------------------------
var _cache: Dictionary = {}

## Per-tick cache: count of unique NPCs in BELIEVE/SPREAD/ACT state for any rumor.
var _global_believer_count: int = 0

## Per-tick cache: npc_id → count of NPCs in BELIEVE/SPREAD/ACT state for
## illness-type rumors targeting that NPC.  Used by Scenario 2 evaluator.
var _illness_believer_counts: Dictionary = {}

## Per-tick cache: subject_npc_id → { observer_npc_id: true } for individual
## NPCs in BELIEVE/SPREAD/ACT state for illness-type rumors.  Used by S2 HUD.
var _illness_believer_ids: Dictionary = {}

## Per-tick cache: subject_npc_id → { observer_npc_id: true } for NPCs in
## REJECT state for illness-type rumors.  Used by Scenario 2 contradicted-fail.
var _illness_rejecter_ids: Dictionary = {}


## Recalculate snapshots for every NPC in all_npcs.
## Call at the START of each tick, before state transitions fire.
##
## Sprint 7: single O(N×slots) pre-computation pass eliminates the original
## triple-nested loop (was O(N³) in the worst case with many rumors).
func recalculate_all(all_npcs: Array, current_tick: int) -> void:
	# ── Build NPC id → faction and faction size tables ─────────────────────
	var npc_id_to_faction: Dictionary = {}  # npc_id → faction String
	var faction_sizes:     Dictionary = {}  # faction → int count

	for npc in all_npcs:
		var nid: String = npc.npc_data.get("id", "")
		if nid.is_empty():
			continue
		var f: String = npc.npc_data.get("faction", "")
		npc_id_to_faction[nid] = f
		faction_sizes[f] = faction_sizes.get(f, 0) + 1

	# ── Single O(N×slots) scan — collect all derived data in one pass ──────
	#
	# believer_counts[rid]          → int  (NPCs in BELIEVE/SPREAD/ACT state)
	# rumor_first_slot[rid]         → NpcRumorSlot  (properties shared by all
	#                                  holders of the same rumor id)
	# rids_by_subject[npc_id]       → Dictionary { rid: true }
	# death_info[subject_npc_id]    → { count: int, max_bel: float }
	# faction_bel_info[subject_npc_id][believer_faction]
	#                               → { count: int, ct_counts: { ClaimType: int } }

	var believer_counts:   Dictionary = {}
	var rumor_first_slot:  Dictionary = {}
	var rids_by_subject:   Dictionary = {}
	var death_info:        Dictionary = {}
	var faction_bel_info:  Dictionary = {}
	var global_believer_ids: Dictionary = {}  # npc_id → true; for unique believer count

	_illness_believer_ids.clear()
	_illness_rejecter_ids.clear()
	for npc in all_npcs:
		var npc_faction: String = npc.npc_data.get("faction", "")
		for rid in npc.rumor_slots:
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			var subject: String = slot.rumor.subject_npc_id
			var is_believer: bool = slot.state in _BELIEVER_STATES

			# Track illness rejectors (used by Scenario 2 contradicted-fail evaluator).
			if slot.state == Rumor.RumorState.REJECT \
					and slot.rumor.claim_type == Rumor.ClaimType.ILLNESS:
				var observer_id: String = npc.npc_data.get("id", "")
				if not observer_id.is_empty():
					if not _illness_rejecter_ids.has(subject):
						_illness_rejecter_ids[subject] = {}
					_illness_rejecter_ids[subject][observer_id] = true

			# Track individual illness believers (used by Scenario 2 HUD).
			if is_believer and slot.rumor.claim_type == Rumor.ClaimType.ILLNESS:
				var believer_id: String = npc.npc_data.get("id", "")
				if not believer_id.is_empty():
					if not _illness_believer_ids.has(subject):
						_illness_believer_ids[subject] = {}
					_illness_believer_ids[subject][believer_id] = true

			# First-encounter slot stores rumor properties for delta computation.
			if not rumor_first_slot.has(rid):
				rumor_first_slot[rid] = slot

			# Track all unique rumor ids that target each NPC.
			if not rids_by_subject.has(subject):
				rids_by_subject[subject] = {}
			rids_by_subject[subject][rid] = true

			if is_believer:
				believer_counts[rid] = believer_counts.get(rid, 0) + 1
				var believer_nid: String = npc.npc_data.get("id", "")
				if not believer_nid.is_empty():
					global_believer_ids[believer_nid] = true

				# SOCIALLY_DEAD accumulation (Death rumors only).
				if slot.rumor.claim_type == Rumor.ClaimType.DEATH:
					if not death_info.has(subject):
						death_info[subject] = {"count": 0, "max_bel": 0.0}
					death_info[subject]["count"] += 1
					death_info[subject]["max_bel"] = max(
						death_info[subject]["max_bel"],
						slot.rumor.current_believability
					)

				# Faction believer accumulation (for faction_sentiment).
				if not faction_bel_info.has(subject):
					faction_bel_info[subject] = {}
				var fbis: Dictionary = faction_bel_info[subject]
				if not fbis.has(npc_faction):
					fbis[npc_faction] = {"count": 0, "ct_counts": {}}
				fbis[npc_faction]["count"] += 1
				var ct: int = slot.rumor.claim_type
				fbis[npc_faction]["ct_counts"][ct] = \
					fbis[npc_faction]["ct_counts"].get(ct, 0) + 1

	# ── Build illness-believer lookup (Scenario 2) ────────────────────────────
	# Use _illness_believer_ids (unique NPC set per subject) to avoid
	# double-counting NPCs who believe both original and mutated rumor IDs.
	_illness_believer_counts.clear()
	for npc_id in _illness_believer_ids:
		var count: int = _illness_believer_ids[npc_id].size()
		if count > 0:
			_illness_believer_counts[npc_id] = count

	_global_believer_count = global_believer_ids.size()

	# ── Compute each NPC's snapshot using pre-built tables (O(unique_rids)) ─
	_cache.clear()
	for npc in all_npcs:
		var nid: String = npc.npc_data.get("id", "")
		if nid.is_empty():
			continue
		_cache[nid] = _compute_snapshot(
			nid, current_tick,
			npc_id_to_faction, faction_sizes,
			believer_counts, rumor_first_slot, rids_by_subject,
			death_info, faction_bel_info
		)


## Return the cached snapshot for a given NPC id.  Returns null if not found.
func get_snapshot(npc_id: String) -> ReputationSnapshot:
	return _cache.get(npc_id, null)


## Return a shallow copy of the full cache (for HUD / debug iteration).
func get_all_snapshots() -> Dictionary:
	return _cache.duplicate()


## Returns the number of NPCs currently in BELIEVE/SPREAD/ACT state for
## illness-type rumors about the given NPC.  Used by the Scenario 2 evaluator.
func get_illness_believer_count(npc_id: String) -> int:
	return _illness_believer_counts.get(npc_id, 0)


## Returns true if observer_npc_id is in REJECT state for any illness-type
## rumor about subject_npc_id.  Used by the Scenario 2 contradicted-fail check.
func has_illness_rejecter(subject_npc_id: String, observer_npc_id: String) -> bool:
	if not _illness_rejecter_ids.has(subject_npc_id):
		return false
	return _illness_rejecter_ids[subject_npc_id].has(observer_npc_id)


## Returns an array of NPC ids currently believing illness rumors about the
## given subject.  Used by the Scenario 2 HUD to list individual believers.
func get_illness_believer_ids(subject_npc_id: String) -> Array:
	if not _illness_believer_ids.has(subject_npc_id):
		return []
	return _illness_believer_ids[subject_npc_id].keys()


## Returns an array of NPC ids currently rejecting illness rumors about the
## given subject.  Used by the Scenario 2 HUD.
func get_illness_rejecter_ids(subject_npc_id: String) -> Array:
	if not _illness_rejecter_ids.has(subject_npc_id):
		return []
	return _illness_rejecter_ids[subject_npc_id].keys()


## Returns the count of unique NPCs currently in BELIEVE/SPREAD/ACT state
## for any rumor.  Used by the Objective HUD believers metric.
func get_global_believer_count() -> int:
	return _global_believer_count


# ---------------------------------------------------------------------------
# Internal computation — uses pre-built tables from recalculate_all.
# ---------------------------------------------------------------------------

func _compute_snapshot(
		npc_id:           String,
		current_tick:     int,
		npc_id_to_faction: Dictionary,
		faction_sizes:    Dictionary,
		believer_counts:  Dictionary,
		rumor_first_slot: Dictionary,
		rids_by_subject:  Dictionary,
		death_info:       Dictionary,
		faction_bel_info: Dictionary
) -> ReputationSnapshot:
	var snap := ReputationSnapshot.new()
	snap.npc_id             = npc_id
	snap.base_score         = _base_overrides.get(npc_id, 50)
	snap.last_calculated_tick = current_tick
	snap.is_socially_dead   = false

	# ── SOCIALLY_DEAD check — O(1) lookup ─────────────────────────────────
	if death_info.has(npc_id):
		var di: Dictionary = death_info[npc_id]
		if di["count"] >= SOCIALLY_DEAD_MIN_BELIEVERS \
				and di["max_bel"] > SOCIALLY_DEAD_BELIEVABILITY:
			snap.is_socially_dead = true

	# ── Faction sentiment — O(unique_claim_types) lookup ──────────────────
	var subject_faction: String = npc_id_to_faction.get(npc_id, "")
	var faction_size:    int    = faction_sizes.get(subject_faction, 0)

	var faction_believers := 0
	var claim_type_counts: Dictionary = {}

	if faction_bel_info.has(npc_id) and faction_bel_info[npc_id].has(subject_faction):
		var fbi: Dictionary = faction_bel_info[npc_id][subject_faction]
		faction_believers  = fbi["count"]
		claim_type_counts  = fbi["ct_counts"]

	var dominant_ct    := -1
	var dominant_count := -1
	for ct in claim_type_counts:
		if claim_type_counts[ct] > dominant_count:
			dominant_count = claim_type_counts[ct]
			dominant_ct    = ct

	var faction_direction := -1
	if dominant_ct == Rumor.ClaimType.PRAISE or dominant_ct == Rumor.ClaimType.PROPHECY:
		faction_direction = 1

	var faction_sentiment := 0.0
	if faction_size > 0:
		faction_sentiment = (float(faction_believers) / float(faction_size)) * faction_direction * 20.0
	snap.faction_sentiment = clamp(faction_sentiment, -20.0, 20.0)

	# ── Rumor delta — O(unique_rids_about_this_npc) with O(1) lookups ─────
	var total_delta := 0.0
	var subject_rids: Dictionary = rids_by_subject.get(npc_id, {})

	for rid in subject_rids:
		var slot: Rumor.NpcRumorSlot = rumor_first_slot.get(rid, null)
		if slot == null:
			continue
		var believer_count: int    = believer_counts.get(rid, 0)
		var believer_weight: float = 0.0
		if believer_count > 0:
			believer_weight = min(max(float(believer_count) / 10.0, 0.5), 3.0)
		var direction: int         = CLAIM_DIRECTION.get(slot.rumor.claim_type, -1)
		var delta_r: float         = direction * slot.rumor.intensity \
			* slot.rumor.current_believability * believer_weight
		total_delta += delta_r

	snap.rumor_delta = clamp(total_delta, -40.0, 30.0)

	# ── Final score ───────────────────────────────────────────────────────
	var event_bonus: float = _faction_sentiment_bonuses.get(npc_id, 0.0)
	var raw := snap.base_score + snap.faction_sentiment + snap.rumor_delta + event_bonus
	snap.score = int(clamp(raw, 0.0, 100.0))

	return snap


# ---------------------------------------------------------------------------
# Static UI helpers
# ---------------------------------------------------------------------------

## Color for a given score value (0-100).
static func score_color(score: int) -> Color:
	if score <= 30:
		return Color(0.85, 0.15, 0.15)  # Red — Disgraced
	elif score <= 50:
		return Color(0.85, 0.55, 0.10)  # Amber — Suspect
	elif score <= 70:
		return Color(0.92, 0.90, 0.85)  # Warm white — Respected
	else:
		return Color(1.00, 0.80, 0.10)  # Gold — Distinguished


## Band label for a given score value.
static func score_label(score: int) -> String:
	if score <= 30:   return "Disgraced"
	elif score <= 50: return "Suspect"
	elif score <= 70: return "Respected"
	else:             return "Distinguished"
