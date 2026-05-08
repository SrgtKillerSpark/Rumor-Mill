## test_mid_game_event_agent.gd — Unit tests for MidGameEventAgent (SPA-1017).
##
## Covers:
##   • Activation          — initial inactive state, activate() enables ticking
##   • Event loading       — load_events() stores the event array
##   • Tick — inactivity   — tick() is a no-op when agent is not activated
##   • Tick — window guards — events before/after their day window are skipped or resolved
##   • Tick — probability  — probability=1.0 always fires; pending blocks further events
##   • Tick — dedup        — same day records only one roll per event
##   • Resolve choice      — clears pending, emits event_resolved with correct args
##   • Resolve guards      — id mismatch leaves pending; invalid index clears pending
##   • Pending queries     — has_pending_event / get_pending_event
##   • Upcoming event      — nearest unfired within window returned; resolved/expired skipped
##   • Serialization       — to_data / restore_from_data round-trip; malformed entries dropped
##   • Effect — reputation — apply_score_delta called with correct npc_id and delta
##   • Effect — heat       — add_heat called with correct npc_id and delta
##   • Effect — recon      — recon_actions_remaining incremented by bonusReconActions
##   • Effect — agent refs — illness/rival/inquisitor cooldown_offset updated correctly
##   • Delayed rumors      — entry fires on its trigger day and is removed afterwards
##
## All tests use synthetic in-memory data — no live game nodes required.
## MockWorld extends Node to satisfy MidGameEventAgent.tick()'s typed parameter.
##
## Run from the Godot editor:  Scene → Run Script (or call run() from any autoload).

class_name TestMidGameEventAgent
extends RefCounted


# ── Mock objects ──────────────────────────────────────────────────────────────

class MockReputationSystem extends RefCounted:
	var delta_calls: Array = []
	func apply_score_delta(npc_id: String, delta: int) -> void:
		delta_calls.append({"npc_id": npc_id, "delta": delta})
	func get_snapshot(_npc_id: String):
		return null


class MockIntelStore extends RefCounted:
	var heat_calls: Array = []
	var recon_actions_remaining: int = 3
	var free_quarantine_charges: int = 0
	var free_campaign_charges: int = 0
	var bonus_expose_uses: int = 0
	var bribe_charges: int = 5
	func add_heat(npc_id: String, delta: float) -> void:
		heat_calls.append({"npc_id": npc_id, "delta": delta})


## Extends Node to satisfy MidGameEventAgent.tick(world: Node) type constraint.
class MockWorld extends Node:
	var reputation_system = null
	var intel_store = null
	var npcs: Array = []
	var day_night = null
	var scenario_manager = null
	func inject_rumor(_npc_id, _claim_type, _intensity, _subject_id, _source) -> void:
		pass


class MockAgentRef extends RefCounted:
	var cooldown_offset: int = 0
	var disrupt_charges_remaining: int = 0


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Activation & loading
		"test_initial_active_is_false",
		"test_activate_sets_active",
		"test_load_events_stores_events",
		# Tick — inactivity guard
		"test_tick_noop_when_inactive",
		# Tick — window guards
		"test_tick_skips_event_before_window",
		"test_tick_marks_resolved_past_window",
		# Tick — probability firing
		"test_tick_fires_event_with_probability_one",
		"test_tick_does_not_fire_when_already_pending",
		# Tick — per-day dedup
		"test_tick_rolls_once_per_day",
		# Resolve choice
		"test_resolve_choice_clears_pending",
		"test_resolve_choice_emits_event_resolved",
		"test_resolve_choice_id_mismatch_leaves_pending",
		"test_resolve_choice_invalid_index_clears_pending",
		# Pending queries
		"test_has_pending_event_false_initially",
		"test_get_pending_event_empty_initially",
		"test_has_pending_event_true_after_fire",
		# Upcoming event
		"test_get_upcoming_event_returns_nearest_unfired",
		"test_get_upcoming_event_skips_resolved",
		"test_get_upcoming_event_skips_past_window",
		"test_get_upcoming_event_empty_when_none_available",
		# Serialization
		"test_to_data_contains_expected_keys",
		"test_restore_from_data_round_trip",
		"test_restore_from_data_skips_invalid_delayed_rumor_entries",
		# Effect application
		"test_apply_effects_reputation_change",
		"test_apply_effects_heat_change",
		"test_apply_effects_bonus_recon_actions",
		"test_apply_effects_illness_cooldown_delta",
		"test_apply_effects_rival_cooldown_bonus",
		"test_apply_effects_inquisitor_cooldown_delta",
		# Delayed rumors
		"test_delayed_rumors_fire_on_trigger_day",
		"test_delayed_rumors_removed_after_firing",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nMidGameEventAgent tests: %d passed, %d failed" % [passed, failed])


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_agent() -> MidGameEventAgent:
	return MidGameEventAgent.new()


