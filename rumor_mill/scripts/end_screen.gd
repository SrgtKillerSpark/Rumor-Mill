extends CanvasLayer

## end_screen.gd — SPA-138 redesign + SPA-212 analytics tab.
##
## 760x640 expanded panel with:
##   1. Win / Fail banner + scenario title
##   2. Italic summary narrative (SPA-128 copy)
##   3. Tab bar: RESULTS | REPLAY (analytics)
##   4a. Results tab (default):
##       Left  — _stats_container: Days, Rumors, NPCs Reached, Peak Belief + bonus
##       Right — _npc_container:  3 key NPCs with final score and arrow
##   4b. Replay tab (SPA-212):
##       Rumor timeline bar chart, top influencers, key moments log
##   5. Buttons: Play Again | Next Scenario (dimmed if not applicable) | Main Menu
##
## Procedurally built CanvasLayer (layer 30 — above all other HUDs).
## Wire via setup(world, day_night) from main.gd.
##
## Subsystem modules (SPA-1010):
##   EndScreenScoring    — stat data, fail inference, summary text, NPC outcomes
##   EndScreenAnimations — count-up tween, arrow bounce, button pulse
##   EndScreenReplayTab  — analytics replay tab content
##   EndScreenFeedback   — post-game feedback prompt modal

# ── Palette ───────────────────────────────────────────────────────────────────
const C_BACKDROP     := Color(0.04, 0.02, 0.02, 0.90)
const C_PANEL_BG     := Color(0.13, 0.09, 0.07, 1.0)
const C_CARD_BG      := Color(0.10, 0.07, 0.05, 1.0)
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_WIN          := Color(0.92, 0.78, 0.12, 1.0)
const C_FAIL         := Color(0.85, 0.18, 0.12, 1.0)
const C_HEADING      := Color(0.91, 0.85, 0.70, 1.0)
const C_SUBHEADING   := Color(0.75, 0.65, 0.50, 1.0)
const C_BODY         := Color(0.70, 0.65, 0.55, 1.0)
const C_BTN_NORMAL   := Color(0.40, 0.22, 0.08, 1.0)
const C_BTN_HOVER    := Color(0.60, 0.34, 0.12, 1.0)
const C_BTN_TEXT     := Color(0.95, 0.91, 0.80, 1.0)

const PANEL_W := 760
const PANEL_H := 640

# ── SPA-784: "What went wrong" defeat one-liner ────────────────────────────
const WHAT_WENT_WRONG := {
	"exposed":              "You were identified — the rumor lost its anonymity.",
	"timeout":              "You ran out of time before the story could take hold.",
	"contradicted":         "A credible voice contradicted the rumor publicly.",
	"calder_implicated":    "Calder became the target of your own narrative.",
	"aldric_destroyed":     "Aldric's reputation collapsed under your campaign.",
	"marta_silenced":       "Marta was turned into the villain of her own story.",
	"reputation_collapsed": "A protected NPC's reputation fell below the threshold.",
}

# ── Node refs ─────────────────────────────────────────────────────────────────
var _backdrop:              ColorRect      = null
var _panel:                 PanelContainer = null
var _result_banner:         Label          = null
var _scenario_title:        Label          = null
var _narrative_lbl:         RichTextLabel  = null
var _strategic_hint_lbl:    RichTextLabel  = null
var _stats_container:       VBoxContainer  = null
var _npc_container:         VBoxContainer  = null
var _btn_again:             Button         = null
var _btn_next:              Button         = null
var _btn_main_menu:         Button         = null
var _tease_lbl:             RichTextLabel  = null
var _tab_results:           Button         = null
var _tab_replay:            Button         = null
var _results_container:     Control        = null
var _replay_container:      VBoxContainer  = null
var _what_went_wrong_lbl:   Label          = null

# ── Runtime refs ──────────────────────────────────────────────────────────────
var _world_ref:     Node2D = null
var _day_night_ref: Node   = null
var _analytics_ref: ScenarioAnalytics = null

# ── State ─────────────────────────────────────────────────────────────────────
var _current_scenario_id: String = ""
var _resolving:           bool   = false
var _last_outcome_won:    bool   = false

