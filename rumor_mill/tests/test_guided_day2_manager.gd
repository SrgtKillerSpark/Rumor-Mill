## test_guided_day2_manager.gd — Unit tests for GuidedDay2Manager (SPA-2082).
##
## Covers:
##   Section 1 — Initial state (3 tests):
##     I1  _active is false before activate()
##     I2  all fired/connected flags are false on construction
##     I3  all external refs are null on construction
##
##   Section 2 — activate() (2 tests):
##     A1  activate() sets _active = true
##     A2  activate() stores the supplied banner ref
##
##   Section 3 — _on_day_changed() (4 tests):
##     D1  day 2 arrival queues HINT_DAWN on the banner
##     D2  day 2 arrival sets _on_day2 and _dawn_fired
##     D3  non-day-2 value: no hint queued, no state change
##     D4  calling _on_day_changed(2) twice queues HINT_DAWN exactly once
##
##   Section 4 — _on_journal_visibility_changed() (4 tests):
##     J1  fires HINT_JOURNAL when on_day2, dawn_fired, and journal is visible
##     J2  suppressed when _dawn_fired is false (day 2 sequence not yet started)
##     J3  suppressed when journal is not visible
##     J4  suppressed when _journal_fired is already true (idempotent)
##
##   Section 5 — _on_recon_action() (6 tests):
##     R1  fires HINT_OBSERVE on success + day2 + journal_fired + "Observed" prefix
##     R2  successful Observe sets _active = false (manager deactivates itself)
##     R3  suppressed when success = false
##     R4  suppressed when message prefix is not "Observed"
##     R5  suppressed when not on day 2
##     R6  suppressed when _journal_fired is false
##     R7  suppressed when _observe_fired is already true (idempotent)
##
## Mutation sensitivity:
##   Removing `day != 2` check in _on_day_changed breaks D3.
##   Removing `_dawn_fired` guard breaks D4.
##   Removing `not _on_day2` guard in journal handler breaks J2.
##   Removing `not _journal.visible` guard breaks J3.
##   Removing `not _journal_fired` guard breaks J4.
##   Removing `not success` guard in recon handler breaks R3.
##   Removing `begins_with("Observed")` check breaks R4.
##   Removing `not _on_day2` guard in recon handler breaks R5.
##   Removing `not _journal_fired` guard in recon handler breaks R6.
##   Removing `not _observe_fired` guard breaks R7.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestGuidedDay2Manager
extends RefCounted

const _GuidedDay2Mgr = preload("res://scripts/guided_day2_manager.gd")

# ── Mock objects ──────────────────────────────────────────────────────────────

class MockBanner extends Node:
	var queued_hints: Array = []

	func queue_hint(hint_id: String) -> void:
		queued_hints.append(hint_id)


class MockJournal extends CanvasLayer:
	## CanvasLayer inherits visible from CanvasItem — set directly in tests.
	pass


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns [mgr, banner] pre-wired for the recon (HINT_OBSERVE) happy path.
## All prerequisites are met; _observe_fired is left false.
func _make_observe_ready() -> Array:
	var mgr    := _GuidedDay2Mgr.new()
	var banner := MockBanner.new()
	mgr._tutorial_banner = banner
	mgr._active          = true
	mgr._on_day2         = true
	mgr._dawn_fired      = true
	mgr._journal_fired   = true
	return [mgr, banner]


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Section 1 — Initial state
		"test_i1_initial_active_false",
		"test_i2_initial_flags_all_false",
		"test_i3_initial_refs_all_null",
		# Section 2 — activate()
		"test_a1_activate_sets_active",
		"test_a2_activate_stores_banner_ref",
		# Section 3 — _on_day_changed()
		"test_d1_day2_fires_dawn_hint",
		"test_d2_day2_sets_on_day2_and_dawn_fired",
		"test_d3_non_day2_no_hint",
		"test_d4_day2_idempotent",
		# Section 4 — _on_journal_visibility_changed()
		"test_j1_journal_fires_hint_when_conditions_met",
		"test_j2_journal_suppressed_before_dawn_fired",
		"test_j3_journal_suppressed_when_not_visible",
		"test_j4_journal_suppressed_when_already_fired",
		# Section 5 — _on_recon_action()
		"test_r1_recon_fires_observe_hint",
		"test_r2_recon_sets_active_false",
		"test_r3_recon_suppressed_on_failure",
		"test_r4_recon_suppressed_wrong_prefix",
		"test_r5_recon_suppressed_before_day2",
		"test_r6_recon_suppressed_before_journal_fired",
		"test_r7_recon_suppressed_when_already_fired",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\n  %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Section 1 — Initial state
