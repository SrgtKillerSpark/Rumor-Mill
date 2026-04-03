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

# Prevent duplicate tooltip triggers for observe / eavesdrop / npc_state_change.
var _observe_tooltip_fired:          bool = false
var _eavesdrop_tooltip_fired:        bool = false
var _npc_state_change_tooltip_fired: bool = false
var _evidence_tooltip_fired:         bool = false

# Cached ReconController reference for post-tutorial-init wiring.
var _recon_ctrl_ref: Node = null

# ── Sprint 10: S1 banner hint gates ───────────────────────────────────────────
var _banner_camera_gate:    bool = false  # set true after camera_moved fires
var _banner_observe_gate:   bool = false  # set true after first successful Observe
var _banner_eavesdrop_gate: bool = false  # set true after first successful Eavesdrop
var _banner_seed_fired:     bool = false  # guard for hint_propagation 5 s delay
var _banner_believe_fired:  bool = false  # guard for hint_objectives

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
		_pause_menu_script._pending_restart_id = ""
		_on_begin_game.call_deferred(_restart_id)
		return

	_main_menu = preload("res://scripts/main_menu.gd").new()
	_main_menu.name = "MainMenu"
	add_child(_main_menu)
	_main_menu.begin_game.connect(_on_begin_game)

	print("Rumor Mill — showing main menu (Sprint 8).")


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
	_init_journal()
	_wire_rumor_events()
	_init_objective_hud()
	_init_scenario3_hud()
	_init_tutorial_system()
	_init_end_screen()
	_init_audio()
	_init_pause_menu()
	_init_npc_tooltip()

	# Loading complete — dismiss the tip screen.
	if _loading_tips != null:
		_loading_tips.end_transition()
		_loading_tips.force_hide()

	print("Rumor Mill — Sprint 9 loaded. Scenario: %s" % scenario_id)
	print("  F1: debug console  |  F2: NPC state badges  |  F3: social graph (debug)  |  F4: lineage tree")
	print("  G: Social Graph Overlay  |  R: Rumor Crafting Panel  |  J: Player Journal")
	print("  Right-click building: Observe  |  Right-click NPC: Eavesdrop")
	print("  Esc: Pause / return to menu")


func _init_recon_system() -> void:
	var intel_store: PlayerIntelStore = world.intel_store
	if intel_store == null:
		push_error("Main: world.intel_store is null — recon system not wired")
		return

	# ReconHUD: shows action counter + toasts; opens RumorPanel on R.
	if recon_hud != null and recon_hud.has_method("setup"):
		recon_hud.setup(intel_store, rumor_panel)

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
	var recon_ctrl := preload("res://scripts/recon_controller.gd").new()
	recon_ctrl.name = "ReconController"
	add_child(recon_ctrl)
	recon_ctrl.setup(world, intel_store)

	# Pipe action results to the HUD toast.
	if recon_hud != null and recon_hud.has_method("show_toast"):
		recon_ctrl.action_performed.connect(recon_hud.show_toast)

	# Pipe action results to the tutorial system (observe / eavesdrop tooltips).
	recon_ctrl.action_performed.connect(_on_recon_action_for_tutorial)

	# Cache ref so _wire_s1_recon_hints can run after _init_tutorial_system().
	_recon_ctrl_ref = recon_ctrl

	# Pipe action results to AudioManager (recon SFX).
	recon_ctrl.action_performed.connect(AudioManager.on_recon_action)

	# Wire eavesdrop exposure → ScenarioManager fail trigger (Scenario 1).
	recon_ctrl.player_exposed.connect(_on_player_exposed)

	# Wire bribe_executed → journal timeline entry.
	recon_ctrl.bribe_executed.connect(_on_bribe_executed)

	print("Main: recon system wired (intel_store + controller + HUD + 3-panel rumor modal)")


func _init_journal() -> void:
	if journal == null:
		push_error("Main: $Journal node not found — journal not wired")
		return

	var intel_store: PlayerIntelStore = world.intel_store
	if journal.has_method("setup"):
		journal.setup(world, intel_store, day_night)

	print("Main: Player Journal wired (J to open)")


## Called when the player successfully seeds a rumor via the crafting panel.
func _on_rumor_seeded(
		rumor_id: String,
		subject_name: String,
		claim_id: String,
		seed_target_name: String
) -> void:
	print("Main: rumor seeded — id=%s claim=%s about=%s via=%s" % [
		rumor_id, claim_id, subject_name, seed_target_name])
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
	print("Main: rumor_event wired to journal timeline")


## Relay world rumor events into the Journal timeline and overlay.
func _on_rumor_event(message: String, tick: int) -> void:
	if journal != null and journal.has_method("push_timeline_event"):
		journal.push_timeline_event(tick, message)
	if social_graph_overlay != null and social_graph_overlay.has_method("on_rumor_event"):
		social_graph_overlay.on_rumor_event(message)


func _init_objective_hud() -> void:
	if objective_hud == null:
		push_error("Main: $ObjectiveHUD node not found — objective HUD not wired")
		return
	var sm: ScenarioManager = world.scenario_manager
	if sm == null:
		push_error("Main: world.scenario_manager is null — objective HUD not wired")
		return
	if objective_hud.has_method("setup"):
		objective_hud.setup(sm, day_night)
	print("Main: Objective HUD wired")


