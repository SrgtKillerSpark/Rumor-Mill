## test_feedback_sequence.gd — Unit tests for feedback_sequence.gd (SPA-1042).
##
## Covers:
##   • Palette constants: win/fail banner colours, particle colours, vignette
##   • Shader string constants are non-empty
##   • Initial state: refs null, _running=false
##
## NOTE: play_sequence() drives tweens and create_tween() — not tested here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestFeedbackSequence
extends RefCounted

const FeedbackSequenceScript := preload("res://scripts/feedback_sequence.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_fs() -> CanvasLayer:
	return FeedbackSequenceScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette
		"test_c_gold_vignette_translucent",
		"test_c_banner_win_bg_dark",
		"test_c_banner_fail_bg_dark_red",
		"test_c_banner_win_tx_warm",
		"test_c_banner_fail_tx_red",
		"test_c_particle_gold_bright",
		# Shader constants
		"test_vignette_shader_nonempty",
		"test_desaturation_shader_nonempty",
		"test_iris_shader_nonempty",
		# Initial state
		"test_initial_camera_ref_null",
		"test_initial_day_night_ref_null",
		"test_initial_world_ref_null",
		"test_initial_vignette_rect_null",
		"test_initial_desat_rect_null",
		"test_initial_iris_rect_null",
		"test_initial_banner_panel_null",
		"test_initial_banner_label_null",
		"test_initial_particle_layer_null",
		"test_initial_running_false",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nFeedbackSequence tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_gold_vignette_translucent() -> bool:
	var fs := _make_fs()
	var ok := fs.C_GOLD_VIGNETTE.a < 0.60 and fs.C_GOLD_VIGNETTE.r > 0.85
	fs.free()
	return ok


static func test_c_banner_win_bg_dark() -> bool:
	var fs := _make_fs()
	var ok := fs.C_BANNER_WIN_BG.r < 0.25 and fs.C_BANNER_WIN_BG.a > 0.85
	fs.free()
	return ok


static func test_c_banner_fail_bg_dark_red() -> bool:
	var fs := _make_fs()
	# dark red: r > g and r > b, but all still dark
	var ok := fs.C_BANNER_FAIL_BG.r > fs.C_BANNER_FAIL_BG.g and fs.C_BANNER_FAIL_BG.r < 0.30
	fs.free()
	return ok


static func test_c_banner_win_tx_warm() -> bool:
	var fs := _make_fs()
	# warm parchment: high r, high g, moderate b
	var ok := fs.C_BANNER_WIN_TX.r > 0.85 and fs.C_BANNER_WIN_TX.g > 0.80
	fs.free()
	return ok


static func test_c_banner_fail_tx_red() -> bool:
	var fs := _make_fs()
	var ok := fs.C_BANNER_FAIL_TX.r > 0.85 and fs.C_BANNER_FAIL_TX.g < 0.50
	fs.free()
	return ok


static func test_c_particle_gold_bright() -> bool:
	var fs := _make_fs()
	var ok := fs.C_PARTICLE_GOLD.r == 1.0 and fs.C_PARTICLE_GOLD.g > 0.75
	fs.free()
	return ok


# ── Shader constants ──────────────────────────────────────────────────────────

static func test_vignette_shader_nonempty() -> bool:
	var fs := _make_fs()
	var ok := not (fs.VIGNETTE_SHADER as String).is_empty()
	fs.free()
	return ok


static func test_desaturation_shader_nonempty() -> bool:
	var fs := _make_fs()
	var ok := not (fs.DESATURATION_SHADER as String).is_empty()
	fs.free()
	return ok


static func test_iris_shader_nonempty() -> bool:
	var fs := _make_fs()
	var ok := not (fs.IRIS_SHADER as String).is_empty()
	fs.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_camera_ref_null() -> bool:
	var fs := _make_fs()
	var ok := fs._camera_ref == null
	fs.free()
	return ok


static func test_initial_day_night_ref_null() -> bool:
	var fs := _make_fs()
	var ok := fs._day_night_ref == null
	fs.free()
	return ok


static func test_initial_world_ref_null() -> bool:
	var fs := _make_fs()
	var ok := fs._world_ref == null
	fs.free()
	return ok


static func test_initial_vignette_rect_null() -> bool:
	var fs := _make_fs()
	var ok := fs._vignette_rect == null
	fs.free()
	return ok


static func test_initial_desat_rect_null() -> bool:
	var fs := _make_fs()
	var ok := fs._desat_rect == null
	fs.free()
	return ok


static func test_initial_iris_rect_null() -> bool:
	var fs := _make_fs()
	var ok := fs._iris_rect == null
	fs.free()
	return ok


static func test_initial_banner_panel_null() -> bool:
	var fs := _make_fs()
	var ok := fs._banner_panel == null
	fs.free()
	return ok


static func test_initial_banner_label_null() -> bool:
	var fs := _make_fs()
	var ok := fs._banner_label == null
	fs.free()
	return ok


static func test_initial_particle_layer_null() -> bool:
	var fs := _make_fs()
	var ok := fs._particle_layer == null
	fs.free()
	return ok


static func test_initial_running_false() -> bool:
	var fs := _make_fs()
	var ok := fs._running == false
	fs.free()
	return ok