# ══════════════════════════════════════════════════════════════════════════════

## I1: manager must not be active before activate() is called.
func test_i1_initial_active_false() -> bool:
	var mgr := _GuidedDay2Mgr.new()
	return mgr._active == false


## I2: all fired/connected boolean flags are false on construction.
func test_i2_initial_flags_all_false() -> bool:
	var mgr := _GuidedDay2Mgr.new()
	return (
		mgr._on_day2           == false and
		mgr._dawn_fired        == false and
		mgr._journal_fired     == false and
		mgr._observe_fired     == false and
		mgr._connected_day     == false and
		mgr._connected_journal == false and
		mgr._connected_recon   == false
	)


## I3: all external dependency refs are null on construction.
func test_i3_initial_refs_all_null() -> bool:
	var mgr := _GuidedDay2Mgr.new()
	return (
		mgr._tutorial_sys    == null and
		mgr._tutorial_banner == null and
		mgr._day_night       == null and
		mgr._recon_ctrl      == null and
		mgr._journal         == null
	)


# ══════════════════════════════════════════════════════════════════════════════
# Section 2 — activate()
# ══════════════════════════════════════════════════════════════════════════════

## A1: activate() with null dependencies sets _active = true without crashing.
func test_a1_activate_sets_active() -> bool:
	var mgr := _GuidedDay2Mgr.new()
	mgr.activate(null, null, null, null, null)
	return mgr._active == true


## A2: activate() stores the supplied banner reference.
func test_a2_activate_stores_banner_ref() -> bool:
	var mgr    := _GuidedDay2Mgr.new()
	var banner := MockBanner.new()
	mgr.activate(null, banner, null, null, null)
	return mgr._tutorial_banner == banner


# ══════════════════════════════════════════════════════════════════════════════
# Section 3 — _on_day_changed()
# ══════════════════════════════════════════════════════════════════════════════

## D1: day 2 arrival causes HINT_DAWN to be queued on the banner.
func test_d1_day2_fires_dawn_hint() -> bool:
	var mgr    := _GuidedDay2Mgr.new()
	var banner := MockBanner.new()
	mgr._tutorial_banner = banner
	mgr._on_day_changed(2)
	return banner.queued_hints.has(_GuidedDay2Mgr.HINT_DAWN)


## D2: day 2 arrival sets both _on_day2 and _dawn_fired.
func test_d2_day2_sets_on_day2_and_dawn_fired() -> bool:
	var mgr := _GuidedDay2Mgr.new()
	mgr._on_day_changed(2)
	return mgr._on_day2 == true and mgr._dawn_fired == true


## D3: non-day-2 values do not queue any hint and leave all flags false.
func test_d3_non_day2_no_hint() -> bool:
	var mgr    := _GuidedDay2Mgr.new()
	var banner := MockBanner.new()
	mgr._tutorial_banner = banner
	mgr._on_day_changed(1)
	mgr._on_day_changed(3)
	return banner.queued_hints.is_empty() and mgr._dawn_fired == false


## D4: calling _on_day_changed(2) twice queues HINT_DAWN exactly once.
func test_d4_day2_idempotent() -> bool:
	var mgr    := _GuidedDay2Mgr.new()
	var banner := MockBanner.new()
	mgr._tutorial_banner = banner
	mgr._on_day_changed(2)
	mgr._on_day_changed(2)
	return banner.queued_hints.size() == 1


# ══════════════════════════════════════════════════════════════════════════════
# Section 4 — _on_journal_visibility_changed()
# ══════════════════════════════════════════════════════════════════════════════

## J1: HINT_JOURNAL fires when on_day2, dawn_fired, and journal is visible.
func test_j1_journal_fires_hint_when_conditions_met() -> bool:
	var mgr     := _GuidedDay2Mgr.new()
	var banner  := MockBanner.new()
	var journal := MockJournal.new()
	journal.visible      = true
	mgr._tutorial_banner = banner
	mgr._journal         = journal
	mgr._on_day2         = true
	mgr._dawn_fired      = true
	mgr._on_journal_visibility_changed()
	return (
		mgr._journal_fired == true and
		banner.queued_hints.has(_GuidedDay2Mgr.HINT_JOURNAL)
	)


## J2: handler returns early when _dawn_fired is false (sequence not started).
func test_j2_journal_suppressed_before_dawn_fired() -> bool:
	var mgr     := _GuidedDay2Mgr.new()
	var banner  := MockBanner.new()
	var journal := MockJournal.new()
	journal.visible      = true
	mgr._tutorial_banner = banner
	mgr._journal         = journal
	mgr._on_day2         = true
	# _dawn_fired left false
	mgr._on_journal_visibility_changed()
	return (
		mgr._journal_fired == false and
		banner.queued_hints.is_empty()
	)


