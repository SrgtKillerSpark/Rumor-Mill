class_name UILayerManager
extends Node

## UILayerManager — owns all in-game HUD/overlay node lifecycle.
## Extracted from main.gd (SPA-1007) to reduce its line count and centralise
## overlay creation, setup, and teardown.
##
## main.gd creates this node once in _on_begin_game and calls setup_all().
## Signal connections that drive game-flow logic remain in main.gd; this class
## only handles node ownership and per-overlay initialisation.

# ── Scene references (set in setup_all) ──────────────────────────────────────
var _parent: Node = null
var _world: Node2D = null
var _day_night: Node = null
var _camera: Camera2D = null
var _recon_hud: CanvasLayer = null
var _rumor_panel: CanvasLayer = null
var _journal: CanvasLayer = null
var _social_graph_overlay: CanvasLayer = null
var _objective_hud: CanvasLayer = null
var _debug_overlay: CanvasLayer = null
var _debug_console: CanvasLayer = null

# ── Public overlay references (read by main.gd after setup) ─────────────────
var tutorial_wiring: TutorialWiring = null
var input_handler: GameInputHandler = null
var rumor_event_wiring: RumorEventWiring = null
var milestone_notifier: CanvasLayer = null
var feedback_seq: CanvasLayer = null
var event_choice_modal: CanvasLayer = null
var recon_ctrl_ref: Node = null

# ── Private overlay references ───────────────────────────────────────────────
var _pause_menu: CanvasLayer = null
var _end_screen: CanvasLayer = null
var _event_card: CanvasLayer = null
var _visual_affordances: CanvasLayer = null
var _milestone_notifier: CanvasLayer = null
var _hud_tooltip: CanvasLayer = null
var _context_controls: CanvasLayer = null
var _npc_info_panel: CanvasLayer = null
var _daily_planning: CanvasLayer = null
var _help_ui: HelpReminderUI = null
var _analytics: ScenarioAnalytics = null
var _analytics_manager: AnalyticsManager = null
var _achievement_hooks: AchievementHooks = null


## Create and wire every in-game HUD/overlay node.
## Called once from main.gd._on_begin_game after the world is activated.
func setup_all(
	parent: Node,
	world: Node2D,
	day_night: Node,
	camera: Camera2D,
	recon_hud: CanvasLayer,
	rumor_panel: CanvasLayer,
	journal: CanvasLayer,
	social_graph_overlay: CanvasLayer,
	objective_hud: CanvasLayer,
	debug_overlay: CanvasLayer,
	debug_console: CanvasLayer,
	scenario_id: String,
) -> void:
	_parent = parent
	_world = world
	_day_night = day_night
	_camera = camera
	_recon_hud = recon_hud
	_rumor_panel = rumor_panel
	_journal = journal
	_social_graph_overlay = social_graph_overlay
	_objective_hud = objective_hud
	_debug_overlay = debug_overlay
	_debug_console = debug_console

	# ── Debug/overlay world refs ─────────────────────────────────────────────
	if _debug_overlay != null and _debug_overlay.has_method("set_world"):
		_debug_overlay.set_world(_world)
	if _social_graph_overlay != null and _social_graph_overlay.has_method("set_world"):
		_social_graph_overlay.set_world(_world)
	if _debug_console != null:
		if _debug_console.has_method("set_world"):
			_debug_console.set_world(_world)
		if _debug_console.has_method("set_overlay"):
			_debug_console.set_overlay(_debug_overlay)

	_init_recon_system()
	# SPA-695: Give TownMoodController the camera so it can shake on milestones.
	_init_journal()

	# SPA-709: Milestone notifier — must be created after journal is ready.
	milestone_notifier = preload("res://scripts/milestone_notifier.gd").new()
	milestone_notifier.name = "MilestoneNotifier"
	_parent.add_child(milestone_notifier)
	if milestone_notifier.has_method("setup"):
		milestone_notifier.setup(_journal, _world.intel_store, _objective_hud)

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

	# SPA-1002: Tutorial wiring — must run after _init_recon_system caches recon_ctrl_ref.
	tutorial_wiring = TutorialWiring.new()
	tutorial_wiring.name = "TutorialWiring"
	_parent.add_child(tutorial_wiring)
	tutorial_wiring.setup(
		_world, _day_night, _camera, _recon_hud, _rumor_panel,
		_journal, _visual_affordances, recon_ctrl_ref
	)

	# HelpReminderUI stays referenced by _init_context_controls_panel.
	_help_ui = HelpReminderUI.new()
	_parent.add_child(_help_ui)
	_help_ui.setup(_parent, _day_night)

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
	input_handler = GameInputHandler.new()
	input_handler.name = "GameInputHandler"
	_parent.add_child(input_handler)
	input_handler.setup(
		_world, _camera, _day_night, _rumor_panel, _journal, _social_graph_overlay,
		_npc_info_panel, tutorial_wiring.tutorial_banner if tutorial_wiring != null else null, _context_controls
	)

	# SPA-1002: Rumor event wiring — must run after milestone notifier + daily planning.
	rumor_event_wiring = RumorEventWiring.new()
	rumor_event_wiring.name = "RumorEventWiring"
	_parent.add_child(rumor_event_wiring)
	rumor_event_wiring.setup(
		_world, _day_night, _camera, _journal, _recon_hud, _rumor_panel,
		_social_graph_overlay, _objective_hud, milestone_notifier,
		_daily_planning, recon_ctrl_ref
	)

	# SPA-805: Wire s1 first blood (must be after rumor_event_wiring creation).
	if _world.active_scenario_id == "scenario_1" and rumor_event_wiring != null:
		if _world.scenario_manager != null and _world.scenario_manager.has_signal("s1_first_blood"):
			if not _world.scenario_manager.s1_first_blood.is_connected(rumor_event_wiring.on_s1_first_blood):
				_world.scenario_manager.s1_first_blood.connect(rumor_event_wiring.on_s1_first_blood)


