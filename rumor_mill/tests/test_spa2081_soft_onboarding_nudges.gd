## test_spa2081_soft_onboarding_nudges.gd — Regression tests for SPA-2081.
##
## Covers SoftOnboardingNudgeManager: timer-based hint system for
## players who skipped the tutorial.  Tests drive the manager's internal
## state directly to avoid scene-tree dependencies.
##
##   Section 1 — Activation gating (2 tests):
##     A1  fresh manager is not active before activate() is called
##     A2  manager becomes active after activate() is called
##
##   Section 2 — Nudge 1: Observe (3 tests):
##     N1  fires after 90 s when no Observe action performed
##     N2  suppressed when player already observed before 90 s elapsed
##     N3  does not re-fire if already marked fired
##
##   Section 3 — Nudge 2: Journal (3 tests):
##     N4  fires 60 s after first Observe when journal not yet opened
##     N5  suppressed when journal opened before the 60 s timer expires
##     N6  skipped when nudge 1 already fired (player never observed)
##
##   Section 4 — Nudge 3: Rumor Panel (2 tests):
##     N7  fires after 120 s when no rumor crafted
##     N8  suppressed when rumor crafted before 120 s elapsed
##
##   Section 5 — Session cap (2 tests):
##     C1  _active becomes false once _nudges_shown reaches MAX_NUDGES
##     C2  no nudge banner call is queued once cap is already reached
##
##   Section 6 — Dismissal / seen guard (1 test):
##     D1  _fire_nudge skips queue_hint if tutorial_sys.has_seen returns true
##
## Mutation sensitivity:
##   Removing the `not _nudge1_fired` guard in Nudge-1 branch breaks N1/N3.
##   Removing `not _observed` guard in Nudge-1 branch breaks N2.
##   Removing `not _nudge1_fired` gate in Nudge-2 branch breaks N6.
##   Removing `not _journal_opened` guard breaks N5.
##   Removing `not _rumor_crafted` guard breaks N8.
##   Removing the cap early-return in _check_nudges() breaks C1/C2.
##   Removing the has_seen() guard in _fire_nudge() breaks D1.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpa2081SoftOnboardingNudges
extends RefCounted

const _SoftNudgeMgr = preload("res://scripts/soft_onboarding_nudge_manager.gd")

# ── Mock objects ──────────────────────────────────────────────────────────────

class MockTutorialSys extends TutorialSystem:
	## Set to true to simulate every hint already having been seen/dismissed.
	var force_seen: bool = false

	func has_seen(hint_id: String) -> bool:
		return force_seen


class MockBanner extends Node:
	var queued_hints: Array = []

	func queue_hint(hint_id: String) -> void:
		queued_hints.append(hint_id)


# ── Helpers ───────────────────────────────────────────────────────────────────

## Returns [mgr, mock_sys, mock_banner] with the manager pre-wired and active
## at the given elapsed time.  No scene-tree signals are connected.
func _make_primed(elapsed: float) -> Array:
	var mgr    := _SoftNudgeMgr.new()
	var sys    := MockTutorialSys.new()
	var banner := MockBanner.new()
	mgr._tutorial_sys    = sys
	mgr._tutorial_banner = banner
	mgr._active          = true
	mgr._elapsed         = elapsed
	return [mgr, sys, banner]


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Section 1 — Activation gating
		"test_a1_not_active_before_activate",
		"test_a2_active_after_activate",
		# Section 2 — Nudge 1: Observe
		"test_n1_nudge1_fires_after_90s_without_observe",
		"test_n2_nudge1_suppressed_when_observed",
		"test_n3_nudge1_does_not_refire",
		# Section 3 — Nudge 2: Journal
		"test_n4_nudge2_fires_60s_after_observe",
		"test_n5_nudge2_suppressed_when_journal_opened",
		"test_n6_nudge2_skipped_when_nudge1_fired",
		# Section 4 — Nudge 3: Rumor Panel
		"test_n7_nudge3_fires_after_120s_without_rumor",
		"test_n8_nudge3_suppressed_when_rumor_crafted",
		# Section 5 — Session cap
		"test_c1_active_becomes_false_at_cap",
		"test_c2_nudge_skipped_when_cap_reached",
		# Section 6 — Dismissal / seen guard
		"test_d1_fire_nudge_skips_when_already_seen",
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
# Section 1 — Activation gating
# ══════════════════════════════════════════════════════════════════════════════

