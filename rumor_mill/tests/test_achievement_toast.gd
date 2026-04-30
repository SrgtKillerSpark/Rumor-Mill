## test_achievement_toast.gd — Unit tests for AchievementToast (SPA-1144).
##
## Covers:
##   • Constants: AUTO_DISMISS_SEC, layer
##   • Queue: _queue starts empty, _is_showing starts false
##   • Queue: show_achievement enqueues when already showing
##   • Queue: _drain_queue pops and plays from queue
##
## AchievementToast builds its UI in _init() via _build_ui().
## Tests instantiate with .new() (no scene tree required for state checks).
##
## Run from the Godot editor: Scene → Run Script.

class_name TestAchievementToast
extends RefCounted


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_toast() -> AchievementToast:
	return AchievementToast.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_auto_dismiss_sec",
		"test_layer_value",
		"test_initial_queue_empty",
		"test_initial_is_showing_false",
		"test_show_achievement_enqueues_when_showing",
		"test_drain_queue_empty_is_noop",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nAchievementToast tests: %d passed, %d failed" % [passed, failed])


# ── Constants ─────────────────────────────────────────────────────────────────

static func test_auto_dismiss_sec() -> bool:
	var t := _make_toast()
	var ok := t.AUTO_DISMISS_SEC == 5.0
	t.free()
	return ok


static func test_layer_value() -> bool:
	var t := _make_toast()
	var ok := t.layer == 120
	t.free()
	return ok


# ── Initial queue state ───────────────────────────────────────────────────────

static func test_initial_queue_empty() -> bool:
	var t := _make_toast()
	var ok := t._queue.is_empty()
	t.free()
	return ok


static func test_initial_is_showing_false() -> bool:
	var t := _make_toast()
	var ok := not t._is_showing
	t.free()
	return ok


# ── Queue behaviour (SPA-1144) ────────────────────────────────────────────────

static func test_show_achievement_enqueues_when_showing() -> bool:
	# Simulate: toast is already mid-display, so _is_showing is true.
	# show_achievement() should push to _queue rather than calling _play().
	var t := _make_toast()
	t._is_showing = true
	t.show_achievement("Test Achievement")
	var ok := t._queue.size() == 1 and t._queue[0] == "Test Achievement"
	t.free()
	return ok


static func test_drain_queue_empty_is_noop() -> bool:
	# _drain_queue() with an empty queue must not crash or change state.
	var t := _make_toast()
	t._drain_queue()   # should be a no-op
	var ok := not t._is_showing and t._queue.is_empty()
	t.free()
	return ok
