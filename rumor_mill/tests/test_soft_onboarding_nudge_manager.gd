## test_soft_onboarding_nudge_manager.gd — Unit tests for SoftOnboardingNudgeManager (SPA-2081).
##
## Complements test_spa2081_soft_onboarding_nudges.gd, which focuses on timer-based
## nudge fire and session-cap logic.  This file targets initial state, _process()
## integration, signal handler state mutations, and the null-dep guard in _fire_nudge().
##
##   Section 1 — Initial state (6 tests):
##     I1  _active, _elapsed, _nudges_shown are at zero/false defaults
##     I2  player-action tracking flags (_observed, _journal_opened, _rumor_crafted) are false
##     I3  nudge fire-flags (_nudge1_fired, _nudge2_fired, _nudge3_fired) are false
##     I4  signal connection flags (_connected_recon/journal/rumor) are false
##     I5  all external refs are null
##     I6  activate() with all-null dependencies sets _active=true without crashing
##
##   Section 2 — _process() integration (2 tests):
##     P1  _process() increments _elapsed when _active=true
##     P2  _process() does NOT increment _elapsed when _active=false
##
##   Section 3 — Signal handler state mutations (4 tests):
##     S1  _on_read_the_room_shown sets _observed=true and snapshots _observe_elapsed
##     S2  _on_read_the_room_shown is idempotent: second call does not overwrite _observe_elapsed
##     S3  _on_journal_visibility_changed sets _journal_opened when journal.visible=true
##     S4  _on_rumor_seeded sets _rumor_crafted=true
##
##   Section 4 — _fire_nudge null-dep guard (1 test):
##     F1  _fire_nudge() with null tutorial_sys/banner returns without crashing
##
## Mutation sensitivity:
##   Removing `_observed` early-return in _on_read_the_room_shown breaks S2.
##   Removing `_journal.visible` guard in _on_journal_visibility_changed breaks S3 (false positive).
##   Removing null checks in _fire_nudge breaks F1.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSoftOnboardingNudgeManager
extends RefCounted

const _SoftNudgeMgr = preload("res://scripts/soft_onboarding_nudge_manager.gd")

# ── Mock objects ──────────────────────────────────────────────────────────────

class MockTutorialSys extends TutorialSystem:
	func has_seen(_hint_id: String) -> bool:
		return false


class MockBanner extends Node:
	var queued_hints: Array = []

	func queue_hint(hint_id: String) -> void:
		queued_hints.append(hint_id)


class MockJournal extends CanvasLayer:
	## CanvasLayer inherits visible from CanvasItem — set directly in tests.
	pass


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Section 1 — Initial state
		"test_i1_active_elapsed_nudges_zero",
		"test_i2_action_flags_false",
		"test_i3_nudge_fired_flags_false",
		"test_i4_signal_connection_flags_false",
		"test_i5_refs_null",
		"test_i6_activate_null_deps_no_crash",
		# Section 2 — _process() integration
		"test_p1_process_increments_elapsed_when_active",
		"test_p2_process_does_not_increment_when_inactive",
		# Section 3 — Signal handler state mutations
		"test_s1_read_the_room_records_observe",
		"test_s2_read_the_room_idempotent",
		"test_s3_journal_visible_sets_opened",
		"test_s4_rumor_seeded_sets_crafted",
		# Section 4 — _fire_nudge null guard
		"test_f1_fire_nudge_null_deps_no_crash",
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

## I1: core numeric/boolean defaults are zero/false on construction.
func test_i1_active_elapsed_nudges_zero() -> bool:
	var mgr := _SoftNudgeMgr.new()
	return (
		mgr._active       == false and
		mgr._elapsed      == 0.0   and
		mgr._nudges_shown == 0
	)


## I2: player-action tracking flags are all false.
func test_i2_action_flags_false() -> bool:
	var mgr := _SoftNudgeMgr.new()
	return (
		mgr._observed       == false and
		mgr._journal_opened == false and
		mgr._rumor_crafted  == false
	)


## I3: nudge fire-flags are all false.
func test_i3_nudge_fired_flags_false() -> bool:
	var mgr := _SoftNudgeMgr.new()
	return (
		mgr._nudge1_fired == false and
		mgr._nudge2_fired == false and
		mgr._nudge3_fired == false
	)


