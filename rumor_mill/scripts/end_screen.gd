extends CanvasLayer

## end_screen.gd — SPA-138 redesign.
##
## 760x640 expanded panel with:
##   1. Win / Fail banner + scenario title
##   2. Italic summary narrative (SPA-128 copy)
##   3. Two-column card row:
##      Left  — _stats_container: Days, Rumors, NPCs Reached, Peak Belief + bonus
##      Right — _npc_container:  3 key NPCs with final score and arrow
##   4. Buttons: Play Again | Next Scenario (dimmed if not applicable) | Main Menu
##
## Procedurally built CanvasLayer (layer 30 — above all other HUDs).
## Wire via setup(world, day_night) from main.gd.

# ── Palette ───────────────────────────────────────────────────────────────────
const C_BACKDROP     := Color(0.04, 0.02, 0.02, 0.90)
const C_PANEL_BG     := Color(0.13, 0.09, 0.07, 1.0)
const C_CARD_BG      := Color(0.10, 0.07, 0.05, 1.0)
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_WIN          := Color(0.92, 0.78, 0.12, 1.0)   # gold
const C_FAIL         := Color(0.85, 0.18, 0.12, 1.0)   # crimson
const C_HEADING      := Color(0.91, 0.85, 0.70, 1.0)   # parchment
const C_SUBHEADING   := Color(0.75, 0.65, 0.50, 1.0)
const C_BODY         := Color(0.70, 0.65, 0.55, 1.0)
const C_MUTED        := Color(0.50, 0.45, 0.38, 1.0)
const C_BTN_NORMAL   := Color(0.40, 0.22, 0.08, 1.0)
const C_BTN_HOVER    := Color(0.60, 0.34, 0.12, 1.0)
const C_BTN_TEXT     := Color(0.95, 0.91, 0.80, 1.0)
const C_STAT_LABEL   := Color(0.75, 0.65, 0.50, 1.0)
const C_STAT_VALUE   := Color(0.91, 0.85, 0.70, 1.0)
const C_SCORE_WIN    := Color(0.92, 0.78, 0.12, 1.0)   # gold  — score > 60
const C_SCORE_FAIL   := Color(0.85, 0.18, 0.12, 1.0)   # crimson — score < 40
const C_SCORE_NEU    := Color(0.85, 0.65, 0.15, 1.0)   # amber — neutral

const PANEL_W := 760
const PANEL_H := 640

# ── Key NPC outcomes per scenario ─────────────────────────────────────────────
# id must match the NPC id string used in reputation_system.

# The primary target NPC whose belief score is shown in the "Peak Belief" stat.
# Keyed by integer scenario_id (matches _populate_stats / _build_bonus_stat).
const PEAK_BELIEF_TARGET: Dictionary = {
	1: { "id": "edric_fenn",    "name": "Edric Fenn" },
	2: { "id": "alys_herbwife", "name": "Alys Herbwife" },
	3: { "id": "calder_fenn",   "name": "Calder Fenn" },
	4: { "id": "aldous_prior",  "name": "Aldous Prior" },
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
}

# ── Summary text (SPA-128 design doc) ────────────────────────────────────────
# keyed as { scenario_int: { "win": String, fail_reason: String, ... } }
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
}

# Universal fallback summaries for conditions not defined per-scenario.
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
}

# ── Node refs ─────────────────────────────────────────────────────────────────
var _backdrop:         ColorRect      = null
var _panel:            PanelContainer = null
var _result_banner:    Label          = null
var _scenario_title:   Label          = null
var _narrative_lbl:    RichTextLabel  = null
var _stats_container:  VBoxContainer  = null
var _npc_container:    VBoxContainer  = null
var _bonus_lbl:        Control        = null   # bonus stat label or row to reveal
var _btn_again:        Button         = null
var _btn_next:         Button         = null
var _btn_main_menu:    Button         = null

# ── Runtime refs ──────────────────────────────────────────────────────────────
var _world_ref:     Node2D = null
var _day_night_ref: Node   = null

# ── Active scenario id captured on resolve ────────────────────────────────────
var _current_scenario_id: String = ""

# ── Tween targets for count-up animation ─────────────────────────────────────
# Each entry: { "label": Label, "target": int, "suffix": String }
var _tween_targets: Array = []


