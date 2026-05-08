## test_faction_event_system.gd — Unit tests for FactionEventSystem (SPA-965).
##
## Covers:
##   • Scheduling & initialization — event count, day range, valid types, initial state
##   • Day-change activation      — trigger-day activation, pre-trigger guard, labels
##   • Event-specific effects     — market_dispute hotspot, guard_crackdown heat decay,
##                                  religious_festival reputation bonus
##   • Expiry                     — timed expiry timing, state flags, heat-decay reset,
##                                  expired events skipped on subsequent days
##   • Eavesdrop hotspot queries  — active location, unknown location, expiry pruning
##   • Foreshadow                 — 2 days before trigger, on trigger day, active events
##   • Serialization round-trip   — restore event fields + hotspots, empty-dict no-op
##
## Run from the Godot editor:  Scene → Run Script (or call run() from any autoload).
## All tests use synthetic in-memory data — no live game nodes required.
##
## Since FactionEventSystem uses randi_range() internally, scheduling tests accept
## 1-2 events.  Effect and expiry tests inject events directly into _events to avoid
## dependence on random scheduling.

class_name TestFactionEventSystem
extends RefCounted


# ── Mock objects ──────────────────────────────────────────────────────────────

## Minimal SocialGraph stand-in.  Records mutate_edge calls; get_top_neighbours
## returns an empty array so no third-edge mutation is attempted.
class MockSocialGraph extends RefCounted:
	var mutate_calls: Array = []

	func mutate_edge(a: String, b: String, delta: float, tick: int) -> void:
		mutate_calls.append({"a": a, "b": b, "delta": delta, "tick": tick})

	func get_top_neighbours(_npc_id: String, _count: int) -> Array:
		return []


## Minimal PlayerIntelStore stand-in.  Exposes the one property FactionEventSystem writes.
class MockIntelStore extends RefCounted:
	var heat_decay_override: float = -1.0


## Minimal ReputationSystem stand-in.  Records calls so tests can assert them.
class MockReputationSystem extends RefCounted:
	var sentiment_bonus_calls: Array = []
	var cleared_ids: Array = []

	func set_faction_sentiment_bonus(npc_id: String, bonus: float) -> void:
		sentiment_bonus_calls.append({"npc_id": npc_id, "bonus": bonus})

	func clear_faction_sentiment_bonus(npc_id: String) -> void:
		cleared_ids.append(npc_id)


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Scheduling & initialization
		"test_schedule_events_count_and_day_range",
		"test_schedule_events_valid_event_types",
		"test_schedule_events_initial_state_inactive",
		# Day-change activation
		"test_on_day_changed_activates_on_trigger_day",
		"test_on_day_changed_no_activation_before_trigger",
		"test_get_active_event_labels_after_activation",
		"test_get_active_event_labels_empty_before_activation",
		# Event-specific effects
		"test_market_dispute_sets_eavesdrop_hotspot",
		"test_guard_crackdown_sets_heat_decay_override",
		"test_religious_festival_calls_sentiment_bonus",
		# Expiry
		"test_timed_event_expires_after_duration_days",
		"test_expired_event_is_expired_and_inactive",
		"test_guard_crackdown_expiry_resets_heat_decay",
		"test_expired_event_skipped_on_subsequent_days",
		# Eavesdrop hotspot queries
		"test_is_eavesdrop_hotspot_true_for_active_location",
		"test_is_eavesdrop_hotspot_false_for_unknown_location",
		"test_eavesdrop_hotspot_pruned_when_day_reaches_expiry",
		# Foreshadow
		"test_foreshadow_two_days_before_trigger",
		"test_foreshadow_empty_on_trigger_day",
		"test_foreshadow_empty_for_active_event",
		# Serialization round-trip
		"test_restore_from_data_restores_event_fields_and_hotspots",
		"test_restore_from_data_empty_dict_is_noop",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nFactionEventSystem tests: %d passed, %d failed" % [passed, failed])


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns a FactionEventSystem with an empty NPC list and no subsystems wired.
## Tests that need subsystems set them explicitly after calling this.
static func _make_fes() -> FactionEventSystem:
	var fes := FactionEventSystem.new()
	fes._npcs = []
	return fes


