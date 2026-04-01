extends Node2D

## main.gd — Sprint 6 entry point (Sprint 3 Rumor Crafting UI added).
## Wires DayNightCycle tick → World, debug tools, recon system, Player Journal,
## and the Sprint 6 Scenario 3 HUD.

@onready var world:         Node2D      = $World
@onready var day_night:     Node        = $World/DayNightCycle
@onready var debug_overlay: CanvasLayer = $DebugOverlay
@onready var debug_console: CanvasLayer = $DebugConsole
@onready var recon_hud:     CanvasLayer = $ReconHUD
@onready var rumor_panel:   CanvasLayer = $RumorPanel
@onready var journal:       CanvasLayer = $Journal


func _ready() -> void:
	# Drive NPC ticks from the day/night cycle.
	day_night.game_tick.connect(world.on_game_tick)

	# Wire debug tools (World also self-wires, but doing it here is more robust).
	if debug_overlay != null and debug_overlay.has_method("set_world"):
		debug_overlay.set_world(world)

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

	print("Rumor Mill — Sprint 6 loaded.")
	print("  F1: debug console  |  F2: NPC state badges  |  F3: social graph")
	print("  R: Rumor Crafting Panel  |  J: Player Journal")
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