func _ready() -> void:
	layer = 30
	_build_ui()
	visible = false


## Wire to world and day_night; subscribe to scenario_resolved.
func setup(world: Node2D, day_night: Node) -> void:
	_world_ref     = world
	_day_night_ref = day_night
	if world != null and "scenario_manager" in world and world.scenario_manager != null:
		world.scenario_manager.scenario_resolved.connect(_on_scenario_resolved)


# ── Signal handler ────────────────────────────────────────────────────────────

func _on_scenario_resolved(scenario_id: int, state: ScenarioManager.ScenarioState) -> void:
	if _world_ref == null:
		return
	var won: bool = (state == ScenarioManager.ScenarioState.WON)
	var sm: ScenarioManager = _world_ref.scenario_manager

	_current_scenario_id = _world_ref.active_scenario_id if "active_scenario_id" in _world_ref else ""

	# ── Banner ────────────────────────────────────────────────────────────────
	_result_banner.text = "VICTORY" if won else "DEFEAT"
	_result_banner.add_theme_color_override("font_color", C_WIN if won else C_FAIL)

	# ── Scenario title ────────────────────────────────────────────────────────
	_scenario_title.text = sm.get_title() if sm != null else ""

	# ── Summary narrative (SPA-128) ───────────────────────────────────────────
	var fail_reason := "" if won else _infer_fail_reason(scenario_id)
	var summary := _get_summary_text(scenario_id, won, fail_reason)
	_narrative_lbl.text = "[center][i]" + summary + "[/i][/center]"

	# ── Stats panel ───────────────────────────────────────────────────────────
	_populate_stats(scenario_id, won)

	# ── NPC outcomes ──────────────────────────────────────────────────────────
	_populate_npc_outcomes()

	# ── Next Scenario button ──────────────────────────────────────────────────
	var next_id := _next_scenario_id(_current_scenario_id)
	if won and not next_id.is_empty():
		_btn_next.modulate = Color.WHITE
		_btn_next.disabled = false
	else:
		_btn_next.modulate = Color(1.0, 1.0, 1.0, 0.35)
		_btn_next.disabled = true

	visible = true

	# ── Count-up tween ────────────────────────────────────────────────────────
	_start_count_up_tween()


## Guess the fail reason for the fail-text lookup.
func _infer_fail_reason(scenario_id: int) -> String:
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
	# Check days elapsed vs allowed.
	if _day_night_ref != null and sm.get_days_allowed() > 0:
		var days_elapsed: int = _day_night_ref.current_day if "current_day" in _day_night_ref else 0
		if days_elapsed >= sm.get_days_allowed():
			return "timeout"
	# Scenario-appropriate fallback (avoid S1-specific "exposed" text for S2/S3).
	if scenario_id == 1:
		return "exposed"
	return "timeout"


## Look up summary text from the SPA-128 table.
func _get_summary_text(scenario_id: int, won: bool, fail_reason: String) -> String:
	var key := "win" if won else fail_reason
	var scenario_table: Dictionary = SUMMARY_TEXT.get(scenario_id, {})
	if scenario_table.has(key):
		return scenario_table[key]
	if SUMMARY_FALLBACK.has(key):
		return SUMMARY_FALLBACK[key]
	return "Your scheme ran its course." if won else "Your scheme unravelled."


## Populate the stats grid (4 universal + 1 scenario bonus).
func _populate_stats(scenario_id: int, won: bool) -> void:
	for child in _stats_container.get_children():
		child.queue_free()
	_tween_targets.clear()
	if _bonus_lbl != null:
		_bonus_lbl.queue_free()
		_bonus_lbl = null

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
	# Scoped to the scenario primary target NPC so the stat is contextually
	# meaningful.  Falls back to the population maximum for unknown scenarios.
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
	_add_separator_to(_stats_container)
	_build_bonus_stat(scenario_id)


## Add one stat row (label + value) to _stats_container. Returns the value Label.
func _add_stat_row(label_text: String, initial_value: String) -> Label:
	var row := HBoxContainer.new()

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


