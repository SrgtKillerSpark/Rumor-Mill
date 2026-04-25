class_name EndScreenScoring
extends RefCounted

## end_screen_scoring.gd — Stat calculation, fail inference, summary text,
## NPC outcomes, and player-stat recording for EndScreen.
##
## Extracted from end_screen.gd (SPA-1010). Owns all result-data logic and
## builds the STATS and KEY OUTCOMES card content.
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

# ── Summary text (SPA-128 design doc) ─────────────────────────────────────────
const SUMMARY_TEXT := {
	1: {
		"win": (
			"Edric Fenn resigned the aldermanship within a fortnight, citing ill health that no physician"
			+ " could confirm. Your patron's candidate was endorsed by Prior Aldous before the tax rolls"
			+ " were ever signed, and the autumn assessment passed quietly under new hands."
			+ " The story you planted has already grown three different endings — none of them yours."
		),
		"exposed": (
			"Bram the Guard Captain never moved against you openly — he didn't have to. Once your movements"
			+ " were common knowledge, every rumor you had planted lost its anonymous source and gained"
			+ " a suspect instead. The town closed around Edric Fenn like a fist,"
			+ " and your patron stopped sending letters."
		),
		"timeout": (
			"The tax rolls were sealed before your work could ripen. Fenn's position hardened rather than"
			+ " cracked — a man under rumored attack earns sympathy in a town that fears disruption more"
			+ " than corruption. Your patron made other arrangements. You were not part of them."
		),
	},
	2: {
		"win": (
			"Alys the Herb-Wife left quietly before anyone thought to ask why the illness talk had started."
			+ " Sister Maren's public correction came too late to help her — the customers had already"
			+ " returned to Vera the Midwife, and the market season closed without incident."
			+ " The rumor itself died the way it began: with no one admitting they had started it."
		),
		"contradicted": (
			"Sister Maren's public rebuttal did not name you, but it didn't need to. The town's sympathy"
			+ " shifted to Alys overnight, and the Midwife's customers began to wonder whether the illness"
			+ " talk had been honest concern or deliberate cruelty."
			+ " Alys is still here. You are somewhat less welcome than you were."
		),
		"timeout": (
			"The autumn market ran its full course, and Alys ran hers alongside it. By the last week,"
			+ " several of the Midwife's regular customers had begun buying from both stalls. The window"
			+ " to shape opinion had closed; the market had simply decided. Your wages were not forthcoming."
		),
	},
	3: {
		"win": (
			"Calder Fenn's name was read at the winter festival to a cheer that surprised even Lady Isolde."
			+ " Tomas Reeve accepted a minor administrative posting with the quiet dignity of a man who"
			+ " knows he has already lost. The nomination process moved forward without anyone examining"
			+ " too closely how the ground had shifted beneath it."
		),
		"calder_implicated": (
			"The story mutated somewhere between the Tavern and the Chapel steps — praise curdling into"
			+ " suspicion faster than anyone had expected. Calder Fenn became the subject rather than the"
			+ " beneficiary, and Lady Isolde recognised your fingerprints long before she said so."
			+ " Tomas Reeve, watching from the sidelines, appeared to find the situation quietly satisfying."
		),
		"timeout": (
			"The winter festival came and the nominations were read to a crowd that had settled on no opinion."
			+ " Calder Fenn's name earned the same polite acknowledgement as Tomas Reeve's — neither elevated,"
			+ " neither ruined, neither story quite landing. Lady Isolde paid what was agreed and said nothing"
			+ " beyond that. The ledger, at least, was square."
		),
	},
	4: {
		"win": (
			"Brother Cornelius departed with an unsigned writ and the Bishop's clerk recorded the outcome as"
			+ " 'insufficient evidence.' The three accused returned to their posts — Aldous to his sermons,"
			+ " Vera to her patients, Finn to his prayers — as though the inquisitor had been a passing storm."
			+ " The town chose its own, and the Church accepted the choice. This time."
		),
		"reputation_collapsed": (
			"The stories took root faster than you could uproot them. By the time you understood the shape"
			+ " of the inquisitor's campaign, the town had already chosen its side — and it was not yours."
			+ " The writ was signed before the twentieth day. The accused were led away quietly,"
			+ " and the town returned to its business with the relief of people who had found someone to blame."
		),
		"timeout": (
			"Twenty days passed and the inquisitor's patience outlasted yours. The stories you countered"
			+ " had not been silenced — only muffled. Brother Cornelius presented his findings with the quiet"
			+ " confidence of a man whose work was already done. The formal verdict was a formality."
		),
	},
	5: {
		"win": (
			"The votes were counted in the Town Hall with the doors open and the crowd pressing in."
			+ " Aldric Vane's name was called three times for every one of Edric's. Tomas Reeve's supporters"
			+ " had already left. The new alderman accepted the chain of office with a speech about honest"
			+ " trade and fair governance. Your patron watched from the second row, expressionless."
			+ " But when Vane finished, the old merchant raised his cup — just once, just slightly."
			+ " You were already packed."
		),
		"aldric_destroyed": (
			"The story had started as praise. Somewhere between the Tavern and the Market it curdled — too"
			+ " much too fast, the name repeated until the repetition itself became suspicious."
			+ " Aldric Vane withdrew his candidacy at noon without explanation. His supporters scattered"
			+ " like starlings from a broken eave. Your patron's investment, and whatever goodwill"
			+ " you had built in this town, went with them."
		),
		"timeout": (
			"The votes were counted. Edric Fenn's name was called first, as it had been called for nine years."
			+ " Aldric Vane came second — close enough to taste, far enough to know it was finished."
			+ " Tomas Reeve's handful of supporters consoled themselves with ale and reform pamphlets"
			+ " that no one would read. Your patron did not send for you again."
		),
	},
	6: {
		"win": (
			"The guild audit was called on a Tuesday — at Marta Coin's request, seconded by the Prior."
			+ " Aldric Vane did not attend. His seat in the Guild Hall was empty when the real ledger"
			+ " was read aloud, and the silence that followed it was louder than any accusation"
			+ " you had ever whispered. Marta Coin was elected interim Guild Master before the week was out."
			+ " She did not mention your name. She didn't need to."
		),
		"marta_silenced": (
			"The story changed overnight. Suddenly it was Marta who was the thief — Marta who had falsified"
			+ " records, Marta whose name could not be trusted in any ledger or marketplace."
			+ " Aldric's allies moved with the speed of people who had been waiting for exactly this opening."
			+ " By the time you understood what had happened, Marta's stall was shuttered and her name"
			+ " was poison in the market quarter. You had underestimated how quickly a guild can close ranks."
		),
		"exposed": (
			"The Guard Captain found you at the well, just after dawn."
			+ " 'Aldric Vane sends his regards,' he said — not a threat, a statement of fact."
			+ " By noon, every merchant in the quarter knew your face and your purpose."
			+ " Marta Coin denied ever meeting you. She had no choice, and you could not blame her for it."
		),
		"timeout": (
			"Twenty days passed. The ledger sat in Marta's locked chest, still waiting for the right moment."
			+ " The right moment never came. Aldric Vane's reputation was bruised but intact, and the guild"
			+ " closed its books for the season with the quiet efficiency of an institution that had survived"
			+ " worse than whispers. Marta Coin paid you the second half of your fee without a word."
			+ " You both knew it had been wasted."
		),
	},
}

