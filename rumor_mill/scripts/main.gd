extends Node2D

## main.gd — Sprint 2 entry point.
## Wires DayNightCycle tick → World, and connects DebugOverlay / DebugConsole to World.

@onready var world:         Node2D      = $World
@onready var day_night:     Node        = $World/DayNightCycle
@onready var debug_overlay: CanvasLayer = $DebugOverlay
@onready var debug_console: CanvasLayer = $DebugConsole


func _ready() -> void:
	# Drive NPC ticks from the day/night cycle.
	day_night.game_tick.connect(world.on_game_tick)

	# Wire debug tools to the World (World also self-wires via _wire_debug_nodes,
	# but doing it here is more robust since scene tree is fully ready).
	if debug_overlay != null and debug_overlay.has_method("set_world"):
		debug_overlay.set_world(world)

	if debug_console != null:
		if debug_console.has_method("set_world"):
			debug_console.set_world(world)
		if debug_console.has_method("set_overlay"):
			debug_console.set_overlay(debug_overlay)

	print("Rumor Mill — Sprint 2 loaded.")
	print("  F1: debug console  |  F2: NPC state badges  |  F3: social graph")
	print("  Console: inject_rumor <npc_id> <claim_type> <intensity>")
