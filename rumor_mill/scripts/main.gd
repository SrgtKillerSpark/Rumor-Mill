extends Node2D

## main.gd — Sprint 9 entry point.
## Wires DayNightCycle tick → World, debug tools, recon system, Player Journal,
## Social Graph Overlay, Scenario 3 HUD, Sprint 7 Tutorial Tooltip system,
## Sprint 6 End Screen overlay, Sprint 7 AudioManager, Sprint 8 Main Menu,
## and Sprint 9 Scenario Intro Cards + Loading Tips.
## Sprint 10: Scenario 1 uses the non-blocking TutorialBanner (SPA-131).
##
## Flow: MainMenu → Select → Briefing → Intro Card → loading tip (1.5 s) →
##       world unpaused, active scenario applied, all systems initialised.

@onready var world:                Node2D      = $World
@onready var day_night:            Node        = $World/DayNightCycle
@onready var camera:               Camera2D    = $Camera2D
@onready var debug_overlay:        CanvasLayer = $DebugOverlay
@onready var debug_console:        CanvasLayer = $DebugConsole
@onready var recon_hud:            CanvasLayer = $ReconHUD
@onready var rumor_panel:          CanvasLayer = $RumorPanel
@onready var journal:              CanvasLayer = $Journal
@onready var social_graph_overlay: CanvasLayer = $SocialGraphOverlay
@onready var objective_hud:        CanvasLayer = $ObjectiveHUD

# ── Sprint 8: main menu ───────────────────────────────────────────────────────
var _main_menu:    CanvasLayer = null
var _pause_menu:   CanvasLayer = null

# ── Sprint 9: loading tips (shown during game-start transition) ───────────────
var _loading_tips: CanvasLayer = null

# ── Sprint 7: tutorial system (created programmatically) ──────────────────────
var _tutorial_sys: TutorialSystem = null
var _tutorial_hud: CanvasLayer    = null   # S2/S3: blocking modal tooltips

# ── Sprint 10: Scenario 1 non-blocking banner (SPA-131) ───────────────────────
var _tutorial_banner: CanvasLayer = null   # S1 only

# ── Sprint 6: end screen (created programmatically) ───────────────────────────
var _end_screen: CanvasLayer = null

# ── SPA-784: Victory/defeat feedback sequence ────────────────────────────────
var _feedback_seq: CanvasLayer = null

# ── SPA-841: Consolidated Mission Briefing screen (game-start + recall) ──────
var _mission_briefing: CanvasLayer = null

# ── SPA-541: Persistent controls reference overlay ───────────────────────────
var _controls_ref: CanvasLayer = null

# ── SPA-560: Mid-game narrative event choice modal ───────────────────────────
var _event_choice_modal: CanvasLayer = null

# ── SPA-589: Visual affordances for new players ──────────────────────────────
var _visual_affordances: CanvasLayer = null

# ── SPA-806: Thought bubble legend overlay ──────────────────────────────────
var _thought_legend: CanvasLayer = null

# ── SPA-768: Interactive tutorial controller (step-gated S1 tutorial) ────────
var _tutorial_ctrl: TutorialController = null

# ── SPA-758: Onboarding waypoint marker (3-step guided sequence) ─────────────
var _waypoint_node:  Node2D = null   # world-space marker (pulsing diamond + label)
var _waypoint_tween: Tween  = null
var _waypoint_step:  int    = 0      # 0=inactive, 1=market, 2=eavesdrop pair, 3=R key

# ── SPA-709: Milestone reward notification popup ──────────────────────────────
var _milestone_notifier: CanvasLayer = null

# ── SPA-805: S1 manor golden-pulse highlight (day 1–2 building affordance) ────
var _s1_manor_highlight: Polygon2D = null

# ── SPA-769: HUD tooltip overlay and context controls panel ──────────────────
var _hud_tooltip: CanvasLayer = null
var _context_controls: CanvasLayer = null

# ── SPA-589: Story recap overlay (shown on save load) ─────────────────────────
var _story_recap: CanvasLayer = null

# ── SPA-708: Daily planning overlay (dawn priorities) ─────────────────────────
var _daily_planning: CanvasLayer = null

# ── SPA-212: Analytics data collector ─────────────────────────────────────────
var _analytics: ScenarioAnalytics = null

# ── SPA-244: Local player behaviour event log ──────────────────────────────────
var _analytics_logger: AnalyticsLogger = null
var _analytics_scenario_id: String = ""        # cached scenario id for per-event handlers
var _analytics_rep_snapshot: Dictionary = {}   # npc_id → int score, for delta tracking


# Prevent duplicate tooltip triggers for observe / eavesdrop / npc_state_change.
var _observe_tooltip_fired:          bool = false
var _eavesdrop_tooltip_fired:        bool = false
var _npc_state_change_tooltip_fired: bool = false
var _evidence_tooltip_fired:         bool = false

# Cached ReconController reference for post-tutorial-init wiring.
var _recon_ctrl_ref: Node = null

# ── SPA-629: Rumor Panel first-time tooltip walkthrough ──────────────────────
var _rumor_panel_tooltip: CanvasLayer = null
var _rumor_panel_tooltip_wired: bool  = false  # guard: only trigger once per session

# ── SPA-724: Onboarding action counter for goal strip fade ──────────────────
var _spa724_action_count: int = 0

# ── Sprint 10: S1 banner hint gates ───────────────────────────────────────────
var _banner_camera_gate:       bool = false  # set true after camera_moved fires
var _banner_observe_gate:      bool = false  # set true after first successful Observe
var _banner_eavesdrop_gate:    bool = false  # set true after first successful Eavesdrop
var _banner_seed_fired:        bool = false  # guard for hint_propagation 5 s delay
var _banner_hint06_fired:      bool = false  # guard: rumour panel nudge at tick 24
var _banner_believe_fired:     bool = false  # guard for hint_objectives
var _banner_journal_hint_fired: bool = false  # guard: journal hint shown (observe or eavesdrop)
var _banner_social_graph_fired: bool = false  # guard: social graph hint shown
var _banner_s1_market_cleared: bool = false  # SPA-626: true after first recon clears Market highlight
# Cross-scenario contextual hint gates (S2/S3/S4).
var _ctx_spread_fired:   bool = false
var _ctx_act_fired:      bool = false
var _ctx_reject_fired:   bool = false
var _ctx_tokens_fired:   bool = false
var _ctx_heat_warn_fired: bool = false  # SPA-608: heat warning hint (S1 only)

# ── SPA-788: First-time reward moment guards ──────────────────────────────────
var _reward_first_spread_fired: bool = false
var _reward_first_belief_fired: bool = false
var _ctx_halfway_fired:  bool = false
var _banner_eavesdrop_count:    int  = 0      # counts eavesdrop actions for social graph trigger

# ── SPA-487: Idle-detection hint system ───────────────────────────────────────
var _idle_timer: Timer = null
var _idle_hint_fired_no_action:  bool = false  # first idle nudge
var _idle_hint_fired_no_rumor:   bool = false  # nudge to craft a rumor
var _has_performed_any_action:   bool = false  # true after first recon action
var _has_crafted_any_rumor:      bool = false  # true after first rumor seeded

# Guards against double-initialisation if begin_game fires more than once.
var _game_started: bool = false

# ── SPA-518: Help hotkey reminder label ──────────────────────────────────────
var _help_reminder: Label = null

# ── SPA-272: Per-session achievement tracking ─────────────────────────────────
var _ach_exposed:       bool = false   # true if player_exposed fired this game
var _ach_actions_used:  Dictionary = {}  # action key → true (observe/eavesdrop/craft/bribe)


func _ready() -> void:
	# ── Pause world until the player has chosen a scenario ────────────────────
	world.set_process(false)
	world.set_physics_process(false)
	world.set_process_input(false)
	world.visible = false

	# Keep HUD layers hidden until game starts.
	recon_hud.visible            = false
	rumor_panel.visible          = false
	journal.visible              = false
	social_graph_overlay.visible = false
	objective_hud.visible        = false

	# ── Sprint 9: loading tips overlay (hidden until begin_game fires) ────────
	_loading_tips = preload("res://scripts/loading_tips.gd").new()
	_loading_tips.name = "LoadingTips"
	add_child(_loading_tips)

	# ── Sprint 8: show main menu (or auto-restart a scenario) ────────────────
	var _pause_menu_script = preload("res://scripts/pause_menu.gd")
	var _restart_id: String = _pause_menu_script._pending_restart_id
	if _restart_id != "":
		# SPA-335: record the retry before clearing the pending id.
		PlayerStats.record_retry(_restart_id, GameState.selected_difficulty)
		_pause_menu_script._pending_restart_id = ""
		_on_begin_game.call_deferred(_restart_id)
		return

	_main_menu = preload("res://scripts/main_menu.gd").new()
	_main_menu.name = "MainMenu"
	add_child(_main_menu)
	_main_menu.begin_game.connect(_on_begin_game)


## SPA-767: Update context controls panel mode based on which panels are open.
func _process(_delta: float) -> void:
	if _context_controls == null or not _game_started:
		return
	var mode: int = 0  # EXPLORE
	if rumor_panel.visible:
		mode = 1  # RUMOR_PANEL
	elif journal.visible:
		mode = 2  # JOURNAL
	elif social_graph_overlay.visible:
		mode = 3  # SOCIAL_GRAPH
	elif day_night != null and day_night.has_method("is_paused") and day_night.is_paused():
		mode = 4  # PAUSED
	_context_controls.set_mode(mode)


## SPA-518: H hotkey replays the most recent tutorial hint banner.
func _unhandled_input(event: InputEvent) -> void:
	if not _game_started:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			if _tutorial_banner != null and _tutorial_banner.has_method("replay_hint"):
				_tutorial_banner.replay_hint()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_O:
			_show_objective_recall()
			get_viewport().set_input_as_handled()


## Called when the player clicks Begin on the scenario intro screen.
## Uses await so the loading tips screen renders for at least 1.5 s
## (well above the 0.5 s threshold) while the world initialises.
func _on_begin_game(scenario_id: String) -> void:
	if _game_started:
		return
	_game_started = true

	# SPA-561: Smooth fade-out before leaving the main menu.
	await TransitionManager.fade_out(0.35)

	# Hide / free the menu overlay.
	if _main_menu != null:
		_main_menu.queue_free()
		_main_menu = null

	# Show a loading tip. Await so the tip is actually visible on screen
	# before the synchronous world init runs (~1.5 s > MIN_DURATION_SEC).
	if _loading_tips != null:
		_loading_tips.start_transition()
	# SPA-561: Fade back in so the loading tip is visible.
	await TransitionManager.fade_in(0.35)
	await get_tree().create_timer(1.5).timeout

	# Apply the chosen scenario's edge/personality/reputation overrides.
	world.active_scenario_id = scenario_id
	world._apply_active_scenario()

	# Re-enable world processing and make it visible.
	world.set_process(true)
	world.set_physics_process(true)
	world.set_process_input(true)
	world.visible = true

	# Restore HUD visibility.
	recon_hud.visible            = true
	objective_hud.visible        = true
	if objective_hud.has_method("play_entrance_animation"):
		objective_hud.play_entrance_animation()
	rumor_panel.visible          = false  # closed by default; opened via R key
	journal.visible              = false  # closed by default; opened via J key
	social_graph_overlay.visible = false  # closed by default; opened via G key

	# ── Wire game systems ─────────────────────────────────────────────────────
	# Drive NPC ticks from the day/night cycle.
	day_night.game_tick.connect(world.on_game_tick)
	# SPA-786: Pass total days to day/night cycle for dawn banner display.
	if world.scenario_manager != null:
		day_night.days_allowed = world.scenario_manager.get_days_allowed()

	if debug_overlay != null and debug_overlay.has_method("set_world"):
		debug_overlay.set_world(world)

	if social_graph_overlay != null and social_graph_overlay.has_method("set_world"):
		social_graph_overlay.set_world(world)

	if debug_console != null:
		if debug_console.has_method("set_world"):
			debug_console.set_world(world)
		if debug_console.has_method("set_overlay"):
			debug_console.set_overlay(debug_overlay)

	_init_recon_system()
	# SPA-695: Give TownMoodController the camera so it can shake on milestones.
	if world.town_mood_controller != null and camera != null:
		world.town_mood_controller.set_camera(camera)
	_init_journal()
	# SPA-709: Milestone notifier — must be created after journal is ready.
	_milestone_notifier = preload("res://scripts/milestone_notifier.gd").new()
	_milestone_notifier.name = "MilestoneNotifier"
	add_child(_milestone_notifier)
	if _milestone_notifier.has_method("setup"):
		_milestone_notifier.setup(journal, world.intel_store, objective_hud)
	# Wire milestone tracker callback to the new notifier.
	if world.milestone_tracker != null and _milestone_notifier != null:
		var _sid: int = int(scenario_id.trim_prefix("scenario_"))
		world.milestone_tracker.setup(
			_sid,
			world.reputation_system,
			world.scenario_manager,
			world.intel_store,
			_milestone_notifier.show_milestone
		)
	_wire_rumor_events()
	_init_event_choice_modal()
	_init_objective_hud()
	_init_daily_planning()
	_init_speed_hud()
	_init_zone_indicator()
	_init_npc_conversation_overlay()
	_init_scenario1_hud()
	_init_scenario2_hud()
	_init_scenario3_hud()
	_init_scenario4_hud()
	_init_scenario5_hud()
	_init_scenario6_hud()
	_init_tutorial_system()
	_init_end_screen()
	_init_audio()
	_init_analytics_logger(scenario_id)
	_init_achievement_hooks()
	_init_pause_menu()
	_init_npc_tooltip()
	_init_hud_tooltip()
	_init_context_controls_panel()
	_init_visual_affordances()
	day_night.day_changed.connect(_on_new_day_auto_save)
	PlayerStats.start_session()  # SPA-273: begin timing this play session

	# SPA-335: feed retry count into ScenarioManager so it knows how many times
	# this scenario has been attempted before.
	var _sm_ref: ScenarioManager = world.scenario_manager
	if _sm_ref != null:
		_sm_ref.retry_count = PlayerStats.get_scenario_stats(
			scenario_id, GameState.selected_difficulty).get("retries", 0)

	# SPA-561: Fade out before dismissing loading tips, then fade into gameplay.
	await TransitionManager.fade_out(0.3)
	# Loading complete — dismiss the tip screen.
	if _loading_tips != null:
		_loading_tips.end_transition()
	await TransitionManager.fade_in(0.4)

	# Restore saved state if a load was triggered from the pause menu.
	var _was_save_load := SaveManager.has_pending_load()
	if _was_save_load:
		SaveManager.apply_pending_load(world, day_night, journal, _tutorial_sys)

	# SPA-589: Show "Story So Far" recap after loading a saved game.
	if _was_save_load and world.scenario_manager != null:
		day_night.set_paused(true)
		var speed_node := get_node_or_null("SpeedHUD")
		if speed_node != null and speed_node.has_method("_set_speed"):
			speed_node._set_speed(speed_node.Speed.PAUSE)
		_story_recap = preload("res://scripts/story_recap.gd").new()
		_story_recap.name = "StoryRecap"
		add_child(_story_recap)
		_story_recap.setup(world.scenario_manager, day_night, world)
		_story_recap.dismissed.connect(_on_story_recap_dismissed)

	# SPA-519: Pause Day 1 on fresh game start so the player can orient.
	# Skip if this is a save-load (player already knows the game).
	if not _was_save_load and day_night.current_day == 1:
		day_night.set_paused(true)
		# Sync speed HUD to show paused state.
		var speed_node := get_node_or_null("SpeedHUD")
		if speed_node != null and speed_node.has_method("_set_speed"):
			speed_node._set_speed(speed_node.Speed.PAUSE)
		# SPA-841: Show single Mission Briefing screen.
		_show_mission_briefing()


