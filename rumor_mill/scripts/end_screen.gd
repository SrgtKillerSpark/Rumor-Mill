extends CanvasLayer

## end_screen.gd — SPA-138 redesign + SPA-212 analytics tab.
##
## 760x640 expanded panel with:
##   1. Win / Fail banner + scenario title
##   2. Italic summary narrative (SPA-128 copy)
##   3. Tab bar: RESULTS | REPLAY (analytics)
##   4a. Results tab (default):
##       Left  — stats_container: Days, Rumors, NPCs Reached, Peak Belief + bonus
##       Right — npc_container:  3 key NPCs with final score and arrow
##   4b. Replay tab (SPA-212):
##       Rumor timeline bar chart, top influencers, key moments log
##   5. Buttons: Play Again | Next Scenario (dimmed if not applicable) | Main Menu
##
## Procedurally built CanvasLayer (layer 30 — above all other HUDs).
## Wire via setup(world, day_night) from main.gd.
##
## Subsystem modules (SPA-1010 / SPA-1016):
##   EndScreenPanelBuilder — full UI tree construction and tab management
##   EndScreenSummary      — fail inference, narrative text, defeat one-liner
##   EndScreenScoring      — stat data, NPC outcomes, player-stat recording
##   EndScreenAnimations   — count-up tween, arrow bounce, button pulse
##   EndScreenReplayTab    — analytics replay tab content
##   EndScreenFeedback     — post-game feedback prompt modal
##   EndScreenNavigation   — scenario sequencing, Play Again/Next/Menu actions

# ── Runtime refs ──────────────────────────────────────────────────────────────
var _world_ref:     Node2D = null
var _day_night_ref: Node   = null
var _analytics_ref: ScenarioAnalytics = null

# ── State ─────────────────────────────────────────────────────────────────────
var _current_scenario_id: String = ""
var _resolving:           bool   = false
var _last_outcome_won:    bool   = false

# ── Subsystem modules ─────────────────────────────────────────────────────────
var _panel:      EndScreenPanelBuilder = null
var _summary:    EndScreenSummary      = null
var _scoring:    EndScreenScoring      = null
var _animations: EndScreenAnimations   = null
var _replay_tab: EndScreenReplayTab    = null
var _feedback:   EndScreenFeedback     = null
var _navigation: EndScreenNavigation   = null


