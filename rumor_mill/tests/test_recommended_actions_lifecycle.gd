## test_recommended_actions_lifecycle.gd — Unit tests for SPA-2921 (A2.2)
## JournalRecommendedActions lifecycle state machine.
##
## Covers:
##   • Cooldown guard: suggestion suppressed after 3 ignored shows for 1 cycle
##   • Cooldown reset: counter resets after cooldown skip
##   • Completion: pending completion marks suggestion as completed
##   • Completion visual: completed suggestion shown for 1 refresh then removed
##   • Expiry: suggestion removed when condition no longer met
##   • template_id present: all suggestions carry template_id
##   • Signal-driven completion: action_performed and rumor_seeded handlers
##   • Lifecycle reset: reset_lifecycle() clears all state
##
## Uses the same MockWorld/MockIntelStore from TestJournalRecommendedActions.

class_name TestRecommendedActionsLifecycle
extends RefCounted

const JRA := preload("res://scripts/journal_recommended_actions.gd")


# ── Mock day-night ───────────────────────────────────────────────────────────

class MockDayNight extends RefCounted:
	var _day: int = 1
	func get_current_day() -> int:
		return _day


# ── Mock world ───────────────────────────────────────────────────────────────

class MockWorld extends Node2D:
	var day_night: MockDayNight = null
	var _active_rumor_count: int = 0

	static func make(day: int = 1, active_rumors: int = 0) -> MockWorld:
		var w := MockWorld.new()
		w.day_night = MockDayNight.new()
		w.day_night._day = day
		w._active_rumor_count = active_rumors
		return w

	func get_active_rumor_count() -> int:
		return _active_rumor_count


# ── Mock intel store ─────────────────────────────────────────────────────────

class MockIntelStore extends Node:
	var recon_actions_remaining: int = 0
	var whisper_tokens_remaining: int = 0
	var _obs_count: int = 0
	var _rel_count: int = 0

	static func make(actions: int = 0, tokens: int = 0,
			obs_count: int = 0, rel_count: int = 0) -> MockIntelStore:
		var s := MockIntelStore.new()
		s.recon_actions_remaining = actions
		s.whisper_tokens_remaining = tokens
		s._obs_count = obs_count
		s._rel_count = rel_count
		return s

	func get_observation_count() -> int:
		return _obs_count

	func get_relationship_count() -> int:
		return _rel_count


# ── Factory ──────────────────────────────────────────────────────────────────

static func _make_jra(world, intel) -> VBoxContainer:
	var jra: VBoxContainer = JRA.new()
	jra.setup(world, intel)
	return jra


# ── Test runner ──────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_suggestions_have_template_id",
		"test_cooldown_suppresses_after_threshold",
		"test_cooldown_resets_after_skip",
		"test_completion_via_pending",
		"test_completed_shown_once_then_removed",
		"test_expiry_removes_stale_suggestion",
		"test_action_performed_observe_completes",
		"test_action_performed_eavesdrop_completes",
		"test_rumor_seeded_completes_craft",
		"test_reset_lifecycle_clears_state",
		"test_no_lifecycle_on_first_refresh",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nRecommendedActions lifecycle tests: %d passed, %d failed" % [passed, failed])


# ── Tests ────────────────────────────────────────────────────────────────────

## All suggestions from _compute_suggestions carry a template_id.
func test_suggestions_have_template_id() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(1, 0, 0, 0)
	var jra := _make_jra(world, intel)
	var suggestions: Array = jra._compute_suggestions()
	for s in suggestions:
		if not s.has("template_id") or s["template_id"] == "":
			return false
	return suggestions.size() > 0


## After 3 refreshes showing the same suggestion without completion, it is suppressed.
func test_cooldown_suppresses_after_threshold() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(1, 0, 0, 0)  # triggers "Observe a Building"
	var jra := _make_jra(world, intel)

	# Refresh 3 times (threshold)
	for i in range(3):
		var raw: Array = jra._compute_suggestions()
		var filtered: Array = jra._apply_lifecycle(raw)
		jra._refresh_count += 1
		if i < 3:
			var has_observe := false
			for s in filtered:
				if s.get("template_id") == "observe_building":
					has_observe = true
			if not has_observe and i < 3:
				return false

	# 4th refresh: should be suppressed
	jra._refresh_count += 1
	var raw4: Array = jra._compute_suggestions()
	var filtered4: Array = jra._apply_lifecycle(raw4)
	for s in filtered4:
		if s.get("template_id") == "observe_building":
			return false  # should have been suppressed
	return true


