class_name EndScreenScoring
extends RefCounted

## end_screen_scoring.gd — Stat display, NPC outcomes, and player-stat recording
## for EndScreen.
##
## Extracted from end_screen.gd (SPA-1010). Further trimmed in SPA-1016:
## fail-reason inference and summary-text logic moved to EndScreenSummary.
## Owns all result-data UI logic: builds the STATS and KEY OUTCOMES card content.
##
## Call setup() once node refs are known. Then:
##   populate_stats(scenario_id, won)
##   populate_npc_outcomes(current_scenario_id, last_outcome_won)
##   record_player_stats(scenario_id, won, current_scenario_id)
## Use the get_* accessors to feed EndScreenAnimations after populate_stats.

# ── Palette (subset used by this module) ──────────────────────────────────────
const C_WIN          := Color(0.92, 0.78, 0.12, 1.0)
const C_FAIL         := Color(0.85, 0.18, 0.12, 1.0)
const C_HEADING      := Color(0.91, 0.85, 0.70, 1.0)
const C_SUBHEADING   := Color(0.75, 0.65, 0.50, 1.0)
const C_BODY         := Color(0.70, 0.65, 0.55, 1.0)
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_STAT_LABEL   := Color(0.75, 0.65, 0.50, 1.0)
const C_STAT_VALUE   := Color(0.91, 0.85, 0.70, 1.0)
const C_SCORE_WIN    := Color(0.92, 0.78, 0.12, 1.0)
const C_SCORE_NEU    := Color(0.85, 0.65, 0.15, 1.0)
const C_SCORE_FAIL   := Color(0.85, 0.18, 0.12, 1.0)

# ── Key NPC outcomes per scenario ─────────────────────────────────────────────
const PEAK_BELIEF_TARGET: Dictionary = {
	1: { "id": "edric_fenn",    "name": "Edric Fenn" },
	2: { "id": "alys_herbwife", "name": "Alys Herbwife" },
	3: { "id": "calder_fenn",   "name": "Calder Fenn" },
	4: { "id": "aldous_prior",  "name": "Aldous Prior" },
	5: { "id": "aldric_vane",   "name": "Aldric Vane" },
	6: { "id": "marta_coin",    "name": "Marta Coin" },
}

const NPC_OUTCOMES: Dictionary = {
	"scenario_1": [
		{ "id": "edric_fenn",   "name": "Edric Fenn" },
		{ "id": "bram_guard",   "name": "Bram (Guard)" },
		{ "id": "aldous_prior", "name": "Prior Aldous" },
	],
	"scenario_2": [
		{ "id": "alys_herbwife", "name": "Alys Herbwife" },
		{ "id": "maren_nun",     "name": "Sister Maren" },
		{ "id": "vera_midwife",  "name": "Vera Midwife" },
	],
	"scenario_3": [
		{ "id": "calder_fenn", "name": "Calder Fenn" },
		{ "id": "tomas_reeve", "name": "Tomas Reeve" },
		{ "id": "isolde_fenn", "name": "Lady Isolde" },
	],
	"scenario_4": [
		{ "id": "aldous_prior", "name": "Prior Aldous" },
		{ "id": "vera_midwife", "name": "Vera Midwife" },
		{ "id": "finn_monk",    "name": "Brother Finn" },
	],
	"scenario_5": [
		{ "id": "aldric_vane",  "name": "Aldric Vane" },
		{ "id": "edric_fenn",   "name": "Edric Fenn" },
		{ "id": "tomas_reeve",  "name": "Tomas Reeve" },
	],
	"scenario_6": [
		{ "id": "aldric_vane",  "name": "Guild Master Aldric" },
		{ "id": "marta_coin",   "name": "Marta Coin" },
		{ "id": "annit_scribe", "name": "Annit Scribe" },
	],
}

# ── Runtime refs ──────────────────────────────────────────────────────────────
var _world_ref:       Node2D       = null
var _day_night_ref:   Node         = null
var _stats_container: VBoxContainer = null
var _npc_container:   VBoxContainer = null

# ── Animation-readable state ──────────────────────────────────────────────────
var _tween_targets: Array         = []
var _bonus_lbl:     Control       = null
var _rating_row:    HBoxContainer = null
var _arrow_labels:  Array         = []


func setup(world: Node2D, day_night: Node,
		stats_container: VBoxContainer, npc_container: VBoxContainer) -> void:
	_world_ref       = world
	_day_night_ref   = day_night
	_stats_container = stats_container
	_npc_container   = npc_container


# ── Accessors for EndScreenAnimations ────────────────────────────────────────

func get_tween_targets() -> Array:
	return _tween_targets