## Appends a hand-crafted FactionEvent to fes._events and returns it so the
## caller can inspect or further configure it (e.g. set affected_npc_ids).
static func _inject_event(
		fes: FactionEventSystem,
		event_type: String,
		trigger_day: int,
		duration_days: int
) -> FactionEventSystem.FactionEvent:
	var ev              := FactionEventSystem.FactionEvent.new()
	ev.event_type        = event_type
	ev.trigger_day       = trigger_day
	ev.duration_days     = duration_days
	ev.affected_npc_ids  = []
	ev.metadata          = {}
	ev.is_active         = false
	ev.is_expired        = false
	fes._events.append(ev)
	return ev


# ── Scheduling & initialization ───────────────────────────────────────────────

## _schedule_events() produces 1–MAX_EVENTS entries with trigger days in the
## valid range and no duplicate days.
static func test_schedule_events_count_and_day_range() -> bool:
	var fes := _make_fes()
	fes._schedule_events()
	var count := fes._events.size()
	if count < 1 or count > FactionEventSystem.MAX_EVENTS:
		push_error("test_schedule_events_count_and_day_range: bad event count %d" % count)
		return false
	var seen_days: Array = []
	for ev in fes._events:
		if ev.trigger_day < FactionEventSystem.MIN_TRIGGER_DAY \
				or ev.trigger_day > FactionEventSystem.MAX_TRIGGER_DAY:
			push_error("test_schedule_events_count_and_day_range: trigger_day %d out of [%d, %d]"
					% [ev.trigger_day, FactionEventSystem.MIN_TRIGGER_DAY, FactionEventSystem.MAX_TRIGGER_DAY])
			return false
		if seen_days.has(ev.trigger_day):
			push_error("test_schedule_events_count_and_day_range: duplicate trigger_day %d" % ev.trigger_day)
			return false
		seen_days.append(ev.trigger_day)
	return true


## Every scheduled event has an event_type drawn from ALL_EVENT_TYPES.
static func test_schedule_events_valid_event_types() -> bool:
	var fes := _make_fes()
	fes._schedule_events()
	if fes._events.is_empty():
		push_error("test_schedule_events_valid_event_types: no events scheduled")
		return false
	for ev in fes._events:
		if not FactionEventSystem.ALL_EVENT_TYPES.has(ev.event_type):
			push_error("test_schedule_events_valid_event_types: unknown event_type '%s'" % ev.event_type)
			return false
	return true


## Freshly scheduled events start with is_active = false and is_expired = false.
static func test_schedule_events_initial_state_inactive() -> bool:
	var fes := _make_fes()
	fes._schedule_events()
	if fes._events.is_empty():
		push_error("test_schedule_events_initial_state_inactive: no events scheduled")
		return false
	for ev in fes._events:
		if ev.is_active or ev.is_expired:
			push_error("test_schedule_events_initial_state_inactive: event already active or expired")
			return false
	return true


# ── Day-change activation ─────────────────────────────────────────────────────

## on_day_changed(trigger_day) sets is_active = true.
static func test_on_day_changed_activates_on_trigger_day() -> bool:
	var fes      := _make_fes()
	fes._intel_store = MockIntelStore.new()
	var ev := _inject_event(fes, "guard_crackdown", 3, FactionEventSystem.TIMED_EVENT_DURATION)
	fes.on_day_changed(3)
	return ev.is_active


## on_day_changed() before the trigger day does NOT activate the event.
static func test_on_day_changed_no_activation_before_trigger() -> bool:
	var fes := _make_fes()
	var ev  := _inject_event(fes, "guard_crackdown", 5, FactionEventSystem.TIMED_EVENT_DURATION)
	fes.on_day_changed(3)
	return not ev.is_active


