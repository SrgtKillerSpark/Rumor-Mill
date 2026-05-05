# Fixture: SPA-1867 reproduction — class with a var that gets accessed statically.
class_name RingVisuals
extends Node

# STATE_RING_COLOR is a var, not a const — accessing via RingVisuals.STATE_RING_COLOR is invalid
var STATE_RING_COLOR := Color.RED
const RING_WIDTH := 2.0
