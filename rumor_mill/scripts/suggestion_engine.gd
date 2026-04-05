## suggestion_engine.gd — Context-aware next-action suggestion for Tier 3 HUD.
##
## Priority-ordered suggestion logic that replaces the fixed nudge system
## after S1 tutorial completes (nudge_phase >= 4).
##
## Priority order:
##   1. Unspent daily actions
##   2. High-value target available (high sociability at reachable location)
##   3. Rumor momentum (spreading, check Journal)
##   4. Stalled progress (progress hasn't moved)
##   5. Heat warning (suspicion rising)
##   6. Mid-game event pending

class_name SuggestionEngine


var _world_ref: Node2D = null
var _intel_store: PlayerIntelStore = null
var _reputation_system: ReputationSystem = null
var _scenario_manager: ScenarioManager = null
var _day_night: Node = null

## Last progress value seen — used to detect stalling.
var _last_progress: float = -1.0
## How many refreshes progress has been unchanged.
var _stall_count: int = 0
const STALL_THRESHOLD: int = 6  # ~6 ticks of no progress before suggesting change


func setup(world: Node2D, intel_store: PlayerIntelStore, rep_system: ReputationSystem,
		scenario_manager: ScenarioManager, day_night: Node) -> void:
	_world_ref = world
	_intel_store = intel_store
	_reputation_system = rep_system
	_scenario_manager = scenario_manager
	_day_night = day_night


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

	# 6. Mid-game event hint.
	suggestion = _check_event_pending()
	if not suggestion.is_empty():
		return suggestion

	return ""


## Call each tick to update stall tracking.
func refresh() -> void:
	if _scenario_manager == null or _reputation_system == null or _day_night == null:
		return
	var prog: float = _scenario_manager.get_win_progress(
		_reputation_system, _day_night.current_tick if "current_tick" in _day_night else 0)
	if _last_progress < 0.0:
		_last_progress = prog
		_stall_count = 0
		return
	if absf(prog - _last_progress) < 0.005:
		_stall_count += 1
	else:
		_stall_count = 0
		_last_progress = prog


# ── Priority 1: Unspent actions ─────────────────────────────────────────────

func _check_unspent_actions() -> String:
	var obs: int = _intel_store.recon_actions_remaining
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
	var best_npc: Node = null
	var best_score: float = 0.0
	for npc in _world_ref.npcs:
		if not npc.visible:
			continue
		var sociability: float = npc.npc_data.get("sociability", 0.5)
		var has_rumor: bool = not npc.rumor_slots.is_empty()
		# Prefer NPCs without rumors and high sociability.
		var score: float = sociability * (1.5 if not has_rumor else 0.8)
		if score > best_score:
			best_score = score
			best_npc = npc
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
	# Intentionally sparse — this is a placeholder for future event integration.
	# The mid-game event system fires its own overlays; we just hint proximity.
	return ""
