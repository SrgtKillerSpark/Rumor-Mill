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
	Rumor.ClaimType.PRAISE:      1,
	Rumor.ClaimType.PROPHECY:    1,
	Rumor.ClaimType.ACCUSATION: -1,
	Rumor.ClaimType.SCANDAL:    -1,
	Rumor.ClaimType.ILLNESS:    -1,
	Rumor.ClaimType.DEATH:      -1,
	Rumor.ClaimType.HERESY:     -1,
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


## Remove all base score overrides (e.g. when loading a new scenario).
func clear_base_overrides() -> void:
	_base_overrides.clear()


# ---------------------------------------------------------------------------
# Cache: npc_id → ReputationSnapshot (refreshed once per tick).
# ---------------------------------------------------------------------------
var _cache: Dictionary = {}


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

	for npc in all_npcs:
		var npc_faction: String = npc.npc_data.get("faction", "")
		for rid in npc.rumor_slots:
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			var subject: String = slot.rumor.subject_npc_id
			var is_believer: bool = slot.state in _BELIEVER_STATES

			# First-encounter slot stores rumor properties for delta computation.
			if not rumor_first_slot.has(rid):
				rumor_first_slot[rid] = slot

			# Track all unique rumor ids that target each NPC.
			if not rids_by_subject.has(subject):
				rids_by_subject[subject] = {}
			rids_by_subject[subject][rid] = true

			if is_believer:
				believer_counts[rid] = believer_counts.get(rid, 0) + 1

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
	if dominant_ct == Rumor.ClaimType.PRAISE:
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
		var believer_weight: float = min(float(believer_count) / 10.0, 3.0)
		var direction: int         = CLAIM_DIRECTION.get(slot.rumor.claim_type, -1)
		var delta_r: float         = direction * slot.rumor.intensity \
			* slot.rumor.current_believability * believer_weight
		total_delta += delta_r

	snap.rumor_delta = clamp(total_delta, -40.0, 30.0)

	# ── Final score ───────────────────────────────────────────────────────
	var raw := snap.base_score + snap.faction_sentiment + snap.rumor_delta
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
