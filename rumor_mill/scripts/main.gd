extends Node2D

## main.gd — entry point; wires the DayNightCycle tick signal to the World node.

@onready var world: Node2D = $World
@onready var day_night: Node = $World/DayNightCycle


func _ready() -> void:
	# Connect the tick signal so every in-game tick drives NPC movement.
	day_night.game_tick.connect(world.on_game_tick)
	print("Rumor Mill — Sprint 1 loaded. Tick rate: %.1fs per tick." % day_night.tick_duration_seconds)