## A1: A freshly constructed manager must not be active.
## Mirrors: manager does not activate on normal tutorial completion —
## only tutorial_skipped → activate() flips _active.
func test_a1_not_active_before_activate() -> bool:
	var mgr := _SoftNudgeMgr.new()
	return mgr._active == false


## A2: Calling activate() sets _active = true regardless of null deps.
## This is the exact sequence tutorial_wiring uses on tutorial_skipped.
func test_a2_active_after_activate() -> bool:
	var mgr := _SoftNudgeMgr.new()
	mgr.activate(null, null, null, null, null)
	return mgr._active == true


# ══════════════════════════════════════════════════════════════════════════════
# Section 2 — Nudge 1: Observe
# ══════════════════════════════════════════════════════════════════════════════

## N1: nudge 1 fires after elapsed >= 90 s with no observe action performed.
func test_n1_nudge1_fires_after_90s_without_observe() -> bool:
	var parts: Array  = _make_primed(91.0)
	var mgr: RefCounted = parts[0]
	var banner: MockBanner              = parts[2]
	mgr._check_nudges()
	return mgr._nudge1_fired \
		and banner.queued_hints.has(_SoftNudgeMgr.HINT_OBSERVE)


## N2: nudge 1 is suppressed when the player has already observed (before 90 s).
func test_n2_nudge1_suppressed_when_observed() -> bool:
	var parts: Array  = _make_primed(91.0)
	var mgr: RefCounted = parts[0]
	var banner: MockBanner              = parts[2]
	mgr._observed        = true
	mgr._observe_elapsed = 10.0    # observed well before the 90 s threshold
	mgr._check_nudges()
	return not mgr._nudge1_fired \
		and not banner.queued_hints.has(_SoftNudgeMgr.HINT_OBSERVE)


## N3: nudge 1 does not re-fire if _nudge1_fired is already true.
## Elapsed is set just above the trigger threshold (91 s) but below nudge 3
## threshold (120 s) and _observed stays false, isolating nudge 1 exclusively.
func test_n3_nudge1_does_not_refire() -> bool:
	var parts: Array  = _make_primed(91.0)
	var mgr: RefCounted = parts[0]
	var banner: MockBanner              = parts[2]
	mgr._nudge1_fired = true
	mgr._check_nudges()
	return not banner.queued_hints.has(_SoftNudgeMgr.HINT_OBSERVE)


# ══════════════════════════════════════════════════════════════════════════════
# Section 3 — Nudge 2: Journal
# ══════════════════════════════════════════════════════════════════════════════

## N4: nudge 2 fires when the player observed, journal is still closed, and
## >= 60 s have elapsed since first Observe.
## Elapsed = 80 s; observed at t=10 → 70 s since observe (>= 60 s).
## Nudge 1 is skipped because _observed = true; nudge 3 needs 120 s.
func test_n4_nudge2_fires_60s_after_observe() -> bool:
	var parts: Array  = _make_primed(80.0)
	var mgr: RefCounted = parts[0]
	var banner: MockBanner              = parts[2]
	mgr._observed        = true
	mgr._observe_elapsed = 10.0
	mgr._check_nudges()
	return mgr._nudge2_fired \
		and banner.queued_hints.has(_SoftNudgeMgr.HINT_JOURNAL)


## N5: nudge 2 is suppressed when the journal was already opened.
func test_n5_nudge2_suppressed_when_journal_opened() -> bool:
	var parts: Array  = _make_primed(80.0)
	var mgr: RefCounted = parts[0]
	var banner: MockBanner              = parts[2]
	mgr._observed        = true
	mgr._observe_elapsed = 10.0
	mgr._journal_opened  = true
	mgr._check_nudges()
	return not mgr._nudge2_fired \
		and not banner.queued_hints.has(_SoftNudgeMgr.HINT_JOURNAL)


