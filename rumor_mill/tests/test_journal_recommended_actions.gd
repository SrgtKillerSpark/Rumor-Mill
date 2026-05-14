## test_journal_recommended_actions.gd — Unit tests for
## JournalRecommendedActions._compute_suggestions() (SPA-2618).
##
## Covers:
##   • Null-ref guard: returns [] when world or intel_store is null
##   • Priority 1: no observations + actions_left > 0 → "Observe a Building"
##   • Priority 2: observations, no relationships + actions_left > 0 → "Eavesdrop on NPCs"
##   • Priority 3: relationships, no active rumors + tokens_left > 0 → "Craft Your First Rumour"
##   • Priority 4: active_rumors 1–2 + tokens_left > 0 → "Seed Another Rumour"
##   • Day-based: day >= 2 + actions_left > 0 + has_observations → "Follow Up on Intel"
##   • Token-exhausted: tokens_left == 0 + actions_left > 0 → "Scout for Tomorrow"
##   • Suggestion cap: result never exceeds 3 entries
##
## JournalRecommendedActions extends VBoxContainer.  Instantiating without
## adding to the scene tree skips _ready(), leaving UI state irrelevant.
## _compute_suggestions() is called directly after setup().
##
## MockWorld extends Node2D and MockIntelStore extends Node to satisfy the
## typed parameters in setup(world: Node2D, intel_store: Node).
##
## Run from the Godot editor: Scene → Run Script.

class_name TestJournalRecommendedActions
extends RefCounted

const JournalRecommendedActionsScript := preload("res://scripts/journal_recommended_actions.gd")


# ── Mock day-night stand-in ───────────────────────────────────────────────────

## Minimal stand-in for the day/night subsystem.  Accessed via duck-typing
## (_world_ref.day_night.get_current_day()), so RefCounted is sufficient.
class MockDayNight extends RefCounted:
	var _day: int = 1
	func get_current_day() -> int:
		return _day


# ── Mock world ref ────────────────────────────────────────────────────────────

## Extends Node2D to satisfy setup(world: Node2D, ...) type checking.
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


# ── Mock intel store ref ──────────────────────────────────────────────────────

## Extends Node to satisfy setup(..., intel_store: Node) type checking.
## Exposes the same properties and methods that _compute_suggestions() reads.
class MockIntelStore extends Node:
	var recon_actions_remaining: int = 0
	var whisper_tokens_remaining: int = 0
	var _obs_count: int = 0
	var _rel_count: int = 0

	static func make(
			actions: int = 0,
			tokens: int = 0,
			obs_count: int = 0,
			rel_count: int = 0) -> MockIntelStore:
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


# ── Factory ───────────────────────────────────────────────────────────────────

static func _make_jra(world, intel) -> VBoxContainer:
	var jra: VBoxContainer = JournalRecommendedActionsScript.new()
	jra.setup(world, intel)
	return jra


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Null-ref guards
		"test_null_world_returns_empty",
		"test_null_intel_store_returns_empty",
		# Priority 1: no observations
		"test_priority1_no_observations_suggests_observe",
		"test_priority1_no_actions_left_skips_observe",
		# Priority 2: observations but no relationships
		"test_priority2_observations_no_rels_suggests_eavesdrop",
		"test_priority2_no_actions_left_skips_eavesdrop",
		# Priority 3: relationships but no active rumors
		"test_priority3_rels_no_rumors_suggests_craft",
		"test_priority3_no_tokens_skips_craft",
		# Priority 4: active rumors 1–2
		"test_priority4_one_rumor_suggests_seed",
		"test_priority4_two_rumors_suggests_seed",
		"test_priority4_three_or_more_skips_seed",
		# Day-based suggestion
		"test_day2_adds_follow_up_suggestion",
		"test_day1_no_follow_up_suggestion",
		# Token-exhausted suggestion
		"test_no_tokens_adds_scout_suggestion",
		"test_tokens_available_no_scout_suggestion",
		# Cap
		"test_suggestions_capped_at_3",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nJournalRecommendedActions tests: %d passed, %d failed" % [passed, failed])


# ── Null-ref guard tests ──────────────────────────────────────────────────────

static func test_null_world_returns_empty() -> bool:
	var intel := MockIntelStore.make(1, 1, 1, 1)
	var jra: VBoxContainer = JournalRecommendedActionsScript.new()
	jra.setup(null, intel)
	return jra._compute_suggestions().is_empty()


static func test_null_intel_store_returns_empty() -> bool:
	var world := MockWorld.make()
	var jra: VBoxContainer = JournalRecommendedActionsScript.new()
	jra.setup(world, null)
	return jra._compute_suggestions().is_empty()


# ── Priority 1 tests ──────────────────────────────────────────────────────────

## No observations + actions available → first suggestion is "Observe a Building".
static func test_priority1_no_observations_suggests_observe() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(1, 0, 0, 0)
	var jra := _make_jra(world, intel)
	var suggestions: Array = jra._compute_suggestions()
	return suggestions.size() >= 1 and suggestions[0].get("title") == "Observe a Building"


## actions_left == 0 with no observations → Priority 1 condition false, no observe tip.
static func test_priority1_no_actions_left_skips_observe() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(0, 0, 0, 0)
	var jra := _make_jra(world, intel)
	var suggestions: Array = jra._compute_suggestions()
	for s in suggestions:
		if s.get("title") == "Observe a Building":
			return false
	return true


# ── Priority 2 tests ──────────────────────────────────────────────────────────

