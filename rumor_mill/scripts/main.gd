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

# ── Sprint 10: S1 banner hint gates ───────────────────────────────────────────
var _banner_camera_gate:       bool = false  # set true after camera_moved fires
var _banner_observe_gate:      bool = false  # set true after first successful Observe
var _banner_eavesdrop_gate:    bool = false  # set true after first successful Eavesdrop
var _banner_seed_fired:        bool = false  # guard for hint_propagation 5 s delay
var _banner_believe_fired:     bool = false  # guard for hint_objectives
var _banner_journal_hint_fired: bool = false  # guard: journal hint shown (observe or eavesdrop)
var _banner_social_graph_fired: bool = false  # guard: social graph hint shown
# Cross-scenario contextual hint gates (S2/S3/S4).
var _ctx_spread_fired:   bool = false
var _ctx_act_fired:      bool = false
var _ctx_reject_fired:   bool = false
var _ctx_tokens_fired:   bool = false
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



## Called when the player clicks Begin on the scenario intro screen.
## Uses await so the loading tips screen renders for at least 1.5 s
## (well above the 0.5 s threshold) while the world initialises.
func _on_begin_game(scenario_id: String) -> void:
	if _game_started:
		return
	_game_started = true

	# Hide / free the menu overlay.
	if _main_menu != null:
		_main_menu.queue_free()
		_main_menu = null

	# Show a loading tip. Await so the tip is actually visible on screen
	# before the synchronous world init runs (~1.5 s > MIN_DURATION_SEC).
	if _loading_tips != null:
		_loading_tips.start_transition()
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
	rumor_panel.visible          = false  # closed by default; opened via R key
	journal.visible              = false  # closed by default; opened via J key
	social_graph_overlay.visible = false  # closed by default; opened via G key

	# ── Wire game systems ─────────────────────────────────────────────────────
	# Drive NPC ticks from the day/night cycle.
	day_night.game_tick.connect(world.on_game_tick)

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
	# Wire milestone tracker callback now that recon_hud is set up.
	if world.milestone_tracker != null and recon_hud != null and recon_hud.has_method("show_milestone"):
		var _sid: int = int(scenario_id.trim_prefix("scenario_"))
		world.milestone_tracker.setup(
			_sid,
			world.reputation_system,
			world.scenario_manager,
			world.intel_store,
			recon_hud.show_milestone
		)
	_init_journal()
	_wire_rumor_events()
	_init_objective_hud()
	_init_speed_hud()
	_init_npc_conversation_overlay()
	_init_scenario1_hud()
	_init_scenario2_hud()
	_init_scenario3_hud()
	_init_scenario4_hud()
	_init_tutorial_system()
	_init_end_screen()
	_init_audio()
	_init_analytics_logger(scenario_id)
	_init_achievement_hooks()
	_init_pause_menu()
	_init_npc_tooltip()
	day_night.day_changed.connect(_on_new_day_auto_save)
	PlayerStats.start_session()  # SPA-273: begin timing this play session

	# SPA-335: feed retry count into ScenarioManager so it knows how many times
	# this scenario has been attempted before.
	var _sm_ref: ScenarioManager = world.scenario_manager
	if _sm_ref != null:
		_sm_ref.retry_count = PlayerStats.get_scenario_stats(
			scenario_id, GameState.selected_difficulty).get("retries", 0)

	# Loading complete — dismiss the tip screen.
	if _loading_tips != null:
		_loading_tips.end_transition()

	# Restore saved state if a load was triggered from the pause menu.
	if SaveManager.has_pending_load():
		SaveManager.apply_pending_load(world, day_night, journal)
	else:
		# SPA-1098: defensively clear any stale pending-load data that could
		# leak across sessions via the static _pending_load_data variable.
		SaveManager.clear_pending_load()

	# SPA-1098: start the tick loop AFTER all systems are wired and any
	# save data has been restored.  Previously the DayNightCycle timer
	# started in _ready(), causing current_tick to accumulate during the
	# menu and loading screen.
	if day_night != null and day_night.has_method("start_ticking"):
		day_night.start_ticking()



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

	# RumorPanel: 3-panel crafting modal (Subject → Claim → Seed Target).
	if rumor_panel != null and rumor_panel.has_method("setup"):
		rumor_panel.setup(world, intel_store)
	# Log each successfully seeded rumor to the journal timeline.
	if rumor_panel != null and journal != null:
		rumor_panel.rumor_seeded.connect(_on_rumor_seeded)
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
		var _loc := loc_id  # capture loop variable for closure
		interior.interior_opened.connect(func() -> void: AudioManager.set_location_ambient(_loc))
		interior.interior_closed.connect(AudioManager.clear_location_ambient)
	recon_ctrl.set_interiors(_interiors)

	# Pipe action results to the HUD toast.
	if recon_hud != null and recon_hud.has_method("show_toast"):
		recon_ctrl.action_performed.connect(recon_hud.show_toast)

	# Pipe action results to the tutorial system (observe / eavesdrop tooltips).
	recon_ctrl.action_performed.connect(_on_recon_action_for_tutorial)

	# Cache ref so _wire_s1_recon_hints can run after _init_tutorial_system().
	_recon_ctrl_ref = recon_ctrl

	# Pipe action results to AudioManager (recon SFX).
	recon_ctrl.action_performed.connect(AudioManager.on_recon_action)

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
	if journal != null and journal.has_method("push_timeline_event"):
		var _seed_tick: int = day_night.current_tick if day_night != null else 0
		journal.push_timeline_event(
			_seed_tick,
			"Seeded rumor [%s] about %s — whispered to %s" % [
				claim_id, subject_name, seed_target_name
			]
		)


