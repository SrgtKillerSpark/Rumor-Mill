## test_quarantine_system.gd — Unit tests for QuarantineSystem (SPA-1041).
##
## Covers:
##   • Constants: costs, duration ticks, cooldown ticks
##   • Initial state: inactive, quarantined empty, cooldown empty
##   • activate(): sets active, clears state
##   • is_active(): before and after activate
##   • is_quarantined(): for unknown buildings
##   • get_quarantined_buildings(): empty when none active
##   • get_expiry_tick(): -1 for unknown buildings
##   • is_on_cooldown(): false when no cooldown set, true when within window
##   • tick(): expires quarantine and sets cooldown when tick >= expiry
##   • try_quarantine(): blocked by inactive, already quarantined, max-1 active,
##     cooldown, and insufficient resources (via mock intel store)
##
## Strategy: QuarantineSystem extends RefCounted. try_quarantine() needs a
## PlayerIntelStore — a minimal inner stub is used for resource tests.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestQuarantineSystem
extends RefCounted

const QuarantineSystemScript := preload("res://scripts/quarantine_system.gd")
const PlayerIntelStoreScript  := preload("res://scripts/intel_store.gd")


static func _make_qs() -> QuarantineSystem:
	return QuarantineSystemScript.new()


## Minimal PlayerIntelStore with just enough fields for QuarantineSystem.
static func _make_store(
		recon: int = 2,
		whispers: int = 2,
		free_charges: int = 0
) -> PlayerIntelStore:
	var store := PlayerIntelStoreScript.new()
	store.recon_actions_remaining  = recon
	store.whisper_tokens_remaining = whispers
	store.free_quarantine_charges  = free_charges
	return store


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── constants ──
		"test_recon_cost_is_1",
		"test_whisper_cost_is_1",
		"test_legacy_cost_alias",
		"test_duration_ticks_is_48",
		"test_cooldown_ticks_is_72",

		# ── initial state ──
		"test_initial_not_active",
		"test_initial_quarantined_is_empty",
		"test_initial_cooldown_is_empty",

		# ── activate ──
		"test_activate_sets_active",
		"test_activate_clears_quarantined",
		"test_activate_clears_cooldown_dict",

		# ── is_active ──
		"test_is_active_false_before_activate",
		"test_is_active_true_after_activate",

		# ── query methods ──
		"test_is_quarantined_false_for_unknown",
		"test_get_quarantined_buildings_empty_initially",
		"test_get_expiry_tick_minus1_for_unknown",
		"test_is_on_cooldown_false_when_no_cooldown",
		"test_is_on_cooldown_true_within_window",
		"test_is_on_cooldown_false_at_expiry",

		# ── tick expiry ──
		"test_tick_expires_quarantine",
		"test_tick_sets_cooldown_after_expiry",
		"test_tick_does_not_expire_before_due",

		# ── try_quarantine blocked cases ──
		"test_try_quarantine_false_when_not_active",
		"test_try_quarantine_false_if_already_quarantined",
		"test_try_quarantine_false_if_another_active",
		"test_try_quarantine_false_if_on_cooldown",
		"test_try_quarantine_false_if_no_recon",
		"test_try_quarantine_false_if_no_whispers",

		# ── try_quarantine success ──
		"test_try_quarantine_success_with_resources",
		"test_try_quarantine_success_adds_to_quarantined",
		"test_try_quarantine_success_with_free_charge",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			print("  FAIL  %s" % method_name)
			failed += 1

	print("\n  %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

func test_recon_cost_is_1() -> bool:
	return QuarantineSystem.QUARANTINE_RECON_COST == 1


func test_whisper_cost_is_1() -> bool:
	return QuarantineSystem.QUARANTINE_WHISPER_COST == 1


func test_legacy_cost_alias() -> bool:
	return QuarantineSystem.QUARANTINE_COST == QuarantineSystem.QUARANTINE_WHISPER_COST


func test_duration_ticks_is_48() -> bool:
	return QuarantineSystem.QUARANTINE_DURATION_TICKS == 48


func test_cooldown_ticks_is_72() -> bool:
	return QuarantineSystem.QUARANTINE_COOLDOWN_TICKS == 72


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

func test_initial_not_active() -> bool:
	return _make_qs()._active == false


func test_initial_quarantined_is_empty() -> bool:
	return _make_qs()._quarantined.is_empty()


func test_initial_cooldown_is_empty() -> bool:
	return _make_qs()._cooldown_until.is_empty()


# ══════════════════════════════════════════════════════════════════════════════
# activate
# ══════════════════════════════════════════════════════════════════════════════

func test_activate_sets_active() -> bool:
	var qs := _make_qs()
	qs.activate()
	return qs._active == true


func test_activate_clears_quarantined() -> bool:
	var qs := _make_qs()
	qs._quarantined["tavern"] = 100
	qs.activate()
	return qs._quarantined.is_empty()


func test_activate_clears_cooldown_dict() -> bool:
	var qs := _make_qs()
	qs._cooldown_until["market"] = 200
	qs.activate()
	return qs._cooldown_until.is_empty()


# ══════════════════════════════════════════════════════════════════════════════
# is_active
# ══════════════════════════════════════════════════════════════════════════════

func test_is_active_false_before_activate() -> bool:
	return _make_qs().is_active() == false


func test_is_active_true_after_activate() -> bool:
	var qs := _make_qs()
	qs.activate()
	return qs.is_active() == true


# ══════════════════════════════════════════════════════════════════════════════
# Query methods
# ══════════════════════════════════════════════════════════════════════════════

func test_is_quarantined_false_for_unknown() -> bool:
	var qs := _make_qs()
	qs.activate()
	return qs.is_quarantined("nowhere") == false


func test_get_quarantined_buildings_empty_initially() -> bool:
	var qs := _make_qs()
	qs.activate()
	return qs.get_quarantined_buildings().is_empty()


func test_get_expiry_tick_minus1_for_unknown() -> bool:
	var qs := _make_qs()
	qs.activate()
	return qs.get_expiry_tick("nowhere") == -1


func test_is_on_cooldown_false_when_no_cooldown() -> bool:
	var qs := _make_qs()
	qs.activate()
	return qs.is_on_cooldown("tavern", 10) == false


func test_is_on_cooldown_true_within_window() -> bool:
	var qs := _make_qs()
	qs.activate()
	qs._cooldown_until["tavern"] = 100
	return qs.is_on_cooldown("tavern", 50) == true  # 50 < 100


func test_is_on_cooldown_false_at_expiry() -> bool:
	var qs := _make_qs()
	qs.activate()
	qs._cooldown_until["tavern"] = 100
	return qs.is_on_cooldown("tavern", 100) == false  # 100 is NOT < 100


# ══════════════════════════════════════════════════════════════════════════════
# tick expiry
# ══════════════════════════════════════════════════════════════════════════════

func test_tick_expires_quarantine() -> bool:
	var qs := _make_qs()
	qs.activate()
	qs._quarantined["market"] = 50   # expires at tick 50
	qs.tick(50)
	return not qs.is_quarantined("market")


func test_tick_sets_cooldown_after_expiry() -> bool:
	var qs := _make_qs()
	qs.activate()
	qs._quarantined["market"] = 50
	qs.tick(50)
	# Cooldown set to tick 50 + 72 = 122
	return qs._cooldown_until.get("market", -1) == 50 + QuarantineSystem.QUARANTINE_COOLDOWN_TICKS


func test_tick_does_not_expire_before_due() -> bool:
	var qs := _make_qs()
	qs.activate()
	qs._quarantined["chapel"] = 100
	qs.tick(49)
	return qs.is_quarantined("chapel")   # still quarantined


# ══════════════════════════════════════════════════════════════════════════════
# try_quarantine — blocked cases
# ══════════════════════════════════════════════════════════════════════════════

func test_try_quarantine_false_when_not_active() -> bool:
	var qs    := _make_qs()
	var store := _make_store()
	return qs.try_quarantine("tavern", store, 0) == false


func test_try_quarantine_false_if_already_quarantined() -> bool:
	var qs    := _make_qs()
	qs.activate()
	var store := _make_store()
	qs._quarantined["tavern"] = 100
	return qs.try_quarantine("tavern", store, 0) == false


func test_try_quarantine_false_if_another_active() -> bool:
	# Only one quarantine may be active at a time.
	var qs    := _make_qs()
	qs.activate()
	var store := _make_store()
	qs._quarantined["chapel"] = 100   # different building already quarantined
	return qs.try_quarantine("market", store, 0) == false


func test_try_quarantine_false_if_on_cooldown() -> bool:
	var qs    := _make_qs()
	qs.activate()
	var store := _make_store()
	qs._cooldown_until["tavern"] = 100
	return qs.try_quarantine("tavern", store, 50) == false  # 50 < 100


func test_try_quarantine_false_if_no_recon() -> bool:
	var qs    := _make_qs()
	qs.activate()
	var store := _make_store(0, 2)  # recon=0
	return qs.try_quarantine("market", store, 0) == false


func test_try_quarantine_false_if_no_whispers() -> bool:
	var qs    := _make_qs()
	qs.activate()
	var store := _make_store(2, 0)  # whispers=0
	return qs.try_quarantine("market", store, 0) == false


# ══════════════════════════════════════════════════════════════════════════════
# try_quarantine — success cases
# ══════════════════════════════════════════════════════════════════════════════

func test_try_quarantine_success_with_resources() -> bool:
	var qs    := _make_qs()
	qs.activate()
	var store := _make_store(2, 2)
	return qs.try_quarantine("market", store, 0) == true


func test_try_quarantine_success_adds_to_quarantined() -> bool:
	var qs    := _make_qs()
	qs.activate()
	var store := _make_store(2, 2)
	qs.try_quarantine("market", store, 10)
	return qs.is_quarantined("market") and qs.get_expiry_tick("market") == 10 + QuarantineSystem.QUARANTINE_DURATION_TICKS


func test_try_quarantine_success_with_free_charge() -> bool:
	var qs    := _make_qs()
	qs.activate()
	# Store has 0 recon and 0 whispers but 1 free charge.
	var store := _make_store(0, 0, 1)
	return qs.try_quarantine("chapel", store, 0) == true
