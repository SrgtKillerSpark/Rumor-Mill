extends Node2D

## main.gd — Sprint 6/7 entry point.
## Wires DayNightCycle tick → World, debug tools, recon system, Player Journal,
## Social Graph Overlay, Scenario 3 HUD, Sprint 7 Tutorial Tooltip system,
## and Sprint 6 End Screen overlay.

@onready var world:                Node2D      = $World
@onready var day_night:            Node        = $World/DayNightCycle
@onready var debug_overlay:        CanvasLayer = $DebugOverlay
@onready var debug_console:        CanvasLayer = $DebugConsole
@onready var recon_hud:            CanvasLayer = $ReconHUD
@onready var rumor_panel:          CanvasLayer = $RumorPanel
@onready var journal:              CanvasLayer = $Journal
@onready var social_graph_overlay: CanvasLayer = $SocialGraphOverlay

# ── Sprint 7: tutorial system (created programmatically) ──────────────────────
var _tutorial_sys: TutorialSystem = null
var _tutorial_hud: CanvasLayer    = null

# ── Sprint 6: end screen (created programmatically) ───────────────────────────
var _end_screen: CanvasLayer = null

# Prevent duplicate tooltip triggers for observe / eavesdrop.
var _observe_tooltip_fired:    bool = false
var _eavesdrop_tooltip_fired:  bool = false


func _ready() -> void:
	# Drive NPC ticks from the day/night cycle.
	day_night.game_tick.connect(world.on_game_tick)

	# Wire debug tools (World also self-wires, but doing it here is more robust).
	if debug_overlay != null and debug_overlay.has_method("set_world"):
		debug_overlay.set_world(world)

	# ── Sprint 6: Social Graph Overlay ────────────────────────────────────
	if social_graph_overlay != null and social_graph_overlay.has_method("set_world"):
		social_graph_overlay.set_world(world)

	if debug_console != null:
		if debug_console.has_method("set_world"):
			debug_console.set_world(world)
		if debug_console.has_method("set_overlay"):
			debug_console.set_overlay(debug_overlay)

	# ── Sprint 3: wire reconnaissance system ──────────────────────────────
	_init_recon_system()

	# ── Sprint 6: wire Player Journal ─────────────────────────────────────
	_init_journal()

	# ── Sprint 6: wire Scenario 3 HUD ─────────────────────────────────────
	_init_scenario3_hud()

	# ── Sprint 7: wire Tutorial Tooltip system ────────────────────────────
	_init_tutorial_system()

	# ── Sprint 6: wire End Screen ─────────────────────────────────────────
	_init_end_screen()

	print("Rumor Mill — Sprint 6/7 loaded.")
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
	if journal != null and journal.has_method("push_timeline_event"):
		journal.push_timeline_event(
			"Seeded rumor [%s] about %s — whispered to %s" % [
				claim_id, subject_name, seed_target_name
			]
		)


func _init_scenario3_hud() -> void:
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

	print("Main: Tutorial system wired (5 first-encounter tooltips)")


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
