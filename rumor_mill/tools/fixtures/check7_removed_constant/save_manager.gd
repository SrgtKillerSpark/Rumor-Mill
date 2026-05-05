# Fixture: SPA-1678 reproduction — references a removed constant.
# save_manager.gd references RivalAgent.MAX_DISRUPT_CHARGES which no longer exists.
extends Node

func save_game() -> void:
	var max_charges := RivalAgent.MAX_DISRUPT_CHARGES
	print("Saving with max charges: ", max_charges)

func load_game() -> void:
	var name := RivalAgent.AGENT_NAME
	print("Loading agent: ", name)