## J3: handler returns early when journal.visible = false.
func test_j3_journal_suppressed_when_not_visible() -> bool:
	var mgr     := _GuidedDay2Mgr.new()
	var banner  := MockBanner.new()
	var journal := MockJournal.new()
	journal.visible      = false
	mgr._tutorial_banner = banner
	mgr._journal         = journal
	mgr._on_day2         = true
	mgr._dawn_fired      = true
	mgr._on_journal_visibility_changed()
	return banner.queued_hints.is_empty()


## J4: handler is idempotent — second call when _journal_fired=true queues nothing.
func test_j4_journal_suppressed_when_already_fired() -> bool:
	var mgr     := _GuidedDay2Mgr.new()
	var banner  := MockBanner.new()
	var journal := MockJournal.new()
	journal.visible      = true
	mgr._tutorial_banner = banner
	mgr._journal         = journal
	mgr._on_day2         = true
	mgr._dawn_fired      = true
	mgr._journal_fired   = true   # pre-mark as already fired
	mgr._on_journal_visibility_changed()
	return banner.queued_hints.is_empty()


# ══════════════════════════════════════════════════════════════════════════════
# Section 5 — _on_recon_action()
# ══════════════════════════════════════════════════════════════════════════════

## R1: HINT_OBSERVE is queued when all prerequisites are met.
func test_r1_recon_fires_observe_hint() -> bool:
	var parts: Array       = _make_observe_ready()
	var mgr: Node          = parts[0]
	var banner: MockBanner = parts[1]
	mgr._on_recon_action("Observed the market stall", true)
	return (
		mgr._observe_fired == true and
		banner.queued_hints.has(_GuidedDay2Mgr.HINT_OBSERVE)
	)


## R2: a successful Observe deactivates the manager (_active = false).
func test_r2_recon_sets_active_false() -> bool:
	var parts: Array = _make_observe_ready()
	var mgr: Node    = parts[0]
	mgr._on_recon_action("Observed a citizen", true)
	return mgr._active == false


## R3: success = false: nothing fires even if every other condition is met.
func test_r3_recon_suppressed_on_failure() -> bool:
	var parts: Array       = _make_observe_ready()
	var mgr: Node          = parts[0]
	var banner: MockBanner = parts[1]
	mgr._on_recon_action("Observed the square", false)
	return (
		mgr._observe_fired == false and
		banner.queued_hints.is_empty()
	)


## R4: message prefix "Eavesdropped" does not satisfy the "Observed" check.
func test_r4_recon_suppressed_wrong_prefix() -> bool:
	var parts: Array       = _make_observe_ready()
	var mgr: Node          = parts[0]
	var banner: MockBanner = parts[1]
	mgr._on_recon_action("Eavesdropped at the tavern", true)
	return (
		mgr._observe_fired == false and
		banner.queued_hints.is_empty()
	)


## R5: recon action cannot advance the sequence before day 2 arrives.
func test_r5_recon_suppressed_before_day2() -> bool:
	var mgr    := _GuidedDay2Mgr.new()
	var banner := MockBanner.new()
	mgr._tutorial_banner = banner
	mgr._active          = true
	mgr._dawn_fired      = true
	mgr._journal_fired   = true
	# _on_day2 left false
	mgr._on_recon_action("Observed the alley", true)
	return (
		mgr._observe_fired == false and
		banner.queued_hints.is_empty()
	)


## R6: journal hint must have fired before the observe hint can trigger.
func test_r6_recon_suppressed_before_journal_fired() -> bool:
	var mgr    := _GuidedDay2Mgr.new()
	var banner := MockBanner.new()
	mgr._tutorial_banner = banner
	mgr._active          = true
	mgr._on_day2         = true
	mgr._dawn_fired      = true
	# _journal_fired left false
	mgr._on_recon_action("Observed the harbour", true)
	return (
		mgr._observe_fired == false and
		banner.queued_hints.is_empty()
	)


## R7: handler is idempotent — second action after _observe_fired must not re-queue.
func test_r7_recon_suppressed_when_already_fired() -> bool:
	var parts: Array       = _make_observe_ready()
	var mgr: Node          = parts[0]
	var banner: MockBanner = parts[1]
	mgr._observe_fired = true   # pre-mark as already fired
	mgr._on_recon_action("Observed the ruins", true)
	return banner.queued_hints.is_empty()