## get_active_event_labels() contains the correct label string after activation.
static func test_get_active_event_labels_after_activation() -> bool:
	var fes      := _make_fes()
	fes._intel_store = MockIntelStore.new()
	_inject_event(fes, "guard_crackdown", 3, FactionEventSystem.TIMED_EVENT_DURATION)
	fes.on_day_changed(3)
	var labels := fes.get_active_event_labels()
	if labels.size() != 1:
		push_error("test_get_active_event_labels_after_activation: expected 1 label, got %d" % labels.size())
		return false
	return labels[0] == "Guard Crackdown"


## get_active_event_labels() is empty when no event has been activated yet.
static func test_get_active_event_labels_empty_before_activation() -> bool:
	var fes := _make_fes()
	_inject_event(fes, "guard_crackdown", 5, FactionEventSystem.TIMED_EVENT_DURATION)
	return fes.get_active_event_labels().is_empty()


# ── Event-specific effects ────────────────────────────────────────────────────

## market_dispute activation sets eavesdrop_hotspots["market"] with expiry = trigger_day + 3.
static func test_market_dispute_sets_eavesdrop_hotspot() -> bool:
	var mock_sg := MockSocialGraph.new()
	var fes     := _make_fes()
	fes._social_graph = mock_sg
	var ev := _inject_event(fes, "market_dispute", 4, 0)
	ev.affected_npc_ids = ["npc_merchant_a", "npc_merchant_b"]
	fes.on_day_changed(4)
	if not fes.eavesdrop_hotspots.has("market"):
		push_error("test_market_dispute_sets_eavesdrop_hotspot: 'market' key missing from hotspots")
		return false
	var expected_expiry := 4 + 3
	if fes.eavesdrop_hotspots["market"] != expected_expiry:
		push_error("test_market_dispute_sets_eavesdrop_hotspot: expiry %d ≠ expected %d"
				% [fes.eavesdrop_hotspots["market"], expected_expiry])
		return false
	return true


## guard_crackdown activation sets heat_decay_override to GUARD_CRACKDOWN_HEAT_DECAY.
static func test_guard_crackdown_sets_heat_decay_override() -> bool:
	var mock_intel := MockIntelStore.new()
	var fes        := _make_fes()
	fes._intel_store = mock_intel
	_inject_event(fes, "guard_crackdown", 3, FactionEventSystem.TIMED_EVENT_DURATION)
	fes.on_day_changed(3)
	return absf(mock_intel.heat_decay_override - FactionEventSystem.GUARD_CRACKDOWN_HEAT_DECAY) < 0.001


## religious_festival activation calls set_faction_sentiment_bonus() for every NPC id
## in affected_npc_ids, passing RELIGIOUS_FESTIVAL_SENTIMENT_BONUS.
static func test_religious_festival_calls_sentiment_bonus() -> bool:
	var mock_rep := MockReputationSystem.new()
	var fes      := _make_fes()
	fes._reputation_system = mock_rep
	var ev := _inject_event(fes, "religious_festival", 3, FactionEventSystem.TIMED_EVENT_DURATION)
	ev.affected_npc_ids = ["clergy_a", "clergy_b"]
	fes.on_day_changed(3)
	if mock_rep.sentiment_bonus_calls.size() != 2:
		push_error("test_religious_festival_calls_sentiment_bonus: expected 2 calls, got %d"
				% mock_rep.sentiment_bonus_calls.size())
		return false
	var ids_called: Array = []
	for entry in mock_rep.sentiment_bonus_calls:
		if absf(entry["bonus"] - FactionEventSystem.RELIGIOUS_FESTIVAL_SENTIMENT_BONUS) > 0.001:
			push_error("test_religious_festival_calls_sentiment_bonus: wrong bonus %.2f" % entry["bonus"])
			return false
		ids_called.append(entry["npc_id"])
	return ids_called.has("clergy_a") and ids_called.has("clergy_b")