## Called when the player bribes an NPC; logs the event to the journal timeline.
func _on_bribe_executed(npc_name: String, tick: int) -> void:
	if journal != null and journal.has_method("push_timeline_event"):
		journal.push_timeline_event(tick, "Bribed %s — forced to believe a rumor" % npc_name)


## Connect world.rumor_event → journal timeline and social graph overlay.
func _wire_rumor_events() -> void:
	if world == null:
		return
	world.rumor_event.connect(_on_rumor_event)
	world.socially_dead_triggered.connect(_on_socially_dead_triggered)


## Relay world rumor events into the Journal timeline and overlay.
## Also fire milestone HUD effects for the most impactful events.
func _on_rumor_event(message: String, tick: int) -> void:
	if journal != null and journal.has_method("push_timeline_event"):
		journal.push_timeline_event(tick, message)
	if social_graph_overlay != null and social_graph_overlay.has_method("on_rumor_event"):
		social_graph_overlay.on_rumor_event(message)
	# Milestone visual feedback for key events.
	if recon_hud != null and recon_hud.has_method("show_milestone"):
		if message.contains("whispered to"):
			recon_hud.show_milestone("Rumor spreading...", Color(1.00, 0.70, 0.30, 1.0))
		elif message.contains("→ Believe"):
			var npc_name := message.split(" →")[0].strip_edges() if " →" in message else "NPC"
			recon_hud.show_milestone("%s is convinced!" % npc_name, Color(0.50, 1.00, 0.55, 1.0))
		elif message.contains("→ Spread"):
			var npc_name := message.split(" →")[0].strip_edges() if " →" in message else "NPC"
			recon_hud.show_milestone("%s is spreading the word!" % npc_name, Color(0.40, 0.85, 1.00, 1.0))
		elif message.contains("→ Act"):
			var npc_name := message.split(" →")[0].strip_edges() if " →" in message else "NPC"
			recon_hud.show_milestone("%s takes action!" % npc_name, Color(1.00, 0.85, 0.20, 1.0))
		elif message.contains("→ Reject"):
			var npc_name := message.split(" →")[0].strip_edges() if " →" in message else "NPC"
			recon_hud.show_milestone("%s rejected the rumor" % npc_name, Color(0.85, 0.40, 0.30, 1.0))


## Show a HUD toast + milestone when an NPC first becomes SOCIALLY_DEAD.
func _on_socially_dead_triggered(_npc_id: String, npc_name: String, _tick: int) -> void:
	if recon_hud != null and recon_hud.has_method("show_toast"):
		recon_hud.show_toast("%s is SOCIALLY DEAD — reputation permanently frozen" % npc_name, false)
	if recon_hud != null and recon_hud.has_method("show_milestone"):
		recon_hud.show_milestone("☠ %s — SOCIALLY DEAD" % npc_name, Color(0.85, 0.15, 0.15, 1.0))


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