## Minimal event dict with the given probability.  Choices include two entries so
## both choice index 0 and 1 are valid during resolve_choice tests.
static func _make_event(
		ev_id: String,
		win_start: int,
		win_end: int,
		prob: float = 1.0
) -> Dictionary:
	return {
		"id":             ev_id,
		"dayWindowStart": win_start,
		"dayWindowEnd":   win_end,
		"probability":    prob,
		"choices": [
			{"outcomeText": "Choice A outcome", "effects": {}},
			{"outcomeText": "Choice B outcome", "effects": {}},
		],
	}


# ── Activation & loading ──────────────────────────────────────────────────────

static func test_initial_active_is_false() -> bool:
	var agent := _make_agent()
	return not agent._active


static func test_activate_sets_active() -> bool:
	var agent := _make_agent()
	agent.activate()
	return agent._active


static func test_load_events_stores_events() -> bool:
	var agent := _make_agent()
	agent.load_events([_make_event("ev1", 3, 7), _make_event("ev2", 10, 15)])
	if agent._events.size() != 2:
		push_error("test_load_events_stores_events: expected 2 events, got %d" % agent._events.size())
		return false
	return true


# ── Tick — inactivity guard ───────────────────────────────────────────────────

## tick() must be a no-op when the agent has not been activated.
static func test_tick_noop_when_inactive() -> bool:
	var agent := _make_agent()
	agent.load_events([_make_event("ev1", 1, 10, 1.0)])
	var presented := false
	agent.event_presented.connect(func(_d): presented = true)
	agent.tick(5, MockWorld.new())
	if presented:
		push_error("test_tick_noop_when_inactive: event_presented emitted but agent not active")
		return false
	return true


# ── Tick — window guards ──────────────────────────────────────────────────────

## Events whose window has not started yet must not fire.
static func test_tick_skips_event_before_window() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent.load_events([_make_event("ev_future", 10, 15, 1.0)])
	var presented := false
	agent.event_presented.connect(func(_d): presented = true)
	agent.tick(3, MockWorld.new())
	return not presented


## Events whose window end has passed must be added to _resolved_ids.
static func test_tick_marks_resolved_past_window() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent.load_events([_make_event("ev_old", 1, 5, 1.0)])
	agent.tick(6, MockWorld.new())   # day 6 > win_end 5
	if not agent._resolved_ids.has("ev_old"):
		push_error("test_tick_marks_resolved_past_window: 'ev_old' not in _resolved_ids")
		return false
	return true


# ── Tick — probability firing ─────────────────────────────────────────────────

## An event with probability=1.0 must always fire when inside its window.
static func test_tick_fires_event_with_probability_one() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent.load_events([_make_event("ev_fire", 1, 20, 1.0)])
	var presented_id := ""
	agent.event_presented.connect(func(d): presented_id = d.get("id", ""))
	agent.tick(5, MockWorld.new())
	if presented_id.is_empty():
		push_error("test_tick_fires_event_with_probability_one: event_presented not emitted")
		return false
	return presented_id == "ev_fire"


## When a pending event exists, tick() must not fire any further events.
static func test_tick_does_not_fire_when_already_pending() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent.load_events([
		_make_event("ev1", 1, 20, 1.0),
		_make_event("ev2", 1, 20, 1.0),
	])
	var fire_count := 0
	agent.event_presented.connect(func(_d): fire_count += 1)
	# Day 5 — one event fires and becomes pending.
	agent.tick(5, MockWorld.new())
	if fire_count != 1:
		push_error("test_tick_does_not_fire_when_already_pending: expected 1 fire after day 5, got %d" % fire_count)
		return false
	# Day 6 — pending event blocks any new fire.
	agent.tick(6, MockWorld.new())
	if fire_count != 1:
		push_error("test_tick_does_not_fire_when_already_pending: expected still 1 after day 6, got %d" % fire_count)
		return false
	return true


# ── Tick — per-day dedup ──────────────────────────────────────────────────────

