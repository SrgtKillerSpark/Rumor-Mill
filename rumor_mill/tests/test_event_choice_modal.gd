## test_event_choice_modal.gd — Unit tests for event_choice_modal.gd (SPA-1042).
##
## Covers:
##   • Palette constants
##   • Layout constants: PANEL_WIDTH, PANEL_HEIGHT, DIM_TWEEN_SECS
##   • Initial node refs null (present_event() builds UI — not tested here)
##   • Initial state: _current_event_id=""
##
## Run from the Godot editor: Scene → Run Script.

class_name TestEventChoiceModal
extends RefCounted

const EventChoiceModalScript := preload("res://scripts/event_choice_modal.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_ecm() -> CanvasLayer:
	return EventChoiceModalScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_backdrop_near_black",
		"test_c_heading_gold",
		"test_c_preview_muted_parchment",
		# Layout constants
		"test_panel_width",
		"test_panel_height",
		"test_dim_tween_secs",
		# Initial node refs
		"test_initial_backdrop_null",
		"test_initial_panel_null",
		"test_initial_title_label_null",
		"test_initial_body_label_null",
		"test_initial_choice_a_btn_null",
		"test_initial_choice_b_btn_null",
		"test_initial_preview_a_null",
		"test_initial_preview_b_null",
		"test_initial_outcome_label_null",
		"test_initial_dismiss_btn_null",
		# Initial state
		"test_initial_current_event_id_empty",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nEventChoiceModal tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_backdrop_near_black() -> bool:
	var ecm := _make_ecm()
	var ok := ecm.C_BACKDROP.r < 0.10 and ecm.C_BACKDROP.a > 0.75
	ecm.free()
	return ok


static func test_c_heading_gold() -> bool:
	var ecm := _make_ecm()
	var ok := ecm.C_HEADING.r > 0.85 and ecm.C_HEADING.g > 0.70 and ecm.C_HEADING.b < 0.20
	ecm.free()
	return ok


static func test_c_preview_muted_parchment() -> bool:
	var ecm := _make_ecm()
	# muted parchment: moderate r, moderate g, moderate b — all close
	var ok := ecm.C_PREVIEW.r > 0.50 and ecm.C_PREVIEW.r < 0.75
	ecm.free()
	return ok


# ── Layout constants ──────────────────────────────────────────────────────────

static func test_panel_width() -> bool:
	var ecm := _make_ecm()
	var ok := ecm.PANEL_WIDTH == 700
	ecm.free()
	return ok


static func test_panel_height() -> bool:
	var ecm := _make_ecm()
	var ok := ecm.PANEL_HEIGHT == 420
	ecm.free()
	return ok


static func test_dim_tween_secs() -> bool:
	var ecm := _make_ecm()
	var ok := ecm.DIM_TWEEN_SECS == 0.5
	ecm.free()
	return ok


# ── Initial node refs ─────────────────────────────────────────────────────────

static func test_initial_backdrop_null() -> bool:
	var ecm := _make_ecm()
	var ok := ecm._backdrop == null
	ecm.free()
	return ok


static func test_initial_panel_null() -> bool:
	var ecm := _make_ecm()
	var ok := ecm._panel == null
	ecm.free()
	return ok


static func test_initial_title_label_null() -> bool:
	var ecm := _make_ecm()
	var ok := ecm._title_label == null
	ecm.free()
	return ok


static func test_initial_body_label_null() -> bool:
	var ecm := _make_ecm()
	var ok := ecm._body_label == null
	ecm.free()
	return ok


static func test_initial_choice_a_btn_null() -> bool:
	var ecm := _make_ecm()
	var ok := ecm._choice_a_btn == null
	ecm.free()
	return ok


static func test_initial_choice_b_btn_null() -> bool:
	var ecm := _make_ecm()
	var ok := ecm._choice_b_btn == null
	ecm.free()
	return ok


static func test_initial_preview_a_null() -> bool:
	var ecm := _make_ecm()
	var ok := ecm._preview_a == null
	ecm.free()
	return ok


static func test_initial_preview_b_null() -> bool:
	var ecm := _make_ecm()
	var ok := ecm._preview_b == null
	ecm.free()
	return ok


static func test_initial_outcome_label_null() -> bool:
	var ecm := _make_ecm()
	var ok := ecm._outcome_label == null
	ecm.free()
	return ok


static func test_initial_dismiss_btn_null() -> bool:
	var ecm := _make_ecm()
	var ok := ecm._dismiss_btn == null
	ecm.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_current_event_id_empty() -> bool:
	var ecm := _make_ecm()
	var ok := ecm._current_event_id == ""
	ecm.free()
	return ok