func _init_speed_hud() -> void:
	var hud := preload("res://scripts/speed_hud.gd").new()
	hud.name = "SpeedHUD"
	add_child(hud)
	if hud.has_method("setup"):
		hud.setup(day_night)


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


# ── Sprint 7 / Sprint 10: Tutorial system ─────────────────────────────────────

func _init_tutorial_system() -> void:
	_tutorial_sys = TutorialSystem.new()

	if world.active_scenario_id == "scenario_1":
		_init_tutorial_banner_s1()
	else:
		_init_tutorial_hud_s2s3s4()
		_init_context_banner()

	_init_idle_hints()


## All scenarios except S1: non-blocking contextual hint banner for day-gated tips.
## S1 already has its own banner — this adds the cross-scenario hints for S2/S3/S4.
func _init_context_banner() -> void:
	_tutorial_banner = preload("res://scripts/tutorial_banner.gd").new()
	_tutorial_banner.name = "TutorialBanner"
	add_child(_tutorial_banner)
	_tutorial_banner.setup(_tutorial_sys)

	# SPA-479: scenario-specific opening hints — fire after blocking tooltips dismiss.
	var _opening_hint_id: String = ""
	match world.active_scenario_id:
		"scenario_2": _opening_hint_id = "ctx_s2_opening"
		"scenario_3": _opening_hint_id = "ctx_s3_opening"
		"scenario_4": _opening_hint_id = "ctx_s4_opening"
	if _opening_hint_id != "":
		var _open_timer := get_tree().create_timer(8.0)  # delay for blocking tooltips
		var _hint_id_copy: String = _opening_hint_id
		_open_timer.timeout.connect(func() -> void:
			if _tutorial_banner != null:
				_tutorial_banner.queue_hint(_hint_id_copy)
		)

	# Day-gated hints: hook into day_changed signal.
	if day_night != null and day_night.has_signal("day_changed"):
		day_night.day_changed.connect(_on_ctx_day_changed)

	# Whisper token exhaustion hint (SPA-448).
	if world.intel_store != null:
		world.intel_store.tokens_exhausted.connect(_on_ctx_tokens_exhausted)

	# NPC state change hints: first SPREAD, ACT, or REJECT triggers.
	for npc in world.npcs:
		npc.rumor_state_changed.connect(_on_ctx_rumor_state_changed)

	# Suppression: pause banner while Journal / Rumour Panel are open.
	if journal != null:
		journal.visibility_changed.connect(_on_journal_visibility_changed_banner)
	if rumor_panel != null:
		rumor_panel.visibility_changed.connect(_on_rumor_panel_visibility_changed_banner)


## S2 / S3 / S4: blocking modal tooltip overlay.
func _init_tutorial_hud_s2s3s4() -> void:
	_tutorial_hud = preload("res://scripts/tutorial_hud.gd").new()
	_tutorial_hud.name = "TutorialHUD"
	add_child(_tutorial_hud)
	_tutorial_hud.setup(_tutorial_sys)

	_tutorial_hud.queue_tooltip("core_loop")
	_tutorial_hud.queue_tooltip("navigation_controls")
	_tutorial_hud.queue_tooltip("recon_actions")
	if world.active_scenario_id == "scenario_3":
		_tutorial_hud.queue_tooltip("rival_agent")
	if world.active_scenario_id == "scenario_4":
		_tutorial_hud.queue_tooltip("inquisitor_agent")

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

	# HINT-01: mission intro — fires immediately on game start (SPA-479 revised).
	_tutorial_banner.queue_hint("hint_camera")

	# HINT-01b: guided first action — fires 6 s after game start.
	var _first_action_timer := get_tree().create_timer(6.0)
	_first_action_timer.timeout.connect(func() -> void:
		if _tutorial_banner != null:
			_tutorial_banner.queue_hint("hint_first_action")
	)

	# hint_target_npc: fires 14 s after game start to point player toward Edric Fenn.
	var _target_hint_timer := get_tree().create_timer(14.0)
	_target_hint_timer.timeout.connect(func() -> void:
		if _tutorial_banner != null:
			_tutorial_banner.queue_hint("hint_target_npc")
	)

	# hint_speed_controls: fires 20 s after game start to teach pause/speed controls.
	var _speed_hint_timer := get_tree().create_timer(20.0)
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


