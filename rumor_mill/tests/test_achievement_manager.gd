## test_achievement_manager.gd — Unit tests for AchievementManager (SPA-964).
##
## Covers:
##   • unlock()         — sets achievement as unlocked; is_unlocked() returns true
##   • unlock()         — idempotent: calling twice does not error
##   • unlock()         — unknown id is ignored (no crash; is_unlocked() stays false)
##   • is_unlocked()    — returns false for a never-unlocked id
##   • get_all()        — returns exactly 12 achievements; each has id/name/description/unlocked
##   • get_all()        — unlocked status reflects unlock() calls
##   • ACHIEVEMENTS     — every key has required fields: name, description, steam_api_name
##
## AchievementManager is instantiated with .new(); _ready() is NOT called so Steam
## init and file I/O are skipped entirely.  All assertions use in-memory state only.
##
## Run from the Godot editor:  Scene → Run Script (or call run() directly).

class_name TestAchievementManager
extends RefCounted


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_unlock_sets_unlocked",
		"test_unlock_idempotent",
		"test_unlock_unknown_id_no_crash",
		"test_is_unlocked_false_for_never_unlocked",
		"test_get_all_count",
		"test_get_all_has_required_keys",
		"test_get_all_reflects_unlock",
		"test_achievements_have_required_fields",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nAchievementManager tests: %d passed, %d failed" % [passed, failed])


# ── helpers ──────────────────────────────────────────────────────────────────

## Returns a fresh AchievementManager with no unlocks and no Steam or file context.
## _ready() is intentionally not called; the node is never added to the scene tree.
static func _make_mgr() -> AchievementManager:
	return AchievementManager.new()


# ── tests ────────────────────────────────────────────────────────────────────

## unlock() marks the achievement; is_unlocked() returns true immediately after.
static func test_unlock_sets_unlocked() -> bool:
	var mgr := _make_mgr()
	mgr.unlock("scenario_1_complete")
	return mgr.is_unlocked("scenario_1_complete")


## Calling unlock() twice on the same id does not raise an error; state remains unlocked.
static func test_unlock_idempotent() -> bool:
	var mgr := _make_mgr()
	mgr.unlock("ghost")
	mgr.unlock("ghost")
	return mgr.is_unlocked("ghost")


## unlock() with an unknown id emits a warning and is silently ignored (no crash).
## is_unlocked() must return false for the bogus id.
static func test_unlock_unknown_id_no_crash() -> bool:
	var mgr := _make_mgr()
	mgr.unlock("totally_fake_achievement_xyz")
	return not mgr.is_unlocked("totally_fake_achievement_xyz")


## is_unlocked() returns false for an id that has never been passed to unlock().
static func test_is_unlocked_false_for_never_unlocked() -> bool:
	var mgr := _make_mgr()
	return not mgr.is_unlocked("mastermind")


## get_all() returns exactly 12 entries (one per entry in ACHIEVEMENTS).
static func test_get_all_count() -> bool:
	var mgr := _make_mgr()
	var all := mgr.get_all()
	if all.size() != 12:
		push_error("test_get_all_count: expected 12, got %d" % all.size())
		return false
	return true


## Every entry returned by get_all() has the required keys: id, name, description, unlocked.
static func test_get_all_has_required_keys() -> bool:
	var mgr := _make_mgr()
	for entry in mgr.get_all():
		for key in ["id", "name", "description", "unlocked"]:
			if not entry.has(key):
				push_error("test_get_all_has_required_keys: entry missing '%s': %s" % [key, str(entry)])
				return false
	return true


## After unlock(), the matching entry in get_all() has unlocked == true.
static func test_get_all_reflects_unlock() -> bool:
	var mgr := _make_mgr()
	mgr.unlock("speedrunner")
	for entry in mgr.get_all():
		if entry["id"] == "speedrunner":
			if entry["unlocked"] != true:
				push_error("test_get_all_reflects_unlock: 'speedrunner' unlocked flag is false")
				return false
			return true
	push_error("test_get_all_reflects_unlock: 'speedrunner' not found in get_all()")
	return false


## Every key in the static ACHIEVEMENTS constant has the required definition fields.
static func test_achievements_have_required_fields() -> bool:
	for ach_id in AchievementManager.ACHIEVEMENTS:
		var ach: Dictionary = AchievementManager.ACHIEVEMENTS[ach_id]
		for field in ["name", "description", "steam_api_name"]:
			if not ach.has(field):
				push_error("test_achievements_have_required_fields: '%s' missing '%s'" % [ach_id, field])
				return false
	return true