# ── Subsystem modules ─────────────────────────────────────────────────────────
var _scoring:    EndScreenScoring    = null
var _animations: EndScreenAnimations = null
var _replay_tab: EndScreenReplayTab  = null
var _feedback:   EndScreenFeedback   = null


func _ready() -> void:
	layer = 30
	_build_ui()
	_scoring    = EndScreenScoring.new()
	_animations = EndScreenAnimations.new()
	_animations.setup(self)
	_replay_tab = EndScreenReplayTab.new()
	_feedback   = EndScreenFeedback.new()
	_feedback.setup(self, _btn_again)
	visible = false


## Wire to world, day_night, and analytics; subscribe to scenario_resolved.
func setup(world: Node2D, day_night: Node, analytics: ScenarioAnalytics = null) -> void:
	_world_ref     = world
	_day_night_ref = day_night
	_analytics_ref = analytics
	if world != null and "scenario_manager" in world and world.scenario_manager != null:
		world.scenario_manager.scenario_resolved.connect(_on_scenario_resolved)


# ── Signal handler ────────────────────────────────────────────────────────────

func _on_scenario_resolved(scenario_id: int, state: ScenarioManager.ScenarioState) -> void:
	if _resolving or _world_ref == null:
		return
	_resolving = true

	if _day_night_ref != null and _day_night_ref.has_method("set_paused"):
		_day_night_ref.set_paused(true)

	await TransitionManager.fade_out(0.4)

	var won: bool = (state == ScenarioManager.ScenarioState.WON)
	_last_outcome_won = won
	var sm: ScenarioManager = _world_ref.scenario_manager

	_current_scenario_id = _world_ref.active_scenario_id if "active_scenario_id" in _world_ref else ""

	# Wire scoring module now that world/day_night refs are known.
	_scoring.setup(_world_ref, _day_night_ref, _stats_container, _npc_container)

	# ── Banner ────────────────────────────────────────────────────────────────
	_result_banner.text = "VICTORY" if won else "DEFEAT"
	_result_banner.add_theme_color_override("font_color", C_WIN if won else C_FAIL)

	# ── Scenario title ────────────────────────────────────────────────────────
	_scenario_title.text = sm.get_title() if sm != null else ""

	# ── Summary narrative (SPA-128) ───────────────────────────────────────────
	var fail_reason := "" if won else _scoring.infer_fail_reason(scenario_id)
	var summary := _scoring.get_summary_text(scenario_id, won, fail_reason)
	if scenario_id == 2 and fail_reason == "contradicted" and sm != null:
		var carrier: String = sm.s2_maren_carrier_name
		if not carrier.is_empty():
			summary += ("\n\nThe rumor reached her through %s." % carrier)
	_narrative_lbl.text = "[center][i]" + summary + "[/i][/center]"

	# ── SPA-948: Strategic defeat hint ───────────────────────────────────────
	if _strategic_hint_lbl != null:
		if not won and sm != null:
			var hint := sm.get_strategic_defeat_hint(fail_reason)
			if not hint.is_empty():
				_strategic_hint_lbl.text = "[center][b]NEXT TIME:[/b] " + hint + "[/center]"
				_strategic_hint_lbl.visible = true
			else:
				_strategic_hint_lbl.visible = false
		else:
			_strategic_hint_lbl.visible = false

	# ── Stats + NPC outcomes ──────────────────────────────────────────────────
	_scoring.populate_stats(scenario_id, won)
	_scoring.record_player_stats(scenario_id, won, _current_scenario_id)
	_scoring.populate_npc_outcomes(_current_scenario_id, won)

	# ── Analytics (SPA-212) ───────────────────────────────────────────────────
	if _analytics_ref != null:
		_analytics_ref.finalize()
		_replay_tab.setup(_replay_container, _analytics_ref)
		_replay_tab.populate()

	# ── Next Scenario button ──────────────────────────────────────────────────
	var next_id := _next_scenario_id(_current_scenario_id)
	if won and not next_id.is_empty():
		_btn_next.modulate = Color.WHITE
		_btn_next.disabled = false
		_btn_next.focus_mode = Control.FOCUS_ALL
		_animations.start_btn_pulse(_btn_next)
	else:
		_btn_next.modulate = Color(1.0, 1.0, 1.0, 0.35)
		_btn_next.disabled = true
		_btn_next.focus_mode = Control.FOCUS_NONE

	# ── SPA-899: Cross-scenario tease ────────────────────────────────────────
	if _tease_lbl != null:
		if won and not next_id.is_empty():
			var tease_text: String = _load_next_scenario_tease(next_id)
			if not tease_text.is_empty():
				_tease_lbl.text = "[center][color=#c8a84e]\u25b8 " + tease_text + "[/color][/center]"
				_tease_lbl.visible = true
			else:
				_tease_lbl.visible = false
		else:
			_tease_lbl.visible = false

	# ── SPA-784: "What went wrong" one-liner for defeat ──────────────────────
	if not won:
		_show_what_went_wrong(scenario_id, _scoring.infer_fail_reason(scenario_id))

	_show_tab_results()

	visible = true
	# ── Entrance animation ────────────────────────────────────────────────────
	if _backdrop != null:
		_backdrop.modulate.a = 0.0
	if _panel != null:
		_panel.modulate.a = 0.0
		_panel.scale = Vector2(0.92, 0.92)
		_panel.pivot_offset = Vector2(PANEL_W / 2.0, PANEL_H / 2.0)
	TransitionManager.fade_in(0.35)
	var _enter_tw := create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _backdrop != null:
		_enter_tw.tween_property(_backdrop, "modulate:a", 1.0, 0.35)
	if _panel != null:
		_enter_tw.tween_property(_panel, "modulate:a", 1.0, 0.4)
		_enter_tw.tween_property(_panel, "scale", Vector2.ONE, 0.4)

	# SPA-784 / SPA-947: Defeat makes Try Again prominent.
	if not won and _btn_again != null:
		_btn_again.text = "Try Again"
		_btn_again.add_theme_font_size_override("font_size", 18)
		_btn_again.custom_minimum_size = Vector2(180, 48)
		_btn_again.call_deferred("grab_focus")
	elif _btn_again != null:
		_btn_again.text = "Play Again"
		_btn_again.call_deferred("grab_focus")

	# ── Count-up tween + journal SFX ─────────────────────────────────────────
	get_tree().create_timer(0.45).timeout.connect(func() -> void:
		if is_inside_tree():
			AudioManager.play_sfx("journal_open")
			_animations.start_count_up(
				_scoring.get_tween_targets(),
				_scoring.get_bonus_lbl(),
				_scoring.get_rating_row(),
				_scoring.get_arrow_labels(),
			)
	)

	# ── SPA-336 / SPA-947: Feedback prompt ───────────────────────────────────
	var feedback_delay := 5.0 if won else 8.0
	var scenario_id_snap := _current_scenario_id
	var won_snap := won
	get_tree().create_timer(feedback_delay).timeout.connect(func() -> void:
		if is_inside_tree():
			_feedback.show_prompt(won_snap, scenario_id_snap)
	)


