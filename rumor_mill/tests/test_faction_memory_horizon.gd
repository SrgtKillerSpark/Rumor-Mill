## test_faction_memory_horizon.gd — Unit tests for FactionMemoryHorizon (SPA-3295).
##
## Covers:
##   • Severity horizon classification: seed/evidence → Moderate (42),
##     observe/eavesdrop → Minor (18), faction_schism → Major (72),
##     delta magnitude >= 15 → Major regardless of source
##   • Decay curves per severity: full impact at tick 0, half at 50% horizon,
##     zero at full horizon
##   • Stack pruning: zero-impact entries removed by on_tick()
##   • Stack cap: oldest entry evicted when size exceeds STACK_CAP (10)
##   • Dialog hint qualifier: appears when decaying + far from band boundary;
##     absent when fresh or near boundary
##   • Positive + negative delta cancellation
##   • Serialization round-trip (to_dict / from_dict); empty-dict no-op
##   • Band label correctness across all four bands
##
## All tests use synthetic in-memory data — no live game nodes required.
##
## Run from the Godot editor: Scene → Run Script (or call run() from any autoload).

class_name TestFactionMemoryHorizon
extends RefCounted

const FactionMemoryHorizon := preload("res://scripts/faction_memory_horizon.gd")


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Severity horizon classification
		"test_seed_maps_to_moderate_horizon",
		"test_evidence_maps_to_moderate_horizon",
		"test_eavesdrop_maps_to_minor_horizon",
		"test_observe_maps_to_minor_horizon",
		"test_faction_schism_maps_to_major_horizon",
		"test_large_delta_maps_to_major_horizon",
		"test_negative_large_delta_maps_to_major",
		# Decay curves per severity
		"test_decay_at_tick_zero_is_full_delta",
		"test_decay_at_half_moderate_horizon",
		"test_decay_at_full_moderate_horizon",
		"test_major_horizon_curve",
		"test_minor_horizon_curve",
		# Stack pruning
		"test_pruning_removes_zero_impact_entries",
		"test_pruning_keeps_active_entries",
		"test_pruning_mixed_active_and_expired",
		# Stack cap
		"test_stack_cap_at_ten_entries",
		"test_stack_cap_keeps_newest_entries",
		# Dialog hint qualifiers
		"test_qualifier_absent_when_not_decaying",
		"test_qualifier_absent_when_near_boundary",
		"test_qualifier_absent_when_no_memory",
		"test_qualifier_present_hostile_band",
		"test_qualifier_present_wary_band",
		"test_qualifier_present_warm_band",
		"test_qualifier_present_friendly_band",
		# Positive + negative cancellation
		"test_positive_negative_cancellation_at_zero",
		"test_positive_negative_cancellation_at_half",
		# Serialization
		"test_serialize_roundtrip",
		"test_restore_empty_dict_is_noop",
		# Band labels
		"test_band_hostile_at_minus_fifteen",
		"test_band_hostile_at_boundary",
		"test_band_wary_mid",
		"test_band_wary_at_zero",
		"test_band_warm_mid",
		"test_band_warm_at_ten",
		"test_band_friendly",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nFactionMemoryHorizon tests: %d passed, %d failed" % [passed, failed])


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make() -> FactionMemoryHorizon:
	return FactionMemoryHorizon.new()


# ── Severity horizon classification ──────────────────────────────────────────

static func test_seed_maps_to_moderate_horizon() -> bool:
	var fmh := _make()
	fmh.record_action("merchant", -5, 0, "seed")
	var entry: Dictionary = fmh._action_memory["merchant"][0]
	if entry.get("horizon") != FactionMemoryHorizon.HORIZON_MODERATE:
		push_error("test_seed_maps_to_moderate_horizon: horizon=%d" % entry.get("horizon"))
		return false
	return true


static func test_evidence_maps_to_moderate_horizon() -> bool:
	var fmh := _make()
	fmh.record_action("clergy", -8, 0, "evidence")
	var entry: Dictionary = fmh._action_memory["clergy"][0]
	if entry.get("horizon") != FactionMemoryHorizon.HORIZON_MODERATE:
		push_error("test_evidence_maps_to_moderate_horizon: horizon=%d" % entry.get("horizon"))
		return false
	return true