## The same event must only be rolled once per day.  The roll is recorded in
## _rolled_days regardless of whether randf() fired.
static func test_tick_rolls_once_per_day() -> bool:
	var agent := _make_agent()
	agent.activate()
	# Probability 0 so the event never fires; we check _rolled_days directly.
	agent.load_events([_make_event("ev_roll", 1, 20, 0.0)])
	agent.tick(5, MockWorld.new())
	if not agent._rolled_days.has("ev_roll"):
		push_error("test_tick_rolls_once_per_day: roll not recorded on first tick")
		return false
	if agent._rolled_days["ev_roll"] != 5:
		push_error("test_tick_rolls_once_per_day: expected rolled_day=5, got %d" % agent._rolled_days["ev_roll"])
		return false
	# Second call on the same day — the record must remain 5 (not overwritten).
	agent.tick(5, MockWorld.new())
	return agent._rolled_days["ev_roll"] == 5


# ── Resolve choice ────────────────────────────────────────────────────────────

## resolve_choice() must clear the pending event.
static func test_resolve_choice_clears_pending() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent.load_events([_make_event("ev_res", 1, 20, 1.0)])
	agent.tick(5, MockWorld.new())
	if not agent.has_pending_event():
		push_error("test_resolve_choice_clears_pending: no pending event after tick")
		return false
	agent.resolve_choice("ev_res", 0)
	return not agent.has_pending_event()


## resolve_choice() must emit event_resolved with the correct event id, choice
## index, and outcome text.
static func test_resolve_choice_emits_event_resolved() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent.load_events([_make_event("ev_sig", 1, 20, 1.0)])
	agent.tick(5, MockWorld.new())
	var resolved_id    := ""
	var resolved_index := -1
	var resolved_text  := ""
	agent.event_resolved.connect(func(eid, ci, ot):
		resolved_id    = eid
		resolved_index = ci
		resolved_text  = ot
	)
	agent.resolve_choice("ev_sig", 1)   # choice index 1 → "Choice B outcome"
	if resolved_id != "ev_sig":
		push_error("test_resolve_choice_emits_event_resolved: wrong event id '%s'" % resolved_id)
		return false
	if resolved_index != 1:
		push_error("test_resolve_choice_emits_event_resolved: wrong choice index %d" % resolved_index)
		return false
	return resolved_text == "Choice B outcome"


## Passing the wrong event id must leave the pending event in place.
static func test_resolve_choice_id_mismatch_leaves_pending() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent.load_events([_make_event("ev_real", 1, 20, 1.0)])
	agent.tick(5, MockWorld.new())
	agent.resolve_choice("ev_wrong_id", 0)
	return agent.has_pending_event()


## An out-of-range choice index must clear the pending event (defensive path).
static func test_resolve_choice_invalid_index_clears_pending() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent.load_events([_make_event("ev_bad", 1, 20, 1.0)])
	agent.tick(5, MockWorld.new())
	agent.resolve_choice("ev_bad", 99)
	return not agent.has_pending_event()


# ── Pending queries ───────────────────────────────────────────────────────────

static func test_has_pending_event_false_initially() -> bool:
	var agent := _make_agent()
	return not agent.has_pending_event()


static func test_get_pending_event_empty_initially() -> bool:
	var agent := _make_agent()
	return agent.get_pending_event().is_empty()


static func test_has_pending_event_true_after_fire() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent.load_events([_make_event("ev_pend", 1, 20, 1.0)])
	agent.tick(5, MockWorld.new())
	return agent.has_pending_event()


# ── Upcoming event ────────────────────────────────────────────────────────────

## get_upcoming_event() must return the event whose dayWindowStart is nearest.
static func test_get_upcoming_event_returns_nearest_unfired() -> bool:
	var agent := _make_agent()
	var ev_near := _make_event("ev_near", 5, 10)
	var ev_far  := _make_event("ev_far", 15, 20)
	agent.load_events([ev_far, ev_near])   # intentionally out of order
	var upcoming := agent.get_upcoming_event(1)
	if upcoming.is_empty():
		push_error("test_get_upcoming_event_returns_nearest_unfired: result is empty")
		return false
	return upcoming.get("id", "") == "ev_near"


## Events that have already been resolved must not be returned.
static func test_get_upcoming_event_skips_resolved() -> bool:
	var agent := _make_agent()
	agent.load_events([_make_event("ev_done", 5, 10)])
	agent._resolved_ids["ev_done"] = true
	return agent.get_upcoming_event(1).is_empty()


## Events whose window end is before the current day must not be returned.
static func test_get_upcoming_event_skips_past_window() -> bool:
	var agent := _make_agent()
	agent.load_events([_make_event("ev_expired", 1, 3)])
	return agent.get_upcoming_event(5).is_empty()   # day 5 > win_end 3


## With no events loaded the result is an empty dict.
static func test_get_upcoming_event_empty_when_none_available() -> bool:
	var agent := _make_agent()
	return agent.get_upcoming_event(1).is_empty()


# ── Serialization ─────────────────────────────────────────────────────────────

