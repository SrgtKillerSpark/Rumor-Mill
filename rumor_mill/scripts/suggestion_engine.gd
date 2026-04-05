## suggestion_engine.gd — Context-aware hint engine for the Tier 3 HUD slot.
##
## Two-layer design:
##   • Content layer  — the original 6-priority get_suggestion() logic.  Used
##     as the text source for the inactivity and dawn triggers.
##   • Trigger layer  — 5 trigger conditions evaluate every game tick via
##     refresh().  When a trigger fires and the daily budget permits, the engine
##     emits hint_ready(text) so the HUD can show the toast widget.
##
## Trigger priority (highest → lowest):
##   1. Heat spike       — any NPC heat crosses the heat_spike_threshold
##   2. Pace deficit     — win_progress / time_fraction < 0.6 after day 3
##   3. Faction momentum — a faction's rep delta exceeds ±15 in one day
##   4. Dawn transition  — new day starts with unspent daily actions
##   5. Inactivity       — no player action for >= INACTIVITY_TICKS ticks
##
## Balance rules (never relax these):
##   • Max 2 hints per in-game day.
##   • Minimum 36-tick cooldown between hints (doubles on fast-dismiss).
##   • Never reveal exact scores, hidden NPC positions, or graph internals.

class_name SuggestionEngine

## Emitted when a triggered hint is ready to display.
signal hint_ready(text: String)

# ── Constants ──────────────────────────────────────────────────────────────
const MAX_HINTS_PER_DAY  := 2
const DEFAULT_COOLDOWN   := 36    # ticks (~1.5 in-game hours)
const INACTIVITY_TICKS   := 90    # ~90 real seconds at 1 tick/s
const STALL_THRESHOLD    := 6     # unchanged progress refreshes before suggesting change
const DEFAULT_HEAT_SPIKE_THRESHOLD := 60.0

# ── System references ─────────────────────────────────────────────────────
var _world_ref:        Node2D             = null
var _intel_store:      PlayerIntelStore   = null
var _reputation_system: ReputationSystem  = null
var _scenario_manager: ScenarioManager   = null
var _day_night:        Node               = null

# ── Content-layer state (original stall tracking) ────────────────────────
var _last_progress: float = -1.0
var _stall_count:   int   = 0

# ── Trigger-layer state ───────────────────────────────────────────────────
## Hints fired so far today (resets on day_changed).
var _hints_today:    int = 0
## Tick when the last hint fired (for cooldown enforcement).
var _last_hint_tick: int = -999
## Current cooldown length in ticks; doubles on consecutive fast dismissals.
var _cooldown_ticks: int = DEFAULT_COOLDOWN
## Tick of the most recent detected player action (action spend or movement).
var _last_action_tick: int = 0
## Reputation scores snapshotted at each dawn for momentum diff.
var _dawn_snapshots: Dictionary = {}  # npc_id (String) → score (int)
## NPC IDs already heat-warned today (prevents repeat alerts for same NPC).
var _heat_alerts_today: Array = []  # Array[String]
## Consecutive fast-dismiss count (drives cooldown doubling).
var _fast_dismiss_count: int = 0
## Guards: each boolean trigger fires at most once per day.
var _inactivity_fired:          bool = false
var _pace_deficit_fired_today:  bool = false
var _faction_momentum_fired_today: bool = false
var _dawn_hint_fired:           bool = false

# ── Scenario overrides ─────────────────────────────────────────────────────
## Heat value at which the spike trigger activates (default 60; S4 uses 50).
var _heat_spike_threshold: float = DEFAULT_HEAT_SPIKE_THRESHOLD
## Ordered list of hint category keys preferred for this scenario (empty = default).
## E.g. ["illness", "claim_type"] for S2 to prioritise illness claim suggestions.
var _priority_categories: Array = []


# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

func setup(world: Node2D, intel_store: PlayerIntelStore, rep_system: ReputationSystem,
		scenario_manager: ScenarioManager, day_night: Node) -> void:
	_world_ref         = world
	_intel_store       = intel_store
	_reputation_system = rep_system
	_scenario_manager  = scenario_manager
	_day_night         = day_night
	_apply_scenario_overrides()


func _apply_scenario_overrides() -> void:
	if _scenario_manager == null:
		return
	var overrides: Dictionary = _scenario_manager.get_suggestion_overrides()
	if overrides.is_empty():
		return
	_heat_spike_threshold = overrides.get("heat_spike_threshold", DEFAULT_HEAT_SPIKE_THRESHOLD)
	_priority_categories  = overrides.get("category_priorities", [])


# ---------------------------------------------------------------------------
# Called by ObjectiveHUD._on_day_changed — resets daily counters.
# ---------------------------------------------------------------------------