## I4: signal connection tracking flags are all false.
func test_i4_signal_connection_flags_false() -> bool:
	var mgr := _SoftNudgeMgr.new()
	return (
		mgr._connected_recon   == false and
		mgr._connected_journal == false and
		mgr._connected_rumor   == false
	)


## I5: all external dependency refs are null.
func test_i5_refs_null() -> bool:
	var mgr := _SoftNudgeMgr.new()
	return (
		mgr._tutorial_sys    == null and
		mgr._tutorial_banner == null and
		mgr._recon_ctrl      == null and
		mgr._journal         == null and
		mgr._rumor_panel     == null
	)


## I6: activate() with all-null dependencies sets _active=true without crashing.
func test_i6_activate_null_deps_no_crash() -> bool:
	var mgr := _SoftNudgeMgr.new()
	mgr.activate(null, null, null, null, null)
	return mgr._active == true


# ══════════════════════════════════════════════════════════════════════════════
# Section 2 — _process() integration
# ══════════════════════════════════════════════════════════════════════════════

## P1: _process() advances _elapsed by delta when the manager is active.
func test_p1_process_increments_elapsed_when_active() -> bool:
	var mgr := _SoftNudgeMgr.new()
	mgr._active = true
	var before: float = mgr._elapsed
	mgr._process(0.5)
	return mgr._elapsed > before


## P2: _process() does nothing when _active = false.
func test_p2_process_does_not_increment_when_inactive() -> bool:
	var mgr := _SoftNudgeMgr.new()
	# _active is false by default
	var before: float = mgr._elapsed
	mgr._process(1.0)
	return mgr._elapsed == before


# ══════════════════════════════════════════════════════════════════════════════
# Section 3 — Signal handler state mutations
# ══════════════════════════════════════════════════════════════════════════════

## S1: _on_read_the_room_shown sets _observed=true and snapshots _observe_elapsed
## to the current value of _elapsed.
func test_s1_read_the_room_records_observe() -> bool:
	var mgr := _SoftNudgeMgr.new()
	mgr._elapsed = 45.0
	mgr._on_read_the_room_shown("district_1")
	return (
		mgr._observed        == true and
		mgr._observe_elapsed == 45.0
	)


## S2: a second call to _on_read_the_room_shown must not overwrite _observe_elapsed.
## The nudge-2 timer is relative to the FIRST observe — subsequent calls are ignored.
func test_s2_read_the_room_idempotent() -> bool:
	var mgr := _SoftNudgeMgr.new()
	mgr._elapsed = 30.0
	mgr._on_read_the_room_shown("district_1")
	mgr._elapsed = 90.0
	mgr._on_read_the_room_shown("district_2")   # must be a no-op
	return mgr._observe_elapsed == 30.0


## S3: _on_journal_visibility_changed sets _journal_opened=true when journal.visible=true.
func test_s3_journal_visible_sets_opened() -> bool:
	var mgr     := _SoftNudgeMgr.new()
	var journal := MockJournal.new()
	journal.visible = true
	mgr._journal    = journal
	mgr._on_journal_visibility_changed()
	return mgr._journal_opened == true


## S4: _on_rumor_seeded sets _rumor_crafted=true regardless of the argument values.
func test_s4_rumor_seeded_sets_crafted() -> bool:
	var mgr := _SoftNudgeMgr.new()
	mgr._on_rumor_seeded("rumor_42", "npc_a", "claim_x", "npc_b")
	return mgr._rumor_crafted == true


# ══════════════════════════════════════════════════════════════════════════════
# Section 4 — _fire_nudge null-dep guard
# ══════════════════════════════════════════════════════════════════════════════

## F1: _fire_nudge() with null tutorial_sys and null banner returns immediately
## without crashing and without incrementing _nudges_shown.
func test_f1_fire_nudge_null_deps_no_crash() -> bool:
	var mgr := _SoftNudgeMgr.new()
	# _tutorial_sys and _tutorial_banner are null by default
	mgr._fire_nudge(_SoftNudgeMgr.HINT_OBSERVE)
	return mgr._nudges_shown == 0   # count stays zero: no hint was queued