static func test_eavesdrop_maps_to_minor_horizon() -> bool:
	var fmh := _make()
	fmh.record_action("noble", -3, 0, "eavesdrop")
	var entry: Dictionary = fmh._action_memory["noble"][0]
	if entry.get("horizon") != FactionMemoryHorizon.HORIZON_MINOR:
		push_error("test_eavesdrop_maps_to_minor_horizon: horizon=%d" % entry.get("horizon"))
		return false
	return true


static func test_observe_maps_to_minor_horizon() -> bool:
	var fmh := _make()
	fmh.record_action("merchant", -2, 0, "observe")
	var entry: Dictionary = fmh._action_memory["merchant"][0]
	if entry.get("horizon") != FactionMemoryHorizon.HORIZON_MINOR:
		push_error("test_observe_maps_to_minor_horizon: horizon=%d" % entry.get("horizon"))
		return false
	return true


static func test_faction_schism_maps_to_major_horizon() -> bool:
	var fmh := _make()
	fmh.record_action("noble", -20, 0, "faction_schism")
	var entry: Dictionary = fmh._action_memory["noble"][0]
	if entry.get("horizon") != FactionMemoryHorizon.HORIZON_MAJOR:
		push_error("test_faction_schism_maps_to_major_horizon: horizon=%d" % entry.get("horizon"))
		return false
	return true


## Delta of magnitude >= MAJOR_DELTA_THRESHOLD maps to Major regardless of source.
static func test_large_delta_maps_to_major_horizon() -> bool:
	var fmh := _make()
	fmh.record_action("clergy", -15, 0, "seed")
	var entry: Dictionary = fmh._action_memory["clergy"][0]
	if entry.get("horizon") != FactionMemoryHorizon.HORIZON_MAJOR:
		push_error("test_large_delta_maps_to_major_horizon: horizon=%d" % entry.get("horizon"))
		return false
	return true


## Negative delta of magnitude >= threshold also maps to Major.
static func test_negative_large_delta_maps_to_major() -> bool:
	var fmh := _make()
	fmh.record_action("merchant", -16, 0, "observe")  # observe normally → Minor
	var entry: Dictionary = fmh._action_memory["merchant"][0]
	if entry.get("horizon") != FactionMemoryHorizon.HORIZON_MAJOR:
		push_error("test_negative_large_delta_maps_to_major: horizon=%d" % entry.get("horizon"))
		return false
	return true


# ── Decay curves ──────────────────────────────────────────────────────────────

static func test_decay_at_tick_zero_is_full_delta() -> bool:
	var fmh := _make()
	fmh.record_action("merchant", -10, 0, "seed")  # horizon = 42
	var disp: float = fmh.get_disposition("merchant", 0)
	if not is_equal_approx(disp, -10.0):
		push_error("test_decay_at_tick_zero_is_full_delta: got %f" % disp)
		return false
	return true


## At half the Moderate horizon (tick 21 of 42), remaining impact is 50%.
static func test_decay_at_half_moderate_horizon() -> bool:
	var fmh := _make()
	fmh.record_action("merchant", -10, 0, "seed")  # horizon = 42
	var disp: float = fmh.get_disposition("merchant", 21)
	if not is_equal_approx(disp, -5.0):
		push_error("test_decay_at_half_moderate_horizon: got %f" % disp)
		return false
	return true


## At the full Moderate horizon (tick 42), remaining impact is 0.
static func test_decay_at_full_moderate_horizon() -> bool:
	var fmh := _make()
	fmh.record_action("merchant", -10, 0, "seed")  # horizon = 42
	var disp: float = fmh.get_disposition("merchant", 42)
	if not is_equal_approx(disp, 0.0):
		push_error("test_decay_at_full_moderate_horizon: got %f" % disp)
		return false
	return true


## Major horizon: half at 36 ticks, zero at 72 ticks.
static func test_major_horizon_curve() -> bool:
	var fmh := _make()
	fmh.record_action("noble", -20, 0, "faction_schism")  # horizon = 72
	var half: float = fmh.get_disposition("noble", 36)
	if not is_equal_approx(half, -10.0):
		push_error("test_major_horizon_curve at 36: got %f" % half)
		return false
	var full: float = fmh.get_disposition("noble", 72)
	if not is_equal_approx(full, 0.0):
		push_error("test_major_horizon_curve at 72: got %f" % full)
		return false
	return true


