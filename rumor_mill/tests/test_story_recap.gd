## test_story_recap.gd — Unit tests for story_recap.gd (SPA-1042).
##
## Covers:
##   • Palette constants
##   • Initial node refs null (setup() calls _build_ui() and _populate(), which
##     require a scene tree — so we test without calling setup())
##
## NOTE: setup() calls _build_ui() + _populate() which add nodes — not tested here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestStoryRecap
extends RefCounted

const StoryRecapScript := preload("res://scripts/story_recap.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_sr() -> CanvasLayer:
	return StoryRecapScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_backdrop_near_black",
		"test_c_title_is_gold",
		"test_c_accent_is_amber",
		"test_c_muted_subdued",
		# Initial node refs
		"test_initial_backdrop_null",
		"test_initial_panel_null",
		"test_initial_title_label_null",
		"test_initial_body_null",
		"test_initial_dismiss_hint_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nStoryRecap tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_backdrop_near_black() -> bool:
	var sr := _make_sr()
	var ok := sr.C_BACKDROP.r < 0.10 and sr.C_BACKDROP.a > 0.80
	sr.free()
	return ok


static func test_c_title_is_gold() -> bool:
	var sr := _make_sr()
	var ok := sr.C_TITLE.r > 0.85 and sr.C_TITLE.g > 0.70 and sr.C_TITLE.b < 0.20
	sr.free()
	return ok


static func test_c_accent_is_amber() -> bool:
	var sr := _make_sr()
	# amber: high r, moderate g, low b
	var ok := sr.C_ACCENT.r > 0.90 and sr.C_ACCENT.g > 0.55 and sr.C_ACCENT.b < 0.35
	sr.free()
	return ok


static func test_c_muted_subdued() -> bool:
	var sr := _make_sr()
	# muted: moderate r, moderate g, moderate b (all somewhat close)
	var ok := sr.C_MUTED.r > 0.50 and sr.C_MUTED.r < 0.75
	sr.free()
	return ok


# ── Initial node refs ─────────────────────────────────────────────────────────

static func test_initial_backdrop_null() -> bool:
	var sr := _make_sr()
	var ok := sr._backdrop == null
	sr.free()
	return ok


static func test_initial_panel_null() -> bool:
	var sr := _make_sr()
	var ok := sr._panel == null
	sr.free()
	return ok


static func test_initial_title_label_null() -> bool:
	var sr := _make_sr()
	var ok := sr._title_label == null
	sr.free()
	return ok


static func test_initial_body_null() -> bool:
	var sr := _make_sr()
	var ok := sr._body == null
	sr.free()
	return ok


static func test_initial_dismiss_hint_null() -> bool:
	var sr := _make_sr()
	var ok := sr._dismiss_hint == null
	sr.free()
	return ok
