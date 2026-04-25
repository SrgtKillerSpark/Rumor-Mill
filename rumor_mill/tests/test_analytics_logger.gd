## test_analytics_logger.gd — Unit tests for AnalyticsLogger constants and
## initial state (SPA-1065).
##
## Covers:
##   • SAVE_PATH constant value
##   • Initial state: _session_start_time == 0
##   • get_session_duration_seconds() returns 0 before start_session() is called
##   • start_session() sets _session_start_time to a positive value
##   • get_session_duration_seconds() returns non-negative after start_session()
##
## Strategy: AnalyticsLogger extends RefCounted — instantiated via .new().
## log_event() writes to user:// and checks SettingsManager.analytics_enabled
## (autoload), which is safe in the editor test runner but file writes are
## intentionally NOT exercised here to keep the suite side-effect-free.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestAnalyticsLogger
extends RefCounted

const AnalyticsLoggerScript := preload("res://scripts/analytics_logger.gd")


static func _make_al() -> AnalyticsLogger:
	return AnalyticsLoggerScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── constants ──
		"test_save_path_value",

		# ── initial state ──
		"test_initial_session_start_time_zero",
		"test_get_session_duration_zero_before_start",

		# ── start_session() ──
		"test_start_session_sets_positive_time",
		"test_duration_non_negative_after_start",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			print("  FAIL  %s" % method_name)
			failed += 1

	print("\n  %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

func test_save_path_value() -> bool:
	return AnalyticsLoggerScript.SAVE_PATH == "user://analytics.json"


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_session_start_time_zero() -> bool:
	var al := _make_al()
	return al._session_start_time == 0


func test_get_session_duration_zero_before_start() -> bool:
	var al := _make_al()
	return al.get_session_duration_seconds() == 0


# ══════════════════════════════════════════════════════════════════════════════
# start_session()
# ══════════════════════════════════════════════════════════════════════════════

func test_start_session_sets_positive_time() -> bool:
	var al := _make_al()
	al.start_session("scenario_1", "apprentice")
	return al._session_start_time > 0


func test_duration_non_negative_after_start() -> bool:
	var al := _make_al()
	al.start_session("scenario_1", "apprentice")
	return al.get_session_duration_seconds() >= 0