func get_bonus_lbl() -> Control:
	return _bonus_lbl


func get_rating_row() -> HBoxContainer:
	return _rating_row


func get_arrow_labels() -> Array:
	return _arrow_labels


# ── Public methods ────────────────────────────────────────────────────────────

## Record end-of-game data into the PlayerStats autoload (SPA-273).
func record_player_stats(scenario_id: int, won: bool, current_scenario_id: String) -> void:
	if _world_ref == null:
		return
	var days_taken := 0
	if _day_night_ref != null and "current_day" in _day_night_ref:
		days_taken = _day_night_ref.current_day

	var rumors_spread := 0
	if _world_ref.propagation_engine != null:
		rumors_spread = _world_ref.propagation_engine.lineage.size()

	var npcs_reached := 0
	if not _world_ref.npcs.is_empty():
		for npc in _world_ref.npcs:
			if "rumor_slots" in npc and not npc.rumor_slots.is_empty():
				npcs_reached += 1

	var peak_belief := 0
	if _world_ref.reputation_system != null:
		var target: Dictionary = PEAK_BELIEF_TARGET.get(scenario_id, {})
		if not target.is_empty():
			var snap: Variant = _world_ref.reputation_system.get_snapshot(str(target["id"]))
			if snap != null:
				peak_belief = snap.score

	var bribes_paid := 0
	var bribery_allowed := scenario_id > 1 and current_scenario_id != "scenario_4"
	if bribery_allowed and _world_ref.intel_store != null:
		bribes_paid = max(0, 2 - _world_ref.intel_store.bribe_charges)

	PlayerStats.record_game(
		current_scenario_id,
		GameState.selected_difficulty,
		won,
		days_taken,
		rumors_spread,
		npcs_reached,
		peak_belief,
		bribes_paid,
	)


## Populate the stats grid (4 universal + 1 scenario bonus).
## Call get_tween_targets(), get_bonus_lbl(), get_rating_row() afterward.
func populate_stats(scenario_id: int, won: bool) -> void:
	for child in _stats_container.get_children():
		child.queue_free()
	_tween_targets.clear()
	if _bonus_lbl != null:
		_bonus_lbl.queue_free()
		_bonus_lbl = null
	_rating_row = null

	var sm: ScenarioManager = _world_ref.scenario_manager if _world_ref != null else null

	# ── Days Taken ────────────────────────────────────────────────────────────
	var days_taken   := 0
	var days_allowed := sm.get_days_allowed() if sm != null else 0
	if _day_night_ref != null and "current_day" in _day_night_ref:
		days_taken = _day_night_ref.current_day

	var days_val_lbl := _add_stat_row("Days Taken", "0 / %d days" % days_allowed)
	_tween_targets.append({
		"label":  days_val_lbl,
		"target": days_taken,
		"suffix": " / %d days" % days_allowed,
	})

	# ── Rumors Spread ─────────────────────────────────────────────────────────
	var rumors_spread := 0
	if _world_ref != null and _world_ref.propagation_engine != null:
		rumors_spread = _world_ref.propagation_engine.lineage.size()

	var rumors_val_lbl := _add_stat_row("Rumors Spread", "0 rumors")
	_tween_targets.append({
		"label":  rumors_val_lbl,
		"target": rumors_spread,
		"suffix": " rumors",
	})

	# ── NPCs Reached ──────────────────────────────────────────────────────────
	var npcs_reached := 0
	var npc_total    := 0
	if _world_ref != null and not _world_ref.npcs.is_empty():
		npc_total = _world_ref.npcs.size()
		for npc in _world_ref.npcs:
			if "rumor_slots" in npc and not npc.rumor_slots.is_empty():
				npcs_reached += 1

	var npcs_val_lbl := _add_stat_row("NPCs Reached", "0 / %d NPCs" % npc_total)
	_tween_targets.append({
		"label":  npcs_val_lbl,
		"target": npcs_reached,
		"suffix": " / %d NPCs" % npc_total,
	})

	# ── Peak Belief ───────────────────────────────────────────────────────────
	var peak_belief := 0
	if _world_ref != null and _world_ref.reputation_system != null:
		var target: Dictionary = PEAK_BELIEF_TARGET.get(scenario_id, {})
		if not target.is_empty():
			var snap: Variant = _world_ref.reputation_system.get_snapshot(str(target["id"]))
			if snap != null:
				peak_belief = snap.score
		else:
			var all_snaps: Dictionary = _world_ref.reputation_system.get_all_snapshots()
			for npc_id in all_snaps:
				var snap: ReputationSystem.ReputationSnapshot = all_snaps[npc_id]
				if snap.score > peak_belief:
					peak_belief = snap.score

	var peak_val_lbl := _add_stat_row("Peak Belief", "0% peak belief")
	_tween_targets.append({
		"label":  peak_val_lbl,
		"target": peak_belief,
		"suffix": "% peak belief",
	})

	# ── Scenario-specific bonus stat ──────────────────────────────────────────
	_build_bonus_stat(scenario_id)

	# ── SPA-907: Performance summary ──────────────────────────────────────────
	_build_performance_summary(won, days_taken, days_allowed, npcs_reached, npc_total, peak_belief)


