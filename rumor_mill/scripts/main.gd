extends Node2D

## main.gd — Sprint 8 entry point.
## Wires DayNightCycle tick → World, debug tools, recon system, Player Journal,
## Social Graph Overlay, Scenario 3 HUD, Sprint 7 Tutorial Tooltip system,
## Sprint 6 End Screen overlay, Sprint 7 AudioManager, and Sprint 8 Main Menu.
##
## Flow: MainMenu overlay shown first → player selects scenario → Begin →
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
var _main_menu: CanvasLayer = null

# ── Sprint 7: tutorial system (created programmatically) ──────────────────────
var _tutorial_sys: TutorialSystem = null
var _tutorial_hud: CanvasLayer    = null

# ── Sprint 6: end screen (created programmatically) ───────────────────────────
var _end_screen: CanvasLayer = null

# Prevent duplicate tooltip triggers for observe / eavesdrop / npc_state_change.
var _observe_tooltip_fired:          bool = false
var _eavesdrop_tooltip_fired:        bool = false
var _npc_state_change_tooltip_fired: bool = false

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

	# ── Sprint 8: show main menu ───────────────────────────────────────────────
	_main_menu = preload("res://scripts/main_menu.gd").new()
	_main_menu.name = "MainMenu"
	add_child(_main_menu)
	_main_menu.begin_game.connect(_on_begin_game)

	print("Rumor Mill — showing main menu (Sprint 8).")


## Called when the player clicks Begin on the briefing screen.
func _on_begin_game(scenario_id: String) -> void:
	if _game_started:
		return
	_game_started = true

	# Hide / free the menu overlay.
	if _main_menu != null:
		_main_menu.queue_free()
		_main_menu = null

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

	print("Rumor Mill — Sprint 8 loaded. Scenario: %s" % scenario_id)
	print("  F1: debug console  |  F2: NPC state badges  |  F3: social graph (debug)  |  F4: lineage tree")
	print("  G: Social Graph Overlay  |  R: Rumor Crafting Panel  |  J: Player Journal")
	print("  Right-click building: Observe  |  Right-click NPC: Eavesdrop")


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

	# Pipe action results to AudioManager (recon SFX).
	recon_ctrl.action_performed.connect(AudioManager.on_recon_action)

	# Wire eavesdrop exposure → ScenarioManager fail trigger (Scenario 1).
	recon_ctrl.player_exposed.connect(_on_player_exposed)

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


# ── Sprint 7: Tutorial Tooltip system ─────────────────────────────────────────

func _init_tutorial_system() -> void:
	_tutorial_sys = TutorialSystem.new()

	_tutorial_hud = preload("res://scripts/tutorial_hud.gd").new()
	_tutorial_hud.name = "TutorialHUD"
	add_child(_tutorial_hud)
	_tutorial_hud.setup(_tutorial_sys)

	# Tooltip 1: explain recon actions on first game load.
	_tutorial_hud.queue_tooltip("recon_actions")

	# Tooltip 4: rumour crafting — first time the Rumor Panel becomes visible.
	if rumor_panel != null:
		rumor_panel.visibility_changed.connect(_on_rumor_panel_visibility_changed)

	# Tooltip 5: reputation — first time the Journal becomes visible.
	if journal != null:
		journal.visibility_changed.connect(_on_journal_visibility_changed)

	# Tooltip (npc_state_change): first time any NPC transitions to EVALUATING.
	for npc in world.npcs:
		npc.first_npc_became_evaluating.connect(_on_first_npc_state_change)

	print("Main: Tutorial system wired (5 first-encounter tooltips)")


## Connected to recon_ctrl.player_exposed — triggers Scenario 1 exposure fail.
func _on_player_exposed() -> void:
	if world != null and world.scenario_manager != null:
		world.scenario_manager.on_player_exposed()


## Connected to recon_ctrl.action_performed — fires observe / eavesdrop tooltips.
func _on_recon_action_for_tutorial(message: String, success: bool) -> void:
	if not success or _tutorial_hud == null:
		return
	# Tooltip 2: first successful Observe.
	if not _observe_tooltip_fired and message.begins_with("Observed"):
		_observe_tooltip_fired = true
		_tutorial_hud.queue_tooltip("observe")
	# Tooltip 3: first successful Eavesdrop.
	elif not _eavesdrop_tooltip_fired and message.begins_with("Eavesdropped"):
		_eavesdrop_tooltip_fired = true
		_tutorial_hud.queue_tooltip("eavesdrop")


## Tooltip (npc_state_change) trigger — fires once when any NPC first enters EVALUATING.
func _on_first_npc_state_change() -> void:
	if _npc_state_change_tooltip_fired or _tutorial_hud == null:
		return
	_npc_state_change_tooltip_fired = true
	_tutorial_hud.queue_tooltip("npc_state_change")


## Tooltip 4 trigger — fires once when the Rumor Panel first opens.
func _on_rumor_panel_visibility_changed() -> void:
	if rumor_panel == null or not rumor_panel.visible:
		return
	if _tutorial_hud != null:
		_tutorial_hud.queue_tooltip("rumor_crafting")
	# Disconnect so this only triggers once.
	rumor_panel.visibility_changed.disconnect(_on_rumor_panel_visibility_changed)


## Tooltip 5 trigger — fires once when the Journal first opens.
func _on_journal_visibility_changed() -> void:
	if journal == null or not journal.visible:
		return
	if _tutorial_hud != null:
		_tutorial_hud.queue_tooltip("reputation")
	# Disconnect so this only triggers once.
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


## Relay scenario_resolved to AudioManager win/fail stings.
func _on_scenario_resolved_audio(scenario_id: int, state: ScenarioManager.ScenarioState) -> void:
	if state == ScenarioManager.ScenarioState.WON:
		AudioManager.on_win()
	elif state == ScenarioManager.ScenarioState.FAILED:
		AudioManager.on_fail()
