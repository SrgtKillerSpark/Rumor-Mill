## test_weather_system.gd — Unit tests for WeatherSystem constants and initial state (SPA-1041).
##
## Covers:
##   • Tuning constants: RAIN_START_CHANCE, RAIN_STOP_CHANCE, RAIN_FORBIDDEN_HOUR, RAIN_MAX_ALPHA
##   • Initial state (before _ready fires — Node not in scene tree): is_raining false, _rain_time 0
##   • _start_rain() / _stop_rain() state transitions (invoked directly, tween skipped)
##
## Strategy: WeatherSystem extends Node. Instantiating via .new() does NOT fire _ready(),
## so overlay/tween setup is skipped. _start_rain() and _stop_rain() call emit_signal
## and _set_overlay_alpha(); the latter guards on _rect == null, so it is safe to call
## without a scene tree. The tween returned is null/invalid but no error fires.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestWeatherSystem
extends RefCounted

const WeatherSystemScript := preload("res://scripts/weather_system.gd")


static func _make_ws() -> Node:
	return WeatherSystemScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── constants ──
		"test_rain_start_chance_is_004",
		"test_rain_stop_chance_is_022",
		"test_rain_forbidden_hour_is_0",
		"test_rain_max_alpha_is_055",

		# ── initial state ──
		"test_initial_is_raining_false",
		"test_initial_rain_time_zero",

		# ── _start_rain / _stop_rain state flags ──
		"test_start_rain_sets_is_raining",
		"test_start_rain_resets_rain_time",
		"test_stop_rain_clears_is_raining",
		"test_start_rain_noop_when_already_raining",
		"test_stop_rain_noop_when_not_raining",
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

func test_rain_start_chance_is_004() -> bool:
	return absf(WeatherSystemScript.RAIN_START_CHANCE - 0.04) < 0.0001


func test_rain_stop_chance_is_022() -> bool:
	return absf(WeatherSystemScript.RAIN_STOP_CHANCE - 0.22) < 0.0001


func test_rain_forbidden_hour_is_0() -> bool:
	return WeatherSystemScript.RAIN_FORBIDDEN_HOUR == 0


func test_rain_max_alpha_is_055() -> bool:
	return absf(WeatherSystemScript.RAIN_MAX_ALPHA - 0.55) < 0.0001


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_is_raining_false() -> bool:
	var ws := _make_ws()
	var result := ws.is_raining == false
	ws.free()
	return result


func test_initial_rain_time_zero() -> bool:
	var ws := _make_ws()
	var result := absf(ws._rain_time) < 0.0001
	ws.free()
	return result


# ══════════════════════════════════════════════════════════════════════════════
# _start_rain / _stop_rain
# (tween and overlay are null — _set_overlay_alpha guards on _rect == null)
# ══════════════════════════════════════════════════════════════════════════════

func test_start_rain_sets_is_raining() -> bool:
	var ws := _make_ws()
	ws._start_rain()
	var result := ws.is_raining == true
	ws.free()
	return result


func test_start_rain_resets_rain_time() -> bool:
	var ws := _make_ws()
	ws._rain_time = 99.0
	ws._start_rain()
	var result := absf(ws._rain_time) < 0.0001
	ws.free()
	return result


func test_stop_rain_clears_is_raining() -> bool:
	var ws := _make_ws()
	ws.is_raining = true
	ws._stop_rain()
	var result := ws.is_raining == false
	ws.free()
	return result


func test_start_rain_noop_when_already_raining() -> bool:
	var ws := _make_ws()
	ws.is_raining = true
	ws._rain_time = 5.0
	ws._start_rain()
	# Guard `if is_raining: return` → _rain_time NOT reset to 0
	var result := absf(ws._rain_time - 5.0) < 0.0001
	ws.free()
	return result


func test_stop_rain_noop_when_not_raining() -> bool:
	var ws := _make_ws()
	ws.is_raining = false
	ws._stop_rain()
	# Guard `if not is_raining: return` — still false
	var result := ws.is_raining == false
	ws.free()
	return result