# ── Scenario navigation ───────────────────────────────────────────────────────

## Returns the next scenario's string id, or "" if there is none.
static func _next_scenario_id(current: String) -> String:
	match current:
		"scenario_1": return "scenario_2"
		"scenario_2": return "scenario_3"
		"scenario_3": return "scenario_4"
		"scenario_4": return "scenario_5"
		"scenario_5": return "scenario_6"
	return ""


## Load title + teaseHook for the given scenario id from scenarios.json.
static func _load_next_scenario_tease(scenario_id: String) -> String:
	const SCENARIOS_PATH := "res://data/scenarios.json"
	if not FileAccess.file_exists(SCENARIOS_PATH):
		return ""
	var file := FileAccess.open(SCENARIOS_PATH, FileAccess.READ)
	if file == null:
		return ""
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not (parsed is Array):
		return ""
	for entry: Variant in parsed as Array:
		if not (entry is Dictionary):
			continue
		if (entry as Dictionary).get("scenarioId", "") != scenario_id:
			continue
		var title: String = str((entry as Dictionary).get("title", ""))
		var hook: String  = str((entry as Dictionary).get("teaseHook",
				(entry as Dictionary).get("hookText", "")))
		if title.is_empty():
			return ""
		if hook.is_empty():
			return "Next: " + title
		return "Next: " + title + " \u2014 " + hook
	return ""


# ── Defeat feedback ───────────────────────────────────────────────────────────