## SPA-841: Show the consolidated Mission Briefing screen.
## Merges Strategic Overview + ReadyOverlay + MissionCard into one screen.
func _show_mission_briefing() -> void:
	var sm: ScenarioManager = world.scenario_manager if world != null else null
	if sm == null:
		_on_mission_briefing_dismissed()
		return

	var brief: Dictionary = sm.get_strategic_brief()
	var objective_card: Dictionary = sm.get_objective_card()

	# Find the target NPC's raw data dict from the spawned NPC list.
	var target_id: String = brief.get("targetNpcId", "")
	var npc_data: Dictionary = {}
	if target_id != "" and world != null:
		for npc in world.npcs:
			if npc.npc_data.get("id", "") == target_id:
				npc_data = npc.npc_data
				break

	_mission_briefing = preload("res://scripts/mission_briefing.gd").new()
	_mission_briefing.name = "MissionBriefing"
	add_child(_mission_briefing)
	_mission_briefing.setup(
		sm.get_objective_one_liner(),
		sm.get_win_condition_line(),
		objective_card,
		brief,
		npc_data
	)
	_mission_briefing.dismissed.connect(_on_mission_briefing_dismissed)


func _on_mission_briefing_dismissed() -> void:
	_mission_briefing = null
	# Resume normal speed via SpeedHUD so button state stays in sync.
	var speed_node := get_node_or_null("SpeedHUD")
	if speed_node != null and speed_node.has_method("_set_speed"):
		speed_node._set_speed(speed_node.Speed.NORMAL)
	else:
		day_night.set_paused(false)
	# SPA-627: Flash a one-time hint so the player knows O recalls this overlay.
	if objective_hud != null and objective_hud.has_method("show_o_hotkey_hint"):
		objective_hud.show_o_hotkey_hint()

	# SPA-720: Mark the primary target NPC with a crest icon for the first 60 seconds.
	var _sm_brief: ScenarioManager = world.scenario_manager if world != null else null
	if _sm_brief != null:
		var brief: Dictionary = _sm_brief.get_strategic_brief()
		var target_id: String = brief.get("targetNpcId", "")
		if target_id != "":
			_start_target_npc_marker(target_id)

	# SPA-724: Auto-show contextual "What next" hint on game start so players
	# aren't left guessing what to do in the first 60 seconds.
	if recon_hud != null and recon_hud.has_method("auto_show_initial_hint"):
		recon_hud.auto_show_initial_hint()
	# SPA-724: Show compact goal reminder strip below the ReconHUD.
	if recon_hud != null and recon_hud.has_method("build_goal_strip"):
		var _sm2: ScenarioManager = world.scenario_manager
		if _sm2 != null:
			var card: Dictionary = _sm2.get_objective_card()
			var goal_text: String = card.get("mission", "")
			if goal_text != "":
				recon_hud.build_goal_strip("GOAL: " + goal_text)

	# SPA-626: S1 first-time player flow — camera pan + Market highlight + gated banner.
	if world.active_scenario_id == "scenario_1":
		_init_s1_onboarding_flow()
	else:
		# SPA-804: S2-S6 — short "What's New" TutorialController sequence.
		_init_sx_onboarding_flow(world.active_scenario_id)


## SPA-720: Attach a subtle amber crest marker above the primary target NPC for 60 seconds.
## Parented to the NPC node so it tracks position automatically.
func _start_target_npc_marker(npc_id: String) -> void:
	if world == null:
		return
	var target_npc: Node2D = null
	for npc in world.npcs:
		if npc.npc_data.get("id", "") == npc_id:
			target_npc = npc
			break
	if target_npc == null:
		return
	# Diamond crest polygon rendered above the NPC sprite.
	var crest := Polygon2D.new()
	crest.name = "TargetCrestMarker"
	crest.polygon = PackedVector2Array([
		Vector2(0.0,  -12.0),
		Vector2(9.0,   0.0),
		Vector2(0.0,   12.0),
		Vector2(-9.0,  0.0),
	])
	crest.color    = Color(0.957, 0.651, 0.227, 0.85)   # amber
	crest.position = Vector2(0.0, -72.0)                  # above the 96 px sprite
	crest.z_index  = 10
	target_npc.add_child(crest)
	# Slow pulse so the marker is visible but not distracting.
	var tw := target_npc.create_tween().set_loops()
	tw.tween_property(crest, "modulate:a", 0.3, 1.1) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(crest, "modulate:a", 1.0, 1.1) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# Auto-remove after 60 seconds.
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		if tw != null and tw.is_valid():
			tw.kill()
		if is_instance_valid(crest):
			crest.queue_free()
	)


## SPA-626: Camera auto-pan to Market, single-target highlight, and persistent gated banner.
## Called from _on_mission_briefing_dismissed() when scenario_1 is active.
func _init_s1_onboarding_flow() -> void:
	# Resolve Market building world-space position via the building entry cell.
	var market_cell: Vector2i = world._building_entries.get("market", Vector2i(12, 30))
	var market_world_pos: Vector2 = Vector2.ZERO
	if _recon_ctrl_ref != null and _recon_ctrl_ref.has_method("_cell_to_world"):
		market_world_pos = _recon_ctrl_ref._cell_to_world(market_cell)

	# 1. Camera auto-pan to Market over 2 s.
	if camera.has_method("pan_to_target"):
		camera.pan_to_target(market_world_pos, 2.0)

	# 2. Single-target pulse-glow on Market building.
	if _visual_affordances != null and _visual_affordances.has_method("highlight_single_target"):
		_visual_affordances.highlight_single_target(market_world_pos)

	# SPA-805: Second highlight on the Manor (Edric's building) — subtle gold pulse for 2 days.
	_init_s1_manor_highlight()

	# 3. Persistent gated banner — stays until first Recon Action.
	if _tutorial_banner != null:
		_tutorial_banner.queue_hint("hint_s1_investigate_gate")

	# 4. SPA-758: Waypoint marker on Market — step 1 of 3-step guided sequence.
	_show_waypoint_step1_market(market_world_pos)

	# 5. SPA-768: Interactive tutorial controller — step-gated progression.
	_tutorial_ctrl = preload("res://scripts/tutorial_controller.gd").new()
	_tutorial_ctrl.name = "TutorialController"
	add_child(_tutorial_ctrl)
	_tutorial_ctrl.setup(
		_tutorial_sys, _tutorial_banner, camera,
		_recon_ctrl_ref, journal, rumor_panel, world
	)
	_tutorial_ctrl.start()


## SPA-804: S2-S6 "What's New" banner sequence via TutorialController.
## Called from _on_mission_briefing_dismissed() for non-S1 scenarios.
func _init_sx_onboarding_flow(scenario_id: String) -> void:
	if _tutorial_sys == null or _tutorial_banner == null:
		return
	_tutorial_ctrl = preload("res://scripts/tutorial_controller.gd").new()
	_tutorial_ctrl.name = "TutorialController"
	add_child(_tutorial_ctrl)
	_tutorial_ctrl.setup(
		_tutorial_sys, _tutorial_banner, camera,
		_recon_ctrl_ref, journal, rumor_panel, world,
		scenario_id
	)
	_tutorial_ctrl.start()


# ── SPA-805: S1 manor golden-pulse affordance (Edric's building, days 1–2) ────

## Create a soft golden diamond highlight on the Manor building for days 1–2 of S1.
## Cleared automatically on day 3 or when the scenario resolves.
func _init_s1_manor_highlight() -> void:
	if world == null or _recon_ctrl_ref == null:
		return
	var manor_cell: Vector2i = world._building_entries.get("manor", Vector2i(8, 14))
	var manor_pos := Vector2.ZERO
	if _recon_ctrl_ref.has_method("_cell_to_world"):
		manor_pos = _recon_ctrl_ref._cell_to_world(manor_cell)
	if manor_pos == Vector2.ZERO:
		return
	# Build a slightly smaller diamond than the Market highlight, in a distinct gold.
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([
		Vector2(0.0,  -22.0),
		Vector2(34.0,   0.0),
		Vector2(0.0,   22.0),
		Vector2(-34.0,  0.0),
	])
	poly.color    = Color(1.00, 0.80, 0.12, 0.22)  # warm gold, softer than Market highlight
	poly.name     = "S1ManorHighlight"
	poly.position = manor_pos
	poly.z_index  = 1
	world.add_child(poly)
	_s1_manor_highlight = poly
	# Slow sine-wave pulse via looping tween.
	var pulse_tw := poly.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tw.tween_property(poly, "modulate:a", 0.35, 1.2)
	pulse_tw.tween_property(poly, "modulate:a", 1.0,  1.2)
	# Auto-clear on day 3.
	if day_night != null and day_night.has_signal("day_changed"):
		var _clear_manor := func(day: int) -> void:
			if day >= 3:
				_clear_s1_manor_highlight()
		day_night.day_changed.connect(_clear_manor)


## Pulse the manor highlight each frame (called via a simple _process override is not
## available on main.gd, so we reuse the existing game_tick signal instead).
func _clear_s1_manor_highlight() -> void:
	if _s1_manor_highlight != null and is_instance_valid(_s1_manor_highlight):
		var tw := create_tween()
		tw.tween_property(_s1_manor_highlight, "modulate:a", 0.0, 0.8)
		tw.tween_callback(_s1_manor_highlight.queue_free)
	_s1_manor_highlight = null


# ── SPA-758: Onboarding waypoint marker system ──────────────────────────────

## Step 1: Pulsing marker on Market building — "Start here — Observe who's inside"
func _show_waypoint_step1_market(market_pos: Vector2) -> void:
	_clear_waypoint()
	_waypoint_step = 1
	_waypoint_node = _create_waypoint_marker(
		market_pos + Vector2(0.0, -48.0),
		"▼  Start here — Observe who's inside"
	)
	if world != null:
		world.add_child(_waypoint_node)


## Step 2: Move marker to two NPCs in conversation — "Eavesdrop on their relationship"
func _show_waypoint_step2_eavesdrop() -> void:
	_clear_waypoint()
	_waypoint_step = 2
	# Find two NPCs that are close enough for eavesdrop (within 3 tiles).
	var best_pair_pos: Vector2 = Vector2.ZERO
	var found: bool = false
	if world != null:
		for i in range(world.npcs.size()):
			if found:
				break
			for j in range(i + 1, world.npcs.size()):
				var npc_a: Node2D = world.npcs[i]
				var npc_b: Node2D = world.npcs[j]
				var dist: int = abs(npc_a.current_cell.x - npc_b.current_cell.x) \
				              + abs(npc_a.current_cell.y - npc_b.current_cell.y)
				if dist <= 3:
					best_pair_pos = (npc_a.position + npc_b.position) * 0.5
					found = true
					break
	if not found:
		# Fallback: use position of first NPC.
		if world != null and world.npcs.size() > 0:
			best_pair_pos = world.npcs[0].position
	_waypoint_node = _create_waypoint_marker(
		best_pair_pos + Vector2(0.0, -56.0),
		"▼  Eavesdrop on their relationship"
	)
	if world != null:
		world.add_child(_waypoint_node)


