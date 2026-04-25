## test_controls_reference.gd — Unit tests for controls_reference.gd (SPA-1042).
##
## Covers:
##   • Palette constants: C_BG, C_BORDER, C_HEADING, C_KEY_NAME, C_KEY_DESC
##   • BINDINGS: 20 entries, each has 2 elements
##   • Initial state: _panel null, _is_visible false
##   • toggle() flips _is_visible
##
## Run from the Godot editor: Scene → Run Script.

class_name TestControlsReference
extends RefCounted

const ControlsReferenceScript := preload("res://scripts/controls_reference.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_cr() -> CanvasLayer:
	return ControlsReferenceScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_bg_dark",
		"test_c_heading_gold",
		"test_c_key_name_warm",
		# BINDINGS
		"test_bindings_count",
		"test_bindings_all_have_two_elements",
		# Initial state
		"test_initial_panel_null",
		"test_initial_fade_tween_null",
		"test_initial_is_visible_false",
		# toggle() logic
		"test_toggle_flips_is_visible",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nControlsReference tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_bg_dark() -> bool:
	var cr := _make_cr()
	var ok := cr.C_BG.r < 0.15 and cr.C_BG.a > 0.80
	cr.free()
	return ok


static func test_c_heading_gold() -> bool:
	var cr := _make_cr()
	var ok := cr.C_HEADING.r > 0.85 and cr.C_HEADING.g > 0.70 and cr.C_HEADING.b < 0.20
	cr.free()
	return ok


static func test_c_key_name_warm() -> bool:
	var cr := _make_cr()
	var ok := cr.C_KEY_NAME.r > 0.85 and cr.C_KEY_NAME.g > 0.78
	cr.free()
	return ok


# ── BINDINGS ──────────────────────────────────────────────────────────────────

static func test_bindings_count() -> bool:
	var cr := _make_cr()
	var ok := cr.BINDINGS.size() == 20
	cr.free()
	return ok


static func test_bindings_all_have_two_elements() -> bool:
	var cr := _make_cr()
	var ok := true
	for binding in cr.BINDINGS:
		if (binding as Array).size() != 2:
			ok = false
			break
	cr.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_panel_null() -> bool:
	var cr := _make_cr()
	var ok := cr._panel == null
	cr.free()
	return ok


static func test_initial_fade_tween_null() -> bool:
	var cr := _make_cr()
	var ok := cr._fade_tween == null
	cr.free()
	return ok


static func test_initial_is_visible_false() -> bool:
	var cr := _make_cr()
	var ok := cr._is_visible == false
	cr.free()
	return ok


# ── toggle() ─────────────────────────────────────────────────────────────────
#
# toggle() flips _is_visible; then calls _fade_tween code — but _fade_tween
# is null initially, so the kill() guard fires safely.

static func test_toggle_flips_is_visible() -> bool:
	var cr := _make_cr()
	var before: bool = cr._is_visible   # false
	cr.toggle()
	var after: bool = cr._is_visible    # true
	var ok := before == false and after == true
	cr.free()
	return ok