func _show_what_went_wrong(scenario_id: int, fail_reason: String) -> void:
	if _what_went_wrong_lbl != null:
		_what_went_wrong_lbl.queue_free()
	var text: String = WHAT_WENT_WRONG.get(fail_reason, "Your scheme unravelled.")
	_what_went_wrong_lbl = Label.new()
	_what_went_wrong_lbl.text = text
	_what_went_wrong_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_what_went_wrong_lbl.add_theme_font_size_override("font_size", 13)
	_what_went_wrong_lbl.add_theme_color_override("font_color", C_FAIL)
	_what_went_wrong_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _results_container != null and _results_container.get_parent() != null:
		var vbox := _results_container.get_parent()
		var idx_after: int = _results_container.get_index() + 1
		vbox.add_child(_what_went_wrong_lbl)
		vbox.move_child(_what_went_wrong_lbl, idx_after)


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = C_BACKDROP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

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

	# ── Summary narrative ─────────────────────────────────────────────────────
	_narrative_lbl = RichTextLabel.new()
	_narrative_lbl.fit_content          = true
	_narrative_lbl.custom_maximum_size  = Vector2(0, 120)
	_narrative_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_narrative_lbl.bbcode_enabled       = true
	_narrative_lbl.add_theme_color_override("default_color", C_BODY)
	_narrative_lbl.add_theme_font_size_override("normal_font_size", 15)
	vbox.add_child(_narrative_lbl)

	# ── SPA-948: Strategic defeat hint ───────────────────────────────────────
	_strategic_hint_lbl = RichTextLabel.new()
	_strategic_hint_lbl.fit_content          = true
	_strategic_hint_lbl.custom_maximum_size  = Vector2(0, 60)
	_strategic_hint_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_strategic_hint_lbl.bbcode_enabled       = true
	_strategic_hint_lbl.add_theme_color_override("default_color", Color(0.95, 0.75, 0.30, 1.0))
	_strategic_hint_lbl.add_theme_font_size_override("normal_font_size", 13)
	_strategic_hint_lbl.add_theme_font_size_override("bold_font_size", 13)
	_strategic_hint_lbl.visible = false
	vbox.add_child(_strategic_hint_lbl)

	vbox.add_child(_make_separator())

	# ── SPA-840: Next-scenario tease ─────────────────────────────────────────
	_tease_lbl = RichTextLabel.new()
	_tease_lbl.custom_minimum_size = Vector2(0, 32)
	_tease_lbl.fit_content = true
	_tease_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tease_lbl.bbcode_enabled = true
	_tease_lbl.add_theme_color_override("default_color", C_SUBHEADING)
	_tease_lbl.add_theme_font_size_override("normal_font_size", 14)
	_tease_lbl.visible = false
	vbox.add_child(_tease_lbl)

	# ── SPA-212: Tab bar ─────────────────────────────────────────────────────
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_row)

	_tab_results = _make_tab_button("RESULTS", true)
	_tab_results.pressed.connect(_show_tab_results)
	tab_row.add_child(_tab_results)

	_tab_replay = _make_tab_button("REPLAY", false)
	_tab_replay.pressed.connect(_show_tab_replay)
	tab_row.add_child(_tab_replay)

	_tab_results.focus_neighbor_right = _tab_replay.get_path()
	_tab_results.focus_next           = _tab_replay.get_path()
	_tab_replay.focus_neighbor_left   = _tab_results.get_path()
	_tab_replay.focus_previous        = _tab_results.get_path()

	# ── Results tab content ───────────────────────────────────────────────────
	_results_container = HBoxContainer.new()
	_results_container.add_theme_constant_override("separation", 12)
	_results_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_results_container)

	var left_card := _make_card()
	left_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_container.add_child(left_card)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 6)
	left_card.add_child(left_vbox)

	var stats_heading := Label.new()
	stats_heading.text = "STATS"
	stats_heading.add_theme_font_size_override("font_size", 13)
	stats_heading.add_theme_color_override("font_color", C_HEADING)
	left_vbox.add_child(stats_heading)

	_add_separator_to(left_vbox)

	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", 5)
	left_vbox.add_child(_stats_container)

	var right_card := _make_card()
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_results_container.add_child(right_card)

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

	# ── Replay tab content ────────────────────────────────────────────────────
	_replay_container = VBoxContainer.new()
	_replay_container.add_theme_constant_override("separation", 8)
	_replay_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_replay_container.visible = false
	vbox.add_child(_replay_container)

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

	_btn_again.focus_neighbor_right      = _btn_next.get_path()
	_btn_again.focus_next                = _btn_next.get_path()
	_btn_again.focus_neighbor_left       = _btn_main_menu.get_path()
	_btn_again.focus_previous            = _btn_main_menu.get_path()
	_btn_next.focus_neighbor_left        = _btn_again.get_path()
	_btn_next.focus_previous             = _btn_again.get_path()
	_btn_next.focus_neighbor_right       = _btn_main_menu.get_path()
	_btn_next.focus_next                 = _btn_main_menu.get_path()
	_btn_main_menu.focus_neighbor_left   = _btn_next.get_path()
	_btn_main_menu.focus_previous        = _btn_next.get_path()
	_btn_main_menu.focus_neighbor_right  = _btn_again.get_path()
	_btn_main_menu.focus_next            = _btn_again.get_path()


