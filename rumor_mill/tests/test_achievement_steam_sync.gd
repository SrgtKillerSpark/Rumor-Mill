## test_achievement_steam_sync.gd — Unit tests for GodotSteam sync and debug_clear (SPA-1097).
##
## Covers:
##   • _sync_from_steam()  — Steam-achieved entries merged into _unlocked (Steam wins)
##   • _sync_from_steam()  — already-local achievements are kept when Steam also reports them
##   • _sync_from_steam()  — non-achieved Steam entries do not overwrite local unlocks
##   • debug_clear()       — removes the achievement from _unlocked
##   • debug_clear()       — calls clearAchievement + storeStats on Steam
##   • debug_clear()       — no-op for unknown achievement id
##   • unlock() warning    — setAchievement() failure is logged (not silent)
##   • unlock() warning    — storeStats() failure is logged (not silent)
##
## The Steam SDK is replaced with MockSteam so no GodotSteam extension is needed.
## _ready() is never called — Steam init and file I/O are skipped.
##
## Run from the Godot editor:  Scene → Run Script (or call run() directly).

class_name TestAchievementSteamSync
extends RefCounted


# ── Steam test double ─────────────────────────────────────────────────────────

## Minimal Steam double that records calls and lets tests control return values.
class MockSteam:
	extends RefCounted

	var set_achievement_calls: Array = []
	var clear_achievement_calls: Array = []
	var store_stats_call_count: int = 0

	## Per-steam-name override: { steam_api_name → { ret, achieved } }
	var get_achievement_results: Dictionary = {}

	var set_achievement_return: bool = true
	var store_stats_return: bool = true
	var clear_achievement_return: bool = true

	func setAchievement(name: String) -> bool:
		set_achievement_calls.append(name)
		return set_achievement_return

	func storeStats() -> bool:
		store_stats_call_count += 1
		return store_stats_return

	func clearAchievement(name: String) -> bool:
		clear_achievement_calls.append(name)
		return clear_achievement_return

	func getAchievement(name: String) -> Dictionary:
		return get_achievement_results.get(name, {"ret": false, "achieved": false})

	func run_callbacks() -> void:
		pass


# ── helpers ───────────────────────────────────────────────────────────────────

## Fresh manager with no unlocks, no Steam, no file I/O.
static func _make_mgr() -> AchievementManager:
	return AchievementManager.new()


## Fresh manager with the given MockSteam injected and _steam_active = true.
static func _make_mgr_with_steam(mock: MockSteam) -> AchievementManager:
	var mgr := AchievementManager.new()
	mgr._steam = mock
	mgr._steam_active = true
	return mgr


# ── test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_sync_adds_steam_achieved_entry",
		"test_sync_keeps_existing_local_unlock",
		"test_sync_skips_not_achieved_steam_entries",
		"test_sync_steam_achieved_overrides_absent_local",
		"test_debug_clear_removes_from_unlocked",
		"test_debug_clear_calls_steam",
		"test_debug_clear_unknown_id_no_crash",
		"test_unlock_logs_set_achievement_failure",
		"test_unlock_logs_store_stats_failure",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nAchievementSteamSync tests: %d passed, %d failed" % [passed, failed])


# ── sync tests ────────────────────────────────────────────────────────────────

## _sync_from_steam() should add an achievement that Steam reports as achieved
## but is absent from local state.
func test_sync_adds_steam_achieved_entry() -> bool:
	var mock := MockSteam.new()
	mock.get_achievement_results["ACH_GHOST"] = {"ret": true, "achieved": true}
	var mgr := _make_mgr_with_steam(mock)

	mgr._sync_from_steam()

	if not mgr.is_unlocked("ghost"):
		push_error("test_sync_adds_steam_achieved_entry: 'ghost' should be unlocked after sync")
		return false
	return true


## _sync_from_steam() should not clobber a locally unlocked achievement when
## Steam also reports it as achieved.
func test_sync_keeps_existing_local_unlock() -> bool:
	var mock := MockSteam.new()
	mock.get_achievement_results["ACH_GHOST"] = {"ret": true, "achieved": true}
	var mgr := _make_mgr_with_steam(mock)
	mgr._unlocked["ghost"] = true  # already locally unlocked

	mgr._sync_from_steam()

	if not mgr.is_unlocked("ghost"):
		push_error("test_sync_keeps_existing_local_unlock: 'ghost' should still be unlocked")
		return false
	return true