## Populate the NPC outcomes right card.
## Call after populate_stats so _arrow_labels is refreshed.
func populate_npc_outcomes(current_scenario_id: String, last_outcome_won: bool) -> void:
	for child in _npc_container.get_children():
		child.queue_free()
	_arrow_labels.clear()

	if _world_ref == null or _world_ref.reputation_system == null:
		return

	var rep: ReputationSystem = _world_ref.reputation_system
	var npcs_to_show: Array = NPC_OUTCOMES.get(current_scenario_id, [])

	for entry in npcs_to_show:
		var npc_id: String   = str(entry["id"])
		var npc_name: String = str(entry["name"])
		var snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot(npc_id)
		if snap == null:
			continue

		var score := snap.score
		var arrow_text: String
		var arrow_color: Color
		if not last_outcome_won:
			if score > 60:
				arrow_text  = "▲"
			elif score < 40:
				arrow_text  = "▼"
			else:
				arrow_text  = "—"
			arrow_color = C_SCORE_FAIL
		else:
			if score > 60:
				arrow_text  = "▲"
				arrow_color = C_SCORE_WIN
			elif score < 40:
				arrow_text  = "▼"
				arrow_color = C_SCORE_FAIL
			else:
				arrow_text  = "—"
				arrow_color = C_SCORE_NEU

		var row := HBoxContainer.new()
		row.modulate.a = 0.0

		var name_lbl := Label.new()
		name_lbl.text = npc_name
		name_lbl.custom_minimum_size = Vector2(130, 0)
		name_lbl.add_theme_color_override("font_color", C_HEADING)
		row.add_child(name_lbl)

		var score_lbl := Label.new()
		score_lbl.text = "%3d" % score
		score_lbl.custom_minimum_size = Vector2(36, 0)
		score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		score_lbl.add_theme_color_override("font_color", C_SUBHEADING)
		row.add_child(score_lbl)

		var arrow_lbl := Label.new()
		arrow_lbl.text = "  " + arrow_text
		arrow_lbl.add_theme_color_override("font_color", arrow_color)
		row.add_child(arrow_lbl)
		_arrow_labels.append(arrow_lbl)

		_npc_container.add_child(row)
		# SPA-561: Staggered fade-in for NPC rows.
		var npc_idx: int = _npc_container.get_child_count() - 1
		var delay: float = 0.8 + npc_idx * 0.2
		# Capture row for the closure.
		var row_ref := row
		_world_ref.get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(row_ref):
				var tw := row_ref.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				tw.tween_property(row_ref, "modulate:a", 1.0, 0.3)
		)


# ── Private helpers ───────────────────────────────────────────────────────────

func _add_stat_row(label_text: String, initial_value: String) -> Label:
	var row := HBoxContainer.new()
	row.modulate.a = 0.0

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(140, 0)
	lbl.add_theme_color_override("font_color", C_STAT_LABEL)
	row.add_child(lbl)

	var val := Label.new()
	val.text = initial_value
	val.add_theme_color_override("font_color", C_STAT_VALUE)
	row.add_child(val)

	_stats_container.add_child(row)
	return val


func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_PANEL_BORDER
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	return sep


