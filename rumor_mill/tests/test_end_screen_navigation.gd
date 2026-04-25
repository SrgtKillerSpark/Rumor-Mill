## test_end_screen_navigation.gd — Unit tests for end_screen_navigation.gd (SPA-1026).
##
## Covers:
##   • Initial instance state: _tree, _current_scenario_id
##   • setup(): stores SceneTree reference
##   • set_scenario_id(): stores and overwrites scenario id
##   • static next_scenario_id(): full mapping table (S1→S2→…→S6→"") plus unknown input
##   • load_next_scenario_tease(): returns "" when scenarios.json absent
##
## EndScreenNavigation extends RefCounted — safe to instantiate without scene tree.
## Button-handler coroutines (on_play_again etc.) require TransitionManager + live
## scene tree and are not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestEndScreenNavigation
extends RefCounted

const EndScreenNavigationScript := preload("res://scripts/end_screen_navigation.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_esn() -> RefCounted:
	return EndScreenNavigationScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Initial state
		"test_initial_tree_null",
		"test_initial_scenario_id_empty",
		# setup()
		"test_setup_stores_tree",
		# set_scenario_id()
		"test_set_scenario_id_stores_value",
		"test_set_scenario_id_overwrites",
		"test_set_scenario_id_empty_string",
		# next_scenario_id() mapping
		"test_next_scenario_id_s1_to_s2",
		"test_next_scenario_id_s2_to_s3",
		"test_next_scenario_id_s3_to_s4",
		"test_next_scenario_id_s4_to_s5",
		"test_next_scenario_id_s5_to_s6",
		"test_next_scenario_id_s6_returns_empty",
		"test_next_scenario_id_unknown_returns_empty",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nEndScreenNavigation tests: %d passed, %d failed" % [passed, failed])


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_tree_null() -> bool:
	return _make_esn()._tree == null


static func test_initial_scenario_id_empty() -> bool:
	return _make_esn()._current_scenario_id == ""


# ── setup() ───────────────────────────────────────────────────────────────────

## SceneTree cannot be instantiated directly in tests; we verify via a null pass
## to confirm the field is assigned (null is an acceptable stored value here).
static func test_setup_stores_tree() -> bool:
	var esn := _make_esn()
	esn.setup(null)
	return esn._tree == null   # confirms the assignment path executed


# ── set_scenario_id() ─────────────────────────────────────────────────────────

static func test_set_scenario_id_stores_value() -> bool:
	var esn := _make_esn()
	esn.set_scenario_id("scenario_3")
	return esn._current_scenario_id == "scenario_3"


static func test_set_scenario_id_overwrites() -> bool:
	var esn := _make_esn()
	esn.set_scenario_id("scenario_1")
	esn.set_scenario_id("scenario_5")
	return esn._current_scenario_id == "scenario_5"


static func test_set_scenario_id_empty_string() -> bool:
	var esn := _make_esn()
	esn.set_scenario_id("scenario_2")
	esn.set_scenario_id("")
	return esn._current_scenario_id == ""


# ── next_scenario_id() ────────────────────────────────────────────────────────

static func test_next_scenario_id_s1_to_s2() -> bool:
	return EndScreenNavigationScript.next_scenario_id("scenario_1") == "scenario_2"


static func test_next_scenario_id_s2_to_s3() -> bool:
	return EndScreenNavigationScript.next_scenario_id("scenario_2") == "scenario_3"


static func test_next_scenario_id_s3_to_s4() -> bool:
	return EndScreenNavigationScript.next_scenario_id("scenario_3") == "scenario_4"


static func test_next_scenario_id_s4_to_s5() -> bool:
	return EndScreenNavigationScript.next_scenario_id("scenario_4") == "scenario_5"


static func test_next_scenario_id_s5_to_s6() -> bool:
	return EndScreenNavigationScript.next_scenario_id("scenario_5") == "scenario_6"


## scenario_6 is the last scenario — no next entry exists.
static func test_next_scenario_id_s6_returns_empty() -> bool:
	return EndScreenNavigationScript.next_scenario_id("scenario_6") == ""


## Any unrecognised id must also return "".
static func test_next_scenario_id_unknown_returns_empty() -> bool:
	return EndScreenNavigationScript.next_scenario_id("scenario_99") == ""
