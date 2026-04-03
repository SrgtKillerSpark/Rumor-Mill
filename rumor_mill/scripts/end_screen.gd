extends CanvasLayer

## end_screen.gd — Sprint 6 end screen overlay (SPA-133 update).
##
## Shown when ScenarioManager emits scenario_resolved (win or fail).
## Displays:
##   1. Win / Fail banner
##   2. Scenario narrative summary (from SPA-128 design doc)
##   3. Stats panel — rumors spread, NPCs corrupted, days taken, evidence used
##   4. Play Again / Next Scenario (win only) / Main Menu buttons
##
## Procedurally built CanvasLayer (layer 30 — above all other HUDs).
## Wire via setup(world, day_night) from main.gd.

# ── Palette ───────────────────────────────────────────────────────────────────
const C_BACKDROP     := Color(0.04, 0.02, 0.02, 0.90)
const C_PANEL_BG     := Color(0.13, 0.09, 0.07, 1.0)
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_WIN          := Color(0.92, 0.78, 0.12, 1.0)   # gold
const C_FAIL         := Color(0.85, 0.18, 0.12, 1.0)   # crimson
const C_HEADING      := Color(0.91, 0.85, 0.70, 1.0)   # parchment
const C_SUBHEADING   := Color(0.75, 0.65, 0.50, 1.0)
const C_BODY         := Color(0.70, 0.65, 0.55, 1.0)
const C_BTN_NORMAL   := Color(0.40, 0.22, 0.08, 1.0)
const C_BTN_HOVER    := Color(0.60, 0.34, 0.12, 1.0)
const C_BTN_TEXT     := Color(0.95, 0.91, 0.80, 1.0)
const C_STAT_LABEL   := Color(0.75, 0.65, 0.50, 1.0)
const C_STAT_VALUE   := Color(0.91, 0.85, 0.70, 1.0)

const PANEL_W := 720
const PANEL_H := 520

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
var _btn_again:        Button         = null
var _btn_next:         Button         = null
var _btn_main_menu:    Button         = null

# ── Runtime refs ──────────────────────────────────────────────────────────────
var _world_ref:     Node2D = null
var _day_night_ref: Node   = null

# ── Active scenario id captured on resolve ────────────────────────────────────
var _current_scenario_id: String = ""


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
	_narrative_lbl.text = _get_summary_text(scenario_id, won, fail_reason)

	# ── Stats panel ───────────────────────────────────────────────────────────
	_populate_stats()

	# ── Next Scenario button — only shown when player won and a next exists ───
	var next_id := _next_scenario_id(_current_scenario_id)
	_btn_next.visible = (won and not next_id.is_empty())

	visible = true


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
	return "exposed"


## Look up summary text from the SPA-128 table.
func _get_summary_text(scenario_id: int, won: bool, fail_reason: String) -> String:
	var key := "win" if won else fail_reason
	var scenario_table: Dictionary = SUMMARY_TEXT.get(scenario_id, {})
	if scenario_table.has(key):
		return scenario_table[key]
	# Fall back to universal table.
	if SUMMARY_FALLBACK.has(key):
		return SUMMARY_FALLBACK[key]
	return "Your scheme ran its course." if won else "Your scheme unravelled."


## Populate the stats grid with 4 metrics.
func _populate_stats() -> void:
	for child in _stats_container.get_children():
		child.queue_free()

	var rumors_spread := 0
	var npcs_corrupted := 0
	var days_taken := 0
	var evidence_used := 0

	if _world_ref != null:
		if _world_ref.propagation_engine != null:
			rumors_spread = _world_ref.propagation_engine.lineage.size()

		if not _world_ref.npcs.is_empty():
			for npc in _world_ref.npcs:
				if "rumor_slots" in npc:
					for slot in npc.rumor_slots.values():
						var s: int = slot.state
						if s == Rumor.RumorState.BELIEVE or s == Rumor.RumorState.SPREAD \
								or s == Rumor.RumorState.ACT:
							npcs_corrupted += 1
							break

		if _world_ref.intel_store != null:
			evidence_used = _world_ref.intel_store.evidence_used_count

	if _day_night_ref != null and "current_day" in _day_night_ref:
		days_taken = _day_night_ref.current_day

	_add_stat_row("Rumors Spread",   str(rumors_spread))
	_add_stat_row("NPCs Corrupted",  str(npcs_corrupted))
	_add_stat_row("Days Taken",      str(days_taken))
	_add_stat_row("Evidence Used",   str(evidence_used))