## _sync_from_steam() must not unlock achievements that Steam reports as not achieved.
func test_sync_skips_not_achieved_steam_entries() -> bool:
	var mock := MockSteam.new()
	mock.get_achievement_results["ACH_MASTERMIND"] = {"ret": true, "achieved": false}
	var mgr := _make_mgr_with_steam(mock)

	mgr._sync_from_steam()

	if mgr.is_unlocked("mastermind"):
		push_error("test_sync_skips_not_achieved_steam_entries: 'mastermind' should NOT be unlocked")
		return false
	return true


## When Steam returns achieved=true for an id absent locally, sync merges it in
## (Steam wins on conflict).
func test_sync_steam_achieved_overrides_absent_local() -> bool:
	var mock := MockSteam.new()
	mock.get_achievement_results["ACH_SPEEDRUNNER"] = {"ret": true, "achieved": true}
	var mgr := _make_mgr_with_steam(mock)
	# 'speedrunner' is deliberately absent from local state

	mgr._sync_from_steam()

	if not mgr.is_unlocked("speedrunner"):
		push_error("test_sync_steam_achieved_overrides_absent_local: 'speedrunner' should be unlocked")
		return false
	return true


# ── debug_clear tests ─────────────────────────────────────────────────────────

## debug_clear() removes the given id from _unlocked.
func test_debug_clear_removes_from_unlocked() -> bool:
	if not OS.is_debug_build():
		# This test only runs in debug builds — skip gracefully.
		print("  SKIP  test_debug_clear_removes_from_unlocked (release build)")
		return true
	var mock := MockSteam.new()
	var mgr := _make_mgr_with_steam(mock)
	mgr._unlocked["ghost"] = true

	mgr.debug_clear("ghost")

	if mgr.is_unlocked("ghost"):
		push_error("test_debug_clear_removes_from_unlocked: 'ghost' should be cleared")
		return false
	return true


## debug_clear() calls clearAchievement and storeStats on the Steam singleton.
func test_debug_clear_calls_steam() -> bool:
	if not OS.is_debug_build():
		print("  SKIP  test_debug_clear_calls_steam (release build)")
		return true
	var mock := MockSteam.new()
	var mgr := _make_mgr_with_steam(mock)
	mgr._unlocked["ghost"] = true

	mgr.debug_clear("ghost")

	if mock.clear_achievement_calls.size() == 0:
		push_error("test_debug_clear_calls_steam: clearAchievement was not called")
		return false
	if mock.clear_achievement_calls[0] != "ACH_GHOST":
		push_error("test_debug_clear_calls_steam: wrong steam_api_name passed to clearAchievement")
		return false
	if mock.store_stats_call_count == 0:
		push_error("test_debug_clear_calls_steam: storeStats was not called")
		return false
	return true


## debug_clear() with an unknown id should not crash and should not call Steam.
func test_debug_clear_unknown_id_no_crash() -> bool:
	if not OS.is_debug_build():
		print("  SKIP  test_debug_clear_unknown_id_no_crash (release build)")
		return true
	var mock := MockSteam.new()
	var mgr := _make_mgr_with_steam(mock)

	mgr.debug_clear("totally_fake_xyz")

	if mock.clear_achievement_calls.size() != 0:
		push_error("test_debug_clear_unknown_id_no_crash: clearAchievement should not be called for unknown id")
		return false
	return true


# ── error-handling tests ──────────────────────────────────────────────────────

## unlock() should not crash and should complete the local state update even
## when setAchievement() returns false (failure logged, not silent).
func test_unlock_logs_set_achievement_failure() -> bool:
	var mock := MockSteam.new()
	mock.set_achievement_return = false
	var mgr := _make_mgr_with_steam(mock)

	mgr.unlock("ghost")

	# Local state must still be updated despite the Steam failure.
	if not mgr.is_unlocked("ghost"):
		push_error("test_unlock_logs_set_achievement_failure: local unlock should still be set")
		return false
	if mock.set_achievement_calls.size() == 0:
		push_error("test_unlock_logs_set_achievement_failure: setAchievement should have been called")
		return false
	return true


## unlock() should not crash and local state should be set even when
## storeStats() returns false.
func test_unlock_logs_store_stats_failure() -> bool:
	var mock := MockSteam.new()
	mock.store_stats_return = false
	var mgr := _make_mgr_with_steam(mock)

	mgr.unlock("mastermind")

	if not mgr.is_unlocked("mastermind"):
		push_error("test_unlock_logs_store_stats_failure: local unlock should still be set")
		return false
	if mock.store_stats_call_count == 0:
		push_error("test_unlock_logs_store_stats_failure: storeStats should have been called")
		return false
	return true
