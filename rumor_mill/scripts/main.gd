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

# ── SPA-1002: Tutorial wiring (extracted to TutorialWiring) ──────────────────
var _tutorial_wiring: TutorialWiring = null

# ── Sprint 6: end screen (created programmatically) ───────────────────────────
var _end_screen: CanvasLayer = null

# ── SPA-784: Victory/defeat feedback sequence ────────────────────────────────
var _feedback_seq: CanvasLayer = null

# ── SPA-841: Consolidated Mission Briefing screen (game-start + recall) ──────
var _mission_briefing: CanvasLayer = null

# ── SPA-560: Mid-game narrative event choice modal ───────────���───────────────
var _event_choice_modal: CanvasLayer = null

# ── SPA-953: Faction event card overlay with screen dim ─────────────────────
var _event_card: CanvasLayer = null

# ── SPA-589: Visual affordances for new players ──────────────────────────────
var _visual_affordances: CanvasLayer = null


# ── SPA-709: Milestone reward notification popup ──────────────────────────────
var _milestone_notifier: CanvasLayer = null

# ── SPA-769: HUD tooltip overlay and context controls panel ──────────────────
var _hud_tooltip: CanvasLayer = null
var _context_controls: CanvasLayer = null

# ── SPA-872: NPC quick-info panel and Tab NPC cycling ─────────────────────────
var _npc_info_panel: CanvasLayer = null

# ── SPA-1002: Input dispatch (extracted to GameInputHandler) ─────────────────
var _input_handler: GameInputHandler = null

# ── SPA-589: Story recap overlay (shown on save load) ─────────────────────────
var _story_recap: CanvasLayer = null

# ── SPA-708: Daily planning overlay (dawn priorities) ─────────────────────────
var _daily_planning: CanvasLayer = null

# ── SPA-212: Analytics data collector ─────────────────────────────────────────
var _analytics: ScenarioAnalytics = null

# ── SPA-244 / SPA-994: Analytics logger signal wiring ────────────────────────
var _analytics_manager: AnalyticsManager = null


# Cached ReconController reference for post-tutorial-init wiring.
var _recon_ctrl_ref: Node = null

# ── SPA-1002: Rumor event wiring (extracted to RumorEventWiring) ──────────────
var _rumor_event_wiring: RumorEventWiring = null

# Guards against double-initialisation if begin_game fires more than once.
var _game_started: bool = false

# ── SPA-995: Help-reminder UI, thought legend, and controls reference ─────────
var _help_ui: HelpReminderUI = null