## to_data() must include all four required keys.
static func test_to_data_contains_expected_keys() -> bool:
	var agent := _make_agent()
	var data := agent.to_data()
	for key in ["resolved_ids", "rolled_days", "pending_event", "delayed_rumors"]:
		if not data.has(key):
			push_error("test_to_data_contains_expected_keys: missing key '%s'" % key)
			return false
	return true


## Serialise a non-empty agent state and restore it into a fresh agent.
static func test_restore_from_data_round_trip() -> bool:
	var agent := _make_agent()
	agent._resolved_ids["ev_done"]    = true
	agent._rolled_days["ev_rolled"]   = 7
	var data := agent.to_data()

	var agent2 := _make_agent()
	agent2.restore_from_data(data)
	if not agent2._resolved_ids.has("ev_done"):
		push_error("test_restore_from_data_round_trip: resolved_ids not restored")
		return false
	if agent2._rolled_days.get("ev_rolled") != 7:
		push_error("test_restore_from_data_round_trip: rolled_days not restored (got %s)" % str(agent2._rolled_days.get("ev_rolled")))
		return false
	return true


## Invalid delayed_rumor entries (non-Dictionary or missing required keys) must
## be silently dropped; valid entries must be kept.
static func test_restore_from_data_skips_invalid_delayed_rumor_entries() -> bool:
	var agent := _make_agent()
	agent.restore_from_data({
		"resolved_ids":  {},
		"rolled_days":   {},
		"pending_event": {},
		"delayed_rumors": [
			# Valid.
			{"claimType": "scandal", "subjectNpcId": "npc_a", "triggerDay": 5, "intensity": 3},
			# Invalid: not a Dictionary.
			"this_is_a_string",
			# Invalid: missing required keys.
			{"claimType": "scandal"},
		],
	})
	if agent._delayed_rumors.size() != 1:
		push_error("test_restore_from_data_skips_invalid_delayed_rumor_entries: expected 1, got %d"
				% agent._delayed_rumors.size())
		return false
	return agent._delayed_rumors[0].get("subjectNpcId", "") == "npc_a"


# ── Effect application — reputation ──────────────────────────────────────────

## reputationChanges effects call reputation_system.apply_score_delta correctly.
static func test_apply_effects_reputation_change() -> bool:
	var agent    := _make_agent()
	agent.activate()
	var mock_rep   := MockReputationSystem.new()
	var mock_world := MockWorld.new()
	mock_world.reputation_system = mock_rep

	var ev := {
		"id": "ev_rep", "dayWindowStart": 1, "dayWindowEnd": 20, "probability": 1.0,
		"choices": [
			{
				"outcomeText": "done",
				"effects": {
					"reputationChanges": [{"npcId": "aldous_prior", "delta": 10}]
				}
			}
		]
	}
	agent.load_events([ev])
	agent.tick(5, mock_world)
	agent.resolve_choice("ev_rep", 0)

	if mock_rep.delta_calls.size() != 1:
		push_error("test_apply_effects_reputation_change: expected 1 call, got %d" % mock_rep.delta_calls.size())
		return false
	return mock_rep.delta_calls[0]["npc_id"] == "aldous_prior" \
		and mock_rep.delta_calls[0]["delta"] == 10


# ── Effect application — heat ─────────────────────────────────────────────────

## heatChanges effects call intel_store.add_heat with the correct npc_id and delta.
static func test_apply_effects_heat_change() -> bool:
	var agent    := _make_agent()
	agent.activate()
	var mock_intel := MockIntelStore.new()
	var mock_world := MockWorld.new()
	mock_world.intel_store = mock_intel

	var ev := {
		"id": "ev_heat", "dayWindowStart": 1, "dayWindowEnd": 20, "probability": 1.0,
		"choices": [
			{
				"outcomeText": "done",
				"effects": {
					"heatChanges": [{"npcId": "npc_x", "delta": 0.15}]
				}
			}
		]
	}
	agent.load_events([ev])
	agent.tick(5, mock_world)
	agent.resolve_choice("ev_heat", 0)

	if mock_intel.heat_calls.size() != 1:
		push_error("test_apply_effects_heat_change: expected 1 call, got %d" % mock_intel.heat_calls.size())
		return false
	return mock_intel.heat_calls[0]["npc_id"] == "npc_x" \
		and absf(mock_intel.heat_calls[0]["delta"] - 0.15) < 0.001


# ── Effect application — recon actions ───────────────────────────────────────

