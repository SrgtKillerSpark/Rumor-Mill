## test_end_screen_animations.gd — Unit tests for end_screen_animations.gd (SPA-1026).
##
## Covers:
##   • Initial instance state: _owner, _btn_pulse_tween
##   • setup(): stores owner reference
##   • start_count_up(): early-return guard when _owner is null or targets empty
##   • start_btn_pulse(): early-return guard when btn_next is null or disabled
##
## EndScreenAnimations extends RefCounted — safe to instantiate without scene tree.
## Tween paths and timer paths require the full scene tree and are not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestEndScreenAnimations
extends RefCounted

const EndScreenAnimationsScript := preload("res://scripts/end_screen_animations.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_esa() -> RefCounted:
	return EndScreenAnimationsScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Initial state
		"test_initial_owner_null",
		"test_initial_btn_pulse_tween_null",
		# setup()
		"test_setup_stores_owner",
		"test_setup_overwrites_previous_owner",
		# start_count_up null guards
		"test_start_count_up_null_owner_empty_targets_no_crash",
		"test_start_count_up_null_owner_no_crash",
		# start_btn_pulse null guards
		"test_start_btn_pulse_null_btn_no_crash",
		"test_start_btn_pulse_disabled_btn_no_crash",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nEndScreenAnimations tests: %d passed, %d failed" % [passed, failed])


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_owner_null() -> bool:
	return _make_esa()._owner == null


static func test_initial_btn_pulse_tween_null() -> bool:
	return _make_esa()._btn_pulse_tween == null


# ── setup() ───────────────────────────────────────────────────────────────────

static func test_setup_stores_owner() -> bool:
	var esa := _make_esa()
	var stub := Node.new()
	esa.setup(stub)
	var ok := esa._owner == stub
	stub.free()
	return ok


static func test_setup_overwrites_previous_owner() -> bool:
	var esa := _make_esa()
	var stub_a := Node.new()
	var stub_b := Node.new()
	esa.setup(stub_a)
	esa.setup(stub_b)
	var ok := esa._owner == stub_b
	stub_a.free()
	stub_b.free()
	return ok


# ── start_count_up null guards ────────────────────────────────────────────────

## With _owner == null and targets empty, start_count_up must return without crashing.
static func test_start_count_up_null_owner_empty_targets_no_crash() -> bool:
	var esa := _make_esa()
	esa.start_count_up([], null, null, [])
	return true


## With _owner == null but a non-empty target list, the guard also fires (null check first).
static func test_start_count_up_null_owner_no_crash() -> bool:
	var esa := _make_esa()
	# Pass a dummy entry — the guard requires _owner != null before using it.
	var dummy_entry := {"label": null, "target": 5, "suffix": ""}
	esa.start_count_up([dummy_entry], null, null, [])
	return true


# ── start_btn_pulse null guards ───────────────────────────────────────────────

## Null button — must return immediately without crash.
static func test_start_btn_pulse_null_btn_no_crash() -> bool:
	var esa := _make_esa()
	esa.start_btn_pulse(null)
	return true


## Disabled button — must return immediately without crash.
static func test_start_btn_pulse_disabled_btn_no_crash() -> bool:
	var esa := _make_esa()
	var btn := Button.new()
	btn.disabled = true
	esa.start_btn_pulse(btn)
	btn.free()
	return true