## Step 3: Flash R key prompt (screen-space, not world-space).
func _show_waypoint_step3_craft() -> void:
	_clear_waypoint()
	_waypoint_step = 3
	# Create a screen-space prompt via a CanvasLayer label.
	var cl := CanvasLayer.new()
	cl.name = "WaypointCraftPrompt"
	cl.layer = 18
	add_child(cl)
	var lbl := Label.new()
	lbl.text = "Press  R  to craft your first rumor"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.957, 0.651, 0.227, 1.0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	lbl.anchor_left   = 0.5
	lbl.anchor_right  = 0.5
	lbl.anchor_top    = 0.7
	lbl.anchor_bottom = 0.7
	lbl.offset_left   = -200
	lbl.offset_right  = 200
	lbl.offset_top    = -20
	lbl.offset_bottom = 20
	cl.add_child(lbl)
	# Pulse the label.
	_waypoint_tween = cl.create_tween().set_loops()
	_waypoint_tween.tween_property(lbl, "modulate:a", 0.3, 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_waypoint_tween.tween_property(lbl, "modulate:a", 1.0, 0.8) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# Auto-remove after 30 seconds.
	get_tree().create_timer(30.0).timeout.connect(func() -> void:
		if _waypoint_step == 3:
			_clear_waypoint()
			_waypoint_step = 0
	)


## Advance waypoint on action.  Called from _on_recon_action_for_tutorial.
func _advance_waypoint(action: String) -> void:
	if _waypoint_step == 1 and action == "observe":
		_show_waypoint_step2_eavesdrop()
	elif _waypoint_step == 2 and action == "eavesdrop":
		_show_waypoint_step3_craft()


## Clear the current waypoint marker.
func _clear_waypoint() -> void:
	if _waypoint_tween != null and _waypoint_tween.is_valid():
		_waypoint_tween.kill()
	_waypoint_tween = null
	if _waypoint_node != null and is_instance_valid(_waypoint_node):
		_waypoint_node.queue_free()
		_waypoint_node = null
	# Step 3 uses a CanvasLayer child instead of _waypoint_node.
	var craft_prompt := get_node_or_null("WaypointCraftPrompt")
	if craft_prompt != null:
		craft_prompt.queue_free()


## Build a world-space pulsing waypoint marker (diamond + label).
func _create_waypoint_marker(pos: Vector2, text: String) -> Node2D:
	var root := Node2D.new()
	root.name = "WaypointMarker"
	root.position = pos
	root.z_index = 12

	# Diamond shape.
	var diamond := Polygon2D.new()
	diamond.polygon = PackedVector2Array([
		Vector2(0.0,  -10.0),
		Vector2(7.0,   0.0),
		Vector2(0.0,   10.0),
		Vector2(-7.0,  0.0),
	])
	diamond.color = Color(0.957, 0.651, 0.227, 0.90)
	root.add_child(diamond)

	# Text label offset to the right.
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.96, 0.84, 0.40, 1.0))
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	lbl.position = Vector2(12, -10)
	root.add_child(lbl)

	# Pulse tween.
	_waypoint_tween = root.create_tween().set_loops()
	_waypoint_tween.tween_property(root, "modulate:a", 0.35, 1.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_waypoint_tween.tween_property(root, "modulate:a", 1.0, 1.0) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	return root


## SPA-841: Show the Mission Briefing mid-game in recall mode. Blocked during active dialogs.
func _show_objective_recall() -> void:
	if _mission_briefing != null:
		return
	if _event_choice_modal != null and _event_choice_modal.visible:
		return
	var sm: ScenarioManager = world.scenario_manager if world != null else null
	if sm == null:
		return
	var speed_node := get_node_or_null("SpeedHUD")
	if speed_node != null and speed_node.has_method("_set_speed"):
		speed_node._set_speed(speed_node.Speed.PAUSE)
	else:
		day_night.set_paused(true)

	var brief: Dictionary = sm.get_strategic_brief()
	var target_id: String = brief.get("targetNpcId", "")
	var npc_data: Dictionary = {}
	if target_id != "" and world != null:
		for npc in world.npcs:
			if npc.npc_data.get("id", "") == target_id:
				npc_data = npc.npc_data
				break

	_mission_briefing = preload("res://scripts/mission_briefing.gd").new()
	_mission_briefing.name = "MissionBriefingRecall"
	add_child(_mission_briefing)
	_mission_briefing.setup_recall(
		sm.get_objective_one_liner(),
		sm.get_win_condition_line(),
		sm.get_objective_card(),
		brief,
		npc_data
	)
	_mission_briefing.dismissed.connect(_on_recall_briefing_dismissed)


## SPA-841: Dismiss callback for player-triggered recall briefing.
func _on_recall_briefing_dismissed() -> void:
	_mission_briefing = null
	var speed_node := get_node_or_null("SpeedHUD")
	if speed_node != null and speed_node.has_method("_set_speed"):
		speed_node._set_speed(speed_node.Speed.NORMAL)
	else:
		day_night.set_paused(false)


## SPA-589: Resume gameplay after story recap is dismissed.
func _on_story_recap_dismissed() -> void:
	_story_recap = null
	var speed_node := get_node_or_null("SpeedHUD")
	if speed_node != null and speed_node.has_method("_set_speed"):
		speed_node._set_speed(speed_node.Speed.NORMAL)
	else:
		day_night.set_paused(false)


## SPA-589: Visual affordances — NPC/building interactable highlights for new players.
func _init_visual_affordances() -> void:
	_visual_affordances = preload("res://scripts/visual_affordances.gd").new()
	_visual_affordances.name = "VisualAffordances"
	add_child(_visual_affordances)
	_visual_affordances.setup(world, day_night)


func _init_recon_system() -> void:
	var intel_store: PlayerIntelStore = world.intel_store
	if intel_store == null:
		push_error("Main: world.intel_store is null — recon system not wired")
		return

	# ReconHUD: shows action counter + toasts; opens RumorPanel on R.
	if recon_hud != null and recon_hud.has_method("setup"):
		recon_hud.setup(intel_store, rumor_panel)
	if recon_hud != null and recon_hud.has_method("setup_hints"):
		recon_hud.setup_hints(world)
	if recon_hud != null and recon_hud.has_method("setup_feed"):
		recon_hud.setup_feed(journal, day_night)

	# RumorPanel: 3-panel crafting modal (Subject → Claim → Seed Target).
	if rumor_panel != null and rumor_panel.has_method("setup"):
		rumor_panel.setup(world, intel_store)
	# Log each successfully seeded rumor to the journal timeline.
	if rumor_panel != null and journal != null:
		rumor_panel.rumor_seeded.connect(_on_rumor_seeded)
	# SPA-708: Track rumor seeding for daily planning priority counters.
	if rumor_panel != null:
		rumor_panel.rumor_seeded.connect(_on_rumor_seeded_for_planning)
	# Evidence tutorial — fires once when compatible evidence items first appear.
	if rumor_panel != null:
		rumor_panel.evidence_first_shown.connect(_on_evidence_first_shown)

	# ReconController: input handler — created programmatically so it sits in
	# the scene tree and receives _unhandled_input events.
	var recon_ctrl: Node = preload("res://scripts/recon_controller.gd").new()
	recon_ctrl.name = "ReconController"
	add_child(recon_ctrl)
	recon_ctrl.setup(world, intel_store)

	# Building interior panels: shown when the player successfully observes
	# the corresponding building (tavern / manor / chapel).
	var _interior_scenes := {
		"tavern": "res://scenes/TavernInterior.tscn",
		"manor":  "res://scenes/ManorInterior.tscn",
		"chapel": "res://scenes/ChapelInterior.tscn",
	}
	var _interiors := {}
	for loc_id in _interior_scenes:
		var interior: CanvasLayer = load(_interior_scenes[loc_id]).instantiate()
		interior.name = loc_id.capitalize() + "Interior"
		add_child(interior)
		_interiors[loc_id] = interior
		# Location ambient: crossfade when interior opens/closes (SPA-491).
		var _loc: String = loc_id  # capture loop variable for closure
		interior.interior_opened.connect(func() -> void: AudioManager.set_location_ambient(_loc))
		interior.interior_closed.connect(AudioManager.clear_location_ambient)
	recon_ctrl.set_interiors(_interiors)

	# SPA-683: NPC conversation dialogue panel — created programmatically so it
	# sits above the hover tooltip layer but below the RumorPanel.
	var npc_dialogue_panel: Node = preload("res://scripts/npc_dialogue_panel.gd").new()
	npc_dialogue_panel.name = "NpcDialoguePanel"
	add_child(npc_dialogue_panel)
	npc_dialogue_panel.setup(world, intel_store, rumor_panel)
	recon_ctrl.set_dialogue_panel(npc_dialogue_panel)
	# "Seed Rumor" in the dialogue panel opens the rumor crafting panel (if not
	# already open). The inner Panel node named "Panel" tracks open/close state.
	npc_dialogue_panel.seed_rumor_requested.connect(
		func() -> void:
			if rumor_panel == null or not rumor_panel.has_method("toggle"):
				return
			var inner: Node = rumor_panel.get_node_or_null("Panel")
			if inner == null or not inner.visible:
				rumor_panel.toggle()
	)

	# Pipe action results to the HUD toast and recent-actions feed.
	if recon_hud != null and recon_hud.has_method("show_toast"):
		recon_ctrl.action_performed.connect(recon_hud.show_toast)
	if recon_hud != null and recon_hud.has_method("push_feed_entry"):
		recon_ctrl.action_performed.connect(recon_hud.push_feed_entry)

	# Pipe action results to the tutorial system (observe / eavesdrop tooltips).
	recon_ctrl.action_performed.connect(_on_recon_action_for_tutorial)

	# Cache ref so _wire_s1_recon_hints can run after _init_tutorial_system().
	_recon_ctrl_ref = recon_ctrl

	# Pipe action results to AudioManager (recon SFX).
	recon_ctrl.action_performed.connect(AudioManager.on_recon_action)

	# SPA-708: Pipe action results to daily planning priority counters.
	recon_ctrl.action_performed.connect(_on_recon_action_for_planning)
	recon_ctrl.bribe_executed.connect(_on_bribe_for_planning)

	# Pipe bribe events to AudioManager (coin SFX).
	recon_ctrl.bribe_executed.connect(AudioManager.on_bribe_executed)

	# Wire eavesdrop exposure → ScenarioManager fail trigger (Scenario 1).
	recon_ctrl.player_exposed.connect(_on_player_exposed)

	# Wire bribe_executed → journal timeline entry.
	recon_ctrl.bribe_executed.connect(_on_bribe_executed)



func _init_journal() -> void:
	if journal == null:
		push_error("Main: $Journal node not found — journal not wired")
		return

	var intel_store: PlayerIntelStore = world.intel_store
	if journal.has_method("setup"):
		journal.setup(world, intel_store, day_night)



## Called when the player successfully seeds a rumor via the crafting panel.
func _on_rumor_seeded(
		rumor_id: String,
		subject_name: String,
		claim_id: String,
		seed_target_name: String
) -> void:
	AudioManager.on_rumor_seeded(rumor_id, subject_name, claim_id, seed_target_name)
	_camera_shake(5.0, 0.3)
	# SPA-805: Ripple VFX on the seed target NPC.
	_spawn_seed_ripple(seed_target_name)
	# SPA-805: Pulse the Believers counter on the objective HUD.
	if objective_hud != null and objective_hud.has_method("pulse_believers_counter"):
		objective_hud.pulse_believers_counter()
	if journal != null and journal.has_method("push_timeline_event"):
		var _seed_tick: int = day_night.current_tick if day_night != null else 0
		journal.push_timeline_event(
			_seed_tick,
			"Seeded rumor [%s] about %s — whispered to %s" % [
				claim_id, subject_name, seed_target_name
			]
		)
	# Toast + feed entry confirming the plant-rumor action to the player.
	var toast_msg := "Whispered to %s — [%s] about %s" % [seed_target_name, claim_id, subject_name]
	if recon_hud != null and recon_hud.has_method("show_toast"):
		recon_hud.show_toast(toast_msg, true)
	if recon_hud != null and recon_hud.has_method("push_feed_entry"):
		recon_hud.push_feed_entry(toast_msg, true)


## SPA-805: Spawn expanding ring VFX at the seed target NPC's world position.
## Looks up the NPC by display name among world.npcs.
func _spawn_seed_ripple(seed_target_name: String) -> void:
	if world == null:
		return
	var npc_pos := Vector2.ZERO
	var found := false
	for npc in world.npcs:
		var nid: String = npc.npc_data.get("id", "")
		if nid.replace("_", " ").capitalize() == seed_target_name:
			npc_pos = npc.global_position
			found = true
			break
	if not found:
		return
	var fx := preload("res://scripts/rumor_ripple_vfx.gd").new()
	world.add_child(fx)
	fx.global_position = npc_pos


## SPA-805: Called when scenario_manager emits s1_first_blood (Edric rep < 48).
func _on_s1_first_blood() -> void:
	if _milestone_notifier != null and _milestone_notifier.has_method("show_milestone"):
		_milestone_notifier.show_milestone(
			"First Blood — Edric's reputation cracks!",
			Color(0.92, 0.45, 0.12, 1.0)
		)


## Called when the player bribes an NPC; logs the event to the journal timeline.
func _on_bribe_executed(npc_name: String, tick: int) -> void:
	if journal != null and journal.has_method("push_timeline_event"):
		journal.push_timeline_event(tick, "Bribed %s — forced to believe a rumor" % npc_name)


# ── SPA-708: Daily planning priority counter handlers ─────────────────────────

func _on_recon_action_for_planning(message: String, success: bool) -> void:
	if _daily_planning == null or not success:
		return
	var lower := message.to_lower()
	if lower.find("observe") >= 0:
		_daily_planning.increment_counter("observe_count")
	elif lower.find("eavesdrop") >= 0:
		_daily_planning.increment_counter("eavesdrop_count")


func _on_bribe_for_planning(_npc_name: String, _tick: int) -> void:
	if _daily_planning != null:
		_daily_planning.increment_counter("bribe_count")


func _on_rumor_seeded_for_planning(
		_rumor_id: String, _subject_name: String,
		_claim_id: String, seed_target_name: String
) -> void:
	if _daily_planning == null:
		return
	_daily_planning.increment_counter("whisper_count")
	# Check if target is clergy for the specific priority.
	if seed_target_name.to_lower().find("clergy") >= 0 or seed_target_name.to_lower().find("priest") >= 0 or seed_target_name.to_lower().find("friar") >= 0:
		_daily_planning.increment_counter("whisper_clergy")


## Connect world.rumor_event → journal timeline and social graph overlay.
## Also wires per-NPC SPA-788 reward-moment signals (once per session).
func _wire_rumor_events() -> void:
	if world == null:
		return
	world.rumor_event.connect(_on_rumor_event)
	world.socially_dead_triggered.connect(_on_socially_dead_triggered)
	# SPA-850: cascade celebration when 3+ NPCs believe same rumor in one day.
	if world.has_signal("cascade_triggered"):
		world.cascade_triggered.connect(_on_cascade_triggered)
	# SPA-788: first-spread and first-belief-flip reward moments.
	if "npcs" in world:
		for npc in world.npcs:
			if npc.has_signal("rumor_transmitted"):
				npc.rumor_transmitted.connect(_on_first_rumor_transmitted)
			if npc.has_signal("rumor_state_changed"):
				npc.rumor_state_changed.connect(_on_first_belief_flip)


## Relay world rumor events into the Journal timeline and overlay.
## Also fire milestone HUD effects for the most impactful events.
func _on_rumor_event(message: String, tick: int) -> void:
	# SPA-848: diagnostic lines are embedded after "\n" — split to keep journal entry clean.
	var parts := message.split("\n", false, 1)
	var main_msg := parts[0]
	var diagnostic := parts[1] if parts.size() > 1 else ""
	if journal != null and journal.has_method("push_timeline_event"):
		journal.push_timeline_event(tick, main_msg, diagnostic)
	if social_graph_overlay != null and social_graph_overlay.has_method("on_rumor_event"):
		social_graph_overlay.on_rumor_event(main_msg)
	# SPA-827: Cause-and-effect toast + feed entry + ripple VFX on each NPC-to-NPC spread.
	# Format: "FromName whispered to ToName [id]"
	if main_msg.contains("whispered to"):
		var wt_parts := main_msg.split(" whispered to ", false)
		if wt_parts.size() >= 2:
			var from_name := wt_parts[0].strip_edges()
			var to_part := wt_parts[1].split(" [", false)
			var to_name := to_part[0].strip_edges()
			var to_role := ""
			var to_npc_pos := Vector2.ZERO
			if world != null:
				for npc in world.npcs:
					if npc.npc_data.get("name", "") == to_name:
						to_role = npc.npc_data.get("role", "")
						to_npc_pos = npc.global_position
						break
			# Toast: show FROM → TO so the chain of cause-and-effect is explicit.
			var from_first := from_name.split(" ")[0]
			var to_first   := to_name.split(" ")[0]
			var toast_msg: String
			if to_role != "":
				toast_msg = "%s → %s the %s — rumor spreads!" % [from_first, to_first, to_role]
			else:
				toast_msg = "%s → %s — rumor spreads!" % [from_first, to_first]
			if recon_hud != null:
				if recon_hud.has_method("show_toast"):
					recon_hud.show_toast(toast_msg, true)
				# Feed entry so the spread chain is visible in Recent Actions.
				if recon_hud.has_method("push_feed_entry"):
					recon_hud.push_feed_entry("%s told %s" % [from_first, to_first], true)
			# Ripple VFX at the receiving NPC's world position.
			# Blue-tinted (vs. gold at seed) so the player can distinguish origin from spread.
			if to_npc_pos != Vector2.ZERO and world != null:
				var fx := preload("res://scripts/rumor_ripple_vfx.gd").new()
				fx.accent_color = Color(0.45, 0.80, 1.0, 0.75)
				world.add_child(fx)
				fx.global_position = to_npc_pos

	# Milestone visual feedback for key state-change events.
	if recon_hud != null and recon_hud.has_method("show_milestone"):
		if main_msg.contains("→ Believe"):
			var npc_name := main_msg.split(" →")[0].strip_edges() if " →" in main_msg else "NPC"
			recon_hud.show_milestone("%s is convinced!" % npc_name, Color(0.50, 1.00, 0.55, 1.0))
			# SPA-827: Golden flash to reinforce the belief moment — clear cause-and-effect signal.
			if recon_hud.has_method("show_action_flash"):
				recon_hud.show_action_flash(true)
		elif main_msg.contains("→ Spread"):
			var npc_name := main_msg.split(" →")[0].strip_edges() if " →" in main_msg else "NPC"
			recon_hud.show_milestone("%s is spreading the word!" % npc_name, Color(0.40, 0.85, 1.00, 1.0))
		elif main_msg.contains("→ Act"):
			var npc_name := main_msg.split(" →")[0].strip_edges() if " →" in main_msg else "NPC"
			recon_hud.show_milestone("%s takes action!" % npc_name, Color(1.00, 0.85, 0.20, 1.0))
		elif main_msg.contains("→ Reject"):
			var npc_name := main_msg.split(" →")[0].strip_edges() if " →" in main_msg else "NPC"
			recon_hud.show_milestone("%s rejected the rumor" % npc_name, Color(0.85, 0.40, 0.30, 1.0))


## SPA-788 Moment 1: fires once the first time any NPC-to-NPC rumor transmission occurs.
## Layered audio motif + gossip-line particles + parchment toast + brief camera nudge.
func _on_first_rumor_transmitted(from_name: String, to_name: String, _rumor_id: String) -> void:
	if _reward_first_spread_fired:
		return
	_reward_first_spread_fired = true

	# Audio: 2-note descending minor-third whisper motif (semitone ratio 2^(-3/12) ≈ 0.841).
	AudioManager.play_sfx_pitched("whisper", 1.0)
	get_tree().create_timer(0.28).timeout.connect(
		func() -> void: AudioManager.play_sfx_pitched("whisper", 0.841), CONNECT_ONE_SHOT
	)

	# Visual: gossip-line particle trail from spreader to receiver.
	var from_pos := Vector2.ZERO
	var to_pos   := Vector2.ZERO
	if world != null and "npcs" in world:
		for npc in world.npcs:
			var nm: String = npc.npc_data.get("name", "")
			if nm == from_name:
				from_pos = npc.global_position
			if nm == to_name:
				to_pos = npc.global_position
	if from_pos != Vector2.ZERO and to_pos != Vector2.ZERO:
		_spawn_gossip_line_particles(from_pos, to_pos)

	# UI: parchment-styled toast.
	_show_parchment_toast("Your words have found new lips.", 3.0)

	# Feel: brief camera nudge (120 ms).
	_camera_shake(3.5, 0.12)


## SPA-788 Moment 2: fires once when any NPC first transitions to BELIEVE / SPREAD / ACT.
## Conviction audio chime + dark vignette flash + thought-bubble override + milestone popup
## + belief-shaken walk penalty for the rest of the day.
func _on_first_belief_flip(npc_name: String, new_state_name: String, _rumor_id: String) -> void:
	if _reward_first_belief_fired:
		return
	if new_state_name != "BELIEVE" and new_state_name != "SPREAD" and new_state_name != "ACT":
		return
	_reward_first_belief_fired = true

	# Audio: reputation_down pitched down 2 semitones (2^(-2/12) ≈ 0.891) + conviction chime.
	AudioManager.play_sfx_pitched("reputation_down", 0.891)
	AudioManager.play_sfx("milestone_chime")

	# Visual: NPC dark-vignette flash + thought-bubble conviction override.
	if world != null and "npcs" in world:
		for npc in world.npcs:
			if npc.npc_data.get("name", "") == npc_name:
				if npc.has_method("flash_belief_vignette"):
					npc.flash_belief_vignette()
				if npc.has_method("set_belief_shaken"):
					npc.set_belief_shaken(true)
				var bubble: Node = npc.get("_thought_bubble")
				if bubble != null and bubble.has_method("show_override"):
					bubble.show_override("!", Color(0.40, 1.00, 0.50, 1.0), 2.0)
				break

	# UI: milestone popup, green-coded — fires exactly once per session.
	if _milestone_notifier != null and _milestone_notifier.has_method("show_milestone"):
		_milestone_notifier.show_milestone(
			"A townsfolk has become a true believer.",
			Color(0.50, 1.00, 0.55, 1.0),
			"first_belief_flip"
		)


## SPA-850: Cascade celebration — 3+ NPCs believed the same rumor in one day.
## Shows "RUMOR WILDFIRE" milestone popup with amber particles and audio burst.
func _on_cascade_triggered(rumor_id: String, believer_count: int) -> void:
	# Audio burst: milestone chime + pitched-up reputation_up for excitement.
	AudioManager.play_sfx("milestone_chime")
	AudioManager.play_sfx_pitched("reputation_up", 1.12)

	# Milestone popup — amber/orange color, scaled particle count by believer count.
	var text := "RUMOR WILDFIRE — %d new believers!" % believer_count
	if _milestone_notifier != null and _milestone_notifier.has_method("show_milestone"):
		_milestone_notifier.show_milestone(
			text,
			Color(1.00, 0.75, 0.20, 1.0),
			""
		)

	# Toast in recon HUD for the activity feed.
	if recon_hud != null and recon_hud.has_method("show_toast"):
		recon_hud.show_toast(text, true)

	# Journal log so the cascade is visible in the timeline.
	if journal != null and journal.has_method("push_timeline_event"):
		var tick: int = 0
		if world != null and world.day_night != null:
			tick = world.day_night.current_tick
		journal.push_timeline_event(tick, text)

	# Camera shake for visceral feedback.
	_camera_shake(5.0, 0.18)


## SPA-788: Spawns a world-space CPUParticles2D trail between two NPC positions.
## Uses a direction + velocity range so particles fly from spreader toward receiver.
func _spawn_gossip_line_particles(from_pos: Vector2, to_pos: Vector2) -> void:
	if world == null:
		return
	var dir    := (to_pos - from_pos).normalized()
	var dist   := from_pos.distance_to(to_pos)
	var travel_time := 0.8  # seconds — matches lifetime

	var particles := CPUParticles2D.new()
	particles.name = "GossipLineParticles"
	particles.global_position          = from_pos
	particles.z_index                  = 10
	particles.emitting                 = true
	particles.one_shot                 = true
	particles.amount                   = 18
	particles.lifetime                 = travel_time
	particles.explosiveness            = 0.0
	particles.spread                   = 8.0
	particles.direction                = dir
	particles.initial_velocity_min     = dist / travel_time * 0.85
	particles.initial_velocity_max     = dist / travel_time * 1.10
	particles.color                    = Color(0.95, 0.78, 0.30, 0.72)  # thin gold thread
	particles.scale_amount_min         = 1.5
	particles.scale_amount_max         = 3.0
	world.add_child(particles)
	get_tree().create_timer(travel_time + 0.25).timeout.connect(
		func() -> void:
			if is_instance_valid(particles):
				particles.queue_free(),
		CONNECT_ONE_SHOT
	)


## SPA-788: Shows a warm parchment-coloured floating toast for duration seconds.
## Created as a transient CanvasLayer (layer 19) that removes itself when done.
func _show_parchment_toast(text: String, duration: float) -> void:
	var cl := CanvasLayer.new()
	cl.name  = "ParchmentToast"
	cl.layer = 19
	add_child(cl)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.70, 0.56, 0.28, 0.92)  # warm parchment
	style.set_corner_radius_all(5)
	style.content_margin_left   = 12.0
	style.content_margin_right  = 12.0
	style.content_margin_top    = 7.0
	style.content_margin_bottom = 7.0
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 76.0
	cl.add_child(panel)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.16, 0.09, 0.04, 1.0))  # dark ink
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.25))
	panel.add_child(lbl)

	panel.modulate.a = 0.0
	var tween := cl.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(duration)
	tween.tween_property(panel, "modulate:a", 0.0, 0.40).set_ease(Tween.EASE_IN)
	tween.tween_callback(cl.queue_free)


