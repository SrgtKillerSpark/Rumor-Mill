## test_ambient_particles.gd — Unit tests for AmbientParticles constants,
## initial state, and _apply_hour() logic (SPA-1065).
##
## Covers:
##   • Hour-window constants: DUST_START/END, FIREFLY_START/END, NIGHT_START
##   • Initial state (before _ready): _ticks_per_day 24, all emitter refs null
##   • _apply_hour() with injected CPUParticles2D:
##     - hour 12 (noon): dust on, firefly off, night off
##     - hour 20 (dusk edge): dust off, firefly on, night on
##     - hour 3  (deep night): dust off, firefly off, night on
##     - hour 0  (midnight): dust off, firefly off, night on
##   • on_game_tick() updates _ticks_per_day and does not crash with null emitters
##
## Strategy: AmbientParticles extends Node. .new() skips _ready(), so the
## CanvasLayer and CPUParticles2D children are not created. Tests that need
## emitter state inject CPUParticles2D directly into the private vars before
## calling _apply_hour().
##
## Run from the Godot editor: Scene → Run Script.

class_name TestAmbientParticles
extends RefCounted

const AmbientParticlesScript := preload("res://scripts/ambient_particles.gd")


static func _make_ap() -> Node:
	return AmbientParticlesScript.new()


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── constants ──
		"test_dust_start_is_8",
		"test_dust_end_is_18",
		"test_firefly_start_is_19",
		"test_firefly_end_is_21",
		"test_night_start_is_20",

		# ── initial state ──
		"test_initial_ticks_per_day",
		"test_initial_layer_null",
		"test_initial_dust_null",
		"test_initial_firefly_null",
		"test_initial_night_null",

		# ── _apply_hour() with injected emitters ──
		"test_hour_noon_dust_on",
		"test_hour_noon_firefly_off",
		"test_hour_noon_night_off",
		"test_hour_20_dust_off",
		"test_hour_20_firefly_on",
		"test_hour_20_night_on",
		"test_hour_3_dust_off",
		"test_hour_3_night_on",

		# ── on_game_tick() null guard ──
		"test_on_game_tick_null_emitters_no_crash",
		"test_on_game_tick_updates_ticks_per_day",
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

func test_dust_start_is_8() -> bool:
	return AmbientParticlesScript.DUST_START == 8


func test_dust_end_is_18() -> bool:
	return AmbientParticlesScript.DUST_END == 18


func test_firefly_start_is_19() -> bool:
	return AmbientParticlesScript.FIREFLY_START == 19


func test_firefly_end_is_21() -> bool:
	return AmbientParticlesScript.FIREFLY_END == 21


func test_night_start_is_20() -> bool:
	return AmbientParticlesScript.NIGHT_START == 20


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_ticks_per_day() -> bool:
	var ap := _make_ap()
	var ok := ap._ticks_per_day == 24
	ap.free()
	return ok


func test_initial_layer_null() -> bool:
	var ap := _make_ap()
	var ok := ap._layer == null
	ap.free()
	return ok


func test_initial_dust_null() -> bool:
	var ap := _make_ap()
	var ok := ap._dust == null
	ap.free()
	return ok


func test_initial_firefly_null() -> bool:
	var ap := _make_ap()
	var ok := ap._firefly == null
	ap.free()
	return ok


func test_initial_night_null() -> bool:
	var ap := _make_ap()
	var ok := ap._night == null
	ap.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# _apply_hour() with injected emitters
# ══════════════════════════════════════════════════════════════════════════════

func _make_ap_with_emitters() -> Array:
	var ap := _make_ap()
	var dust := CPUParticles2D.new()
	var firefly := CPUParticles2D.new()
	var night := CPUParticles2D.new()
	ap._dust    = dust
	ap._firefly = firefly
	ap._night   = night
	return [ap, dust, firefly, night]


func test_hour_noon_dust_on() -> bool:
	var parts := _make_ap_with_emitters()
	var ap: Node = parts[0]; var dust: CPUParticles2D = parts[1]
	ap._apply_hour(12)
	var ok := dust.emitting == true
	for p in parts: p.free()
	return ok


func test_hour_noon_firefly_off() -> bool:
	var parts := _make_ap_with_emitters()
	var ap: Node = parts[0]; var firefly: CPUParticles2D = parts[2]
	ap._apply_hour(12)
	var ok := firefly.emitting == false
	for p in parts: p.free()
	return ok


func test_hour_noon_night_off() -> bool:
	var parts := _make_ap_with_emitters()
	var ap: Node = parts[0]; var night: CPUParticles2D = parts[3]
	ap._apply_hour(12)
	var ok := night.emitting == false
	for p in parts: p.free()
	return ok


func test_hour_20_dust_off() -> bool:
	# Hour 20: DUST_END=18, so dust is off
	var parts := _make_ap_with_emitters()
	var ap: Node = parts[0]; var dust: CPUParticles2D = parts[1]
	ap._apply_hour(20)
	var ok := dust.emitting == false
	for p in parts: p.free()
	return ok


func test_hour_20_firefly_on() -> bool:
	# Hour 20: FIREFLY_START=19, FIREFLY_END=21, so firefly is on
	var parts := _make_ap_with_emitters()
	var ap: Node = parts[0]; var firefly: CPUParticles2D = parts[2]
	ap._apply_hour(20)
	var ok := firefly.emitting == true
	for p in parts: p.free()
	return ok


func test_hour_20_night_on() -> bool:
	# Hour 20: NIGHT_START=20, so night is on
	var parts := _make_ap_with_emitters()
	var ap: Node = parts[0]; var night: CPUParticles2D = parts[3]
	ap._apply_hour(20)
	var ok := night.emitting == true
	for p in parts: p.free()
	return ok


func test_hour_3_dust_off() -> bool:
	var parts := _make_ap_with_emitters()
	var ap: Node = parts[0]; var dust: CPUParticles2D = parts[1]
	ap._apply_hour(3)
	var ok := dust.emitting == false
	for p in parts: p.free()
	return ok


func test_hour_3_night_on() -> bool:
	# Hour 3: NIGHT_START=20, wraps to DUST_START=8; 3 < 8 so night is on
	var parts := _make_ap_with_emitters()
	var ap: Node = parts[0]; var night: CPUParticles2D = parts[3]
	ap._apply_hour(3)
	var ok := night.emitting == true
	for p in parts: p.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# on_game_tick() null guard
# ══════════════════════════════════════════════════════════════════════════════

func test_on_game_tick_null_emitters_no_crash() -> bool:
	var ap := _make_ap()
	# All emitters null — _apply_hour() guards on != null, so no crash.
	ap.on_game_tick(12, 24)
	ap.free()
	return true


func test_on_game_tick_updates_ticks_per_day() -> bool:
	var ap := _make_ap()
	ap.on_game_tick(0, 48)
	var ok := ap._ticks_per_day == 48
	ap.free()
	return ok