## Minor horizon: half at 9 ticks, zero at 18 ticks.
static func test_minor_horizon_curve() -> bool:
	var fmh := _make()
	fmh.record_action("clergy", -6, 0, "eavesdrop")  # horizon = 18
	var half: float = fmh.get_disposition("clergy", 9)
	if not is_equal_approx(half, -3.0):
		push_error("test_minor_horizon_curve at 9: got %f" % half)
		return false
	var full: float = fmh.get_disposition("clergy", 18)
	if not is_equal_approx(full, 0.0):
		push_error("test_minor_horizon_curve at 18: got %f" % full)
		return false
	return true


# ── Stack pruning ─────────────────────────────────────────────────────────────

## on_tick() removes entries that have expired (remaining impact ≈ 0).
static func test_pruning_removes_zero_impact_entries() -> bool:
	var fmh := _make()
	fmh.record_action("merchant", -5, 0, "eavesdrop")  # horizon = 18; zero at tick >= 18
	fmh.on_tick(18)
	var stack: Array = fmh._action_memory.get("merchant", [])
	if stack.size() != 0:
		push_error("test_pruning_removes_zero_impact_entries: size=%d" % stack.size())
		return false
	return true


## on_tick() keeps entries that still have remaining impact.
static func test_pruning_keeps_active_entries() -> bool:
	var fmh := _make()
	fmh.record_action("noble", -8, 0, "seed")  # horizon = 42; active until tick 42
	fmh.on_tick(10)
	var stack: Array = fmh._action_memory.get("noble", [])
	if stack.size() != 1:
		push_error("test_pruning_keeps_active_entries: size=%d" % stack.size())
		return false
	return true


## on_tick() only removes expired entries, keeping active ones intact.
static func test_pruning_mixed_active_and_expired() -> bool:
	var fmh := _make()
	fmh.record_action("clergy", -3, 0, "eavesdrop")  # horizon 18 → expires at tick 18
	fmh.record_action("clergy", -5, 0, "seed")       # horizon 42 → still active at tick 18
	fmh.on_tick(18)
	var stack: Array = fmh._action_memory.get("clergy", [])
	if stack.size() != 1:
		push_error("test_pruning_mixed_active_and_expired: size=%d (expected 1)" % stack.size())
		return false
	return true


# ── Stack cap ─────────────────────────────────────────────────────────────────

## Adding more than STACK_CAP entries caps the stack at STACK_CAP.
static func test_stack_cap_at_ten_entries() -> bool:
	var fmh := _make()
	for i in range(12):
		fmh.record_action("clergy", -1, i, "observe")
	var stack: Array = fmh._action_memory.get("clergy", [])
	if stack.size() != FactionMemoryHorizon.STACK_CAP:
		push_error("test_stack_cap_at_ten_entries: size=%d (expected %d)"
				% [stack.size(), FactionMemoryHorizon.STACK_CAP])
		return false
	return true


## After overflow, the stack holds the 10 newest entries (oldest evicted).
static func test_stack_cap_keeps_newest_entries() -> bool:
	var fmh := _make()
	for i in range(12):
		fmh.record_action("merchant", i, i * 10, "seed")  # delta = i, tick = i*10
	var stack: Array = fmh._action_memory.get("merchant", [])
	# Newest entries have ticks 20..110 (i = 2..11).
	var oldest_tick: int = int(stack[0].get("tick", -1))
	if oldest_tick != 20:  # entry at i=2 is the oldest remaining
		push_error("test_stack_cap_keeps_newest_entries: oldest tick=%d (expected 20)" % oldest_tick)
		return false
	return true


# ── Dialog hint qualifiers ────────────────────────────────────────────────────

## A fresh entry (0 ticks elapsed) is NOT actively decaying — no qualifier.
static func test_qualifier_absent_when_not_decaying() -> bool:
	var fmh := _make()
	fmh.set_base_disposition("merchant", -16.0)
	fmh.record_action("merchant", -2, 0, "seed")  # horizon = 42
	# At tick 0: 0/42 = 0% elapsed; NOT > 50% → not decaying
	var q: String = fmh.get_dialog_qualifier("merchant", 0)
	if q != "":
		push_error("test_qualifier_absent_when_not_decaying: got '%s'" % q)
		return false
	return true


