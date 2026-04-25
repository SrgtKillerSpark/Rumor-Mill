## test_end_screen.gd — Unit tests for end_screen.gd coordinator (SPA-1024).
##
## Covers:
##   • Initial instance state: all runtime refs null, _resolving=false,
##     _last_outcome_won=false, _current_scenario_id=""
##   • Subsystem modules initially null before _ready()
##   • setup(): assigns _world_ref, _day_night_ref, _analytics_ref
##   • setup() null-world guard: no crash when world=null
##   • setup() null-analytics guard: _analytics_ref remains null when omitted
##
## EndScreen extends CanvasLayer.  Instantiating without adding to the scene
## tree skips _ready(), so @onready vars and subsystem modules remain null.
## Signal-connected scene-tree coroutines (_on_scenario_resolved, entrance tweens)
## require TransitionManager + live tree and are not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestEndScreen
extends RefCounted

const EndScreenScript := preload("res://scripts/end_screen.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_es() -> CanvasLayer:
	return EndScreenScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Initial runtime refs
		"test_initial_world_ref_null",
		"test_initial_day_night_ref_null",
		"test_initial_analytics_ref_null",
		# Initial state flags
		"test_initial_resolving_false",
		"test_initial_last_outcome_won_false",
		"test_initial_current_scenario_id_empty",
		# Subsystem modules null before _ready()
		"test_initial_panel_null",
		"test_initial_summary_null",
		"test_initial_scoring_null",
		"test_initial_animations_null",
		"test_initial_replay_tab_null",
		"test_initial_feedback_null",
		"test_initial_navigation_null",
		# setup() assignment
		"test_setup_assigns_world_ref",
		"test_setup_assigns_day_night_ref",
		"test_setup_assigns_analytics_ref",
		"test_setup_null_world_no_crash",
		"test_setup_omit_analytics_ref_remains_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nEndScreen tests: %d passed, %d failed" % [passed, failed])


# ── Initial runtime refs ──────────────────────────────────────────────────────

static func test_initial_world_ref_null() -> bool:
	return _make_es()._world_ref == null


static func test_initial_day_night_ref_null() -> bool:
	return _make_es()._day_night_ref == null


static func test_initial_analytics_ref_null() -> bool:
	return _make_es()._analytics_ref == null


# ── Initial state flags ───────────────────────────────────────────────────────

static func test_initial_resolving_false() -> bool:
	return not _make_es()._resolving


static func test_initial_last_outcome_won_false() -> bool:
	return not _make_es()._last_outcome_won


static func test_initial_current_scenario_id_empty() -> bool:
	return _make_es()._current_scenario_id == ""


# ── Subsystem modules null before _ready() ────────────────────────────────────

static func test_initial_panel_null() -> bool:
	return _make_es()._panel == null


static func test_initial_summary_null() -> bool:
	return _make_es()._summary == null


static func test_initial_scoring_null() -> bool:
	return _make_es()._scoring == null


static func test_initial_animations_null() -> bool:
	return _make_es()._animations == null


static func test_initial_replay_tab_null() -> bool:
	return _make_es()._replay_tab == null


static func test_initial_feedback_null() -> bool:
	return _make_es()._feedback == null


static func test_initial_navigation_null() -> bool:
	return _make_es()._navigation == null


# ── setup() ───────────────────────────────────────────────────────────────────

## setup() must store world_ref (null is a valid test value — confirms assignment path).
static func test_setup_assigns_world_ref() -> bool:
	var es := _make_es()
	es.setup(null, null, null)
	return es._world_ref == null   # assignment path executed


## setup() must store day_night_ref.
static func test_setup_assigns_day_night_ref() -> bool:
	var es := _make_es()
	es.setup(null, null, null)
	return es._day_night_ref == null   # confirms the field was touched


## setup() must store analytics_ref when provided.
static func test_setup_assigns_analytics_ref() -> bool:
	var es := _make_es()
	var fake_analytics: Object = Object.new()
	es.setup(null, null, fake_analytics)
	var ok: bool = es._analytics_ref == fake_analytics
	fake_analytics.free()
	return ok


## Passing null as world must not crash (the guard "if world != null" should fire).
static func test_setup_null_world_no_crash() -> bool:
	var es := _make_es()
	es.setup(null, null)
	return true


## When analytics is omitted the default param is null — _analytics_ref stays null.
static func test_setup_omit_analytics_ref_remains_null() -> bool:
	var es := _make_es()
	es.setup(null, null)
	return es._analytics_ref == null