## Show a HUD toast + milestone when an NPC first becomes SOCIALLY_DEAD.
func _on_socially_dead_triggered(_npc_id: String, npc_name: String, _tick: int) -> void:
	if recon_hud != null and recon_hud.has_method("show_toast"):
		recon_hud.show_toast("%s is SOCIALLY DEAD — reputation permanently frozen" % npc_name, false)
	if recon_hud != null and recon_hud.has_method("show_milestone"):
		recon_hud.show_milestone("☠ %s — SOCIALLY DEAD" % npc_name, Color(0.85, 0.15, 0.15, 1.0))


## SPA-560: Mid-game narrative event choice modal.
func _init_event_choice_modal() -> void:
	if world == null or world.mid_game_event_agent == null:
		return
	_event_choice_modal = preload("res://scripts/event_choice_modal.gd").new()
	_event_choice_modal.name = "EventChoiceModal"
	add_child(_event_choice_modal)

	var agent: MidGameEventAgent = world.mid_game_event_agent
	agent.event_presented.connect(_on_mid_game_event_presented)
	_event_choice_modal.choice_made.connect(_on_mid_game_event_choice_made)
	_event_choice_modal.dismissed.connect(_on_mid_game_event_dismissed)


func _on_mid_game_event_presented(event_data: Dictionary) -> void:
	if _event_choice_modal == null:
		return
	_event_choice_modal.present_event(event_data)
	# Journal entry.
	var event_name: String = str(event_data.get("name", "Event"))
	if journal != null and journal.has_method("push_timeline_event"):
		var tick: int = day_night.current_tick if day_night != null else 0
		journal.push_timeline_event(tick, "[EVENT] %s" % event_name)
	# Toast notification.
	if recon_hud != null and recon_hud.has_method("show_milestone"):
		recon_hud.show_milestone("Event: %s" % event_name, Color(0.92, 0.78, 0.12, 1.0))