const SUMMARY_FALLBACK := {
	"timeout": (
		"The days ran out before the story ran deep enough. Rumors without roots fade with the season,"
		+ " and a town that almost changed simply doesn't."
		+ " Whatever you were paid to accomplish remains undone — the ledger stays open."
	),
	"exposed": (
		"Someone noticed the pattern before the pattern was finished. A foreign face asking the wrong"
		+ " questions in too many places invites scrutiny, and scrutiny is the one thing a rumor campaign"
		+ " cannot survive. You left the town largely intact, with only your reputation as a casualty."
	),
	"contradicted": (
		"A credible voice stepped forward and named the story for what it was: invention. The correction"
		+ " spread faster than the original rumor — corrections usually do, in towns where people are"
		+ " already suspicious. The target emerged with more goodwill than before you arrived."
	),
	"calder_implicated": (
		"The narrative slipped control and landed on the wrong person. When the person you were protecting"
		+ " becomes the subject of the story you were telling, the mission is over"
		+ " — and the client is rarely forgiving about it."
	),
	"aldric_destroyed": (
		"The person you were meant to elevate became the casualty of your own campaign."
		+ " Praise turned to scrutiny, scrutiny to suspicion, and suspicion to collapse."
		+ " The difference between making someone's name and ruining it is thinner than most people suppose,"
		+ " and you found that line from the wrong side."
	),
	"marta_silenced": (
		"The person you were meant to protect became the one they destroyed instead."
		+ " When the opposition turns your patron into the villain of your own story,"
		+ " the mission has already ended — you simply haven't admitted it yet."
		+ " The client's name is now the story, and you are not in it."
	),
}