func _init_scenario3_hud() -> void:
	if world.active_scenario_id != "scenario_3":
		return
	# Build the Scenario 3 dual-track HUD programmatically (no .tscn required).
	var hud := preload("res://scripts/scenario3_hud.gd").new()
	hud.name = "Scenario3HUD"
	add_child(hud)
	if hud.has_method("setup"):
		hud.setup(world, day_night)
	print("Main: Scenario 3 HUD wired")


# ── Sprint 7 / Sprint 10: Tutorial system ─────────────────────────────────────

func _init_tutorial_system() -> void:
	_tutorial_sys = TutorialSystem.new()

	if world.active_scenario_id == "scenario_1":
		_init_tutorial_banner_s1()
	else:
		_init_tutorial_hud_s2s3()


## S2 / S3: existing blocking modal tooltip overlay (unchanged).
func _init_tutorial_hud_s2s3() -> void:
	_tutorial_hud = preload("res://scripts/tutorial_hud.gd").new()
	_tutorial_hud.name = "TutorialHUD"
	add_child(_tutorial_hud)
	_tutorial_hud.setup(_tutorial_sys)

	_tutorial_hud.queue_tooltip("recon_actions")
	_tutorial_hud.queue_tooltip("navigation_controls")
	if world.active_scenario_id == "scenario_3":
		_tutorial_hud.queue_tooltip("rival_agent")

	if rumor_panel != null:
		rumor_panel.visibility_changed.connect(_on_rumor_panel_visibility_changed)
	if journal != null:
		journal.visibility_changed.connect(_on_journal_visibility_changed)
	for npc in world.npcs:
		npc.first_npc_became_evaluating.connect(_on_first_npc_state_change)

	print("Main: Tutorial HUD wired for S2/S3 (modal tooltips)")


## S1: non-blocking banner hint system (SPA-131).
func _init_tutorial_banner_s1() -> void:
	_tutorial_banner = preload("res://scripts/tutorial_banner.gd").new()
	_tutorial_banner.name = "TutorialBanner"
	add_child(_tutorial_banner)
	_tutorial_banner.setup(_tutorial_sys)

	# HINT-01: camera controls — fires immediately on game start.
	_tutorial_banner.queue_hint("hint_camera")

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

	print("Main: Tutorial Banner wired for S1 (10 contextual hints)")


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
			# Dismiss hint_observe if still showing.
		if message.begins_with("Eavesdropped") and not _banner_eavesdrop_gate:
			_banner_eavesdrop_gate = true
			# HINT-05: open journal hint after first eavesdrop.
			_tutorial_banner.queue_hint("hint_journal")


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
	# HINT-06: fire at day 2 (tick 24) if tokens and recon exist and no rumour seeded yet.
	if tick == 24 and _tutorial_banner != null and not _banner_seed_fired:
		var intel: PlayerIntelStore = world.intel_store
		if intel != null and intel.whisper_tokens_remaining >= 1:
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
	_end_screen = preload("res://scripts/end_screen.gd").new()
	_end_screen.name = "EndScreen"
	add_child(_end_screen)
	_end_screen.setup(world, day_night)
	print("Main: End Screen wired")


# ── Sprint 7: Audio ────────────────────────────────────────────────────────────

func _init_audio() -> void:
	# Connect ambient crossfade + new_day SFX to the day/night clock.
	AudioManager.connect_to_day_night(day_night)

	# Connect scenario win/fail events so AudioManager can play stings.
	var sm: ScenarioManager = world.scenario_manager
	if sm != null:
		sm.scenario_resolved.connect(_on_scenario_resolved_audio)

	print("AudioManager: wired into main scene")


# ── Pause Menu ────────────────────────────────────────────────────────────────

func _init_pause_menu() -> void:
	_pause_menu = preload("res://scripts/pause_menu.gd").new()
	_pause_menu.name = "PauseMenu"
	add_child(_pause_menu)
	_pause_menu.setup(world.active_scenario_id)
	# S1: suppress banner while pause menu is open.
	if world.active_scenario_id == "scenario_1" and _tutorial_banner != null:
		_pause_menu.visibility_changed.connect(_on_pause_menu_visibility_changed_banner)
	print("Main: Pause menu wired (Escape to open)")


# ── NPC Tooltip ───────────────────────────────────────────────────────────────

func _init_npc_tooltip() -> void:
	var tooltip := preload("res://scripts/npc_tooltip.gd").new()
	tooltip.name = "NpcTooltip"
	add_child(tooltip)
	tooltip.setup(world)
	print("Main: NPC hover tooltip wired")


## Relay scenario_resolved to AudioManager win/fail stings.
func _on_scenario_resolved_audio(scenario_id: int, state: ScenarioManager.ScenarioState) -> void:
	if state == ScenarioManager.ScenarioState.WON:
		AudioManager.on_win()
	elif state == ScenarioManager.ScenarioState.FAILED:
		AudioManager.on_fail()
