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
# Cache: npc_id → ReputationSnapshot (refreshed once per tick).
# ---------------------------------------------------------------------------
var _cache: Dictionary = {}


## Recalculate snapshots for every NPC in all_npcs.
## Call at the START of each tick, before state transitions fire.
func recalculate_all(all_npcs: Array, current_tick: int) -> void:
	_cache.clear()
	for npc in all_npcs:
		var npc_id: String = npc.npc_data.get("id", "")
		if npc_id.is_empty():
			continue
		_cache[npc_id] = _compute_snapshot(npc_id, all_npcs, current_tick)


## Return the cached snapshot for a given NPC id.  Returns null if not found.
func get_snapshot(npc_id: String) -> ReputationSnapshot:
	return _cache.get(npc_id, null)


## Return a shallow copy of the full cache (for HUD / debug iteration).
func get_all_snapshots() -> Dictionary:
	return _cache.duplicate()


# ---------------------------------------------------------------------------
# Internal computation
# ---------------------------------------------------------------------------

func _compute_snapshot(npc_id: String, all_npcs: Array, current_tick: int) -> ReputationSnapshot:
	var snap := ReputationSnapshot.new()
	snap.npc_id             = npc_id
	snap.base_score         = 50
	snap.last_calculated_tick = current_tick
	snap.is_socially_dead   = false

	# ── SOCIALLY_DEAD check ────────────────────────────────────────────────
	# If a Death claim about this NPC has believability > 0.6 and 5+ believers,
	# the NPC is considered socially dead — reputation is computed but locked in UI.
	var death_believers := 0
	var death_max_believability := 0.0
	for npc in all_npcs:
		for rid in npc.rumor_slots:
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			if slot.rumor.subject_npc_id != npc_id:
				continue
			if slot.rumor.claim_type != Rumor.ClaimType.DEATH:
				continue
			if slot.state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD, Rumor.RumorState.ACT]:
				death_believers += 1
				death_max_believability = max(death_max_believability, slot.rumor.current_believability)

	if death_believers >= SOCIALLY_DEAD_MIN_BELIEVERS and death_max_believability > SOCIALLY_DEAD_BELIEVABILITY:
		snap.is_socially_dead = true

	# ── Faction sentiment ──────────────────────────────────────────────────
	# Identify the subject's faction and count faction members.
	var subject_faction := ""
	for npc in all_npcs:
		if npc.npc_data.get("id", "") == npc_id:
			subject_faction = npc.npc_data.get("faction", "")
			break

	var faction_size := 0
	for npc in all_npcs:
		if npc.npc_data.get("faction", "") == subject_faction:
			faction_size += 1

	# Count faction believers for any rumor targeting this NPC.
	# Also track the dominant active claim type to determine faction direction.
	var faction_believers := 0
	var claim_type_counts: Dictionary = {}

	for npc in all_npcs:
		if npc.npc_data.get("faction", "") != subject_faction:
			continue
		for rid in npc.rumor_slots:
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			if slot.rumor.subject_npc_id != npc_id:
				continue
			if slot.state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD, Rumor.RumorState.ACT]:
				faction_believers += 1
				var ct: int = slot.rumor.claim_type
				claim_type_counts[ct] = claim_type_counts.get(ct, 0) + 1

	# Dominant claim type determines faction direction.
	var dominant_ct := -1
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

	# ── Rumor delta ────────────────────────────────────────────────────────
	# Aggregate delta across all unique rumors where this NPC is the subject.
	# Each rumor is counted once (deduplicated by rumor_id).
	var seen_rumor_ids: Dictionary = {}
	var total_delta := 0.0

	for npc in all_npcs:
		for rid in npc.rumor_slots:
			if seen_rumor_ids.has(rid):
				continue
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			if slot.rumor.subject_npc_id != npc_id:
				continue
			seen_rumor_ids[rid] = true

			# Count total believers for this rumor across all NPCs.
			var believer_count := 0
			for npc2 in all_npcs:
				if npc2.rumor_slots.has(rid):
					var s2: Rumor.NpcRumorSlot = npc2.rumor_slots[rid]
					if s2.state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD, Rumor.RumorState.ACT]:
						believer_count += 1

			var believer_weight: float = min(float(believer_count) / 10.0, 3.0)
			var direction: int         = CLAIM_DIRECTION.get(slot.rumor.claim_type, -1)
			var delta_r: float         = direction * slot.rumor.intensity * slot.rumor.current_believability * believer_weight
			total_delta += delta_r

	snap.rumor_delta = clamp(total_delta, -40.0, 30.0)

	# ── Final score ────────────────────────────────────────────────────────
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