# ── UI helpers ────────────────────────────────────────────────────────────────

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

	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = C_BTN_HOVER
	focus_style.set_border_width_all(2)
	focus_style.border_color = Color(1.00, 0.90, 0.40, 1.0)
	focus_style.set_content_margin_all(8)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover",  hover)
	btn.add_theme_stylebox_override("focus",  focus_style)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)
	return btn


# ── SPA-212: Tab helpers ──────────────────────────────────────────────────────

const C_TAB_ACTIVE   := Color(0.55, 0.38, 0.18, 1.0)
const C_TAB_INACTIVE := Color(0.20, 0.14, 0.10, 1.0)


func _make_tab_button(label_text: String, active: bool) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(100, 28)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)

	var style := StyleBoxFlat.new()
	style.bg_color = C_TAB_ACTIVE if active else C_TAB_INACTIVE
	style.set_border_width_all(1)
	style.border_color = C_PANEL_BORDER
	style.set_content_margin_all(4)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = C_TAB_ACTIVE if active else Color(0.30, 0.22, 0.14, 1.0)
	hover_style.set_border_width_all(1)
	hover_style.border_color = C_PANEL_BORDER
	hover_style.set_content_margin_all(4)

	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = C_TAB_ACTIVE if active else C_TAB_INACTIVE
	focus_style.set_border_width_all(2)
	focus_style.border_color = Color(1.00, 0.90, 0.40, 1.0)
	focus_style.set_content_margin_all(4)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", focus_style)
	return btn


func _set_tab_active(btn: Button, active: bool) -> void:
	var style := btn.get_theme_stylebox("normal") as StyleBoxFlat
	if style != null:
		style.bg_color = C_TAB_ACTIVE if active else C_TAB_INACTIVE


func _show_tab_results() -> void:
	_set_tab_active(_tab_results, true)
	_set_tab_active(_tab_replay, false)
	if _results_container != null:
		_results_container.visible = true
	if _replay_container != null:
		_replay_container.visible = false
	if _tab_results != null:
		_tab_results.call_deferred("grab_focus")


func _show_tab_replay() -> void:
	_set_tab_active(_tab_results, false)
	_set_tab_active(_tab_replay, true)
	if _results_container != null:
		_results_container.visible = false
	if _replay_container != null:
		_replay_container.visible = true
	if _tab_replay != null:
		_tab_replay.call_deferred("grab_focus")


# ── Button handlers ───────────────────────────────────────────────────────────

func _on_play_again() -> void:
	var pause_menu_script = preload("res://scripts/pause_menu.gd")
	pause_menu_script._pending_restart_id = _current_scenario_id
	await TransitionManager.fade_out(0.35)
	get_tree().reload_current_scene()


func _on_next_scenario() -> void:
	var next_id := _next_scenario_id(_current_scenario_id)
	if next_id.is_empty():
		return
	var pause_menu_script = preload("res://scripts/pause_menu.gd")
	pause_menu_script._pending_restart_id = next_id
	await TransitionManager.fade_out(0.35)
	get_tree().reload_current_scene()


func _on_main_menu() -> void:
	var pause_menu_script = preload("res://scripts/pause_menu.gd")
	pause_menu_script._pending_restart_id = ""
	await TransitionManager.fade_out(0.35)
	get_tree().reload_current_scene()
