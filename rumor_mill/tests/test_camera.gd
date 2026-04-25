## test_camera.gd — Unit tests for camera.gd (SPA-1042).
##
## Covers:
##   • Export parameter defaults: pan_speed, zoom_speed, zoom_min, zoom_max,
##     zoom_lerp_speed, edge_pan_enabled, edge_pan_margin, edge_pan_speed,
##     follow_lerp_speed
##   • Initial state: _target_zoom=1.5, _is_dragging=false,
##                    _camera_moved_emitted=false, _follow_target=null
##
## NOTE: _ready() sets position and limit values — requires scene tree, not tested.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestCamera
extends RefCounted

const CameraScript := preload("res://scripts/camera.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_cam() -> Camera2D:
	return CameraScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Export defaults
		"test_pan_speed",
		"test_zoom_speed",
		"test_zoom_min",
		"test_zoom_max",
		"test_zoom_lerp_speed",
		"test_edge_pan_enabled",
		"test_edge_pan_margin",
		"test_edge_pan_speed",
		"test_follow_lerp_speed",
		# Initial state
		"test_initial_target_zoom",
		"test_initial_drag_origin",
		"test_initial_is_dragging_false",
		"test_initial_camera_moved_emitted_false",
		"test_initial_follow_target_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nCamera tests: %d passed, %d failed" % [passed, failed])


# ── Export parameter defaults ─────────────────────────────────────────────────

static func test_pan_speed() -> bool:
	var cam := _make_cam()
	var ok := cam.pan_speed == 400.0
	cam.free()
	return ok


static func test_zoom_speed() -> bool:
	var cam := _make_cam()
	var ok := abs(cam.zoom_speed - 0.15) < 0.001
	cam.free()
	return ok


static func test_zoom_min() -> bool:
	var cam := _make_cam()
	var ok := cam.zoom_min == 0.5
	cam.free()
	return ok


static func test_zoom_max() -> bool:
	var cam := _make_cam()
	var ok := cam.zoom_max == 2.0
	cam.free()
	return ok


static func test_zoom_lerp_speed() -> bool:
	var cam := _make_cam()
	var ok := cam.zoom_lerp_speed == 8.0
	cam.free()
	return ok


static func test_edge_pan_enabled() -> bool:
	var cam := _make_cam()
	var ok := cam.edge_pan_enabled == true
	cam.free()
	return ok


static func test_edge_pan_margin() -> bool:
	var cam := _make_cam()
	var ok := cam.edge_pan_margin == 40.0
	cam.free()
	return ok


static func test_edge_pan_speed() -> bool:
	var cam := _make_cam()
	var ok := cam.edge_pan_speed == 350.0
	cam.free()
	return ok


static func test_follow_lerp_speed() -> bool:
	var cam := _make_cam()
	var ok := cam.follow_lerp_speed == 5.0
	cam.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_target_zoom() -> bool:
	var cam := _make_cam()
	var ok := cam._target_zoom == 1.5
	cam.free()
	return ok


static func test_initial_drag_origin() -> bool:
	var cam := _make_cam()
	var ok := cam._drag_origin.is_equal_approx(Vector2.ZERO)
	cam.free()
	return ok


static func test_initial_is_dragging_false() -> bool:
	var cam := _make_cam()
	var ok := cam._is_dragging == false
	cam.free()
	return ok


static func test_initial_camera_moved_emitted_false() -> bool:
	var cam := _make_cam()
	var ok := cam._camera_moved_emitted == false
	cam.free()
	return ok


static func test_initial_follow_target_null() -> bool:
	var cam := _make_cam()
	var ok := cam._follow_target == null
	cam.free()
	return ok