# ── Overlay init helpers ─────────────────────────────────────────────────────

func _init_recon_system() -> void:
	var intel_store: PlayerIntelStore = _world.intel_store
	if intel_store == null:
		push_error("UILayerManager: world.intel_store is null — recon system not wired")
		return

	# ReconHUD: shows action counter + toasts; opens RumorPanel on R.
	if _recon_hud != null and _recon_hud.has_method("setup"):
		_recon_hud.setup(intel_store, _rumor_panel)
	if _recon_hud != null and _recon_hud.has_method("setup_hints"):
		_recon_hud.setup_hints(_world)
	if _recon_hud != null and _recon_hud.has_method("setup_feed"):
		_recon_hud.setup_feed(_journal, _day_night)

	# RumorPanel: 3-panel crafting modal (Subject -> Claim -> Seed Target).
	if _rumor_panel != null and _rumor_panel.has_method("setup"):
		_rumor_panel.setup(_world, intel_store)

	# ReconController: input handler — created programmatically so it sits in
	# the scene tree and receives _unhandled_input events.
	var recon_ctrl: Node = preload("res://scripts/recon_controller.gd").new()
	recon_ctrl.name = "ReconController"
	_parent.add_child(recon_ctrl)
	recon_ctrl.setup(_world, intel_store)

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
		_parent.add_child(interior)
		_interiors[loc_id] = interior
		# Location ambient: crossfade when interior opens/closes (SPA-491).
		var _loc: String = loc_id  # capture loop variable for closure
		interior.interior_opened.connect(func() -> void: AudioManager.set_location_ambient(_loc))
		interior.interior_closed.connect(AudioManager.clear_location_ambient)
	# SPA-910: wire world reference so each interior can show the NPC roster.
	for loc_id in _interiors:
		_interiors[loc_id].setup_world_ref(_world, loc_id)
	recon_ctrl.set_interiors(_interiors)

	# SPA-683: NPC conversation dialogue panel — created programmatically so it
	# sits above the hover tooltip layer but below the RumorPanel.
	var npc_dialogue_panel: Node = preload("res://scripts/npc_dialogue_panel.gd").new()
	npc_dialogue_panel.name = "NpcDialoguePanel"
	_parent.add_child(npc_dialogue_panel)
	npc_dialogue_panel.setup(_world, intel_store, _rumor_panel)
	recon_ctrl.set_dialogue_panel(npc_dialogue_panel)
	# "Seed Rumor" in the dialogue panel opens the rumor crafting panel (if not
	# already open). The inner Panel node named "Panel" tracks open/close state.
	npc_dialogue_panel.seed_rumor_requested.connect(
		func() -> void:
			if _rumor_panel == null or not _rumor_panel.has_method("toggle"):
				return
			var inner: Node = _rumor_panel.get_node_or_null("Panel")
			if inner == null or not inner.visible:
				_rumor_panel.toggle()
	)

	# Pipe action results to the HUD toast and recent-actions feed.
	if _recon_hud != null and _recon_hud.has_method("show_toast"):
		recon_ctrl.action_performed.connect(_recon_hud.show_toast)
	if _recon_hud != null and _recon_hud.has_method("push_feed_entry"):
		recon_ctrl.action_performed.connect(_recon_hud.push_feed_entry)

	# Cache ref so TutorialWiring.setup() can wire recon signals.
	recon_ctrl_ref = recon_ctrl

	# Pipe action results to AudioManager (recon SFX).
	recon_ctrl.action_performed.connect(AudioManager.on_recon_action)

	# Pipe bribe events to AudioManager (coin SFX).
	recon_ctrl.bribe_executed.connect(AudioManager.on_bribe_executed)

	# Wire eavesdrop exposure -> ScenarioManager fail trigger (Scenario 1).
	recon_ctrl.player_exposed.connect(_on_player_exposed)