# ── SPA-272 / SPA-988: Achievement hooks module ───────────────────────────────
var _achievement_hooks: AchievementHooks = null


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
	# Restore main-menu music on scene reload (AudioManager persists across reloads
	# so its _ready() won't re-run; crossfade from any in-game phase music back to
	# the title theme here).
	AudioManager.play_music("main_theme", true)


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
	# SPA-925: Apply scenario-specific environment mood tint (2 s fade-in).
	if world.town_mood_controller != null:
		world.town_mood_controller.apply_scenario_mood(scenario_id)
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
	_init_event_choice_modal()
	_init_event_card()
	_init_objective_hud()
	_init_daily_planning()
	_init_speed_hud()
	_init_zone_indicator()
	_init_rumor_tracker_hud()
	_init_npc_conversation_overlay()
	_init_scenario1_hud()
	_init_scenario2_hud()
	_init_scenario3_hud()
	_init_scenario4_hud()
	_init_scenario5_hud()
	_init_scenario6_hud()
	# SPA-1002: Tutorial wiring — must run after _init_recon_system caches _recon_ctrl_ref.
	_tutorial_wiring = TutorialWiring.new()
	_tutorial_wiring.name = "TutorialWiring"
	add_child(_tutorial_wiring)
	_tutorial_wiring.setup(
		world, day_night, camera, recon_hud, rumor_panel,
		journal, _visual_affordances, _recon_ctrl_ref
	)
	# HelpReminderUI stays in main.gd — it's referenced by _init_context_controls_panel.
	_help_ui = HelpReminderUI.new()
	add_child(_help_ui)
	_help_ui.setup(self, day_night)
	_init_end_screen()
	_init_audio()
	_init_analytics_logger(scenario_id)
	_init_achievement_hooks()
	_init_pause_menu()
	_init_npc_tooltip()
	_init_hud_tooltip()
	_init_context_controls_panel()
	_init_visual_affordances()
	_init_npc_info_panel()
	# SPA-1002: Input dispatch — must run after all panels are created.
	_input_handler = GameInputHandler.new()
	_input_handler.name = "GameInputHandler"
	add_child(_input_handler)
	_input_handler.setup(
		world, camera, day_night, rumor_panel, journal, social_graph_overlay,
		_npc_info_panel, _tutorial_wiring.tutorial_banner if _tutorial_wiring != null else null, _context_controls
	)
	_input_handler.objective_recall_requested.connect(_show_objective_recall)
	# SPA-1002: Rumor event wiring — must run after milestone notifier + daily planning.
	_rumor_event_wiring = RumorEventWiring.new()
	_rumor_event_wiring.name = "RumorEventWiring"
	add_child(_rumor_event_wiring)
	_rumor_event_wiring.setup(
		world, day_night, camera, journal, recon_hud, rumor_panel,
		social_graph_overlay, objective_hud, _milestone_notifier,
		_daily_planning, _recon_ctrl_ref
	)
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
		SaveManager.apply_pending_load(world, day_night, journal, _tutorial_wiring.tutorial_sys if _tutorial_wiring != null else null)

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
			# SPA-944: 12-second deferred hint pointing non-guided S1 players to
			# the amber crest above Edric.  Guided-tutorial players see ▼ TARGET
			# + gtut_explore hint instead, so they are excluded in the callback.
			if world != null and world.active_scenario_id == "scenario_1" \
					and _tutorial_wiring != null and _tutorial_wiring.tutorial_banner != null:
				get_tree().create_timer(12.0).timeout.connect(func() -> void:
					if _tutorial_wiring._tutorial_ctrl == null or not _tutorial_wiring._tutorial_ctrl.guided_tutorial_active:
						_tutorial_wiring.tutorial_banner.queue_hint("hint_s1_find_target")
				)

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

	# SPA-1002: Onboarding flow delegated to TutorialWiring.
	if _tutorial_wiring != null:
		_tutorial_wiring.start_onboarding(world.active_scenario_id)


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
	# SPA-910: wire world reference so each interior can show the NPC roster.
	for loc_id in _interiors:
		_interiors[loc_id].setup_world_ref(world, loc_id)
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

	# Cache ref so TutorialWiring.setup() can wire recon signals.
	_recon_ctrl_ref = recon_ctrl

	# Pipe action results to AudioManager (recon SFX).
	recon_ctrl.action_performed.connect(AudioManager.on_recon_action)

	# Pipe bribe events to AudioManager (coin SFX).
	recon_ctrl.bribe_executed.connect(AudioManager.on_bribe_executed)

	# Wire eavesdrop exposure → ScenarioManager fail trigger (Scenario 1).
	recon_ctrl.player_exposed.connect(_on_player_exposed)


## Connected to recon_ctrl.player_exposed — triggers Scenario 1 exposure fail.
func _on_player_exposed() -> void:
	if world != null and world.scenario_manager != null:
		world.scenario_manager.on_player_exposed()


func _init_journal() -> void:
	if journal == null:
		push_error("Main: $Journal node not found — journal not wired")
		return

	var intel_store: PlayerIntelStore = world.intel_store
	if journal.has_method("setup"):
		journal.setup(world, intel_store, day_night)



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


## SPA-953: Faction event card overlay — shows parchment card + dim on event_activated.
func _init_event_card() -> void:
	if world == null or world.faction_event_system == null:
		return
	_event_card = preload("res://scripts/event_card.gd").new()
	_event_card.name = "EventCard"
	add_child(_event_card)
	world.faction_event_system.event_activated.connect(
		func(label: String, description: String, day: int) -> void:
			_event_card.show_event(label, description, day)
	)


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


func _init_rumor_tracker_hud() -> void:
	var hud := preload("res://scripts/rumor_tracker_hud.gd").new()
	hud.name = "RumorTrackerHUD"
	add_child(hud)
	if hud.has_method("setup"):
		hud.setup(world, day_night)


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
		if _rumor_event_wiring != null and not world.scenario_manager.s1_first_blood.is_connected(_rumor_event_wiring.on_s1_first_blood):
			world.scenario_manager.s1_first_blood.connect(_rumor_event_wiring.on_s1_first_blood)


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
	# SPA-928: Clear heat tension carried over from a previous session.
	# AudioManager is an autoload singleton that persists across scene reloads;
	# reset before wiring any new signals so restarts start with a clean state.
	AudioManager.set_heat_ambient_tension(false)

	# Connect ambient crossfade + new_day SFX to the day/night clock.
	AudioManager.connect_to_day_night(day_night)

	# Connect scenario win/fail events so AudioManager can play stings.
	var sm: ScenarioManager = world.scenario_manager
	if sm != null:
		sm.scenario_resolved.connect(_on_scenario_resolved_audio)

	# Reputation collapse SFX: play reputation_down when an NPC goes socially dead.
	world.socially_dead_triggered.connect(AudioManager.on_socially_dead)

	# Whisper spend SFX: whisper on each whisper token spend (SPA-917).
	if world.intel_store != null:
		world.intel_store.whisper_spent.connect(func() -> void: AudioManager.play_sfx("whisper"))
		# SPA-917: Heat tension ambient — lower ambient dB when heat warning fires (fires once).
		world.intel_store.heat_warning.connect(func() -> void: AudioManager.set_heat_ambient_tension(true))