# ── Expiry ────────────────────────────────────────────────────────────────────

## A timed event (duration_days > 0) does not expire until duration_days have
## elapsed since trigger_day.
static func test_timed_event_expires_after_duration_days() -> bool:
	var mock_intel := MockIntelStore.new()
	var fes        := _make_fes()
	fes._intel_store = mock_intel
	var ev := _inject_event(fes, "guard_crackdown", 3, 2)
	fes.on_day_changed(3)   # elapsed = 0  — activates
	fes.on_day_changed(4)   # elapsed = 1  — still active (1 < 2)
	if ev.is_expired:
		push_error("test_timed_event_expires_after_duration_days: expired too early on day 4")
		return false
	fes.on_day_changed(5)   # elapsed = 2  — expires (2 >= 2)
	return ev.is_expired


## After expiry: is_expired = true and is_active = false.
static func test_expired_event_is_expired_and_inactive() -> bool:
	var mock_intel := MockIntelStore.new()
	var fes        := _make_fes()
	fes._intel_store = mock_intel
	var ev := _inject_event(fes, "guard_crackdown", 3, 2)
	fes.on_day_changed(3)
	fes.on_day_changed(5)   # triggers expiry
	return ev.is_expired and not ev.is_active


## guard_crackdown expiry resets heat_decay_override to -1.0.
static func test_guard_crackdown_expiry_resets_heat_decay() -> bool:
	var mock_intel := MockIntelStore.new()
	var fes        := _make_fes()
	fes._intel_store = mock_intel
	_inject_event(fes, "guard_crackdown", 3, 2)
	fes.on_day_changed(3)   # activate → heat_decay_override = GUARD_CRACKDOWN_HEAT_DECAY
	if absf(mock_intel.heat_decay_override - FactionEventSystem.GUARD_CRACKDOWN_HEAT_DECAY) > 0.001:
		push_error("test_guard_crackdown_expiry_resets_heat_decay: heat_decay not set after activation")
		return false
	fes.on_day_changed(5)   # expire → heat_decay_override = -1.0
	return absf(mock_intel.heat_decay_override - (-1.0)) < 0.001


## Expired events are skipped on subsequent on_day_changed() calls; their
## effects are not re-applied even if day matches the original trigger_day again.
static func test_expired_event_skipped_on_subsequent_days() -> bool:
	var mock_intel := MockIntelStore.new()
	var fes        := _make_fes()
	fes._intel_store = mock_intel
	var ev := _inject_event(fes, "guard_crackdown", 3, 2)
	fes.on_day_changed(3)
	fes.on_day_changed(5)   # expire
	if not ev.is_expired:
		push_error("test_expired_event_skipped_on_subsequent_days: event not expired after day 5")
		return false
	# Sentinel: if the event re-fires it would set heat_decay_override to 3.0
	mock_intel.heat_decay_override = 99.0
	fes.on_day_changed(3)   # same trigger day; expired branch is hit → skip
	return absf(mock_intel.heat_decay_override - 99.0) < 0.001


# ── Eavesdrop hotspot queries ─────────────────────────────────────────────────

## is_eavesdrop_hotspot() returns true for a location that has an active hotspot entry.
static func test_is_eavesdrop_hotspot_true_for_active_location() -> bool:
	var fes := _make_fes()
	fes.eavesdrop_hotspots["market"] = 10
	return fes.is_eavesdrop_hotspot("market")


## is_eavesdrop_hotspot() returns false for a location not in the hotspot dict.
static func test_is_eavesdrop_hotspot_false_for_unknown_location() -> bool:
	var fes := _make_fes()
	return not fes.is_eavesdrop_hotspot("dungeon")