func _on_mid_game_event_choice_made(event_id: String, choice_index: int) -> void:
	if world == null or world.mid_game_event_agent == null:
		return
	var agent: MidGameEventAgent = world.mid_game_event_agent
	agent.resolve_choice(event_id, choice_index)
	# The agent emits event_resolved with outcome text — show it in the modal.
	# We connect this lazily to avoid permanent connection.
	if not agent.event_resolved.is_connected(_on_mid_game_event_resolved):
		agent.event_resolved.connect(_on_mid_game_event_resolved)


func _on_mid_game_event_resolved(_event_id: String, _choice_index: int, outcome_text: String) -> void:
	if _event_choice_modal != null:
		_event_choice_modal.show_outcome(outcome_text)
	# Journal entry for the outcome.
	if journal != null and journal.has_method("push_timeline_event"):
		var tick: int = day_night.current_tick if day_night != null else 0
		journal.push_timeline_event(tick, "[OUTCOME] %s" % outcome_text.substr(0, 80))


func _on_mid_game_event_dismissed() -> void:
	pass  # Modal handles unpausing; nothing extra needed.


func _init_objective_hud() -> void:
	if objective_hud == null:
		push_error("Main: $ObjectiveHUD node not found — objective HUD not wired")
		return
	var sm: ScenarioManager = world.scenario_manager
	if sm == null:
		push_error("Main: world.scenario_manager is null — objective HUD not wired")
		return
	if objective_hud.has_method("setup"):
		objective_hud.setup(sm, day_night, world.reputation_system, world.intel_store)
	if objective_hud.has_method("setup_world"):
		objective_hud.setup_world(world)


func _init_daily_planning() -> void:
	_daily_planning = preload("res://scenes/DailyPlanningOverlay.tscn").instantiate()
	_daily_planning.name = "DailyPlanningOverlay"
	add_child(_daily_planning)
	if _daily_planning.has_method("setup"):
		_daily_planning.setup(world, day_night, objective_hud)


func _init_speed_hud() -> void:
	var hud := preload("res://scripts/speed_hud.gd").new()
	hud.name = "SpeedHUD"
	add_child(hud)
	if hud.has_method("setup"):
		hud.setup(day_night, world.intel_store if world != null else null)
	# SPA-757: Refresh End Day button visibility each tick.
	if day_night != null and hud.has_method("on_game_tick"):
		day_night.game_tick.connect(hud.on_game_tick)


func _init_zone_indicator() -> void:
	var zi := preload("res://scripts/zone_indicator.gd").new()
	zi.name = "ZoneIndicator"
	add_child(zi)
	if zi.has_method("setup"):
		zi.setup(world, camera)


func _init_npc_conversation_overlay() -> void:
	var overlay := preload("res://scripts/npc_conversation_overlay.gd").new()
	overlay.name = "NpcConversationOverlay"
	add_child(overlay)
	if overlay.has_method("setup"):
		overlay.setup(world)


func _init_scenario1_hud() -> void:
	if world.active_scenario_id != "scenario_1":
		return
	var hud := preload("res://scripts/scenario1_hud.gd").new()
	hud.name = "Scenario1HUD"
	add_child(hud)
	if hud.has_method("setup"):
		hud.setup(world, day_night)
	# SPA-805: Wire the "First Blood" milestone signal.
	if world.scenario_manager != null and world.scenario_manager.has_signal("s1_first_blood"):
		if not world.scenario_manager.s1_first_blood.is_connected(_on_s1_first_blood):
			world.scenario_manager.s1_first_blood.connect(_on_s1_first_blood)


func _init_scenario2_hud() -> void:
	if world.active_scenario_id != "scenario_2":
		return
	var hud := preload("res://scripts/scenario2_hud.gd").new()
	hud.name = "Scenario2HUD"
	add_child(hud)
	if hud.has_method("setup"):
		hud.setup(world, day_night)


func _init_scenario3_hud() -> void:
	if world.active_scenario_id != "scenario_3":
		return
	# Build the Scenario 3 dual-track HUD programmatically (no .tscn required).
	var hud := preload("res://scripts/scenario3_hud.gd").new()
	hud.name = "Scenario3HUD"
	add_child(hud)
	if hud.has_method("setup"):
		hud.setup(world, day_night)


func _init_scenario4_hud() -> void:
	if world.active_scenario_id != "scenario_4":
		return
	var hud := preload("res://scripts/scenario4_hud.gd").new()
	hud.name = "Scenario4HUD"
	add_child(hud)
	if hud.has_method("setup"):
		hud.setup(world, day_night)


func _init_scenario5_hud() -> void:
	if world.active_scenario_id != "scenario_5":
		return
	var hud := preload("res://scripts/scenario5_hud.gd").new()
	hud.name = "Scenario5HUD"
	add_child(hud)
	if hud.has_method("setup"):
		hud.setup(world, day_night)


func _init_scenario6_hud() -> void:
	if world.active_scenario_id != "scenario_6":
		return
	var hud := preload("res://scripts/scenario6_hud.gd").new()
	hud.name = "Scenario6HUD"
	add_child(hud)
	if hud.has_method("setup"):
		hud.setup(world, day_night)


# ── Sprint 7 / Sprint 10: Tutorial system ─────────────────────────────────────

func _init_tutorial_system() -> void:
	_tutorial_sys = TutorialSystem.new()

	if world.active_scenario_id == "scenario_1":
		_init_tutorial_banner_s1()
	else:
		# SPA-804: S2-S6 use non-blocking TutorialBanner only — blocking TutorialHUD
		# removed.  TutorialController for S2-S6 is started after the ready overlay.
		_init_context_banner()

	_init_idle_hints()
	_init_controls_reference()
	_init_help_reminder()
	_init_thought_legend()


## All scenarios except S1: non-blocking contextual hint banner for day-gated tips.
## S1 already has its own banner — this adds the cross-scenario hints for S2/S3/S4.
func _init_context_banner() -> void:
	_tutorial_banner = preload("res://scripts/tutorial_banner.gd").new()
	_tutorial_banner.name = "TutorialBanner"
	add_child(_tutorial_banner)
	_tutorial_banner.setup(_tutorial_sys)

	# SPA-537: "Your First Move" hints — tightened timing (mission briefing
	# is now shown by the ready overlay before gameplay starts).
	var _opening_hint_id: String = ""
	match world.active_scenario_id:
		"scenario_2": _opening_hint_id = "ctx_s2_opening"
		"scenario_3": _opening_hint_id = "ctx_s3_opening"
		"scenario_4": _opening_hint_id = "ctx_s4_opening"
		"scenario_5": _opening_hint_id = "ctx_s5_opening"
		"scenario_6": _opening_hint_id = "ctx_s6_opening"
	if _opening_hint_id != "":
		var _open_timer := get_tree().create_timer(4.0)  # tightened from 8 s
		var _hint_id_copy: String = _opening_hint_id
		_open_timer.timeout.connect(func() -> void:
			if _tutorial_banner != null:
				_tutorial_banner.queue_hint(_hint_id_copy)
		)

	# SPA-549: Scenario-specific onboarding banners — queued after the opening hint.
	# Opening hint fires at 4 s (12 s auto-dismiss), so queue these at 10 s and 16 s.
	var _s_hints: Array = []
	match world.active_scenario_id:
		"scenario_2":
			_s_hints = ["ctx_s2_illness_mechanic", "ctx_s2_maren_warning", "ctx_s2_believer_check"]
		"scenario_3":
			_s_hints = ["ctx_s3_dual_targets", "ctx_s3_rival_intro", "ctx_s3_disrupt_tip"]
		"scenario_4":
			_s_hints = ["ctx_s4_defense_goal", "ctx_s4_inquisitor_info", "ctx_s4_prioritize_finn"]
		"scenario_5":
			_s_hints = ["ctx_s5_three_way_race", "ctx_s5_endorsement_tip"]
		"scenario_6":
			_s_hints = ["ctx_s6_heat_ceiling", "ctx_s6_protect_marta"]
	var _delays: Array = [10.0, 16.0, 22.0]
	for i in range(_s_hints.size()):
		var _hint_id: String = _s_hints[i]
		var _timer := get_tree().create_timer(_delays[i])
		_timer.timeout.connect(func() -> void:
			if _tutorial_banner != null:
				_tutorial_banner.queue_hint(_hint_id)
		)

	# Day-gated hints: hook into day_changed signal.
	if day_night != null and day_night.has_signal("day_changed"):
		day_night.day_changed.connect(_on_ctx_day_changed)

	# Whisper token exhaustion hint (SPA-448).
	if world.intel_store != null:
		world.intel_store.tokens_exhausted.connect(_on_ctx_tokens_exhausted)

	# Heat warning hint (SPA-608): fires once when heat first crosses 50.
	# S1 (ceiling 80) and S6 (ceiling 60) both benefit from an early warning.
	if world.intel_store != null and world.active_scenario_id in ["scenario_1", "scenario_6"]:
		world.intel_store.heat_warning.connect(_on_heat_warning)

	# NPC state change hints: first SPREAD, ACT, or REJECT triggers.
	for npc in world.npcs:
		npc.rumor_state_changed.connect(_on_ctx_rumor_state_changed)

	# Suppression: pause banner while Journal / Rumour Panel are open.
	if journal != null:
		journal.visibility_changed.connect(_on_journal_visibility_changed_banner)
	if rumor_panel != null:
		rumor_panel.visibility_changed.connect(_on_rumor_panel_visibility_changed_banner)


## SPA-804 DEPRECATED — no longer called.  S2-S6 now use TutorialBanner via
## _init_sx_onboarding_flow().  Kept to avoid breaking any tool-generated refs.
func _init_tutorial_hud_s2s3s4() -> void:
	_tutorial_hud = preload("res://scripts/tutorial_hud.gd").new()
	_tutorial_hud.name = "TutorialHUD"
	add_child(_tutorial_hud)
	_tutorial_hud.setup(_tutorial_sys)

	# SPA-589: Show only core_loop immediately; defer navigation and recon
	# tooltips to contextual triggers so the player isn't overwhelmed.
	_tutorial_hud.queue_tooltip("core_loop")
	if world.active_scenario_id == "scenario_3":
		_tutorial_hud.queue_tooltip("rival_agent")
	if world.active_scenario_id == "scenario_4":
		_tutorial_hud.queue_tooltip("inquisitor_agent")
	if world.active_scenario_id == "scenario_5":
		_tutorial_hud.queue_tooltip("election_race")
	if world.active_scenario_id == "scenario_6":
		_tutorial_hud.queue_tooltip("guild_defense")

	# SPA-589: Deferred navigation tooltip — show after 10 s if not yet seen.
	var _nav_timer := get_tree().create_timer(10.0)
	_nav_timer.timeout.connect(func() -> void:
		if _tutorial_hud != null and _tutorial_sys != null:
			if not _tutorial_sys.has_seen("navigation_controls"):
				_tutorial_hud.queue_tooltip("navigation_controls")
	)
	# SPA-589: Deferred recon tooltip — show after first observe/eavesdrop attempt.
	# Fallback: show after 20 s if player hasn't done anything.
	var _recon_timer := get_tree().create_timer(20.0)
	_recon_timer.timeout.connect(func() -> void:
		if _tutorial_hud != null and _tutorial_sys != null:
			if not _tutorial_sys.has_seen("recon_actions"):
				_tutorial_hud.queue_tooltip("recon_actions")
	)

	if rumor_panel != null:
		rumor_panel.visibility_changed.connect(_on_rumor_panel_visibility_changed)
	if journal != null:
		journal.visibility_changed.connect(_on_journal_visibility_changed)
	for npc in world.npcs:
		npc.first_npc_became_evaluating.connect(_on_first_npc_state_change)