## After cooldown skip, the suggestion reappears and counter is reset.
func test_cooldown_resets_after_skip() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(1, 0, 0, 0)
	var jra := _make_jra(world, intel)

	# 3 refreshes to trigger cooldown
	for i in range(3):
		var raw: Array = jra._compute_suggestions()
		jra._apply_lifecycle(raw)
		jra._refresh_count += 1

	# 4th refresh: cooldown active (suppressed)
	jra._refresh_count += 1
	var raw_cd: Array = jra._compute_suggestions()
	jra._apply_lifecycle(raw_cd)

	# 5th refresh: cooldown expired, should reappear
	jra._refresh_count += 1
	var raw5: Array = jra._compute_suggestions()
	var filtered5: Array = jra._apply_lifecycle(raw5)
	for s in filtered5:
		if s.get("template_id") == "observe_building":
			return true
	return false


## Marking a template_id as pending completion transitions to completed state.
func test_completion_via_pending() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(1, 0, 0, 0)
	var jra := _make_jra(world, intel)

	# First refresh to establish active state
	var raw: Array = jra._compute_suggestions()
	jra._apply_lifecycle(raw)
	jra._refresh_count += 1

	# Mark completion
	jra._pending_completions["observe_building"] = true

	# Next refresh applies completion
	var raw2: Array = jra._compute_suggestions()
	jra._apply_lifecycle(raw2)

	return jra._lifecycle.get("observe_building", {}).get("state") == "completed"


## Completed suggestion shown with check mark for 1 refresh, then removed.
func test_completed_shown_once_then_removed() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(1, 0, 0, 0)
	var jra := _make_jra(world, intel)

	# Establish active
	var raw: Array = jra._compute_suggestions()
	jra._apply_lifecycle(raw)
	jra._refresh_count += 1

	# Mark completion
	jra._pending_completions["observe_building"] = true
	var raw2: Array = jra._compute_suggestions()
	jra._apply_lifecycle(raw2)
	jra._refresh_count += 1

	# Next refresh: should show as completed
	var raw3: Array = jra._compute_suggestions()
	var filtered3: Array = jra._apply_lifecycle(raw3)
	var found_completed := false
	for s in filtered3:
		if s.get("template_id") == "observe_building":
			if s.get("_lifecycle_state") == "completed":
				found_completed = true
	if not found_completed:
		return false
	jra._refresh_count += 1

	# Following refresh: should be removed
	var raw4: Array = jra._compute_suggestions()
	var filtered4: Array = jra._apply_lifecycle(raw4)
	for s in filtered4:
		if s.get("template_id") == "observe_building":
			return false  # should have been removed
	return true


## Suggestion that no longer appears in _compute_suggestions is marked expired.
func test_expiry_removes_stale_suggestion() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(1, 0, 0, 0)  # triggers observe
	var jra := _make_jra(world, intel)

	# Establish active
	var raw: Array = jra._compute_suggestions()
	jra._apply_lifecycle(raw)
	jra._refresh_count += 1

	# Change state so observe is no longer suggested (add observations)
	intel._obs_count = 1  # now has observations, observe no longer triggers
	var raw2: Array = jra._compute_suggestions()
	jra._apply_lifecycle(raw2)

	# Observe should be expired
	var state: String = jra._lifecycle.get("observe_building", {}).get("state", "")
	return state == "expired"


## _on_action_performed with "Observe" message sets pending completion.
func test_action_performed_observe_completes() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(1, 0, 0, 0)
	var jra := _make_jra(world, intel)
	jra._on_action_performed("Observed Market Hall", true)
	return jra._pending_completions.has("observe_building")


## _on_action_performed with "Eavesdrop" message sets pending completion.
func test_action_performed_eavesdrop_completes() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(1, 0, 0, 0)
	var jra := _make_jra(world, intel)
	jra._on_action_performed("Eavesdropped on conversation", true)
	return jra._pending_completions.has("eavesdrop_npcs")


## _on_rumor_seeded sets craft/seed pending completions.
func test_rumor_seeded_completes_craft() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(1, 0, 0, 0)
	var jra := _make_jra(world, intel)
	jra._on_rumor_seeded("r1", "Alys", "illness", "Bram")
	return (jra._pending_completions.has("craft_first_rumour")
		and jra._pending_completions.has("seed_another_rumour"))


## reset_lifecycle() clears all state.
func test_reset_lifecycle_clears_state() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(1, 0, 0, 0)
	var jra := _make_jra(world, intel)

	# Build up some state
	var raw: Array = jra._compute_suggestions()
	jra._apply_lifecycle(raw)
	jra._refresh_count += 1
	jra._pending_completions["observe_building"] = true

	jra.reset_lifecycle()
	return (jra._lifecycle.is_empty()
		and jra._refresh_count == 0
		and jra._pending_completions.is_empty())


## First refresh with no prior state shows all suggestions normally.
func test_no_lifecycle_on_first_refresh() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(1, 0, 0, 0)
	var jra := _make_jra(world, intel)

	var raw: Array = jra._compute_suggestions()
	var filtered: Array = jra._apply_lifecycle(raw)
	# Should have same count — nothing filtered on first pass
	return filtered.size() == raw.size()
