# Fixture: SPA-1867 reproduction — test file that accesses a var as if it were a const.
extends Node

func test_ring_color() -> void:
	# This should be caught: STATE_RING_COLOR is var, not const
	var color := RingVisuals.STATE_RING_COLOR
	# This should NOT be caught: RING_WIDTH is const
	var width := RingVisuals.RING_WIDTH
	print(color, width)
