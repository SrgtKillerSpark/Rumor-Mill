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
##
## SPA-1007: HUD/overlay lifecycle delegated to UILayerManager.

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

# ── Pre-game overlays ────────────────────────────────────────────────────────
var _main_menu:    CanvasLayer = null
var _loading_tips: CanvasLayer = null

# ── Game-flow overlays (created conditionally during play) ───────────────────
var _mission_briefing: CanvasLayer = null
var _story_recap:      CanvasLayer = null

# ── SPA-1007: UILayerManager owns all in-game HUD/overlay lifecycle ──────────
var _ui: UILayerManager = null

# Guards against double-initialisation if begin_game fires more than once.
var _game_started: bool = false


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

	# SPA-1544: Reset day/tick counters — DayNightCycle timer runs during the
	# main menu and would otherwise report current_day > 1 at scenario start.
	# Also clear SaveManager session-load flag so fresh games never appear as
	# loaded saves to TutorialController and other consumers.
	day_night.reset_for_new_game()
	SaveManager.clear_new_game_statics()

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

	# ── Wire core game systems ────────────────────────────────────────────────
	# Drive NPC ticks from the day/night cycle.
	day_night.game_tick.connect(world.on_game_tick)
	# SPA-786: Pass total days to day/night cycle for dawn banner display.
	if world.scenario_manager != null:
		day_night.days_allowed = world.scenario_manager.get_days_allowed()

	# SPA-695: Give TownMoodController the camera so it can shake on milestones.
	if world.town_mood_controller != null and camera != null:
		world.town_mood_controller.set_camera(camera)
	# SPA-925: Apply scenario-specific environment mood tint (2 s fade-in).
	if world.town_mood_controller != null:
		world.town_mood_controller.apply_scenario_mood(scenario_id)

	# ── SPA-1007: Delegate all HUD/overlay creation to UILayerManager ────────
	_ui = UILayerManager.new()
	_ui.name = "UILayerManager"
	add_child(_ui)
	_ui.setup_all(
		self, world, day_night, camera, recon_hud, rumor_panel,
		journal, social_graph_overlay, objective_hud,
		debug_overlay, debug_console, scenario_id
	)

	# Wire milestone tracker callback to the new notifier.
	if world.milestone_tracker != null and _ui.milestone_notifier != null:
		var _sid: int = int(scenario_id.trim_prefix("scenario_"))
		world.milestone_tracker.setup(
			_sid,
			world.reputation_system,
			world.scenario_manager,
			world.intel_store,
			_ui.milestone_notifier.show_milestone
		)

	# Connect signals that relay to main.gd game-flow handlers.
	_ui.input_handler.objective_recall_requested.connect(_show_objective_recall)
	var sm: ScenarioManager = world.scenario_manager
	if sm != null:
		sm.scenario_resolved.connect(_on_scenario_resolved_audio)

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
		SaveManager.apply_pending_load(world, day_night, journal, _ui.tutorial_wiring.tutorial_sys if _ui.tutorial_wiring != null else null)

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
					and _ui != null and _ui.tutorial_wiring != null and _ui.tutorial_wiring.tutorial_banner != null:
				get_tree().create_timer(12.0).timeout.connect(func() -> void:
					if _ui.tutorial_wiring._tutorial_ctrl == null or not _ui.tutorial_wiring._tutorial_ctrl.guided_tutorial_active:
						_ui.tutorial_wiring.tutorial_banner.queue_hint("hint_s1_find_target")
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
	if _ui != null and _ui.tutorial_wiring != null:
		_ui.tutorial_wiring.start_onboarding(world.active_scenario_id)


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
	if _ui != null and _ui.event_choice_modal != null and _ui.event_choice_modal.visible:
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


## Auto-save to slot 0 at the start of each new day (SPA-220).
func _on_new_day_auto_save(day: int) -> void:
	var err := SaveManager.save_game(world, day_night, journal, SaveManager.AUTO_SLOT, _ui.tutorial_wiring.tutorial_sys if _ui != null and _ui.tutorial_wiring != null else null)
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
		if _ui != null and _ui.feedback_seq != null:
			_ui.feedback_seq.play_victory(scenario_id)
		else:
			# Fallback if feedback sequence is not available.
			AudioManager.on_win()
			AudioManager.play_sfx("reputation_up")
			_camera_shake(6.0, 0.5)
			_play_win_celebration()
	elif state == ScenarioManager.ScenarioState.FAILED:
		# SPA-784: Full defeat feedback sequence (shudder, desaturation,
		# vignette, banner, hard cut are handled inside the sequence).
		if _ui != null and _ui.feedback_seq != null:
			_ui.feedback_seq.play_defeat(scenario_id)
		else:
			AudioManager.on_fail()
			_camera_shake(15.0, 0.6)


## Flush session time on window close so play time is not lost.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		PlayerStats.flush_session_time()
		get_tree().quit()


# ── Game-feel polish ─────────────────────────────────────────────────────────

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