## bonusReconActions increments intel_store.recon_actions_remaining by that amount.
static func test_apply_effects_bonus_recon_actions() -> bool:
	var agent    := _make_agent()
	agent.activate()
	var mock_intel := MockIntelStore.new()
	mock_intel.recon_actions_remaining = 2
	var mock_world := MockWorld.new()
	mock_world.intel_store = mock_intel

	var ev := {
		"id": "ev_recon", "dayWindowStart": 1, "dayWindowEnd": 20, "probability": 1.0,
		"choices": [
			{"outcomeText": "done", "effects": {"bonusReconActions": 3, "bonusReconDays": 2}}
		]
	}
	agent.load_events([ev])
	agent.tick(5, mock_world)
	agent.resolve_choice("ev_recon", 0)
	return mock_intel.recon_actions_remaining == 5


# ── Effect application — agent refs ──────────────────────────────────────────

## illnessEscalationCooldownDelta adds to illness_agent_ref.cooldown_offset.
static func test_apply_effects_illness_cooldown_delta() -> bool:
	var agent    := _make_agent()
	agent.activate()
	var mock_illness := MockAgentRef.new()
	agent.illness_agent_ref = mock_illness
	var mock_world := MockWorld.new()

	var ev := {
		"id": "ev_illness", "dayWindowStart": 1, "dayWindowEnd": 20, "probability": 1.0,
		"choices": [
			{"outcomeText": "done", "effects": {"illnessEscalationCooldownDelta": 2}}
		]
	}
	agent.load_events([ev])
	agent.tick(5, mock_world)
	agent.resolve_choice("ev_illness", 0)
	return mock_illness.cooldown_offset == 2


## rivalCooldownBonus adds to rival_agent_ref.cooldown_offset.
static func test_apply_effects_rival_cooldown_bonus() -> bool:
	var agent    := _make_agent()
	agent.activate()
	var mock_rival := MockAgentRef.new()
	agent.rival_agent_ref = mock_rival
	var mock_world := MockWorld.new()

	var ev := {
		"id": "ev_rival", "dayWindowStart": 1, "dayWindowEnd": 20, "probability": 1.0,
		"choices": [
			{"outcomeText": "done", "effects": {"rivalCooldownBonus": 3}}
		]
	}
	agent.load_events([ev])
	agent.tick(5, mock_world)
	agent.resolve_choice("ev_rival", 0)
	return mock_rival.cooldown_offset == 3


## inquisitorCooldownDelta adds to inquisitor_agent_ref.cooldown_offset.
static func test_apply_effects_inquisitor_cooldown_delta() -> bool:
	var agent    := _make_agent()
	agent.activate()
	var mock_inq := MockAgentRef.new()
	agent.inquisitor_agent_ref = mock_inq
	var mock_world := MockWorld.new()

	var ev := {
		"id": "ev_inq", "dayWindowStart": 1, "dayWindowEnd": 20, "probability": 1.0,
		"choices": [
			{"outcomeText": "done", "effects": {"inquisitorCooldownDelta": 4}}
		]
	}
	agent.load_events([ev])
	agent.tick(5, mock_world)
	agent.resolve_choice("ev_inq", 0)
	return mock_inq.cooldown_offset == 4


# ── Delayed rumors ────────────────────────────────────────────────────────────

## A delayed rumor whose triggerDay is reached during tick() must be processed.
## With an empty NPC list no rumor is actually injected, but the entry is consumed.
static func test_delayed_rumors_fire_on_trigger_day() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent._delayed_rumors.append({
		"claimType":       "scandal",
		"subjectNpcId":    "npc_target",
		"intensity":       3,
		"triggerDay":      7,
		"triggerCondition": {},
	})
	agent.tick(7, MockWorld.new())
	return agent._delayed_rumors.is_empty()


## Only entries at or past their triggerDay are removed; future entries remain.
static func test_delayed_rumors_removed_after_firing() -> bool:
	var agent := _make_agent()
	agent.activate()
	agent._delayed_rumors.append({
		"claimType": "scandal", "subjectNpcId": "npc_a",
		"intensity": 3, "triggerDay": 5, "triggerCondition": {},
	})
	agent._delayed_rumors.append({
		"claimType": "illness", "subjectNpcId": "npc_b",
		"intensity": 2, "triggerDay": 12, "triggerCondition": {},
	})
	# Day 8: first entry (triggerDay=5) fires and is removed; second (triggerDay=12) stays.
	agent.tick(8, MockWorld.new())
	if agent._delayed_rumors.size() != 1:
		push_error("test_delayed_rumors_removed_after_firing: expected 1 remaining, got %d"
				% agent._delayed_rumors.size())
		return false
	return agent._delayed_rumors[0].get("subjectNpcId", "") == "npc_b"
