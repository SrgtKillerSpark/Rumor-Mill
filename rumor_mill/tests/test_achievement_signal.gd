## test_achievement_signal.gd — Unit tests for achievement_unlocked signal (SPA-1093).
##
## Covers:
##   • signal emitted on first unlock
##   • emitted signal carries the correct achievement id
##   • emitted signal carries the correct display name
##   • signal NOT emitted for an unknown achievement id
##   • signal NOT emitted on a duplicate (already-unlocked) call
##
## AchievementManager is instantiated with .new(); _ready() is NOT called so
## Steam init and file I/O are skipped entirely.

class_name TestAchievementSignal
extends RefCounted


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_signal_emitted_on_unlock",
		"test_signal_carries_correct_id",
		"test_signal_carries_display_name",
		"test_signal_not_emitted_for_unknown_id",
		"test_signal_not_emitted_on_duplicate_unlock",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nAchievementSignal tests: %d passed, %d failed" % [passed, failed])


# ── helpers ──────────────────────────────────────────────────────────────────

static func _make_mgr() -> AchievementManager:
	return AchievementManager.new()


# ── tests ────────────────────────────────────────────────────────────────────

## unlock() emits achievement_unlocked at least once.
static func test_signal_emitted_on_unlock() -> bool:
	var mgr := _make_mgr()
	var emitted := false
	mgr.achievement_unlocked.connect(func(_id: String, _name: String) -> void:
		emitted = true
	)
	mgr.unlock("ghost")
	return emitted


## The emitted signal carries the exact achievement id passed to unlock().
static func test_signal_carries_correct_id() -> bool:
	var mgr := _make_mgr()
	var captured_id := ""
	mgr.achievement_unlocked.connect(func(id: String, _name: String) -> void:
		captured_id = id
	)
	mgr.unlock("ghost")
	if captured_id != "ghost":
		push_error("test_signal_carries_correct_id: expected 'ghost', got '%s'" % captured_id)
		return false
	return true


## The emitted signal carries the achievement's display name (the 'name' field).
static func test_signal_carries_display_name() -> bool:
	var mgr := _make_mgr()
	var captured_name := ""
	mgr.achievement_unlocked.connect(func(_id: String, dname: String) -> void:
		captured_name = dname
	)
	mgr.unlock("ghost")
	var expected: String = AchievementManager.ACHIEVEMENTS["ghost"]["name"]
	if captured_name != expected:
		push_error("test_signal_carries_display_name: expected '%s', got '%s'" % [expected, captured_name])
		return false
	return true


## unlock() with an unknown id emits a warning but never emits achievement_unlocked.
static func test_signal_not_emitted_for_unknown_id() -> bool:
	var mgr := _make_mgr()
	var emitted := false
	mgr.achievement_unlocked.connect(func(_id: String, _name: String) -> void:
		emitted = true
	)
	mgr.unlock("totally_fake_achievement_xyz")
	if emitted:
		push_error("test_signal_not_emitted_for_unknown_id: signal fired for unknown id")
		return false
	return true


## Calling unlock() a second time for the same id does not re-emit the signal.
static func test_signal_not_emitted_on_duplicate_unlock() -> bool:
	var mgr := _make_mgr()
	var emit_count := 0
	mgr.achievement_unlocked.connect(func(_id: String, _name: String) -> void:
		emit_count += 1
	)
	mgr.unlock("ghost")
	mgr.unlock("ghost")
	if emit_count != 1:
		push_error("test_signal_not_emitted_on_duplicate_unlock: expected 1 emission, got %d" % emit_count)
		return false
	return true
