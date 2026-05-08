## test_achievement_hooks.gd — Unit tests for AchievementHooks (SPA-988).
##
## Covers the pure-state methods that do not require autoload context:
##   • Initial state        — _ach_exposed == false, _ach_actions_used == {}
##   • player_exposed       — sets _ach_exposed to true
##   • action_performed     — sets observe/eavesdrop flags; ignores failed actions
##   • action_performed     — unrecognized prefix does not set any flag
##   • bribe_executed       — sets bribe flag
##   • multiple actions     — flags accumulate independently
##
## AchievementHooks is instantiated with .new(); connect_signals() is NOT called
## so no Node refs are needed.  Autoload-dependent methods (_on_achievement_rumor_seeded,
## _on_achievement_scenario_resolved) are covered at the integration level via
## TestAchievementManager and in-editor play testing.
##
## Run from the Godot editor:  Scene → Run Script (or call run() directly).

class_name TestAchievementHooks
extends RefCounted


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_initial_state",
		"test_player_exposed",
		"test_action_performed_observe",
		"test_action_performed_eavesdrop",
		"test_action_performed_failed_ignored",
		"test_action_performed_unrecognized_ignored",
		"test_bribe_executed",
		"test_multiple_actions_accumulated",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nAchievementHooks tests: %d passed, %d failed" % [passed, failed])


# ── helpers ──────────────────────────────────────────────────────────────────

## Returns a fresh AchievementHooks with no connected signals and no external refs.
static func _make_hooks() -> AchievementHooks:
	return AchievementHooks.new()


# ── tests ────────────────────────────────────────────────────────────────────

## Fresh hooks have _ach_exposed == false and _ach_actions_used == {}.
static func test_initial_state() -> bool:
	var h := _make_hooks()
	if h._ach_exposed != false:
		push_error("test_initial_state: _ach_exposed should be false")
		return false
	if not h._ach_actions_used.is_empty():
		push_error("test_initial_state: _ach_actions_used should be empty")
		return false
	return true


## _on_achievement_player_exposed() sets _ach_exposed to true.
static func test_player_exposed() -> bool:
	var h := _make_hooks()
	h._on_achievement_player_exposed()
	if not h._ach_exposed:
		push_error("test_player_exposed: _ach_exposed should be true after exposure")
		return false
	return true


## A successful "Observed ..." message sets the observe flag.
static func test_action_performed_observe() -> bool:
	var h := _make_hooks()
	h._on_achievement_action_performed("Observed the merchant", true)
	if not h._ach_actions_used.has("observe"):
		push_error("test_action_performed_observe: observe flag not set")
		return false
	return true


## A successful "Eavesdropped ..." message sets the eavesdrop flag.
static func test_action_performed_eavesdrop() -> bool:
	var h := _make_hooks()
	h._on_achievement_action_performed("Eavesdropped on the guard", true)
	if not h._ach_actions_used.has("eavesdrop"):
		push_error("test_action_performed_eavesdrop: eavesdrop flag not set")
		return false
	return true


## A failed action does not set any flag regardless of message content.
static func test_action_performed_failed_ignored() -> bool:
	var h := _make_hooks()
	h._on_achievement_action_performed("Observed the merchant", false)
	if h._ach_actions_used.has("observe"):
		push_error("test_action_performed_failed_ignored: observe should not be set on failure")
		return false
	return true


## An unrecognized message prefix does not set any flag.
static func test_action_performed_unrecognized_ignored() -> bool:
	var h := _make_hooks()
	h._on_achievement_action_performed("Pickpocketed the noble", true)
	if not h._ach_actions_used.is_empty():
		push_error("test_action_performed_unrecognized_ignored: no flag should be set for unknown action")
		return false
	return true


## _on_achievement_bribe_executed() sets the bribe flag.
static func test_bribe_executed() -> bool:
	var h := _make_hooks()
	h._on_achievement_bribe_executed("Guard Finn", 3)
	if not h._ach_actions_used.has("bribe"):
		push_error("test_bribe_executed: bribe flag not set")
		return false
	return true


## Multiple actions accumulate independently without overwriting each other.
static func test_multiple_actions_accumulated() -> bool:
	var h := _make_hooks()
	h._on_achievement_action_performed("Observed the baker", true)
	h._on_achievement_action_performed("Eavesdropped on the tailor", true)
	h._on_achievement_bribe_executed("Constable", 7)
	if not h._ach_actions_used.has("observe"):
		push_error("test_multiple_actions_accumulated: observe missing")
		return false
	if not h._ach_actions_used.has("eavesdrop"):
		push_error("test_multiple_actions_accumulated: eavesdrop missing")
		return false
	if not h._ach_actions_used.has("bribe"):
		push_error("test_multiple_actions_accumulated: bribe missing")
		return false
	return true