## Build the scenario-specific bonus stat row, stored in _bonus_lbl.
func _build_bonus_stat(scenario_id: int) -> void:
	var bonus_label_text := ""
	var bonus_value_text := ""

	match scenario_id:
		1:
			bonus_label_text = "Guard Suspicion"
			if _world_ref != null and _world_ref.reputation_system != null:
				var snap: Variant = _world_ref.reputation_system.get_snapshot("bram_guard")
				if snap != null:
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
		_:
			return   # No bonus stat for unknown scenarios.

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

	# Hide numeric bonus (scenario 2) until tween completes; non-numeric shows immediately.
	if scenario_id == 2:
		row.modulate = Color(1.0, 1.0, 1.0, 0.0)
		_bonus_lbl = row as Control   # repurpose _bonus_lbl as the row to reveal
	else:
		_bonus_lbl = null   # no delayed reveal needed


## Populate the NPC outcomes right card.
func _populate_npc_outcomes() -> void:
	for child in _npc_container.get_children():
		child.queue_free()

	if _world_ref == null or _world_ref.reputation_system == null:
		return

	var rep: ReputationSystem = _world_ref.reputation_system
	var npcs_to_show: Array = NPC_OUTCOMES.get(_current_scenario_id, [])

	for entry in npcs_to_show:
		var npc_id: String   = str(entry["id"])
		var npc_name: String = str(entry["name"])
		var snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot(npc_id)
		if snap == null:
			# NPC not present in this scenario — skip silently.
			continue

		var score := snap.score
		var arrow_text: String
		var arrow_color: Color
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

		_npc_container.add_child(row)


## Start count-up tween for all numeric stat value labels.
func _start_count_up_tween() -> void:
	if _tween_targets.is_empty():
		return

	var tw: Tween = create_tween()
	tw.set_parallel(true)

	for entry in _tween_targets:
		var val_lbl: Label   = entry["label"] as Label
		var target: int      = int(entry["target"])
		var suffix: String   = str(entry["suffix"])
		tw.tween_method(
			func(v: float) -> void:
				if is_instance_valid(val_lbl):
					val_lbl.text = str(int(v)) + suffix,
			0.0, float(target), 1.2
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Reveal the bonus row (scenario 2: contradiction events) after tween.
	if _bonus_lbl != null:
		var bonus_ref: Node = _bonus_lbl
		get_tree().create_timer(1.3).timeout.connect(func() -> void:
			if is_instance_valid(bonus_ref):
				bonus_ref.modulate = Color.WHITE
		)


## Returns the next scenario's string id, or "" if there is none.
static func _next_scenario_id(current: String) -> String:
	match current:
		"scenario_1": return "scenario_2"
		"scenario_2": return "scenario_3"
		"scenario_3": return "scenario_4"
	return ""


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-screen dimming backdrop.
	_backdrop = ColorRect.new()
	_backdrop.color = C_BACKDROP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	# Centred panel container.
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	_panel.set_anchor(SIDE_LEFT,   0.5)
	_panel.set_anchor(SIDE_RIGHT,  0.5)
	_panel.set_anchor(SIDE_TOP,    0.5)
	_panel.set_anchor(SIDE_BOTTOM, 0.5)
	_panel.set_offset(SIDE_LEFT,   -PANEL_W / 2.0)
	_panel.set_offset(SIDE_RIGHT,   PANEL_W / 2.0)
	_panel.set_offset(SIDE_TOP,    -PANEL_H / 2.0)
	_panel.set_offset(SIDE_BOTTOM,  PANEL_H / 2.0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color           = C_PANEL_BG
	panel_style.border_color       = C_PANEL_BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	# ── Victory / Defeat banner ───────────────────────────────────────────────
	_result_banner = Label.new()
	_result_banner.text = "VICTORY"
	_result_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_banner.add_theme_font_size_override("font_size", 36)
	_result_banner.add_theme_color_override("font_color", C_WIN)
	vbox.add_child(_result_banner)

	# ── Scenario title ────────────────────────────────────────────────────────
	_scenario_title = Label.new()
	_scenario_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scenario_title.add_theme_font_size_override("font_size", 16)
	_scenario_title.add_theme_color_override("font_color", C_SUBHEADING)
	vbox.add_child(_scenario_title)

	vbox.add_child(_make_separator())

	# ── Summary narrative (italic, centered, 15pt) ────────────────────────────
	_narrative_lbl = RichTextLabel.new()
	_narrative_lbl.custom_minimum_size = Vector2(0, 80)
	_narrative_lbl.fit_content          = false
	_narrative_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_narrative_lbl.bbcode_enabled       = true
	_narrative_lbl.add_theme_color_override("default_color", C_BODY)
	_narrative_lbl.add_theme_font_size_override("normal_font_size", 15)
	vbox.add_child(_narrative_lbl)

	vbox.add_child(_make_separator())

	# ── Two-column card row ───────────────────────────────────────────────────
	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 12)
	cards_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(cards_row)

	# Left card — RESULTS / stats
	var left_card := _make_card()
	left_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_row.add_child(left_card)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 6)
	left_card.add_child(left_vbox)

	var stats_heading := Label.new()
	stats_heading.text = "RESULTS"
	stats_heading.add_theme_font_size_override("font_size", 13)
	stats_heading.add_theme_color_override("font_color", C_HEADING)
	left_vbox.add_child(stats_heading)

	_add_separator_to(left_vbox)

	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", 5)
	left_vbox.add_child(_stats_container)

	# Right card — KEY OUTCOMES / NPC rows
	var right_card := _make_card()
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_row.add_child(right_card)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 6)
	right_card.add_child(right_vbox)

	var npc_heading := Label.new()
	npc_heading.text = "KEY OUTCOMES"
	npc_heading.add_theme_font_size_override("font_size", 13)
	npc_heading.add_theme_color_override("font_color", C_HEADING)
	right_vbox.add_child(npc_heading)

	_add_separator_to(right_vbox)

	_npc_container = VBoxContainer.new()
	_npc_container.add_theme_constant_override("separation", 7)
	right_vbox.add_child(_npc_container)

	vbox.add_child(_make_separator())

	# ── Button row ────────────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	_btn_again = _make_button("Play Again", 150)
	_btn_again.pressed.connect(_on_play_again)
	btn_row.add_child(_btn_again)

	_btn_next = _make_button("Next Scenario", 160)
	_btn_next.pressed.connect(_on_next_scenario)
	_btn_next.modulate = Color(1.0, 1.0, 1.0, 0.35)
	_btn_next.disabled = true
	btn_row.add_child(_btn_next)

	_btn_main_menu = _make_button("Main Menu", 150)
	_btn_main_menu.pressed.connect(_on_main_menu)
	btn_row.add_child(_btn_main_menu)