## Connected to recon_ctrl.player_exposed — triggers Scenario 1 exposure fail.
func _on_player_exposed() -> void:
	if _world != null and _world.scenario_manager != null:
		_world.scenario_manager.on_player_exposed()


func _init_journal() -> void:
	if _journal == null:
		push_error("UILayerManager: $Journal node not found — journal not wired")
		return
	var intel_store: PlayerIntelStore = _world.intel_store
	if _journal.has_method("setup"):
		_journal.setup(_world, intel_store, _day_night)


## SPA-560: Mid-game narrative event choice modal.
func _init_event_choice_modal() -> void:
	if _world == null or _world.mid_game_event_agent == null:
		return
	event_choice_modal = preload("res://scripts/event_choice_modal.gd").new()
	event_choice_modal.name = "EventChoiceModal"
	_parent.add_child(event_choice_modal)

	var agent: MidGameEventAgent = _world.mid_game_event_agent
	agent.event_presented.connect(_on_mid_game_event_presented)
	event_choice_modal.choice_made.connect(_on_mid_game_event_choice_made)
	event_choice_modal.dismissed.connect(_on_mid_game_event_dismissed)


## SPA-953: Faction event card overlay — shows parchment card + dim on event_activated.
func _init_event_card() -> void:
	if _world == null or _world.faction_event_system == null:
		return
	_event_card = preload("res://scripts/event_card.gd").new()
	_event_card.name = "EventCard"
	_parent.add_child(_event_card)
	_world.faction_event_system.event_activated.connect(
		func(label: String, description: String, day: int) -> void:
			_event_card.show_event(label, description, day)
	)


func _on_mid_game_event_presented(event_data: Dictionary) -> void:
	if event_choice_modal == null:
		return
	event_choice_modal.present_event(event_data)
	# Journal entry.
	var event_name: String = str(event_data.get("name", "Event"))
	if _journal != null and _journal.has_method("push_timeline_event"):
		var tick: int = _day_night.current_tick if _day_night != null else 0
		_journal.push_timeline_event(tick, "[EVENT] %s" % event_name)
	# Toast notification.
	if _recon_hud != null and _recon_hud.has_method("show_milestone"):
		_recon_hud.show_milestone("Event: %s" % event_name, Color(0.92, 0.78, 0.12, 1.0))


func _on_mid_game_event_choice_made(event_id: String, choice_index: int) -> void:
	if _world == null or _world.mid_game_event_agent == null:
		return
	var agent: MidGameEventAgent = _world.mid_game_event_agent
	agent.resolve_choice(event_id, choice_index)
	# The agent emits event_resolved with outcome text — show it in the modal.
	# We connect this lazily to avoid permanent connection.
	if not agent.event_resolved.is_connected(_on_mid_game_event_resolved):
		agent.event_resolved.connect(_on_mid_game_event_resolved)