## Decaying but within 3 points of the nearest band boundary — no qualifier.
static func test_qualifier_absent_when_near_boundary() -> bool:
	# disposition ≈ -9.476 at tick 22 — only 0.524 points from the -10 boundary
	var fmh := _make()
	fmh.set_base_disposition("noble", -9.0)
	fmh.record_action("noble", -1, 0, "seed")  # horizon = 42
	# At tick 22: ticks_elapsed=22, 22/42=0.524 > 0.5 → actively decaying.
	# impact = -1 * (1 - 22/42) ≈ -0.476. disp ≈ -9.476.
	# Nearest boundary: -10 at distance 0.524 < 3 → no qualifier.
	var q: String = fmh.get_dialog_qualifier("noble", 22)
	if q != "":
		push_error("test_qualifier_absent_when_near_boundary: got '%s'" % q)
		return false
	return true


## Faction with no recorded actions returns "" regardless of base disposition.
static func test_qualifier_absent_when_no_memory() -> bool:
	var fmh := _make()
	fmh.set_base_disposition("merchant", -16.0)
	var q: String = fmh.get_dialog_qualifier("merchant", 50)
	if q != "":
		push_error("test_qualifier_absent_when_no_memory: got '%s'" % q)
		return false
	return true


## Decaying entry, Hostile band, well away from -10 boundary → correct qualifier.
static func test_qualifier_present_hostile_band() -> bool:
	# disp ≈ -16 + (-2 * 0.476) ≈ -16.952 at tick 22; band=Hostile; dist to -10 ≈ 6.95 >= 3
	var fmh := _make()
	fmh.set_base_disposition("merchant", -16.0)
	fmh.record_action("merchant", -2, 0, "seed")  # horizon = 42
	var q: String = fmh.get_dialog_qualifier("merchant", 22)
	if q != "...but memories are fading":
		push_error("test_qualifier_present_hostile_band: got '%s'" % q)
		return false
	return true


## Decaying entry, Wary band, far from both boundaries → correct qualifier.
static func test_qualifier_present_wary_band() -> bool:
	# disp ≈ -5 + (-1 * 0.476) ≈ -5.476; band=Wary; dist to -10≈4.52, to 0≈5.48 → min 4.52 >= 3
	var fmh := _make()
	fmh.set_base_disposition("noble", -5.0)
	fmh.record_action("noble", -1, 0, "seed")  # horizon = 42
	var q: String = fmh.get_dialog_qualifier("noble", 22)
	if q != "...though less so than before":
		push_error("test_qualifier_present_wary_band: got '%s'" % q)
		return false
	return true


## Decaying positive entry, Warm band, far from both boundaries → correct qualifier.
static func test_qualifier_present_warm_band() -> bool:
	# disp ≈ 5 + (1 * 0.476) ≈ 5.476; band=Warm; dist to 0≈5.48, to 10≈4.52 → min 4.52 >= 3
	var fmh := _make()
	fmh.set_base_disposition("clergy", 5.0)
	fmh.record_action("clergy", 1, 0, "seed")  # horizon = 42, positive delta
	var q: String = fmh.get_dialog_qualifier("clergy", 22)
	if q != "...though the goodwill is fading":
		push_error("test_qualifier_present_warm_band: got '%s'" % q)
		return false
	return true


## Decaying entry, Friendly band, well above 10 → correct qualifier.
static func test_qualifier_present_friendly_band() -> bool:
	# disp ≈ 16 + (1 * 0.476) ≈ 16.476; band=Friendly; dist to 10 ≈ 6.48 >= 3
	var fmh := _make()
	fmh.set_base_disposition("merchant", 16.0)
	fmh.record_action("merchant", 1, 0, "seed")  # horizon = 42
	var q: String = fmh.get_dialog_qualifier("merchant", 22)
	if q != "...but old favors are being forgotten":
		push_error("test_qualifier_present_friendly_band: got '%s'" % q)
		return false
	return true


# ── Positive + negative cancellation ─────────────────────────────────────────

## Equal positive and negative deltas cancel to zero disposition at any tick.
static func test_positive_negative_cancellation_at_zero() -> bool:
	var fmh := _make()
	fmh.record_action("noble", -10, 0, "seed")
	fmh.record_action("noble",  10, 0, "seed")
	var disp: float = fmh.get_disposition("noble", 0)
	if not is_equal_approx(disp, 0.0):
		push_error("test_positive_negative_cancellation_at_zero: got %f" % disp)
		return false
	return true