func _on_day_changed(_day: int) -> void:
	_hints_today                  = 0
	_heat_alerts_today.clear()
	_fast_dismiss_count           = 0
	_cooldown_ticks               = DEFAULT_COOLDOWN
	_pace_deficit_fired_today     = false
	_faction_momentum_fired_today = false
	_dawn_hint_fired              = false
	_inactivity_fired             = false
	_snapshot_dawn_reputations()


# ---------------------------------------------------------------------------
# Called by ObjectiveHUD._on_day_transition_started — dawn trigger.
# ---------------------------------------------------------------------------

func _on_dawn(_day: int) -> void:
	if _dawn_hint_fired:
		return
	if not _can_fire_hint():
		return
	# Fire dawn hint only if the player has unspent actions (natural pause point).
	if _intel_store == null:
		return
	if _intel_store.recon_actions_remaining < _intel_store.max_daily_actions:
		return  # Player already spent some actions; skip orientation hint.
	var text: String = get_suggestion()
	if text.is_empty():
		return
	_dawn_hint_fired = true
	_fire_hint(text)


# ---------------------------------------------------------------------------
# Called by ObjectiveHUD every tick — evaluates triggers.
# ---------------------------------------------------------------------------

## Also call notify_player_action() when a player action is detected so the
## inactivity timer resets correctly.
func refresh() -> void:
	if _scenario_manager == null or _reputation_system == null or _day_night == null:
		return
	var tick: int = _day_night.current_tick if "current_tick" in _day_night else 0

	# Content-layer stall tracking (unchanged from original).
	var prog: float = _scenario_manager.get_win_progress(
		_reputation_system, tick)
	if _last_progress < 0.0:
		_last_progress = prog
		_stall_count   = 0
	elif absf(prog - _last_progress) < 0.005:
		_stall_count += 1
	else:
		_stall_count   = 0
		_last_progress = prog

	# Trigger-layer evaluation.
	_evaluate_triggers(tick)


# ---------------------------------------------------------------------------
# Player-action and dismiss notifications
# ---------------------------------------------------------------------------

## Call this whenever a player performs an action (observe, whisper, etc.)
## so the inactivity timer resets.
func notify_player_action(tick: int) -> void:
	_last_action_tick = tick
	_inactivity_fired = false


## Call this when the toast is dismissed so cooldown can be adjusted.
func notify_hint_dismissed(was_fast: bool) -> void:
	if was_fast:
		_fast_dismiss_count += 1
		# Double the cooldown for each consecutive fast dismissal (capped at ×8).
		_cooldown_ticks = DEFAULT_COOLDOWN * (1 << mini(_fast_dismiss_count, 3))
	else:
		_fast_dismiss_count = 0
		_cooldown_ticks     = DEFAULT_COOLDOWN


# ---------------------------------------------------------------------------
# Trigger evaluation
# ---------------------------------------------------------------------------

func _evaluate_triggers(tick: int) -> void:
	if not _can_fire_hint():
		return

	# Priority 1: Heat spike.
	var hint: String = _trigger_heat_spike()
	if not hint.is_empty():
		_fire_hint(hint)
		return

	# Priority 2: Pace deficit (only after day 3, fires once per day).
	if not _pace_deficit_fired_today:
		hint = _trigger_pace_deficit(tick)
		if not hint.is_empty():
			_pace_deficit_fired_today = true
			_fire_hint(hint)
			return

	# Priority 3: Faction momentum (fires once per day).
	if not _faction_momentum_fired_today:
		hint = _trigger_faction_momentum()
		if not hint.is_empty():
			_faction_momentum_fired_today = true
			_fire_hint(hint)
			return

	# Priority 4: Inactivity (fires once per idle streak, resets on action).
	if not _inactivity_fired:
		hint = _trigger_inactivity(tick)
		if not hint.is_empty():
			_inactivity_fired = true
			_fire_hint(hint)
			return


func _can_fire_hint() -> bool:
	if _hints_today >= MAX_HINTS_PER_DAY:
		return false
	var tick: int = _day_night.current_tick if _day_night != null and "current_tick" in _day_night else 0
	if tick - _last_hint_tick < _cooldown_ticks:
		return false
	return true


func _fire_hint(text: String) -> void:
	_hints_today += 1
	_last_hint_tick = _day_night.current_tick if _day_night != null and "current_tick" in _day_night else 0
	hint_ready.emit(text)


# ---------------------------------------------------------------------------
# Individual trigger conditions
# ---------------------------------------------------------------------------