## S1: non-blocking banner hint system (SPA-131).
func _init_tutorial_banner_s1() -> void:
	_tutorial_banner = preload("res://scripts/tutorial_banner.gd").new()
	_tutorial_banner.name = "TutorialBanner"
	add_child(_tutorial_banner)
	_tutorial_banner.setup(_tutorial_sys)

	# SPA-537: The ready overlay now shows the full mission briefing, so the
	# first banner hint is the immediate first action — not the mission intro.
	# Tightened timing: 2 s → first action, 8 s → target NPC, 14 s → controls.
	# Creates a snappy "first 60 seconds" flow:
	#   0 s: ReadyOverlay dismissed → game starts
	#   2 s: "Step 1: Observe a Building" banner
	#   8 s: "Step 2: Eavesdrop" banner (if player hasn't already)
	#  14 s: "Time Controls" banner

	# HINT-01: immediate first action — fires 2 s after game start.
	var _first_action_timer := get_tree().create_timer(2.0)
	_first_action_timer.timeout.connect(func() -> void:
		if _tutorial_banner != null:
			_tutorial_banner.queue_hint("hint_first_action")
	)

	# HINT-02: point toward target NPC — fires 8 s after game start.
	var _target_hint_timer := get_tree().create_timer(8.0)
	_target_hint_timer.timeout.connect(func() -> void:
		if _tutorial_banner != null:
			_tutorial_banner.queue_hint("hint_target_npc")
	)

	# hint_speed_controls: fires 14 s after game start.
	var _speed_hint_timer := get_tree().create_timer(14.0)
	_speed_hint_timer.timeout.connect(func() -> void:
		if _tutorial_banner != null:
			_tutorial_banner.queue_hint("hint_speed_controls")
	)

	# Suppression: pause banner while Journal / Rumour Panel / Pause Menu are open.
	if journal != null:
		journal.visibility_changed.connect(_on_journal_visibility_changed_banner)
	if rumor_panel != null:
		rumor_panel.visibility_changed.connect(_on_rumor_panel_visibility_changed_banner)

	# Wire camera_moved for HINT-02 gate.
	var cam: Camera2D = world.get_node_or_null("Camera2D")
	if cam == null:
		# Camera may be a direct child of the scene root instead.
		for child in get_children():
			if child is Camera2D:
				cam = child
				break
	if cam != null and cam.has_signal("camera_moved"):
		cam.camera_moved.connect(_on_s1_camera_moved)

	# HINT-03: first building hover — wired after recon_ctrl is created.
	# (wired later in _wire_s1_recon_hints once recon_ctrl is available)

	# HINT-05: journal open after eavesdrop — handled in _on_s1_recon_action.
	# HINT-06: day 2 tick.
	if day_night != null:
		day_night.game_tick.connect(_on_s1_game_tick)

	# HINT-07: panel seed shown.
	if rumor_panel != null:
		rumor_panel.panel_seed_shown.connect(_on_s1_panel_seed_shown)

	# HINT-08: 5 s after seed.
	if rumor_panel != null:
		rumor_panel.rumor_seeded.connect(_on_s1_rumor_seeded)

	# HINT-09: first NPC reaches BELIEVE state.
	for npc in world.npcs:
		npc.rumor_state_changed.connect(_on_s1_rumor_state_changed)

	# HINT-10: evidence acquired (reuses existing signal).
	if rumor_panel != null:
		rumor_panel.evidence_first_shown.connect(_on_s1_evidence_first_shown)

	# SPA-629: Rumor Panel first-time tooltip walkthrough.
	if rumor_panel != null:
		_rumor_panel_tooltip = preload("res://scripts/rumor_panel_tooltip.gd").new()
		_rumor_panel_tooltip.name = "RumorPanelTooltip"
		add_child(_rumor_panel_tooltip)
		_rumor_panel_tooltip.setup(rumor_panel)
		rumor_panel.visibility_changed.connect(_on_rumor_panel_first_open_tooltip)

	# Wire hover signals now that banner is ready (recon_ctrl was cached earlier).
	if _recon_ctrl_ref != null:
		_wire_s1_recon_hints(_recon_ctrl_ref)



## Wires S1 hint signals from recon_ctrl and NPCs to the tutorial banner.
## Called from _init_tutorial_banner_s1() after recon_ctrl is cached.
func _wire_s1_recon_hints(recon_ctrl: Node) -> void:
	if _tutorial_banner == null:
		return
	# HINT-02: NPC hover after camera moved.
	if recon_ctrl.has_signal("valid_eavesdrop_hovered"):
		recon_ctrl.valid_eavesdrop_hovered.connect(_on_s1_valid_eavesdrop_hovered)
	# HINT-03: first building hover.
	if recon_ctrl.has_signal("building_first_hovered"):
		recon_ctrl.building_first_hovered.connect(_on_s1_building_first_hovered)
	# Wire NPC hover for HINT-02 via all NPC nodes.
	for npc in world.npcs:
		if npc.has_signal("npc_hovered"):
			npc.npc_hovered.connect(_on_s1_npc_hovered)


## Connected to recon_ctrl.player_exposed — triggers Scenario 1 exposure fail.
func _on_player_exposed() -> void:
	if world != null and world.scenario_manager != null:
		world.scenario_manager.on_player_exposed()


## Connected to recon_ctrl.action_performed — drives S1 banner gates.
## SPA-804: S2/S3 modal tooltip calls removed; blocking TutorialHUD replaced by
## non-blocking TutorialBanner driven by TutorialController.
func _on_recon_action_for_tutorial(message: String, success: bool) -> void:
	if not success:
		return
	# SPA-589: Notify visual affordances so they fade after enough actions.
	if _visual_affordances != null and _visual_affordances.has_method("on_action_performed"):
		_visual_affordances.on_action_performed()
	# SPA-724: Fade goal strip after player has taken 3 successful actions.
	_spa724_action_count += 1
	if _spa724_action_count >= 3 and recon_hud != null and recon_hud.has_method("fade_goal_strip"):
		recon_hud.fade_goal_strip()

	# SPA-626: Clear the Market highlight and dismiss the gated banner on first recon action.
	if not _banner_s1_market_cleared:
		_banner_s1_market_cleared = true
		if _visual_affordances != null and _visual_affordances.has_method("clear_single_target"):
			_visual_affordances.clear_single_target()
		if _tutorial_banner != null and _tutorial_banner.has_method("dismiss_hint"):
			_tutorial_banner.dismiss_hint("hint_s1_investigate_gate")

	# SPA-758: Notify banner of action for action-gated hints + advance waypoint.
	if message.begins_with("Observed"):
		if _tutorial_banner != null and _tutorial_banner.has_method("notify_action"):
			_tutorial_banner.notify_action("observe")
		_advance_waypoint("observe")
	elif message.begins_with("Eavesdropped"):
		if _tutorial_banner != null and _tutorial_banner.has_method("notify_action"):
			_tutorial_banner.notify_action("eavesdrop")
		_advance_waypoint("eavesdrop")

	# S1 banner: open observe gate (HINT-04 unlocks) and eavesdrop gate (HINT-05).
	if _tutorial_banner != null:
		if message.begins_with("Observed") and not _banner_observe_gate:
			_banner_observe_gate = true
			# Prompt Journal after first intel discovery (Observe counts as first discovery).
			if not _banner_journal_hint_fired:
				_banner_journal_hint_fired = true
				_tutorial_banner.queue_hint("hint_journal")
		if message.begins_with("Eavesdropped"):
			if not _banner_eavesdrop_gate:
				_banner_eavesdrop_gate = true
				# Journal hint after first eavesdrop, if not already shown from Observe.
				if not _banner_journal_hint_fired:
					_banner_journal_hint_fired = true
					_tutorial_banner.queue_hint("hint_journal")
				# SPA-537: Immediately nudge toward Rumour Panel after first eavesdrop
				# (tighter flow — don't wait until Day 2).
				if not _banner_seed_fired:
					var _rumour_nudge_timer := get_tree().create_timer(4.0)
					_rumour_nudge_timer.timeout.connect(func() -> void:
						if not is_instance_valid(self):
							return
						if _tutorial_banner != null and not _banner_seed_fired:
							_tutorial_banner.queue_hint("hint_rumour_panel")
						# SPA-626: Auto-open Rumour Panel after first eavesdrop (4 s delay).
						if is_instance_valid(rumor_panel) and rumor_panel.panel != null and not rumor_panel.panel.visible and not _banner_seed_fired:
							rumor_panel.toggle()
					)
			_banner_eavesdrop_count += 1
			# Introduce social graph when 2+ relationships are revealed.
			if _banner_eavesdrop_count >= 2 and not _banner_social_graph_fired:
				_banner_social_graph_fired = true
				_tutorial_banner.queue_hint("hint_social_graph")


# ── S1 banner signal handlers ─────────────────────────────────────────────────

func _on_s1_camera_moved() -> void:
	_banner_camera_gate = true
	# Dismiss HINT-01 if it's active (player has already found camera controls).
	# The banner will auto-dismiss; no forced close needed.


func _on_s1_npc_hovered(_npc: Node2D) -> void:
	# HINT-02: fire once after camera has been moved.
	if _banner_camera_gate and _tutorial_banner != null:
		_tutorial_banner.queue_hint("hint_hover_npc")
		# Disconnect all NPC hover connections — hint fired.
		for npc in world.npcs:
			if npc.has_signal("npc_hovered") and npc.npc_hovered.is_connected(_on_s1_npc_hovered):
				npc.npc_hovered.disconnect(_on_s1_npc_hovered)


func _on_s1_building_first_hovered() -> void:
	# HINT-03: first building hover.
	if _tutorial_banner != null:
		_tutorial_banner.queue_hint("hint_observe")


func _on_s1_valid_eavesdrop_hovered() -> void:
	# HINT-04: valid eavesdrop target hovered, but only after first Observe.
	if _banner_observe_gate and _tutorial_banner != null:
		_tutorial_banner.queue_hint("hint_eavesdrop")


func _on_s1_game_tick(tick: int) -> void:
	# HINT-06: fire at day 2 (tick 24) if tokens exist, player has eavesdropped, and no rumour seeded.
	# Gating on _banner_eavesdrop_gate ensures the player has gathered intel before being nudged
	# toward the Rumour Panel — avoids an arbitrary first seed choice (SPA-170 recommendation).
	if tick >= 24 and not _banner_hint06_fired and _tutorial_banner != null and not _banner_seed_fired:
		var intel: PlayerIntelStore = world.intel_store
		if intel != null and intel.whisper_tokens_remaining >= 1 and _banner_eavesdrop_gate:
			_banner_hint06_fired = true
			_tutorial_banner.queue_hint("hint_rumour_panel")


func _on_s1_panel_seed_shown() -> void:
	# HINT-07: first time panel 3 opens.
	if _tutorial_banner != null:
		_tutorial_banner.queue_hint("hint_seed_target")


func _on_s1_rumor_seeded(
		_rumor_id: String,
		_subject_name: String,
		_claim_id: String,
		_seed_target_name: String
) -> void:
	# SPA-758: Dismiss action-gated craft_rumor banner and clear waypoint step 3.
	if _tutorial_banner != null and _tutorial_banner.has_method("notify_action"):
		_tutorial_banner.notify_action("craft_rumor")
	if _waypoint_step == 3:
		_clear_waypoint()
		_waypoint_step = 0
	# HINT-08: 5 s after first seed.
	if _banner_seed_fired or _tutorial_banner == null:
		return
	_banner_seed_fired = true
	# SPA-626: Immediate toast — confirm the whisper is in motion.
	if recon_hud != null and recon_hud.has_method("show_toast"):
		recon_hud.show_toast("Rumours take time to spread. Watch the dawn bulletin tomorrow.", false)
	var timer := get_tree().create_timer(5.0)
	timer.timeout.connect(func() -> void:
		if _tutorial_banner != null:
			_tutorial_banner.queue_hint("hint_propagation")
	)


func _on_s1_rumor_state_changed(
		_npc_name: String, new_state_name: String, _rumor_id: String
) -> void:
	# HINT-09: first NPC reaches BELIEVE for any player-seeded rumour.
	if new_state_name == "BELIEVE" and not _banner_believe_fired and _tutorial_banner != null:
		_banner_believe_fired = true
		_tutorial_banner.queue_hint("hint_objectives")


func _on_s1_evidence_first_shown() -> void:
	# HINT-10: evidence item acquired.
	if _tutorial_banner != null and not _evidence_tooltip_fired:
		_evidence_tooltip_fired = true
		_tutorial_banner.queue_hint("hint_evidence")