func _build_bonus_stat(scenario_id: int) -> void:
	var bonus_label_text := ""
	var bonus_value_text := ""

	match scenario_id:
		1:
			bonus_label_text = "Guard Suspicion"
			if _world_ref != null and _world_ref.reputation_system != null:
				var snap: Variant = _world_ref.reputation_system.get_snapshot("bram_guard")
				if snap != null and "score" in snap:
					var s: int = snap.score
					if s >= 80:
						bonus_value_text = "Active"
					elif s >= 60:
						bonus_value_text = "High"
					elif s >= 30:
						bonus_value_text = "Medium"
					else:
						bonus_value_text = "Low"
				else:
					bonus_value_text = "—"
			else:
				bonus_value_text = "—"
		2:
			bonus_label_text = "Contradiction Events"
			var count := 0
			if _world_ref != null and _world_ref.propagation_engine != null:
				count = _world_ref.propagation_engine.contradiction_count
			bonus_value_text = str(count)
		3:
			bonus_label_text = "Calder Rep Delta"
			if _world_ref != null and _world_ref.scenario_manager != null:
				var sm: ScenarioManager = _world_ref.scenario_manager
				var start_score := sm.calder_score_start
				var final_score := sm.calder_score_final
				if start_score >= 0 and final_score >= 0:
					var delta := final_score - start_score
					bonus_value_text = ("+%d pts" % delta) if delta >= 0 else ("%d pts" % delta)
				else:
					bonus_value_text = "—"
			else:
				bonus_value_text = "—"
		4:
			bonus_label_text = "Min Protected Rep"
			if _world_ref != null and _world_ref.scenario_manager != null:
				var progress: Dictionary = _world_ref.scenario_manager.get_scenario_4_progress(
					_world_ref.reputation_system
				)
				bonus_value_text = "%d pts" % progress.get("min_score", 0)
			else:
				bonus_value_text = "—"
		5:
			bonus_label_text = "Election Margin"
			if _world_ref != null and _world_ref.scenario_manager != null:
				var progress: Dictionary = _world_ref.scenario_manager.get_scenario_5_progress(
					_world_ref.reputation_system
				)
				var aldric: int = progress.get("aldric_score", 48)
				var edric: int  = progress.get("edric_score", 58)
				var tomas: int  = progress.get("tomas_score", 45)
				var runner_up: int = max(edric, tomas)
				var margin: int = aldric - runner_up
				bonus_value_text = ("+%d pts" % margin) if margin >= 0 else ("%d pts" % margin)
			else:
				bonus_value_text = "—"
		6:
			bonus_label_text = "Peak Heat"
			if _world_ref != null and _world_ref.scenario_manager != null:
				var progress: Dictionary = _world_ref.scenario_manager.get_scenario_6_progress(
					_world_ref.reputation_system
				)
				var max_heat: float = progress.get("max_heat", 0.0)
				bonus_value_text = "%d / %d" % [int(max_heat), int(ScenarioManager.S6_EXPOSED_HEAT)]
			else:
				bonus_value_text = "—"
		_:
			return   # No bonus stat for unknown scenarios.

	_stats_container.add_child(_make_separator())
	var row := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = bonus_label_text
	lbl.custom_minimum_size = Vector2(140, 0)
	lbl.add_theme_color_override("font_color", C_STAT_LABEL)
	row.add_child(lbl)

	_bonus_lbl = Label.new()
	_bonus_lbl.text = bonus_value_text
	_bonus_lbl.add_theme_color_override("font_color", C_STAT_VALUE)
	row.add_child(_bonus_lbl)

	_stats_container.add_child(row)

	if scenario_id == 2:
		row.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_bonus_lbl = row as Control
	else:
		_bonus_lbl = null


## SPA-907: Build a short performance rating line at the bottom of the stats card.
func _build_performance_summary(won: bool, days_taken: int, days_allowed: int,
		npcs_reached: int, npc_total: int, peak_belief: int) -> void:
	_stats_container.add_child(_make_separator())

	var day_score: float = 0.0
	if days_allowed > 0:
		day_score = clampf(1.0 - (float(days_taken) / float(days_allowed)), 0.0, 1.0)
	var reach_score: float = float(npcs_reached) / float(maxi(npc_total, 1))
	var belief_score: float = clampf(float(peak_belief) / 100.0, 0.0, 1.0)

	var composite: float = belief_score * 0.45 + reach_score * 0.35 + day_score * 0.20
	var pct: int = int(composite * 100.0)

	var rating: String
	var rating_color: Color
	if not won:
		rating = "Incomplete"
		rating_color = C_FAIL
	elif pct >= 85:
		rating = "Masterful"
		rating_color = C_WIN
	elif pct >= 65:
		rating = "Competent"
		rating_color = C_SCORE_NEU
	elif pct >= 40:
		rating = "Adequate"
		rating_color = C_SUBHEADING
	else:
		rating = "Narrow"
		rating_color = C_SCORE_FAIL

	_rating_row = HBoxContainer.new()
	_rating_row.modulate.a = 0.0

	var lbl := Label.new()
	lbl.text = "Rating"
	lbl.custom_minimum_size = Vector2(140, 0)
	lbl.add_theme_color_override("font_color", C_STAT_LABEL)
	_rating_row.add_child(lbl)

	var val := Label.new()
	val.text = rating
	val.add_theme_color_override("font_color", rating_color)
	val.add_theme_font_size_override("font_size", 15)
	_rating_row.add_child(val)

	_stats_container.add_child(_rating_row)