## N6: nudge 2 is skipped when nudge 1 already fired.
## The spec explicitly blocks nudge 2 if nudge 1 was sent (player was still
## being guided toward Observe first; Journal nudge would be misleading).
func test_n6_nudge2_skipped_when_nudge1_fired() -> bool:
	var parts: Array  = _make_primed(130.0)
	var mgr: RefCounted = parts[0]
	var banner: MockBanner              = parts[2]
	# Nudge 1 already fired; player later observed but journal still not opened.
	mgr._nudge1_fired    = true
	mgr._nudges_shown    = 1
	mgr._observed        = true
	mgr._observe_elapsed = 65.0   # 130 - 65 = 65 s since observe (>= 60 s)
	mgr._check_nudges()
	return not mgr._nudge2_fired \
		and not banner.queued_hints.has(_SoftNudgeMgr.HINT_JOURNAL)


# ══════════════════════════════════════════════════════════════════════════════
# Section 4 — Nudge 3: Rumor Panel
# ══════════════════════════════════════════════════════════════════════════════

## N7: nudge 3 fires after elapsed >= 120 s when no rumor has been crafted.
## Nudges 1 and 2 are pre-marked fired to isolate nudge 3.
func test_n7_nudge3_fires_after_120s_without_rumor() -> bool:
	var parts: Array  = _make_primed(121.0)
	var mgr: RefCounted = parts[0]
	var banner: MockBanner              = parts[2]
	mgr._nudge1_fired = true
	mgr._nudge2_fired = true
	mgr._nudges_shown = 2
	mgr._check_nudges()
	return mgr._nudge3_fired \
		and banner.queued_hints.has(_SoftNudgeMgr.HINT_RUMOR)


## N8: nudge 3 is suppressed when a rumor was already crafted.
func test_n8_nudge3_suppressed_when_rumor_crafted() -> bool:
	var parts: Array  = _make_primed(121.0)
	var mgr: RefCounted = parts[0]
	var banner: MockBanner              = parts[2]
	mgr._nudge1_fired  = true
	mgr._nudge2_fired  = true
	mgr._nudges_shown  = 2
	mgr._rumor_crafted = true
	mgr._check_nudges()
	return not mgr._nudge3_fired \
		and not banner.queued_hints.has(_SoftNudgeMgr.HINT_RUMOR)


# ══════════════════════════════════════════════════════════════════════════════
# Section 5 — Session cap
# ══════════════════════════════════════════════════════════════════════════════

## C1: _active becomes false immediately when _nudges_shown >= MAX_NUDGES at
## the top of _check_nudges(), enforcing the 3-nudge session cap.
func test_c1_active_becomes_false_at_cap() -> bool:
	var parts: Array  = _make_primed(200.0)
	var mgr: RefCounted = parts[0]
	mgr._nudges_shown = _SoftNudgeMgr.MAX_NUDGES
	mgr._check_nudges()
	return mgr._active == false


## C2: no hint is queued once _nudges_shown already equals MAX_NUDGES.
func test_c2_nudge_skipped_when_cap_reached() -> bool:
	var parts: Array  = _make_primed(200.0)
	var mgr: RefCounted = parts[0]
	var banner: MockBanner              = parts[2]
	mgr._nudges_shown = _SoftNudgeMgr.MAX_NUDGES
	mgr._check_nudges()
	return banner.queued_hints.is_empty()


# ══════════════════════════════════════════════════════════════════════════════
# Section 6 — Dismissal / seen guard
# ══════════════════════════════════════════════════════════════════════════════

## D1: _fire_nudge skips queue_hint when tutorial_sys.has_seen returns true,
## i.e. the player previously dismissed the hint (banner marks it seen on close).
func test_d1_fire_nudge_skips_when_already_seen() -> bool:
	var parts: Array  = _make_primed(91.0)
	var mgr: RefCounted = parts[0]
	var sys: MockTutorialSys            = parts[1]
	var banner: MockBanner              = parts[2]
	sys.force_seen = true   # every hint ID is already seen
	mgr._check_nudges()
	# Nudge-1 condition is satisfied by elapsed, but the has_seen guard must veto it.
	return banner.queued_hints.is_empty() and mgr._nudges_shown == 0