func _trigger_heat_spike() -> String:
	if _intel_store == null or not _intel_store.heat_enabled:
		return ""
	var best_npc_id: String = ""
	var best_heat:   float  = 0.0
	for npc_id in _intel_store.heat:
		var h: float = _intel_store.heat[npc_id]
		if h >= _heat_spike_threshold and npc_id not in _heat_alerts_today:
			if h > best_heat:
				best_heat   = h
				best_npc_id = npc_id
	if best_npc_id.is_empty():
		return ""
	_heat_alerts_today.append(best_npc_id)
	var name: String = _get_npc_display_name(best_npc_id)
	if best_heat >= 80.0:
		return "%s is dangerously close to catching you. Consider bribing or laying low." % name
	elif best_heat >= 70.0:
		return "%s is very wary. Divert attention or lie low for a day." % name
	else:
		return "%s has grown suspicious. A bribe might help." % name


func _trigger_pace_deficit(tick: int) -> String:
	if _scenario_manager == null or _reputation_system == null or _day_night == null:
		return ""
	var current_day: int = _day_night.current_day if "current_day" in _day_night else 1
	if current_day <= 3:
		return ""
	var progress:   float = _scenario_manager.get_win_progress(_reputation_system, tick)
	var time_frac:  float = _scenario_manager.get_time_fraction(tick)
	if time_frac <= 0.0:
		return ""
	if progress / time_frac < 0.6:
		return "Progress is falling behind. Try a different claim type or target a new faction."
	return ""


func _trigger_faction_momentum() -> String:
	if _reputation_system == null or _dawn_snapshots.is_empty():
		return ""
	if _world_ref == null or not "npcs" in _world_ref:
		return ""
	# Build faction → current avg score and dawn avg score.
	var faction_dawn:    Dictionary = {}  # faction → sum at dawn
	var faction_current: Dictionary = {}  # faction → sum now
	var faction_counts:  Dictionary = {}  # faction → npc count
	var current_snaps: Dictionary = _reputation_system.get_all_snapshots()
	for npc in _world_ref.npcs:
		var nid: String     = npc.npc_data.get("id", "")
		var fac: String     = npc.npc_data.get("faction", "")
		if nid.is_empty() or fac.is_empty():
			continue
		var cur_score: int = current_snaps[nid].score if current_snaps.has(nid) else 50
		var dwn_score: int = _dawn_snapshots.get(nid, 50)
		faction_current[fac] = faction_current.get(fac, 0) + cur_score
		faction_dawn[fac]    = faction_dawn.get(fac, 0)    + dwn_score
		faction_counts[fac]  = faction_counts.get(fac, 0)  + 1
	# Find the faction with the largest daily delta.
	var biggest_fac:   String = ""
	var biggest_delta: float  = 0.0
	for fac in faction_current:
		var cnt: int = faction_counts.get(fac, 1)
		var avg_cur: float = float(faction_current[fac]) / cnt
		var avg_dwn: float = float(faction_dawn[fac])    / cnt
		var delta: float   = avg_cur - avg_dwn
		if absf(delta) > absf(biggest_delta):
			biggest_delta = delta
			biggest_fac   = fac
	if absf(biggest_delta) < 15.0 or biggest_fac.is_empty():
		return ""
	var dir: String = "rising" if biggest_delta > 0 else "dropping"
	var display_fac: String = biggest_fac.capitalize()
	if biggest_delta < 0:
		return "The %s faction's mood is dropping quickly — your rumors may be taking hold." % display_fac
	else:
		return "The %s faction seems to be rallying — sentiment is %s. Check your approach." % [display_fac, dir]


func _trigger_inactivity(tick: int) -> String:
	if tick - _last_action_tick < INACTIVITY_TICKS:
		return ""
	# Use existing content-layer suggestions for idle players.
	return get_suggestion()


# ---------------------------------------------------------------------------
# Dawn reputation snapshot
# ---------------------------------------------------------------------------

func _snapshot_dawn_reputations() -> void:
	if _reputation_system == null:
		return
	var snaps: Dictionary = _reputation_system.get_all_snapshots()
	_dawn_snapshots.clear()
	for npc_id in snaps:
		_dawn_snapshots[npc_id] = snaps[npc_id].score


# ---------------------------------------------------------------------------
# Helper: get display name for an NPC id
# ---------------------------------------------------------------------------

func _get_npc_display_name(npc_id: String) -> String:
	if _world_ref != null and "npcs" in _world_ref:
		for npc in _world_ref.npcs:
			if npc.npc_data.get("id", "") == npc_id:
				return npc.npc_data.get("displayName",
					npc_id.replace("_", " ").capitalize())
	return npc_id.replace("_", " ").capitalize()


# ---------------------------------------------------------------------------
# Helper: derive observed NPC ids from location intel
# ---------------------------------------------------------------------------