func _add_stat_row(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(220, 0)
	lbl.add_theme_color_override("font_color", C_STAT_LABEL)
	row.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_color_override("font_color", C_STAT_VALUE)
	row.add_child(val)

	_stats_container.add_child(row)


## Returns the next scenario's string id, or "" if there is none.
static func _next_scenario_id(current: String) -> String:
	match current:
		"scenario_1": return "scenario_2"
		"scenario_2": return "scenario_3"
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
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.set_anchor(SIDE_LEFT,   0.5)
	_panel.set_anchor(SIDE_RIGHT,  0.5)
	_panel.set_anchor(SIDE_TOP,    0.5)
	_panel.set_anchor(SIDE_BOTTOM, 0.5)
	_panel.set_offset(SIDE_LEFT,   -PANEL_W / 2.0)
	_panel.set_offset(SIDE_RIGHT,   PANEL_W / 2.0)
	_panel.set_offset(SIDE_TOP,    -PANEL_H / 2.0)
	_panel.set_offset(SIDE_BOTTOM,  PANEL_H / 2.0)

	var style := StyleBoxFlat.new()
	style.bg_color           = C_PANEL_BG
	style.border_color       = C_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
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

	vbox.add_child(_separator())

	# ── Summary narrative ─────────────────────────────────────────────────────
	_narrative_lbl = RichTextLabel.new()
	_narrative_lbl.custom_minimum_size = Vector2(0, 72)
	_narrative_lbl.fit_content          = true
	_narrative_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_narrative_lbl.add_theme_color_override("default_color", C_BODY)
	vbox.add_child(_narrative_lbl)

	vbox.add_child(_separator())

	# ── Stats panel ───────────────────────────────────────────────────────────
	var stats_heading := Label.new()
	stats_heading.text = "Run Summary"
	stats_heading.add_theme_font_size_override("font_size", 14)
	stats_heading.add_theme_color_override("font_color", C_HEADING)
	vbox.add_child(stats_heading)

	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", 4)
	vbox.add_child(_stats_container)

	vbox.add_child(_separator())

	# ── Buttons ───────────────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	_btn_again = _make_button("Play Again")
	_btn_again.pressed.connect(_on_play_again)
	btn_row.add_child(_btn_again)

	_btn_next = _make_button("Next Scenario")
	_btn_next.pressed.connect(_on_next_scenario)
	_btn_next.visible = false
	btn_row.add_child(_btn_next)

	_btn_main_menu = _make_button("Main Menu")
	_btn_main_menu.pressed.connect(_on_main_menu)
	btn_row.add_child(_btn_main_menu)


func _separator() -> HSeparator:
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_PANEL_BORDER
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	return sep


func _make_button(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(140, 40)

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
	var pause_menu_script = load("res://scripts/pause_menu.gd")
	pause_menu_script._pending_restart_id = _current_scenario_id
	get_tree().reload_current_scene()


func _on_next_scenario() -> void:
	var next_id := _next_scenario_id(_current_scenario_id)
	if next_id.is_empty():
		return
	var pause_menu_script = load("res://scripts/pause_menu.gd")
	pause_menu_script._pending_restart_id = next_id
	get_tree().reload_current_scene()


func _on_main_menu() -> void:
	var pause_menu_script = load("res://scripts/pause_menu.gd")
	pause_menu_script._pending_restart_id = ""
	get_tree().reload_current_scene()