func _make_card() -> PanelContainer:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color     = C_CARD_BG
	card_style.border_color = C_PANEL_BORDER
	card_style.set_border_width_all(1)
	card_style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", card_style)
	return card


func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_PANEL_BORDER
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	return sep


func _add_separator_to(container: Node) -> void:
	container.add_child(_make_separator())


func _make_button(label: String, min_width: int) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(min_width, 40)

	var normal := StyleBoxFlat.new()
	normal.bg_color = C_BTN_NORMAL
	normal.set_border_width_all(1)
	normal.border_color = C_PANEL_BORDER
	normal.set_content_margin_all(8)

	var hover := StyleBoxFlat.new()
	hover.bg_color = C_BTN_HOVER
	hover.set_border_width_all(1)
	hover.border_color = C_PANEL_BORDER
	hover.set_content_margin_all(8)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover",  hover)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)
	return btn


# ── Button handlers ───────────────────────────────────────────────────────────

func _on_play_again() -> void:
	var pause_menu_script = load("res://scripts/pause_menu.gd") as Script
	if pause_menu_script == null:
		push_error("EndScreen: failed to load pause_menu.gd")
		return
	pause_menu_script._pending_restart_id = _current_scenario_id
	get_tree().reload_current_scene()


func _on_next_scenario() -> void:
	var next_id := _next_scenario_id(_current_scenario_id)
	if next_id.is_empty():
		return
	var pause_menu_script = load("res://scripts/pause_menu.gd") as Script
	if pause_menu_script == null:
		push_error("EndScreen: failed to load pause_menu.gd")
		return
	pause_menu_script._pending_restart_id = next_id
	get_tree().reload_current_scene()


func _on_main_menu() -> void:
	var pause_menu_script = load("res://scripts/pause_menu.gd") as Script
	if pause_menu_script == null:
		push_error("EndScreen: failed to load pause_menu.gd")
		return
	pause_menu_script._pending_restart_id = ""
	get_tree().reload_current_scene()