# ── Runtime refs ──────────────────────────────────────────────────────────────
var _world_ref:      Node2D = null
var _day_night_ref:  Node   = null
var _stats_container:  VBoxContainer = null
var _npc_container:    VBoxContainer = null

# ── Animation-readable state ──────────────────────────────────────────────────
var _tween_targets: Array       = []
var _bonus_lbl:     Control     = null
var _rating_row:    HBoxContainer = null
var _arrow_labels:  Array       = []


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

## Guess the fail reason for the fail-text lookup.
func infer_fail_reason(scenario_id: int) -> String:
	if _world_ref == null or _world_ref.scenario_manager == null:
		return "timeout"
	var sm: ScenarioManager = _world_ref.scenario_manager
	if scenario_id == 3:
		var rep: ReputationSystem = _world_ref.reputation_system
		if rep != null:
			var calder := rep.get_snapshot(ScenarioManager.CALDER_FENN_ID)
			if calder != null and calder.score < ScenarioManager.S3_FAIL_CALDER_BELOW:
				return "calder_implicated"
	if scenario_id == 2:
		var rep: ReputationSystem = _world_ref.reputation_system
		if rep != null and rep.has_illness_rejecter(ScenarioManager.ALYS_HERBWIFE_ID, ScenarioManager.MAREN_NUN_ID):
			return "contradicted"
	if scenario_id == 4:
		var rep: ReputationSystem = _world_ref.reputation_system
		if rep != null:
			for npc_id in ScenarioManager.S4_PROTECTED_NPC_IDS:
				var snap := rep.get_snapshot(npc_id)
				if snap != null and snap.score < ScenarioManager.S4_FAIL_REP_BELOW:
					return "reputation_collapsed"
	if scenario_id == 5:
		var rep: ReputationSystem = _world_ref.reputation_system
		if rep != null:
			var aldric := rep.get_snapshot(ScenarioManager.ALDRIC_VANE_ID)
			if aldric != null and aldric.score < ScenarioManager.S5_FAIL_ALDRIC_BELOW:
				return "aldric_destroyed"
	if scenario_id == 6:
		var rep: ReputationSystem = _world_ref.reputation_system
		if rep != null:
			var marta := rep.get_snapshot(ScenarioManager.MARTA_COIN_ID)
			if marta != null and marta.score < ScenarioManager.S6_FAIL_MARTA_BELOW:
				return "marta_silenced"
		if _world_ref.intel_store != null:
			for npc_id in _world_ref.intel_store.heat:
				if _world_ref.intel_store.heat[npc_id] >= ScenarioManager.S6_EXPOSED_HEAT:
					return "exposed"
	# Check days elapsed vs allowed.
	if _day_night_ref != null and sm.get_days_allowed() > 0:
		var days_elapsed: int = _day_night_ref.current_day if "current_day" in _day_night_ref else 0
		if days_elapsed >= sm.get_days_allowed():
			return "timeout"
	# Scenario-appropriate fallback.
	if scenario_id == 1:
		return "exposed"
	return "timeout"


## Look up summary text from the SPA-128 table.
func get_summary_text(scenario_id: int, won: bool, fail_reason: String) -> String:
	var key := "win" if won else fail_reason
	var scenario_table: Dictionary = SUMMARY_TEXT.get(scenario_id, {})
	if scenario_table.has(key):
		return scenario_table[key]
	# Fall back to ScenarioManager (scenarios.json) for any key not in the hard-coded table.
	if _world_ref != null and _world_ref.scenario_manager != null:
		var sm: ScenarioManager = _world_ref.scenario_manager
		var json_text := sm.get_victory_text() if won else sm.get_fail_text(key)
		if not json_text.is_empty():
			return json_text
	if SUMMARY_FALLBACK.has(key):
		return SUMMARY_FALLBACK[key]
	return "Your scheme ran its course." if won else "Your scheme unravelled."


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
	var days_taken    := 0
	var days_allowed  := sm.get_days_allowed() if sm != null else 0
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
