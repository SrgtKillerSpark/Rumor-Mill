## test_fes_memory_integration.gd — Integration tests: FactionEventSystem → FactionMemoryHorizon.
##
## Verifies that each of the four FES event types calls record_action() with the correct
## faction_id, delta sign/magnitude, tick, and source, and that get_disposition() reflects
## the recorded entries.
##
## Acceptance criteria (SPA-4111):
##   1. guard_crackdown  → record_action("guard",    -20, tick, "guard_crackdown")
##   2. market_dispute   → record_action("merchant",  -8, tick, "market_dispute")
##   3. religious_festival → record_action("clergy",   8, tick, "religious_festival")
##   4. noble_feast      → record_action("noble",      8, tick, "noble_feast")
##   5. When _faction_memory_horizon is null, activation does not crash.
##   6. After guard_crackdown fires, get_disposition("guard", tick) < 0.

class_name TestFesMemoryIntegration
extends RefCounted


# ── Minimal mocks ──────────────────────────────────────────────────────────────

class MockIntelStore extends RefCounted:
	var heat_decay_override: float = -1.0


class MockSocialGraph extends RefCounted:
	func mutate_edge(_a: String, _b: String, _d: float, _t: int) -> void:
		pass
	func get_top_neighbours(_id: String, _n: int) -> Array:
		return []


class MockReputationSystem extends RefCounted:
	func set_faction_sentiment_bonus(_id: String, _bonus: float) -> void:
		pass
	func clear_faction_sentiment_bonus(_id: String) -> void:
		pass


# ── Helpers ────────────────────────────────────────────────────────────────────

static func _make_fes_with_horizon(
		horizon: FactionMemoryHorizon,
		intel_store: MockIntelStore = null,
		social_graph: MockSocialGraph = null,
		reputation_system: MockReputationSystem = null
) -> FactionEventSystem:
	var fes                       := FactionEventSystem.new()
	fes._npcs                      = []
	fes._faction_memory_horizon    = horizon
	fes._intel_store               = intel_store if intel_store != null else MockIntelStore.new()
	fes._social_graph              = social_graph if social_graph != null else MockSocialGraph.new()
	fes._reputation_system         = reputation_system if reputation_system != null else MockReputationSystem.new()
	return fes


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


# ── Test runner ────────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_guard_crackdown_records_major_negative_for_guard_faction",
		"test_market_dispute_records_moderate_negative_for_merchant_faction",
		"test_religious_festival_records_moderate_positive_for_clergy_faction",
		"test_noble_feast_records_moderate_positive_for_noble_faction",
		"test_no_crash_when_faction_memory_horizon_is_null",
		"test_guard_crackdown_disposition_is_negative_after_activation",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nFES memory integration tests: %d passed, %d failed" % [passed, failed])


# ── Tests ──────────────────────────────────────────────────────────────────────

## guard_crackdown activation calls record_action("guard", -20, tick, "guard_crackdown").
func test_guard_crackdown_records_major_negative_for_guard_faction() -> bool:
	var horizon := FactionMemoryHorizon.new()
	var fes     := _make_fes_with_horizon(horizon)
	_inject_event(fes, "guard_crackdown", 3, FactionEventSystem.TIMED_EVENT_DURATION)

	fes.on_day_changed(3)

	var stack: Array = horizon._action_memory.get("guard", [])
	if stack.is_empty():
		push_error("test_guard_crackdown_records_major_negative_for_guard_faction: no entry for 'guard' faction")
		return false
	var entry: Dictionary = stack[0]
	if entry.get("delta") != -20:
		push_error("test_guard_crackdown_records_major_negative_for_guard_faction: expected delta -20, got %s" % str(entry.get("delta")))
		return false
	if entry.get("source") != "guard_crackdown":
		push_error("test_guard_crackdown_records_major_negative_for_guard_faction: expected source 'guard_crackdown', got '%s'" % str(entry.get("source")))
		return false
	var expected_tick: int = (3 - 1) * 24
	if entry.get("tick") != expected_tick:
		push_error("test_guard_crackdown_records_major_negative_for_guard_faction: expected tick %d, got %s" % [expected_tick, str(entry.get("tick"))])
		return false
	return true