func _on_mid_game_event_resolved(_event_id: String, _choice_index: int, outcome_text: String) -> void:
	if event_choice_modal != null:
		event_choice_modal.show_outcome(outcome_text)
	# Journal entry for the outcome.
	if _journal != null and _journal.has_method("push_timeline_event"):
		var tick: int = _day_night.current_tick if _day_night != null else 0
		_journal.push_timeline_event(tick, "[OUTCOME] %s" % outcome_text.substr(0, 80))


func _on_mid_game_event_dismissed() -> void:
	pass  # Modal handles unpausing; nothing extra needed.


func _init_objective_hud() -> void:
	if _objective_hud == null:
		push_error("UILayerManager: $ObjectiveHUD node not found — objective HUD not wired")
		return
	var sm: ScenarioManager = _world.scenario_manager
	if sm == null:
		push_error("UILayerManager: world.scenario_manager is null — objective HUD not wired")
		return
	if _objective_hud.has_method("setup"):
		_objective_hud.setup(sm, _day_night, _world.reputation_system, _world.intel_store)
	if _objective_hud.has_method("setup_world"):
		_objective_hud.setup_world(_world)


func _init_daily_planning() -> void:
	_daily_planning = preload("res://scenes/DailyPlanningOverlay.tscn").instantiate()
	_daily_planning.name = "DailyPlanningOverlay"
	_parent.add_child(_daily_planning)
	if _daily_planning.has_method("setup"):
		_daily_planning.setup(_world, _day_night, _objective_hud)


func _init_speed_hud() -> void:
	var hud := preload("res://scripts/speed_hud.gd").new()
	hud.name = "SpeedHUD"
	_parent.add_child(hud)
	if hud.has_method("setup"):
		hud.setup(_day_night, _world.intel_store if _world != null else null)
	# SPA-757: Refresh End Day button visibility each tick.
	if _day_night != null and hud.has_method("on_game_tick"):
		_day_night.game_tick.connect(hud.on_game_tick)


func _init_zone_indicator() -> void:
	var zi := preload("res://scripts/zone_indicator.gd").new()
	zi.name = "ZoneIndicator"
	_parent.add_child(zi)
	if zi.has_method("setup"):
		zi.setup(_world, _camera)


func _init_rumor_tracker_hud() -> void:
	var hud := preload("res://scripts/rumor_tracker_hud.gd").new()
	hud.name = "RumorTrackerHUD"
	_parent.add_child(hud)
	if hud.has_method("setup"):
		hud.setup(_world, _day_night)


func _init_npc_conversation_overlay() -> void:
	var overlay := preload("res://scripts/npc_conversation_overlay.gd").new()
	overlay.name = "NpcConversationOverlay"
	_parent.add_child(overlay)
	if overlay.has_method("setup"):
		overlay.setup(_world)


func _init_scenario1_hud() -> void:
	if _world.active_scenario_id != "scenario_1":
		return
	var hud := preload("res://scripts/scenario1_hud.gd").new()
	hud.name = "Scenario1HUD"
	_parent.add_child(hud)
	if hud.has_method("setup"):
		hud.setup(_world, _day_night)
	# NOTE: SPA-805 s1_first_blood wiring moved to setup_all() after
	# rumor_event_wiring creation to fix ordering dependency.


func _init_scenario2_hud() -> void:
	if _world.active_scenario_id != "scenario_2":
		return
	var hud := preload("res://scripts/scenario2_hud.gd").new()
	hud.name = "Scenario2HUD"
	_parent.add_child(hud)
	if hud.has_method("setup"):
		hud.setup(_world, _day_night)


func _init_scenario3_hud() -> void:
	if _world.active_scenario_id != "scenario_3":
		return
	# Build the Scenario 3 dual-track HUD programmatically (no .tscn required).
	var hud := preload("res://scripts/scenario3_hud.gd").new()
	hud.name = "Scenario3HUD"
	_parent.add_child(hud)
	if hud.has_method("setup"):
		hud.setup(_world, _day_night)


func _init_scenario4_hud() -> void:
	if _world.active_scenario_id != "scenario_4":
		return
	var hud := preload("res://scripts/scenario4_hud.gd").new()
	hud.name = "Scenario4HUD"
	_parent.add_child(hud)
	if hud.has_method("setup"):
		hud.setup(_world, _day_night)