func _get_observed_npc_ids() -> Dictionary:
	var result: Dictionary = {}  # npc_id → true
	if _intel_store == null:
		return result
	for loc_id in _intel_store.location_intel:
		for intel in _intel_store.location_intel[loc_id]:
			for entry in intel.npcs_seen:
				var nid: String = entry.get("npc_id", "")
				if not nid.is_empty():
					result[nid] = true
	return result


# ---------------------------------------------------------------------------
# Content layer — original 6-priority text generator (unchanged logic).
# Used by inactivity and dawn triggers, and as the "? What next" fallback.
# ---------------------------------------------------------------------------

## Returns the highest-priority suggestion text, or "" if none applies.
func get_suggestion() -> String:
	if _world_ref == null or _intel_store == null:
		return ""

	# 1. Unspent daily actions.
	var suggestion: String = _check_unspent_actions()
	if not suggestion.is_empty():
		return suggestion

	# 2. High-value target available.
	suggestion = _check_high_value_target()
	if not suggestion.is_empty():
		return suggestion

	# 3. Rumor momentum — spreading, prompt journal check.
	suggestion = _check_rumor_momentum()
	if not suggestion.is_empty():
		return suggestion

	# 4. Stalled progress.
	suggestion = _check_stalled_progress()
	if not suggestion.is_empty():
		return suggestion

	# 5. Heat warning.
	suggestion = _check_heat_warning()
	if not suggestion.is_empty():
		return suggestion

	# 6. Mid-game event hint (placeholder).
	suggestion = _check_event_pending()
	if not suggestion.is_empty():
		return suggestion

	return ""


# ── Priority 1: Unspent actions ─────────────────────────────────────────────

func _check_unspent_actions() -> String:
	var obs:     int = _intel_store.recon_actions_remaining
	var whispers: int = _intel_store.whisper_tokens_remaining
	if obs > 0 and whispers > 0:
		return "You have %d observation%s and %d whisper%s left today" % [
			obs, "" if obs == 1 else "s",
			whispers, "" if whispers == 1 else "s"]
	elif obs > 0:
		return "You have %d observation%s remaining — gather intel" % [
			obs, "" if obs == 1 else "s"]
	elif whispers > 0:
		return "You have %d whisper%s left — seed a rumor" % [
			whispers, "" if whispers == 1 else "s"]
	return ""


# ── Priority 2: High-value target available ──────────────────────────────────

func _check_high_value_target() -> String:
	if not "npcs" in _world_ref:
		return ""
	var observed: Dictionary = _get_observed_npc_ids()
	var best_npc:   Node  = null
	var best_score: float = 0.0
	for npc in _world_ref.npcs:
		if not npc.visible:
			continue
		# Only suggest NPCs the player has already observed.
		if not observed.is_empty() and not observed.has(npc.npc_data.get("id", "")):
			continue
		var sociability: float = npc.npc_data.get("sociability", 0.5)
		var has_rumor:   bool  = not npc.rumor_slots.is_empty()
		var score: float = sociability * (1.5 if not has_rumor else 0.8)
		if score > best_score:
			best_score = score
			best_npc   = npc
	if best_npc != null and best_score >= 0.7:
		var npc_name: String = best_npc.npc_data.get("displayName",
			best_npc.npc_data.get("id", "").replace("_", " ").capitalize())
		return "%s is nearby and well-connected. Seed a rumor?" % npc_name
	return ""


# ── Priority 3: Rumor momentum ──────────────────────────────────────────────

func _check_rumor_momentum() -> String:
	if not "npcs" in _world_ref:
		return ""
	var spreading_count: int = 0
	for npc in _world_ref.npcs:
		for rid in npc.rumor_slots:
			if npc.rumor_slots[rid].state == Rumor.RumorState.SPREAD:
				spreading_count += 1
	if spreading_count > 0:
		return "Your rumor is spreading — check the Journal (J) for details"
	return ""


# ── Priority 4: Stalled progress ────────────────────────────────────────────

func _check_stalled_progress() -> String:
	if _stall_count >= STALL_THRESHOLD:
		return "Progress has stalled. Try a different claim type or target a new faction"
	return ""


# ── Priority 5: Heat warning ────────────────────────────────────────────────

func _check_heat_warning() -> String:
	if _intel_store == null:
		return ""
	var max_heat: float = 0.0
	for npc_id in _intel_store.heat:
		if _intel_store.heat[npc_id] > max_heat:
			max_heat = _intel_store.heat[npc_id]
	if max_heat >= 50.0:
		return "Suspicion is rising. Lay low or use a bribe."
	return ""


# ── Priority 6: Mid-game event hint ─────────────────────────────────────────

func _check_event_pending() -> String:
	# Placeholder — mid-game event system fires its own overlays.
	return ""