## Connected to recon_ctrl.action_performed — fires observe / eavesdrop tooltips
## for S2/S3 modal system; also drives S1 banner gates.
func _on_recon_action_for_tutorial(message: String, success: bool) -> void:
	if not success:
		return
	# S2/S3 modal tooltips.
	if _tutorial_hud != null:
		if not _observe_tooltip_fired and message.begins_with("Observed"):
			_observe_tooltip_fired = true
			_tutorial_hud.queue_tooltip("observe")
		elif not _eavesdrop_tooltip_fired and message.begins_with("Eavesdropped"):
			_eavesdrop_tooltip_fired = true
			_tutorial_hud.queue_tooltip("eavesdrop")

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
	if tick == 24 and _tutorial_banner != null and not _banner_seed_fired:
		var intel: PlayerIntelStore = world.intel_store
		if intel != null and intel.whisper_tokens_remaining >= 1 and _banner_eavesdrop_gate:
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
	# HINT-08: 5 s after first seed.
	if _banner_seed_fired or _tutorial_banner == null:
		return
	_banner_seed_fired = true
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
	# Halfway warning: check if past 50% of days and progress is slow.
	if not _ctx_halfway_fired and world.scenario_manager != null:
		var total: int = world.scenario_manager.get_days_allowed()
		if day > total / 2:
			_ctx_halfway_fired = true
			_tutorial_banner.queue_hint("ctx_halfway_warning")
	# Event aftermath: show bulletin text the morning after an event expires.
	if world.faction_event_system != null:
		var aftermaths: Array = world.faction_event_system.get_aftermath_for_day(day)
		for entry in aftermaths:
			_tutorial_banner.queue_hint(entry["hint_id"], entry["text"])


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


## ── SPA-487: Idle-detection hint system ──────────────────────────────────────
## Fires contextual hints when the player hasn't taken actions for a while.

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
	# SPA-335: flush session time whenever the pause menu opens so partial
	# play time is saved if the player quits from the pause menu.
	_pause_menu.visibility_changed.connect(_on_pause_menu_visibility_changed_flush)
	# S1: suppress banner while pause menu is open.
	if world.active_scenario_id == "scenario_1" and _tutorial_banner != null:
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


## Auto-save to slot 0 at the start of each new day (SPA-220).
func _on_new_day_auto_save(day: int) -> void:
	var err := SaveManager.save_game(world, day_night, journal, SaveManager.AUTO_SLOT)
	if not err.is_empty():
		push_warning("[Main] Auto-save failed on day %d: %s" % [day, err])


## Relay scenario_resolved to AudioManager win/fail stings.
## Also persists scenario completion via ProgressData (SPA-137).
func _on_scenario_resolved_audio(scenario_id: int, state: ScenarioManager.ScenarioState) -> void:
	if state == ScenarioManager.ScenarioState.WON:
		AudioManager.on_win()
		AudioManager.play_sfx("reputation_up")
		_camera_shake(6.0, 0.5)
		_play_win_celebration()
		# Persist the win so the main menu can unlock subsequent scenarios.
		var active_id: String = world.active_scenario_id if "active_scenario_id" in world else ("scenario_%d" % scenario_id)
		ProgressData.mark_completed(active_id)
	elif state == ScenarioManager.ScenarioState.FAILED:
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

	# Speed run: win in under 10 days.
	var current_day: int = day_night.current_day if day_night != null and "current_day" in day_night else 99
	if current_day < 10:
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

	# Mastermind: all four scenarios completed (checks persisted unlock state).
	if (AchievementManager.is_unlocked("scenario_1_complete")
			and AchievementManager.is_unlocked("scenario_2_complete")
			and AchievementManager.is_unlocked("scenario_3_complete")
			and AchievementManager.is_unlocked("scenario_4_complete")):
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
		TutorialSystem.TOOLTIP_ORDER.size(),
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
	get_tree().create_timer(2.0).timeout.connect(layer.queue_free)