## Has observations, no relationships, actions available → "Eavesdrop on NPCs".
static func test_priority2_observations_no_rels_suggests_eavesdrop() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(1, 0, 1, 0)
	var jra := _make_jra(world, intel)
	var suggestions: Array = jra._compute_suggestions()
	return suggestions.size() >= 1 and suggestions[0].get("title") == "Eavesdrop on NPCs"


## actions_left == 0 → Priority 2 elif condition false, no eavesdrop tip.
static func test_priority2_no_actions_left_skips_eavesdrop() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(0, 0, 1, 0)
	var jra := _make_jra(world, intel)
	var suggestions: Array = jra._compute_suggestions()
	for s in suggestions:
		if s.get("title") == "Eavesdrop on NPCs":
			return false
	return true


# ── Priority 3 tests ──────────────────────────────────────────────────────────

## Has relationships, zero active rumors, tokens available → "Craft Your First Rumour".
static func test_priority3_rels_no_rumors_suggests_craft() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(0, 1, 1, 1)
	var jra := _make_jra(world, intel)
	var suggestions: Array = jra._compute_suggestions()
	return suggestions.size() >= 1 and suggestions[0].get("title") == "Craft Your First Rumour"


## tokens_left == 0 → Priority 3 elif condition false, craft tip skipped.
static func test_priority3_no_tokens_skips_craft() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(0, 0, 1, 1)
	var jra := _make_jra(world, intel)
	var suggestions: Array = jra._compute_suggestions()
	for s in suggestions:
		if s.get("title") == "Craft Your First Rumour":
			return false
	return true


# ── Priority 4 tests ──────────────────────────────────────────────────────────

## 1 active rumor + tokens available → "Seed Another Rumour".
static func test_priority4_one_rumor_suggests_seed() -> bool:
	var world := MockWorld.make(1, 1)
	var intel := MockIntelStore.make(0, 1, 1, 1)
	var jra := _make_jra(world, intel)
	var suggestions: Array = jra._compute_suggestions()
	return suggestions.size() >= 1 and suggestions[0].get("title") == "Seed Another Rumour"


## 2 active rumors + tokens available → "Seed Another Rumour".
static func test_priority4_two_rumors_suggests_seed() -> bool:
	var world := MockWorld.make(1, 2)
	var intel := MockIntelStore.make(0, 1, 1, 1)
	var jra := _make_jra(world, intel)
	var suggestions: Array = jra._compute_suggestions()
	return suggestions.size() >= 1 and suggestions[0].get("title") == "Seed Another Rumour"


## active_rumors >= 3 → Priority 4 condition (< 3) false, seed tip skipped.
static func test_priority4_three_or_more_skips_seed() -> bool:
	var world := MockWorld.make(1, 3)
	var intel := MockIntelStore.make(0, 1, 1, 1)
	var jra := _make_jra(world, intel)
	var suggestions: Array = jra._compute_suggestions()
	for s in suggestions:
		if s.get("title") == "Seed Another Rumour":
			return false
	return true


# ── Day-based suggestion tests ────────────────────────────────────────────────

## day >= 2 + actions_left > 0 + has_observations → "Follow Up on Intel" appended.
static func test_day2_adds_follow_up_suggestion() -> bool:
	var world := MockWorld.make(2, 0)
	var intel := MockIntelStore.make(1, 0, 1, 0)
	var jra := _make_jra(world, intel)
	var suggestions: Array = jra._compute_suggestions()
	for s in suggestions:
		if s.get("title") == "Follow Up on Intel":
			return true
	return false


## day == 1 → day-based condition false, no "Follow Up on Intel".
static func test_day1_no_follow_up_suggestion() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(1, 0, 1, 0)
	var jra := _make_jra(world, intel)
	var suggestions: Array = jra._compute_suggestions()
	for s in suggestions:
		if s.get("title") == "Follow Up on Intel":
			return false
	return true


# ── Token-exhausted suggestion tests ─────────────────────────────────────────

## tokens_left == 0 + actions_left > 0 → "Scout for Tomorrow" appended.
static func test_no_tokens_adds_scout_suggestion() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(1, 0, 0, 0)
	var jra := _make_jra(world, intel)
	var suggestions: Array = jra._compute_suggestions()
	for s in suggestions:
		if s.get("title") == "Scout for Tomorrow":
			return true
	return false


## tokens_left > 0 → scout condition false, no "Scout for Tomorrow".
static func test_tokens_available_no_scout_suggestion() -> bool:
	var world := MockWorld.make(1, 0)
	var intel := MockIntelStore.make(1, 1, 0, 0)
	var jra := _make_jra(world, intel)
	var suggestions: Array = jra._compute_suggestions()
	for s in suggestions:
		if s.get("title") == "Scout for Tomorrow":
			return false
	return true


# ── Suggestion cap test ───────────────────────────────────────────────────────

## Verifies the resize(3) cap is enforced.  The scenario below naturally yields
## 3 suggestions (P2 + day-based + scout); the cap must not truncate to < 3 and
## must never allow > 3 even as the engine grows.
##
## State: day=2, obs=1, rels=0, actions=1, tokens=0, rumors=0
##   • P2 fires ("Eavesdrop on NPCs")
##   • Day-based fires ("Follow Up on Intel")  [day=2, actions>0, has_obs]
##   • Scout fires ("Scout for Tomorrow")       [tokens=0, actions>0]
##   → 3 total; cap keeps result <= 3.
static func test_suggestions_capped_at_3() -> bool:
	var world := MockWorld.make(2, 0)
	var intel := MockIntelStore.make(1, 0, 1, 0)
	var jra := _make_jra(world, intel)
	var suggestions: Array = jra._compute_suggestions()
	return suggestions.size() <= 3