## market_dispute activation calls record_action("merchant", -8, tick, "market_dispute").
func test_market_dispute_records_moderate_negative_for_merchant_faction() -> bool:
	var horizon := FactionMemoryHorizon.new()
	var fes     := _make_fes_with_horizon(horizon)
	var ev      := _inject_event(fes, "market_dispute", 4, 0)
	ev.affected_npc_ids = ["npc_merchant_a", "npc_merchant_b"]

	fes.on_day_changed(4)

	var stack: Array = horizon._action_memory.get("merchant", [])
	if stack.is_empty():
		push_error("test_market_dispute_records_moderate_negative_for_merchant_faction: no entry for 'merchant' faction")
		return false
	var entry: Dictionary = stack[0]
	if entry.get("delta") != -8:
		push_error("test_market_dispute_records_moderate_negative_for_merchant_faction: expected delta -8, got %s" % str(entry.get("delta")))
		return false
	if entry.get("source") != "market_dispute":
		push_error("test_market_dispute_records_moderate_negative_for_merchant_faction: expected source 'market_dispute', got '%s'" % str(entry.get("source")))
		return false
	return true


## religious_festival activation calls record_action("clergy", 8, tick, "religious_festival").
func test_religious_festival_records_moderate_positive_for_clergy_faction() -> bool:
	var horizon := FactionMemoryHorizon.new()
	var fes     := _make_fes_with_horizon(horizon)
	_inject_event(fes, "religious_festival", 5, FactionEventSystem.TIMED_EVENT_DURATION)

	fes.on_day_changed(5)

	var stack: Array = horizon._action_memory.get("clergy", [])
	if stack.is_empty():
		push_error("test_religious_festival_records_moderate_positive_for_clergy_faction: no entry for 'clergy' faction")
		return false
	var entry: Dictionary = stack[0]
	if entry.get("delta") != 8:
		push_error("test_religious_festival_records_moderate_positive_for_clergy_faction: expected delta 8, got %s" % str(entry.get("delta")))
		return false
	if entry.get("source") != "religious_festival":
		push_error("test_religious_festival_records_moderate_positive_for_clergy_faction: expected source 'religious_festival', got '%s'" % str(entry.get("source")))
		return false
	return true


## noble_feast activation calls record_action("noble", 8, tick, "noble_feast").
func test_noble_feast_records_moderate_positive_for_noble_faction() -> bool:
	var horizon := FactionMemoryHorizon.new()
	var fes     := _make_fes_with_horizon(horizon)
	_inject_event(fes, "noble_feast", 6, FactionEventSystem.TIMED_EVENT_DURATION)

	fes.on_day_changed(6)

	var stack: Array = horizon._action_memory.get("noble", [])
	if stack.is_empty():
		push_error("test_noble_feast_records_moderate_positive_for_noble_faction: no entry for 'noble' faction")
		return false
	var entry: Dictionary = stack[0]
	if entry.get("delta") != 8:
		push_error("test_noble_feast_records_moderate_positive_for_noble_faction: expected delta 8, got %s" % str(entry.get("delta")))
		return false
	if entry.get("source") != "noble_feast":
		push_error("test_noble_feast_records_moderate_positive_for_noble_faction: expected source 'noble_feast', got '%s'" % str(entry.get("source")))
		return false
	return true


## All four event types activate without crashing when _faction_memory_horizon is null.
func test_no_crash_when_faction_memory_horizon_is_null() -> bool:
	for event_type in FactionEventSystem.ALL_EVENT_TYPES:
		var fes := FactionEventSystem.new()
		fes._npcs                   = []
		fes._faction_memory_horizon = null
		fes._intel_store            = MockIntelStore.new()
		fes._social_graph           = MockSocialGraph.new()
		fes._reputation_system      = MockReputationSystem.new()
		var ev := _inject_event(fes, event_type, 3, FactionEventSystem.TIMED_EVENT_DURATION)
		if event_type == "market_dispute":
			ev.affected_npc_ids = ["npc_a", "npc_b"]
		fes.on_day_changed(3)  # must not crash
	return true


## After guard_crackdown fires, get_disposition("guard", tick) returns a negative value.
func test_guard_crackdown_disposition_is_negative_after_activation() -> bool:
	var horizon    := FactionMemoryHorizon.new()
	var fes        := _make_fes_with_horizon(horizon)
	_inject_event(fes, "guard_crackdown", 3, FactionEventSystem.TIMED_EVENT_DURATION)

	fes.on_day_changed(3)

	var tick: int       = (3 - 1) * 24
	var disp: float     = horizon.get_disposition("guard", tick)
	if disp >= 0.0:
		push_error("test_guard_crackdown_disposition_is_negative_after_activation: expected negative disposition, got %f" % disp)
		return false
	return true
