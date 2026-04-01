extends Node2D

## main.gd — Sprint 3 entry point.
## Wires DayNightCycle tick → World, debug tools, and the Sprint 3 recon system.

@onready var world:         Node2D      = $World
@onready var day_night:     Node        = $World/DayNightCycle
@onready var debug_overlay: CanvasLayer = $DebugOverlay
@onready var debug_console: CanvasLayer = $DebugConsole
@onready var recon_hud:     CanvasLayer = $ReconHUD
@onready var rumor_panel:   CanvasLayer = $RumorPanel


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

	print("Rumor Mill — Sprint 3 loaded.")
	print("  F1: debug console  |  F2: NPC state badges  |  F3: social graph")
	print("  R: open/close Rumor Crafting Panel 1 (Subject Selection)")
	print("  Right-click building: Observe  |  Right-click NPC: Eavesdrop")


func _init_recon_system() -> void:
	var intel_store: PlayerIntelStore = world.intel_store
	if intel_store == null:
		push_error("Main: world.intel_store is null — recon system not wired")
		return

	# ReconHUD: shows action counter + toasts; opens RumorPanel on R.
	if recon_hud != null and recon_hud.has_method("setup"):
		recon_hud.setup(intel_store, rumor_panel)

	# RumorPanel (Panel 1): subject selection with relationship intel.
	if rumor_panel != null and rumor_panel.has_method("setup"):
		rumor_panel.setup(world, intel_store)

	# ReconController: input handler — created programmatically so it sits in
	# the scene tree and receives _unhandled_input events.
	var recon_ctrl := preload("res://scripts/recon_controller.gd").new()
	recon_ctrl.name = "ReconController"
	add_child(recon_ctrl)
	recon_ctrl.setup(world, intel_store)

	# Pipe action results to the HUD toast.
	if recon_hud != null and recon_hud.has_method("show_toast"):
		recon_ctrl.action_performed.connect(recon_hud.show_toast)

	print("Main: recon system wired (intel_store + controller + HUD + panel)")