## Cancellation holds at half horizon (both decay at the same rate).
static func test_positive_negative_cancellation_at_half() -> bool:
	var fmh := _make()
	fmh.record_action("noble", -10, 0, "seed")
	fmh.record_action("noble",  10, 0, "seed")
	var disp: float = fmh.get_disposition("noble", 21)  # half of 42
	if not is_equal_approx(disp, 0.0):
		push_error("test_positive_negative_cancellation_at_half: got %f" % disp)
		return false
	return true


# ── Serialization round-trip ──────────────────────────────────────────────────

static func test_serialize_roundtrip() -> bool:
	var fmh := _make()
	fmh.set_base_disposition("merchant", 5.0)
	fmh.record_action("merchant", -8, 10, "seed")
	fmh.record_action("clergy",   -3,  5, "eavesdrop")

	var fmh2 := _make()
	fmh2.from_dict(fmh.to_dict())

	var tick := 20
	var d1m: float = fmh.get_disposition("merchant", tick)
	var d2m: float = fmh2.get_disposition("merchant", tick)
	if not is_equal_approx(d1m, d2m):
		push_error("test_serialize_roundtrip merchant: %f vs %f" % [d1m, d2m])
		return false

	var d1c: float = fmh.get_disposition("clergy", tick)
	var d2c: float = fmh2.get_disposition("clergy", tick)
	if not is_equal_approx(d1c, d2c):
		push_error("test_serialize_roundtrip clergy: %f vs %f" % [d1c, d2c])
		return false

	return true


## from_dict({}) is a no-op and does not clear existing state.
static func test_restore_empty_dict_is_noop() -> bool:
	var fmh := _make()
	fmh.record_action("noble", -5, 0, "seed")
	fmh.from_dict({})
	var disp: float = fmh.get_disposition("noble", 0)
	if not is_equal_approx(disp, -5.0):
		push_error("test_restore_empty_dict_is_noop: got %f" % disp)
		return false
	return true


# ── Band labels ───────────────────────────────────────────────────────────────

static func test_band_hostile_at_minus_fifteen() -> bool:
	if FactionMemoryHorizon.get_band(-15.0) != "Hostile":
		push_error("test_band_hostile_at_minus_fifteen: got '%s'" % FactionMemoryHorizon.get_band(-15.0))
		return false
	return true


static func test_band_hostile_at_boundary() -> bool:
	# BAND_HOSTILE_MAX = -10.0; disposition <= -10 is Hostile.
	if FactionMemoryHorizon.get_band(-10.0) != "Hostile":
		push_error("test_band_hostile_at_boundary: got '%s'" % FactionMemoryHorizon.get_band(-10.0))
		return false
	return true


static func test_band_wary_mid() -> bool:
	if FactionMemoryHorizon.get_band(-5.0) != "Wary":
		push_error("test_band_wary_mid: got '%s'" % FactionMemoryHorizon.get_band(-5.0))
		return false
	return true


static func test_band_wary_at_zero() -> bool:
	# BAND_WARY_MAX = 0.0; disposition <= 0 (and > -10) is Wary.
	if FactionMemoryHorizon.get_band(0.0) != "Wary":
		push_error("test_band_wary_at_zero: got '%s'" % FactionMemoryHorizon.get_band(0.0))
		return false
	return true


static func test_band_warm_mid() -> bool:
	if FactionMemoryHorizon.get_band(5.0) != "Warm":
		push_error("test_band_warm_mid: got '%s'" % FactionMemoryHorizon.get_band(5.0))
		return false
	return true


static func test_band_warm_at_ten() -> bool:
	# BAND_WARM_MAX = 10.0; disposition <= 10 (and > 0) is Warm.
	if FactionMemoryHorizon.get_band(10.0) != "Warm":
		push_error("test_band_warm_at_ten: got '%s'" % FactionMemoryHorizon.get_band(10.0))
		return false
	return true


static func test_band_friendly() -> bool:
	if FactionMemoryHorizon.get_band(15.0) != "Friendly":
		push_error("test_band_friendly: got '%s'" % FactionMemoryHorizon.get_band(15.0))
		return false
	return true