func _init_scenario5_hud() -> void:
	if _world.active_scenario_id != "scenario_5":
		return
	var hud := preload("res://scripts/scenario5_hud.gd").new()
	hud.name = "Scenario5HUD"
	_parent.add_child(hud)
	if hud.has_method("setup"):
		hud.setup(_world, _day_night)


func _init_scenario6_hud() -> void:
	if _world.active_scenario_id != "scenario_6":
		return
	var hud := preload("res://scripts/scenario6_hud.gd").new()
	hud.name = "Scenario6HUD"
	_parent.add_child(hud)
	if hud.has_method("setup"):
		hud.setup(_world, _day_night)


# ── Sprint 6: End Screen ─────────────────────────────────────────────────────

func _init_end_screen() -> void:
	# SPA-212: Create analytics collector and wire to world signals.
	_analytics = ScenarioAnalytics.new()
	_analytics.setup(_world, _day_night)

	_end_screen = preload("res://scripts/end_screen.gd").new()
	_end_screen.name = "EndScreen"
	_parent.add_child(_end_screen)
	_end_screen.setup(_world, _day_night, _analytics)

	# SPA-784: Feedback sequence (runs before end screen appears).
	feedback_seq = preload("res://scripts/feedback_sequence.gd").new()
	feedback_seq.name = "FeedbackSequence"
	_parent.add_child(feedback_seq)
	feedback_seq.setup(_camera, _day_night, _world)


# ── Sprint 7: Audio ──────────────────────────────────────────────────────────

func _init_audio() -> void:
	# SPA-928: Clear heat tension carried over from a previous session.
	AudioManager.set_heat_ambient_tension(false)

	# Connect ambient crossfade + new_day SFX to the day/night clock.
	AudioManager.connect_to_day_night(_day_night)

	# NOTE: sm.scenario_resolved -> _on_scenario_resolved_audio is connected
	# in main.gd after setup_all() because the callback lives there.

	# Reputation collapse SFX: play reputation_down when an NPC goes socially dead.
	_world.socially_dead_triggered.connect(AudioManager.on_socially_dead)

	# Whisper spend SFX: whisper on each whisper token spend (SPA-917).
	if _world.intel_store != null:
		_world.intel_store.whisper_spent.connect(func() -> void: AudioManager.play_sfx("whisper"))
		# SPA-917: Heat tension ambient — lower ambient dB when heat warning fires (fires once).
		_world.intel_store.heat_warning.connect(func() -> void: AudioManager.set_heat_ambient_tension(true))


# ── SPA-244: Local analytics logger ─────────────────────────────────────────

func _init_analytics_logger(scenario_id: String) -> void:
	_analytics_manager = AnalyticsManager.new()
	_analytics_manager.setup(scenario_id, _world, _day_night, _rumor_panel, recon_ctrl_ref)


# ── Pause Menu ───────────────────────────────────────────────────────────────

func _init_pause_menu() -> void:
	_pause_menu = preload("res://scripts/pause_menu.gd").new()
	_pause_menu.name = "PauseMenu"
	_parent.add_child(_pause_menu)
	_pause_menu.setup(_world.active_scenario_id)
	_pause_menu.setup_save_load(_world, _day_night, _journal)
	_pause_menu.setup_tutorial(tutorial_wiring.tutorial_sys if tutorial_wiring != null else null)
	# SPA-335: flush session time whenever the pause menu opens so partial
	# play time is saved if the player quits from the pause menu.
	_pause_menu.visibility_changed.connect(_on_pause_menu_visibility_changed_flush)
	# Suppress tutorial banner while pause menu is open (all scenarios).
	if tutorial_wiring != null:
		tutorial_wiring.wire_pause_menu(_pause_menu)


## Flush partial session time whenever the pause menu becomes visible.
func _on_pause_menu_visibility_changed_flush() -> void:
	if _pause_menu != null and _pause_menu.visible:
		PlayerStats.flush_session_time()


# ── NPC Tooltip ──────────────────────────────────────────────────────────────