## S1 banner suppression: pause when Journal opens/closes.
func _on_journal_visibility_changed_banner() -> void:
	if _tutorial_banner == null or journal == null:
		return
	if journal.visible:
		_tutorial_banner.suppress()
	else:
		_tutorial_banner.unsuppress()


## SPA-629: Show first-time tooltip walkthrough when Rumor Panel opens in S1.
func _on_rumor_panel_first_open_tooltip() -> void:
	if _rumor_panel_tooltip_wired or _rumor_panel_tooltip == null or rumor_panel == null:
		return
	if not rumor_panel.visible:
		return
	_rumor_panel_tooltip_wired = true
	_rumor_panel_tooltip.show_walkthrough()
	# Disconnect after first trigger — the tooltip handles its own persistence.
	if rumor_panel.visibility_changed.is_connected(_on_rumor_panel_first_open_tooltip):
		rumor_panel.visibility_changed.disconnect(_on_rumor_panel_first_open_tooltip)


## S1 banner suppression: pause when Rumour Panel opens/closes.
func _on_rumor_panel_visibility_changed_banner() -> void:
	if _tutorial_banner == null or rumor_panel == null:
		return
	if rumor_panel.visible:
		_tutorial_banner.suppress()
	else:
		_tutorial_banner.unsuppress()


## S1 banner suppression: pause when Pause Menu opens/closes.
func _on_pause_menu_visibility_changed_banner() -> void:
	if _tutorial_banner == null or _pause_menu == null:
		return
	if _pause_menu.visible:
		_tutorial_banner.suppress()
	else:
		_tutorial_banner.unsuppress()


# ── Cross-scenario contextual hint handlers ──────────────────────────────────

func _on_ctx_day_changed(day: int) -> void:
	if _tutorial_banner == null:
		return
	if day == 2:
		_tutorial_banner.queue_hint("ctx_actions_refresh")
	elif day == 3:
		_tutorial_banner.queue_hint("ctx_check_journal")
	# S5: endorsement approaches — warn the player 2 days before.
	if world.active_scenario_id == "scenario_5" and world.scenario_manager != null:
		var _endorse_day: int = world.scenario_manager.S5_ENDORSEMENT_DAY
		if day == _endorse_day - 2:
			_tutorial_banner.queue_hint("ctx_s5_endorsement_warning")
	# Halfway warning: check if past 50% of days and progress is slow.
	if not _ctx_halfway_fired and world.scenario_manager != null:
		var total: int = world.scenario_manager.get_days_allowed()
		if day > total / 2:
			_ctx_halfway_fired = true
			_tutorial_banner.queue_hint("ctx_halfway_warning")
	# SPA-786: Late-game audio tension shift at 75% days used.
	if world.scenario_manager != null:
		var total_days: int = world.scenario_manager.get_days_allowed()
		var frac: float = clampf(float(day - 1) / float(max(total_days - 1, 1)), 0.0, 1.0)
		AudioManager.set_late_game_tension(frac >= 0.75)


func _on_ctx_rumor_state_changed(
		_npc_name: String, new_state_name: String, _rumor_id: String
) -> void:
	if _tutorial_banner == null:
		return
	if new_state_name == "SPREAD" and not _ctx_spread_fired:
		_ctx_spread_fired = true
		_tutorial_banner.queue_hint("ctx_rumor_spreading")
	elif new_state_name == "ACT" and not _ctx_act_fired:
		_ctx_act_fired = true
		_tutorial_banner.queue_hint("ctx_rumor_acted")
	elif new_state_name == "REJECT" and not _ctx_reject_fired:
		_ctx_reject_fired = true
		_tutorial_banner.queue_hint("ctx_rumor_rejected")


## Fires once when the player exhausts all Whisper Tokens (S2/S3/S4) (SPA-448).
func _on_ctx_tokens_exhausted() -> void:
	if _ctx_tokens_fired or _tutorial_banner == null:
		return
	_ctx_tokens_fired = true
	_tutorial_banner.queue_hint("ctx_out_of_tokens")


## Fires once in S1 when any NPC's heat first crosses 50 (SPA-608).
## Warns the player before the hard fail at 80.
func _on_heat_warning() -> void:
	if _ctx_heat_warn_fired or _tutorial_banner == null:
		return
	_ctx_heat_warn_fired = true
	_tutorial_banner.queue_hint("ctx_heat_warning")


## ── SPA-487: Idle-detection hint system ──────────────────────────────────────
## Fires contextual hints when the player hasn't taken actions for a while.

## SPA-541: Persistent controls reference overlay (F1 to toggle).
func _init_controls_reference() -> void:
	_controls_ref = preload("res://scripts/controls_reference.gd").new()
	_controls_ref.name = "ControlsReference"
	add_child(_controls_ref)


func _init_idle_hints() -> void:
	_idle_timer = Timer.new()
	_idle_timer.name = "IdleHintTimer"
	_idle_timer.wait_time = 30.0  # 30 seconds of inactivity
	_idle_timer.one_shot = true
	_idle_timer.timeout.connect(_on_idle_timeout)
	add_child(_idle_timer)
	_idle_timer.start()

	# Reset idle timer when the player performs any recon action.
	if _recon_ctrl_ref != null and _recon_ctrl_ref.has_signal("action_performed"):
		_recon_ctrl_ref.action_performed.connect(_on_action_reset_idle)
	# Track rumor seeding via the rumor_seeded signal on rumor_panel.
	if rumor_panel != null and rumor_panel.has_signal("rumor_seeded"):
		rumor_panel.rumor_seeded.connect(_on_rumor_seeded_idle)


func _on_action_reset_idle(message: String, success: bool) -> void:
	if success:
		_has_performed_any_action = true
	if _idle_timer != null:
		_idle_timer.start()  # restart the idle countdown


func _on_rumor_seeded_idle(_rid: String = "", _subj: String = "", _claim: String = "", _tgt: String = "") -> void:
	_has_crafted_any_rumor = true
	if _idle_timer != null:
		_idle_timer.start()


func _on_idle_timeout() -> void:
	if _tutorial_banner == null:
		return
	# First nudge: player hasn't taken any action at all.
	if not _has_performed_any_action and not _idle_hint_fired_no_action:
		_idle_hint_fired_no_action = true
		_tutorial_banner.queue_hint("ctx_idle_no_action")
	# Second nudge: player has observed/eavesdropped but never crafted a rumor.
	elif _has_performed_any_action and not _has_crafted_any_rumor and not _idle_hint_fired_no_rumor:
		_idle_hint_fired_no_rumor = true
		_tutorial_banner.queue_hint("ctx_idle_no_rumor")
	# Restart the timer for future idle checks (60 s gap for subsequent nudges).
	if _idle_timer != null:
		_idle_timer.wait_time = 60.0
		_idle_timer.start()


## SPA-704: Persistent help key hints in bottom-right with subtle background.
## Shows essential hotkeys for 90 s then fades to a compact single-line reminder.
func _init_help_reminder() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 18
	layer.name = "HelpReminderLayer"
	add_child(layer)

	# Background panel for readability.
	var panel := PanelContainer.new()
	panel.anchor_left   = 1.0
	panel.anchor_top    = 1.0
	panel.anchor_right  = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left   = -220
	panel.offset_top    = -80
	panel.offset_right  = -12
	panel.offset_bottom = -12
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.02, 0.65)
	style.set_border_width_all(1)
	style.border_color = Color(0.55, 0.38, 0.18, 0.40)
	style.set_corner_radius_all(4)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var line1 := Label.new()
	line1.text = "R: Rumor  |  J: Journal  |  G: Graph"
	line1.add_theme_font_size_override("font_size", 11)
	line1.add_theme_color_override("font_color", Color(0.85, 0.78, 0.58, 0.85))
	line1.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(line1)

	var line2 := Label.new()
	line2.text = "O: Mission  |  H: Hint  |  F1: Controls"
	line2.add_theme_font_size_override("font_size", 11)
	line2.add_theme_color_override("font_color", Color(0.80, 0.72, 0.55, 0.70))
	line2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(line2)

	var line3 := Label.new()
	line3.text = "Esc: Pause + Settings"
	line3.add_theme_font_size_override("font_size", 11)
	line3.add_theme_color_override("font_color", Color(0.80, 0.72, 0.55, 0.55))
	line3.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vbox.add_child(line3)

	panel.add_child(vbox)
	layer.add_child(panel)

	# Store panel ref so we can fade it.
	_help_reminder = line1  # keep ref for compat

	# Fade out after 90 seconds.
	var fade_timer := get_tree().create_timer(90.0)
	fade_timer.timeout.connect(func() -> void:
		if not is_instance_valid(self) or not is_instance_valid(panel):
			return
		if panel != null:
			var tw := create_tween()
			tw.tween_property(panel, "modulate:a", 0.0, 1.5)
			tw.tween_callback(panel.queue_free)
	)


## SPA-806: Thought bubble symbol legend — bottom-right, above help reminder.
func _init_thought_legend() -> void:
	_thought_legend = preload("res://scripts/thought_bubble_legend.gd").new()
	_thought_legend.name = "ThoughtBubbleLegend"
	add_child(_thought_legend)

	# Determine if the player has completed any scenario (returning player).
	var is_returning: bool = false
	for sc_id in ["scenario_1", "scenario_2", "scenario_3", "scenario_4", "scenario_5", "scenario_6"]:
		for diff in ["apprentice", "master", "spymaster"]:
			var stats: Dictionary = PlayerStats.get_scenario_stats(sc_id, diff)
			if stats.get("games_played", 0) > 0:
				is_returning = true
				break
		if is_returning:
			break

	_thought_legend.setup(day_night, is_returning)


## Evidence tutorial trigger — fires once when compatible evidence is first shown (S2/S3).
func _on_evidence_first_shown() -> void:
	if _evidence_tooltip_fired or _tutorial_hud == null:
		return
	_evidence_tooltip_fired = true
	_tutorial_hud.queue_tooltip("evidence_items")


## Tooltip (npc_state_change) trigger — fires once when any NPC first enters EVALUATING (S2/S3).
func _on_first_npc_state_change() -> void:
	if _npc_state_change_tooltip_fired or _tutorial_hud == null:
		return
	_npc_state_change_tooltip_fired = true
	_tutorial_hud.queue_tooltip("npc_state_change")


## Tooltip 4 trigger — fires once when the Rumor Panel first opens (S2/S3).
func _on_rumor_panel_visibility_changed() -> void:
	if rumor_panel == null or not rumor_panel.visible:
		return
	if _tutorial_hud != null:
		_tutorial_hud.queue_tooltip("rumor_crafting")
	rumor_panel.visibility_changed.disconnect(_on_rumor_panel_visibility_changed)


## Tooltip 5 trigger — fires once when the Journal first opens (S2/S3).
func _on_journal_visibility_changed() -> void:
	if journal == null or not journal.visible:
		return
	if _tutorial_hud != null:
		_tutorial_hud.queue_tooltip("reputation")
	journal.visibility_changed.disconnect(_on_journal_visibility_changed)


# ── Sprint 6: End Screen ───────────────────────────────────────────────────────

func _init_end_screen() -> void:
	# SPA-212: Create analytics collector and wire to world signals.
	_analytics = ScenarioAnalytics.new()
	_analytics.setup(world, day_night)

	_end_screen = preload("res://scripts/end_screen.gd").new()
	_end_screen.name = "EndScreen"
	add_child(_end_screen)
	_end_screen.setup(world, day_night, _analytics)

	# SPA-784: Feedback sequence (runs before end screen appears).
	_feedback_seq = preload("res://scripts/feedback_sequence.gd").new()
	_feedback_seq.name = "FeedbackSequence"
	add_child(_feedback_seq)
	_feedback_seq.setup(camera, day_night, world)


# ── Sprint 7: Audio ────────────────────────────────────────────────────────────

func _init_audio() -> void:
	# Connect ambient crossfade + new_day SFX to the day/night clock.
	AudioManager.connect_to_day_night(day_night)

	# Connect scenario win/fail events so AudioManager can play stings.
	var sm: ScenarioManager = world.scenario_manager
	if sm != null:
		sm.scenario_resolved.connect(_on_scenario_resolved_audio)

	# Reputation collapse SFX: play reputation_down when an NPC goes socially dead.
	world.socially_dead_triggered.connect(AudioManager.on_socially_dead)



# ── SPA-244: Local analytics logger ──────────────────────────────────────────

func _init_analytics_logger(scenario_id: String) -> void:
	_analytics_logger = AnalyticsLogger.new()
	_analytics_logger.start_session(scenario_id, GameState.selected_difficulty)
	_analytics_scenario_id = scenario_id

	# Log each rumor seeded (full context for propagation frequency analysis).
	if rumor_panel != null:
		rumor_panel.rumor_seeded.connect(_on_analytics_rumor_seeded)

	# Log NPC rumor-slot state transitions (BELIEVE / SPREAD / ACT / REJECT).
	if "npcs" in world:
		for npc in world.npcs:
			if npc.has_signal("rumor_state_changed"):
				npc.rumor_state_changed.connect(_on_analytics_npc_state_changed)

	# Log evidence collection interactions (observe / eavesdrop).
	if _recon_ctrl_ref != null and _recon_ctrl_ref.has_signal("action_performed"):
		_recon_ctrl_ref.action_performed.connect(_on_analytics_evidence_interaction)

	# Log per-day reputation deltas for balance tuning.
	if day_night != null and day_night.has_signal("day_changed"):
		day_night.day_changed.connect(_on_analytics_new_day)

	# Log scenario outcome and session summary.
	var sm: ScenarioManager = world.scenario_manager
	if sm != null:
		sm.scenario_resolved.connect(_on_analytics_scenario_resolved)