# ── SPA-244: Local analytics logger ──────────────────────────────────────────

func _init_analytics_logger(scenario_id: String) -> void:
	_analytics_manager = AnalyticsManager.new()
	_analytics_manager.setup(scenario_id, world, day_night, rumor_panel, _recon_ctrl_ref)


# ── Pause Menu ────────────────────────────────────────────────────────────────

func _init_pause_menu() -> void:
	_pause_menu = preload("res://scripts/pause_menu.gd").new()
	_pause_menu.name = "PauseMenu"
	add_child(_pause_menu)
	_pause_menu.setup(world.active_scenario_id)
	_pause_menu.setup_save_load(world, day_night, journal)
	_pause_menu.setup_tutorial(_tutorial_wiring.tutorial_sys if _tutorial_wiring != null else null)
	# SPA-335: flush session time whenever the pause menu opens so partial
	# play time is saved if the player quits from the pause menu.
	_pause_menu.visibility_changed.connect(_on_pause_menu_visibility_changed_flush)
	# Suppress tutorial banner while pause menu is open (all scenarios).
	if _tutorial_wiring != null:
		_tutorial_wiring.wire_pause_menu(_pause_menu)


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
	if _help_ui != null and _help_ui.controls_ref != null:
		_context_controls.setup(_help_ui.controls_ref)


## SPA-872: NPC quick-info panel (shown on Tab cycle or NPC selection).
func _init_npc_info_panel() -> void:
	_npc_info_panel = preload("res://scripts/npc_info_panel.gd").new()
	_npc_info_panel.name = "NpcInfoPanel"
	add_child(_npc_info_panel)
	if world != null and world.intel_store != null:
		_npc_info_panel.setup(world, world.intel_store)
	# Wire action_requested so the panel can trigger recon/rumor actions.
	_npc_info_panel.action_requested.connect(_on_npc_info_action)


## Handle action shortcuts triggered from the NPC info panel.
func _on_npc_info_action(action_key: String, npc: Node2D) -> void:
	match action_key:
		"eavesdrop":
			# Right-click on the NPC is the canonical path; here we programmatically
			# open the dialogue panel if it exists and pre-select eavesdrop.
			if _npc_info_panel != null:
				_npc_info_panel.hide_panel()
			var recon_ctrl: Node = get_node_or_null("World/ReconController")
			if recon_ctrl != null and recon_ctrl.has_method("_try_eavesdrop"):
				recon_ctrl._try_eavesdrop(npc)
		"bribe":
			if _npc_info_panel != null:
				_npc_info_panel.hide_panel()
			var recon_ctrl: Node = get_node_or_null("World/ReconController")
			if recon_ctrl != null and recon_ctrl.has_method("_try_bribe"):
				recon_ctrl._try_bribe(npc)
		"seed":
			# Open the rumor panel — player picks seed target from there.
			if rumor_panel != null and rumor_panel.has_method("toggle"):
				if not rumor_panel.visible:
					rumor_panel.toggle()


## Auto-save to slot 0 at the start of each new day (SPA-220).
func _on_new_day_auto_save(day: int) -> void:
	var err := SaveManager.save_game(world, day_night, journal, SaveManager.AUTO_SLOT, _tutorial_wiring.tutorial_sys if _tutorial_wiring != null else null)
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


# ── SPA-272 / SPA-988: Achievement hooks ─────────────────────────────────────

## Instantiate AchievementHooks and wire all per-session achievement signals.
## Called once per game start.
func _init_achievement_hooks() -> void:
	_achievement_hooks = AchievementHooks.new()
	_achievement_hooks.day_night = day_night
	_achievement_hooks.analytics = _analytics
	var sm: ScenarioManager = world.scenario_manager
	_achievement_hooks.connect_signals(sm, _recon_ctrl_ref, rumor_panel)
	# SPA-335: record tutorial step completion at scenario end.
	if sm != null:
		sm.scenario_resolved.connect(_on_scenario_resolved_tutorial_steps)


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
	var tut_sys: TutorialSystem = _tutorial_wiring.tutorial_sys if _tutorial_wiring != null else null
	if tut_sys == null:
		return
	PlayerStats.record_tutorial_steps(
		"scenario_%d" % scenario_id,
		GameState.selected_difficulty,
		tut_sys.get_seen_count(),
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