func _init_npc_tooltip() -> void:
	var tooltip := preload("res://scripts/npc_tooltip.gd").new()
	tooltip.name = "NpcTooltip"
	_parent.add_child(tooltip)
	tooltip.setup(_world)
	var bldg_tooltip := preload("res://scripts/building_tooltip.gd").new()
	bldg_tooltip.name = "BuildingTooltip"
	_parent.add_child(bldg_tooltip)
	bldg_tooltip.setup(_world)


## SPA-769: HUD tooltip overlay — reads tooltip_text from hovered Controls.
func _init_hud_tooltip() -> void:
	_hud_tooltip = preload("res://scripts/hud_tooltip.gd").new()
	_hud_tooltip.name = "HudTooltip"
	_parent.add_child(_hud_tooltip)


## SPA-767: Context-aware controls panel — replaces static ControlsPanel.
func _init_context_controls_panel() -> void:
	# Hide the static ControlsPanel from the scene tree.
	var hud_node: CanvasLayer = _parent.get_node_or_null("HUD")
	if hud_node != null:
		var static_panel: Panel = hud_node.get_node_or_null("ControlsPanel")
		if static_panel != null:
			static_panel.visible = false

	_context_controls = preload("res://scripts/context_controls_panel.gd").new()
	_context_controls.name = "ContextControlsPanel"
	_parent.add_child(_context_controls)
	if _help_ui != null and _help_ui.controls_ref != null:
		_context_controls.setup(_help_ui.controls_ref)


## SPA-589: Visual affordances — NPC/building interactable highlights for new players.
func _init_visual_affordances() -> void:
	_visual_affordances = preload("res://scripts/visual_affordances.gd").new()
	_visual_affordances.name = "VisualAffordances"
	_parent.add_child(_visual_affordances)
	_visual_affordances.setup(_world, _day_night)


## SPA-872: NPC quick-info panel (shown on Tab cycle or NPC selection).
func _init_npc_info_panel() -> void:
	_npc_info_panel = preload("res://scripts/npc_info_panel.gd").new()
	_npc_info_panel.name = "NpcInfoPanel"
	_parent.add_child(_npc_info_panel)
	if _world != null and _world.intel_store != null:
		_npc_info_panel.setup(_world, _world.intel_store)
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
			var recon_ctrl: Node = _parent.get_node_or_null("World/ReconController")
			if recon_ctrl != null and recon_ctrl.has_method("_try_eavesdrop"):
				recon_ctrl._try_eavesdrop(npc)
		"bribe":
			if _npc_info_panel != null:
				_npc_info_panel.hide_panel()
			var recon_ctrl: Node = _parent.get_node_or_null("World/ReconController")
			if recon_ctrl != null and recon_ctrl.has_method("_try_bribe"):
				recon_ctrl._try_bribe(npc)
		"seed":
			# Open the rumor panel — player picks seed target from there.
			if _rumor_panel != null and _rumor_panel.has_method("toggle"):
				if not _rumor_panel.visible:
					_rumor_panel.toggle()


# ── SPA-272 / SPA-988: Achievement hooks ────────────────────────────────────

## Instantiate AchievementHooks and wire all per-session achievement signals.
func _init_achievement_hooks() -> void:
	_achievement_hooks = AchievementHooks.new()
	_achievement_hooks.day_night = _day_night
	_achievement_hooks.analytics = _analytics
	var sm: ScenarioManager = _world.scenario_manager
	_achievement_hooks.connect_signals(sm, recon_ctrl_ref, _rumor_panel)
	# SPA-335: record tutorial step completion at scenario end.
	if sm != null:
		sm.scenario_resolved.connect(_on_scenario_resolved_tutorial_steps)


## Record tutorial step completion when a scenario resolves (SPA-335).
func _on_scenario_resolved_tutorial_steps(
		scenario_id: int,
		_state: ScenarioManager.ScenarioState
) -> void:
	var tut_sys: TutorialSystem = tutorial_wiring.tutorial_sys if tutorial_wiring != null else null
	if tut_sys == null:
		return
	PlayerStats.record_tutorial_steps(
		"scenario_%d" % scenario_id,
		GameState.selected_difficulty,
		tut_sys.get_seen_count(),
		TutorialSystem.TOOLTIP_DATA.size(),
	)