func _ready() -> void:
	layer = 30

	_panel = EndScreenPanelBuilder.new()
	_panel.build(self)

	_summary    = EndScreenSummary.new()
	_scoring    = EndScreenScoring.new()
	_animations = EndScreenAnimations.new()
	_animations.setup(self)
	_replay_tab = EndScreenReplayTab.new()
	_navigation = EndScreenNavigation.new()
	_navigation.setup(get_tree())

	_feedback = EndScreenFeedback.new()
	_feedback.setup(self, _panel.btn_again)

	_panel.btn_again.pressed.connect(_navigation.on_play_again)
	_panel.btn_next.pressed.connect(_navigation.on_next_scenario)
	_panel.btn_main_menu.pressed.connect(_navigation.on_main_menu)

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
	_navigation.set_scenario_id(_current_scenario_id)

	_scoring.setup(_world_ref, _day_night_ref, _panel.stats_container, _panel.npc_container)
	_summary.setup(_world_ref, _day_night_ref)

	# ── Banner ────────────────────────────────────────────────────────────────
	_panel.result_banner.text = "VICTORY" if won else "DEFEAT"
	_panel.result_banner.add_theme_color_override("font_color",
		EndScreenPanelBuilder.C_WIN if won else EndScreenPanelBuilder.C_FAIL)

	# ── Scenario title ────────────────────────────────────────────────────────
	_panel.scenario_title.text = sm.get_title() if sm != null else ""

	# ── Summary narrative (SPA-128) ───────────────────────────────────────────
	var fail_reason := "" if won else _summary.infer_fail_reason(scenario_id)
	var summary := _summary.get_summary_text(scenario_id, won, fail_reason)
	if scenario_id == 2 and fail_reason == "contradicted" and sm != null:
		var carrier: String = sm.s2_maren_carrier_name
		if not carrier.is_empty():
			summary += ("\n\nThe rumor reached her through %s." % carrier)
	_panel.narrative_lbl.text = "[center][i]" + summary + "[/i][/center]"

	# ── SPA-948: Strategic defeat hint ───────────────────────────────────────
	if _panel.strategic_hint_lbl != null:
		if not won and sm != null:
			var hint := sm.get_strategic_defeat_hint(fail_reason)
			if not hint.is_empty():
				_panel.strategic_hint_lbl.text = "[center][b]NEXT TIME:[/b] " + hint + "[/center]"
				_panel.strategic_hint_lbl.visible = true
			else:
				_panel.strategic_hint_lbl.visible = false
		else:
			_panel.strategic_hint_lbl.visible = false

	# ── Stats + NPC outcomes ──────────────────────────────────────────────────
	_scoring.populate_stats(scenario_id, won)
	_scoring.record_player_stats(scenario_id, won, _current_scenario_id)
	_scoring.populate_npc_outcomes(_current_scenario_id, won)

	# ── Analytics (SPA-212) ───────────────────────────────────────────────────
	if _analytics_ref != null:
		_analytics_ref.finalize()
		_replay_tab.setup(_panel.replay_container, _analytics_ref)
		_replay_tab.populate()

	# ── Next Scenario button ──────────────────────────────────────────────────
	var next_id := EndScreenNavigation.next_scenario_id(_current_scenario_id)
	if won and not next_id.is_empty():
		_panel.btn_next.modulate = Color.WHITE
		_panel.btn_next.disabled = false
		_panel.btn_next.focus_mode = Control.FOCUS_ALL
		_animations.start_btn_pulse(_panel.btn_next)
	else:
		_panel.btn_next.modulate = Color(1.0, 1.0, 1.0, 0.35)
		_panel.btn_next.disabled = true
		_panel.btn_next.focus_mode = Control.FOCUS_NONE

	# ── SPA-899: Cross-scenario tease ────────────────────────────────────────
	if _panel.tease_lbl != null:
		if won and not next_id.is_empty():
			var tease_text: String = EndScreenNavigation.load_next_scenario_tease(next_id)
			if not tease_text.is_empty():
				_panel.tease_lbl.text = "[center][color=#c8a84e]\u25b8 " + tease_text + "[/color][/center]"
				_panel.tease_lbl.visible = true
			else:
				_panel.tease_lbl.visible = false
		else:
			_panel.tease_lbl.visible = false

	# ── SPA-784: "What went wrong" one-liner for defeat ──────────────────────
	if not won:
		_panel.show_what_went_wrong(_summary.get_what_went_wrong(fail_reason))

	_panel.show_tab_results()

	visible = true

	# ── Entrance animation ────────────────────────────────────────────────────
	if _panel.backdrop != null:
		_panel.backdrop.modulate.a = 0.0
	if _panel.panel != null:
		_panel.panel.modulate.a = 0.0
		_panel.panel.scale = Vector2(0.92, 0.92)
		_panel.panel.pivot_offset = Vector2(
			EndScreenPanelBuilder.PANEL_W / 2.0,
			EndScreenPanelBuilder.PANEL_H / 2.0)
	TransitionManager.fade_in(0.35)
	var _enter_tw := create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _panel.backdrop != null:
		_enter_tw.tween_property(_panel.backdrop, "modulate:a", 1.0, 0.35)
	if _panel.panel != null:
		_enter_tw.tween_property(_panel.panel, "modulate:a", 1.0, 0.4)
		_enter_tw.tween_property(_panel.panel, "scale", Vector2.ONE, 0.4)

	# SPA-784 / SPA-947: Defeat makes Try Again prominent.
	if not won and _panel.btn_again != null:
		_panel.btn_again.text = "Try Again"
		_panel.btn_again.add_theme_font_size_override("font_size", 18)
		_panel.btn_again.custom_minimum_size = Vector2(180, 48)
		_panel.btn_again.call_deferred("grab_focus")
	elif _panel.btn_again != null:
		_panel.btn_again.text = "Play Again"
		_panel.btn_again.call_deferred("grab_focus")

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
