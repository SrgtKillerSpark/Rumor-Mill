# Fixture: SPA-1867 reproduction — test file referencing _DEGRADE_MAP on RivalAgent.
extends Node

func test_degradation() -> void:
	# This should be caught: _DEGRADE_MAP does not exist on RivalAgent
	var map := RivalAgent._DEGRADE_MAP
	print(map)
