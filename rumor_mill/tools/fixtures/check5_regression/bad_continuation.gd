extends Node
# Regression fixture for SPA-1543 / SPA-1560.
# Check 5 in check_gdscript_static.js MUST flag bad_pattern() below.
# Do NOT fix this file — it is intentionally broken.


func _ready() -> void:
	pass


func bad_pattern() -> void:
	# SPA-1543: var with := and backslash continuation — GDScript 4.6
	# type inference fails on multi-line := when the RHS uses typed
	# accessors, chained and/or, or method chains.
	var result := some_dict.get("key") and \
		another_condition
	print(result)