## Hotspots are pruned from eavesdrop_hotspots when day >= expiry day.
static func test_eavesdrop_hotspot_pruned_when_day_reaches_expiry() -> bool:
	var fes := _make_fes()
	fes.eavesdrop_hotspots["market"] = 5   # expires on day 5
	fes.on_day_changed(5)                  # day >= expiry → pruned
	return not fes.eavesdrop_hotspots.has("market")


# ── Foreshadow ────────────────────────────────────────────────────────────────

## get_foreshadow_for_day(trigger_day - 2) returns the event's foreshadow text.
static func test_foreshadow_two_days_before_trigger() -> bool:
	var fes := _make_fes()
	_inject_event(fes, "guard_crackdown", 5, FactionEventSystem.TIMED_EVENT_DURATION)
	# day = 3 → day + 2 = 5 → matches trigger_day = 5
	var result := fes.get_foreshadow_for_day(3)
	if result.size() != 1:
		push_error("test_foreshadow_two_days_before_trigger: expected 1 hint, got %d" % result.size())
		return false
	return result[0] == FactionEventSystem.FORESHADOW_TEXT["guard_crackdown"]


## get_foreshadow_for_day(trigger_day) returns empty — day+2 does not match trigger_day.
static func test_foreshadow_empty_on_trigger_day() -> bool:
	var fes := _make_fes()
	_inject_event(fes, "guard_crackdown", 5, FactionEventSystem.TIMED_EVENT_DURATION)
	# day = 5 → day + 2 = 7 → no match for trigger_day = 5
	var result := fes.get_foreshadow_for_day(5)
	return result.is_empty()


## get_foreshadow_for_day() returns empty for events that are already active.
static func test_foreshadow_empty_for_active_event() -> bool:
	var mock_intel := MockIntelStore.new()
	var fes        := _make_fes()
	fes._intel_store = mock_intel
	_inject_event(fes, "guard_crackdown", 5, FactionEventSystem.TIMED_EVENT_DURATION)
	fes.on_day_changed(5)   # activate
	# day = 3 → day + 2 = 5 → would match trigger_day, but is_active blocks it
	var result := fes.get_foreshadow_for_day(3)
	return result.is_empty()


# ── Serialization round-trip ──────────────────────────────────────────────────

## restore_from_data() rebuilds _events from serialized dicts and restores
## eavesdrop_hotspots.
static func test_restore_from_data_restores_event_fields_and_hotspots() -> bool:
	var fes := _make_fes()
	var data := {
		"events": [
			{
				"event_type":       "guard_crackdown",
				"trigger_day":      3,
				"duration_days":    2,
				"affected_npc_ids": [],
				"metadata":         {},
				"is_active":        false,
				"is_expired":       false,
			}
		],
		"eavesdrop_hotspots": {"market": 10},
	}
	fes.restore_from_data(data)
	if fes._events.size() != 1:
		push_error("test_restore_from_data_restores_event_fields_and_hotspots: expected 1 event, got %d"
				% fes._events.size())
		return false
	var ev: FactionEventSystem.FactionEvent = fes._events[0]
	if ev.event_type != "guard_crackdown":
		push_error("test_restore_from_data_restores_event_fields_and_hotspots: wrong event_type '%s'" % ev.event_type)
		return false
	if ev.trigger_day != 3 or ev.duration_days != 2:
		push_error("test_restore_from_data_restores_event_fields_and_hotspots: wrong day/duration")
		return false
	if ev.is_active or ev.is_expired:
		push_error("test_restore_from_data_restores_event_fields_and_hotspots: unexpected active/expired state")
		return false
	if fes.eavesdrop_hotspots.get("market") != 10:
		push_error("test_restore_from_data_restores_event_fields_and_hotspots: hotspot not restored")
		return false
	return true


## restore_from_data({}) is a no-op — returns immediately without touching _events.
static func test_restore_from_data_empty_dict_is_noop() -> bool:
	var fes := _make_fes()
	fes._schedule_events()
	var count_before := fes._events.size()
	fes.restore_from_data({})
	return fes._events.size() == count_before