func _on_analytics_rumor_seeded(
		_rumor_id: String,
		subject_name: String,
		claim_id: String,
		seed_target_name: String
) -> void:
	if _analytics_logger == null:
		return
	var day: int = day_night.current_day if day_night != null and "current_day" in day_night else 0
	_analytics_logger.log_rumor_seeded(subject_name, claim_id, seed_target_name, day, _analytics_scenario_id)


func _on_analytics_npc_state_changed(npc_name: String, new_state: String, rumor_id: String) -> void:
	if _analytics_logger == null:
		return
	var day: int = day_night.current_day if day_night != null and "current_day" in day_night else 0
	_analytics_logger.log_npc_state_changed(npc_name, rumor_id, new_state, day, _analytics_scenario_id)


func _on_analytics_evidence_interaction(message: String, success: bool) -> void:
	if _analytics_logger == null:
		return
	var action_type: String
	if "Observe" in message:
		action_type = "observe"
	elif "Eavesdrop" in message:
		action_type = "eavesdrop"
	else:
		return  # Only log observe and eavesdrop evidence interactions.
	var day: int = day_night.current_day if day_night != null and "current_day" in day_night else 0
	_analytics_logger.log_evidence_interaction(action_type, success, day, _analytics_scenario_id)


func _on_analytics_new_day(day: int) -> void:
	if _analytics_logger == null or world == null:
		return
	var rep: ReputationSystem = world.reputation_system if "reputation_system" in world else null
	if rep == null:
		return
	var snapshots: Dictionary = rep.get_all_snapshots()
	for npc_id in snapshots:
		var snap: ReputationSystem.ReputationSnapshot = snapshots[npc_id]
		var prev_score: int = _analytics_rep_snapshot.get(npc_id, snap.score)
		if abs(snap.score - prev_score) >= 3:
			_analytics_logger.log_reputation_delta(npc_id, prev_score, snap.score, day, _analytics_scenario_id)
		_analytics_rep_snapshot[npc_id] = snap.score


func _on_analytics_scenario_resolved(
		scenario_id: int,
		state: ScenarioManager.ScenarioState
) -> void:
	if _analytics_logger == null:
		return
	var day: int = day_night.current_day if day_night != null and "current_day" in day_night else 0
	_analytics_logger.log_event("scenario_ended", {
		"scenario_id":   "scenario_%d" % scenario_id,
		"difficulty":    GameState.selected_difficulty,
		"outcome":       "WON" if state == ScenarioManager.ScenarioState.WON else "FAILED",
		"day_reached":   day,
		"duration_sec":  _analytics_logger.get_session_duration_seconds(),
	})


# ── Pause Menu ────────────────────────────────────────────────────────────────

func _init_pause_menu() -> void:
	_pause_menu = preload("res://scripts/pause_menu.gd").new()
	_pause_menu.name = "PauseMenu"
	add_child(_pause_menu)
	_pause_menu.setup(world.active_scenario_id)
	_pause_menu.setup_save_load(world, day_night, journal)
	_pause_menu.setup_tutorial(_tutorial_sys)
	# SPA-335: flush session time whenever the pause menu opens so partial
	# play time is saved if the player quits from the pause menu.
	_pause_menu.visibility_changed.connect(_on_pause_menu_visibility_changed_flush)
	# Suppress tutorial banner while pause menu is open (all scenarios).
	if _tutorial_banner != null:
		_pause_menu.visibility_changed.connect(_on_pause_menu_visibility_changed_banner)


# ── NPC Tooltip ───────────────────────────────────────────────────────────────

func _init_npc_tooltip() -> void:
	var tooltip := preload("res://scripts/npc_tooltip.gd").new()
	tooltip.name = "NpcTooltip"
	add_child(tooltip)
	tooltip.setup(world)
	var bldg_tooltip := preload("res://scripts/building_tooltip.gd").new()
	bldg_tooltip.name = "BuildingTooltip"
	add_child(bldg_tooltip)
	bldg_tooltip.setup(world)


## SPA-769: HUD tooltip overlay — reads tooltip_text from hovered Controls.
func _init_hud_tooltip() -> void:
	_hud_tooltip = preload("res://scripts/hud_tooltip.gd").new()
	_hud_tooltip.name = "HudTooltip"
	add_child(_hud_tooltip)


## SPA-767: Context-aware controls panel — replaces static ControlsPanel.
func _init_context_controls_panel() -> void:
	# Hide the static ControlsPanel from the scene tree.
	var hud_node: CanvasLayer = $HUD
	if hud_node != null:
		var static_panel: Panel = hud_node.get_node_or_null("ControlsPanel")
		if static_panel != null:
			static_panel.visible = false

	_context_controls = preload("res://scripts/context_controls_panel.gd").new()
	_context_controls.name = "ContextControlsPanel"
	add_child(_context_controls)
	if _controls_ref != null:
		_context_controls.setup(_controls_ref)


## Auto-save to slot 0 at the start of each new day (SPA-220).
func _on_new_day_auto_save(day: int) -> void:
	var err := SaveManager.save_game(world, day_night, journal, SaveManager.AUTO_SLOT, _tutorial_sys)
	if not err.is_empty():
		push_warning("[Main] Auto-save failed on day %d: %s" % [day, err])


## Relay scenario_resolved to feedback sequence (SPA-784) + AudioManager stings.
## Also persists scenario completion via ProgressData (SPA-137).
func _on_scenario_resolved_audio(scenario_id: int, state: ScenarioManager.ScenarioState) -> void:
	if state == ScenarioManager.ScenarioState.WON:
		# Persist the win so the main menu can unlock subsequent scenarios.
		var active_id: String = world.active_scenario_id if "active_scenario_id" in world else ("scenario_%d" % scenario_id)
		ProgressData.mark_completed(active_id)
		# SPA-784: Full victory feedback sequence (audio, vignette, particles,
		# banner, iris-out are handled inside the sequence).
		if _feedback_seq != null:
			_feedback_seq.play_victory(scenario_id)
		else:
			# Fallback if feedback sequence is not available.
			AudioManager.on_win()
			AudioManager.play_sfx("reputation_up")
			_camera_shake(6.0, 0.5)
			_play_win_celebration()
	elif state == ScenarioManager.ScenarioState.FAILED:
		# SPA-784: Full defeat feedback sequence (shudder, desaturation,
		# vignette, banner, hard cut are handled inside the sequence).
		if _feedback_seq != null:
			_feedback_seq.play_defeat(scenario_id)
		else:
			AudioManager.on_fail()
			_camera_shake(15.0, 0.6)


# ── SPA-272: Achievement hooks ────────────────────────────────────────────────

## Wire all per-session achievement signals.  Called once per game start.
func _init_achievement_hooks() -> void:
	# Scenario win/fail — drives all outcome-based achievements.
	var sm: ScenarioManager = world.scenario_manager
	if sm != null:
		sm.scenario_resolved.connect(_on_achievement_scenario_resolved)
		# SPA-335: record tutorial step completion at scenario end.
		sm.scenario_resolved.connect(_on_scenario_resolved_tutorial_steps)

	# Exposure tracking — ghost achievement.
	if _recon_ctrl_ref != null:
		_recon_ctrl_ref.player_exposed.connect(_on_achievement_player_exposed)
		# Observe / Eavesdrop action tracking.
		_recon_ctrl_ref.action_performed.connect(_on_achievement_action_performed)
		# Bribe tracking.
		_recon_ctrl_ref.bribe_executed.connect(_on_achievement_bribe_executed)

	# Craft Rumor tracking + first-rumor achievement.
	if rumor_panel != null:
		rumor_panel.rumor_seeded.connect(_on_achievement_rumor_seeded)


## Flags that the player was detected this session.
func _on_achievement_player_exposed() -> void:
	_ach_exposed = true


## Tracks Observe and Eavesdrop usage from action_performed messages.
func _on_achievement_action_performed(message: String, success: bool) -> void:
	if not success:
		return
	if message.begins_with("Observed"):
		_ach_actions_used["observe"] = true
	elif message.begins_with("Eavesdropped"):
		_ach_actions_used["eavesdrop"] = true


## Flags that Bribe was used at least once this session.
func _on_achievement_bribe_executed(_npc_name: String, _tick: int) -> void:
	_ach_actions_used["bribe"] = true


## Tracks Craft Rumor usage and unlocks "It Starts With a Whisper" on first seed.
func _on_achievement_rumor_seeded(
		_rumor_id: String,
		_subject_name: String,
		_claim_id: String,
		_seed_target_name: String
) -> void:
	_ach_actions_used["craft"] = true
	AchievementManager.unlock("a_rumor_begins")


## Central achievement evaluator called when a scenario resolves.
func _on_achievement_scenario_resolved(
		scenario_id: int,
		state: ScenarioManager.ScenarioState
) -> void:
	if state != ScenarioManager.ScenarioState.WON:
		return

	# Per-scenario completion.
	AchievementManager.unlock("scenario_%d_complete" % scenario_id)

	# Difficulty-based achievements.
	var diff: String = GameState.selected_difficulty
	if diff == "master":
		AchievementManager.unlock("master_victory")
	elif diff == "spymaster":
		AchievementManager.unlock("spymaster_victory")

	# Speed run: win within 10 days (inclusive).
	var current_day: int = day_night.current_day if day_night != null and "current_day" in day_night else 99
	if current_day <= 10:
		AchievementManager.unlock("speedrunner")

	# Ghost: won without any detection event.
	if not _ach_exposed:
		AchievementManager.unlock("ghost")

	# Jack of all trades: all four action types used.
	if (_ach_actions_used.has("observe") and _ach_actions_used.has("eavesdrop")
			and _ach_actions_used.has("craft") and _ach_actions_used.has("bribe")):
		AchievementManager.unlock("jack_of_all_trades")

	# Whisper network: 20+ unique NPCs received a rumor.
	if _analytics != null:
		var ranking: Array = _analytics.get_influence_ranking(9999)
		var recipients: int = 0
		for entry in ranking:
			if entry.get("received_count", 0) > 0:
				recipients += 1
		if recipients >= 20:
			AchievementManager.unlock("whisper_network")

	# Mastermind: all six scenarios completed (checks persisted unlock state).
	if (AchievementManager.is_unlocked("scenario_1_complete")
			and AchievementManager.is_unlocked("scenario_2_complete")
			and AchievementManager.is_unlocked("scenario_3_complete")
			and AchievementManager.is_unlocked("scenario_4_complete")
			and AchievementManager.is_unlocked("scenario_5_complete")
			and AchievementManager.is_unlocked("scenario_6_complete")):
		AchievementManager.unlock("mastermind")


# ── SPA-335: Demo analytics helpers ──────────────────────────────────────────

## Flush partial session time whenever the pause menu becomes visible.
## Only flushes on show (visible == true) so we don't double-count on hide.
func _on_pause_menu_visibility_changed_flush() -> void:
	if _pause_menu != null and _pause_menu.visible:
		PlayerStats.flush_session_time()


## Record tutorial step completion when a scenario resolves (SPA-335).
func _on_scenario_resolved_tutorial_steps(
		scenario_id: int,
		_state: ScenarioManager.ScenarioState
) -> void:
	if _tutorial_sys == null:
		return
	PlayerStats.record_tutorial_steps(
		"scenario_%d" % scenario_id,
		GameState.selected_difficulty,
		_tutorial_sys.get_seen_count(),
		TutorialSystem.TOOLTIP_DATA.size(),
	)


## Flush session time on window close so play time is not lost.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		PlayerStats.flush_session_time()
		get_tree().quit()


# ── Game-feel polish ──────────────────────────────────────────────────────────

## Trigger a camera shake if the Camera2D node is available.
func _camera_shake(intensity: float, duration: float) -> void:
	if camera != null and camera.has_method("shake_screen"):
		camera.shake_screen(intensity, duration)


## Tween-based gold particle burst played on scenario win (SPA-495).
## Spawns floating glyphs from screen centre and fades them out over 1.5 s.
func _play_win_celebration() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 25
	add_child(layer)
	var center := get_viewport().get_visible_rect().size * 0.5
	var symbols: Array = ["✦", "★", "✦", "★", "✦", "★", "✦", "★"]
	for sym in symbols:
		var lbl := Label.new()
		lbl.text = sym
		lbl.add_theme_font_size_override("font_size", 26)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.22, 1.0))
		lbl.position = center + Vector2(randf_range(-90.0, 90.0), randf_range(-50.0, 50.0))
		layer.add_child(lbl)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(lbl, "position",
			lbl.position + Vector2(randf_range(-70.0, 70.0), randf_range(-130.0, -50.0)), 1.5)
		tw.tween_property(lbl, "modulate:a", 0.0, 1.5)
	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
	)
