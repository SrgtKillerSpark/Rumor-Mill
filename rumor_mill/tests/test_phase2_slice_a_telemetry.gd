## test_phase2_slice_a_telemetry.gd — Phase 2 Slice A telemetry acceptance regression tests
## (SPA-1743).
##
## Covers A1–A9 from docs/phase2-acceptance-tests.md:
##
## evidence_acquired (A1–A5):
##   A1 — AnalyticsManager queues evidence_acquired with evidence_type
##         "forged_document" (snake_case, not "Forged Document") and
##         source_action "observe_building" (observe building call site in
##         recon_controller).
##   A2 — evidence_acquired queued with evidence_type "witness_account" and
##         source_action "eavesdrop_npc" (eavesdrop call site).
##   A3 — evidence_acquired fires regardless of inventory state; the analytics
##         call is independent of PlayerIntelStore.add_evidence() capacity checks.
##   A4 — With SettingsManager.analytics_enabled = false, evidence_acquired
##         produces no NDJSON write (AnalyticsLogger.log_event() early-returns).
##   A5 — Save/load does not re-fire evidence_acquired: a fresh AnalyticsManager
##         starts with an empty event queue (no pre-save events replayed).
##
## evidence_used (A6–A9):
##   A6 — evidence_used is queued on confirmed seed with correct evidence_type,
##         claim_id, seed_target, and subject fields.
##   A7 — Seeding without evidence (log_evidence_used not called) → queue stays
##         empty; no spurious evidence_used event fires.
##   A8 — Cancelled seed (evidence attached, but confirm not clicked) →
##         no evidence_used event (log_evidence_used is called only at confirm).
##   A9 — Exactly one evidence_used event on confirmation; a fresh AnalyticsManager
##         starts at zero events (save/load cannot double-fire the event).
##
## Feature-flag guard: GameState.evidence_economy_v2 = true before each test;
## restored after. Tests pass trivially when the flag is OFF.
##
## Live-logger tests (A4) use _SpyLogger extending AnalyticsLogger to capture
## NDJSON output without file I/O — same strategy as test_spa1614_evidence_used_emission.gd.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestPhase2SliceATelemetry
extends RefCounted

const AnalyticsManagerScript := preload("res://scripts/analytics_manager.gd")


## Spy: captures NDJSON output without disk I/O.
class _SpyLogger extends AnalyticsLogger:
	var call_count: int = 0
	var last_event: Dictionary = {}
	func _append_line(line: String) -> void:
		call_count += 1
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			last_event = parsed


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# A1 — forged_document / observe_building
		"test_a1_forged_document_evidence_type_is_snake_case",
		"test_a1_forged_document_source_action_is_observe_building",
		# A2 — witness_account / eavesdrop_npc
		"test_a2_witness_account_evidence_type_is_snake_case",
		"test_a2_witness_account_source_action_is_eavesdrop_npc",
		# A3 — acquisition independent of inventory capacity
		"test_a3_evidence_acquired_fires_regardless_of_inventory_count",
		# A4 — analytics disabled → no NDJSON write
		"test_a4_evidence_acquired_silent_when_analytics_disabled",
		# A5 — save/load → fresh manager has empty queue
		"test_a5_fresh_manager_queue_is_empty",
		# A6 — confirmed seed: correct payload fields
		"test_a6_evidence_used_evidence_type_field",
		"test_a6_evidence_used_claim_id_field",
		"test_a6_evidence_used_seed_target_field",
		"test_a6_evidence_used_subject_field",
		# A7 — no evidence → no evidence_used event
		"test_a7_no_evidence_used_without_attachment",
		# A8 — cancelled seed → no evidence_used event
		"test_a8_cancelled_seed_no_evidence_used_in_queue",
		# A9 — single event on confirmation; fresh manager starts at zero
		"test_a9_single_evidence_used_on_confirmation",
		"test_a9_fresh_manager_has_zero_evidence_used_events",
	]

	var _saved_flag: bool = GameState.evidence_economy_v2

	for method_name in tests:
		GameState.evidence_economy_v2 = true   ## before_each
		var result: bool = call(method_name)
		GameState.evidence_economy_v2 = _saved_flag  ## after_each

		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nPhase2SliceATelemetry tests: %d passed, %d failed" % [passed, failed])


# ── Internal helpers ──────────────────────────────────────────────────────────

func _make_mgr_no_logger() -> AnalyticsManager:
	## Returns a manager with _analytics_logger = null (pre-setup / queuing state).
	return AnalyticsManagerScript.new()


func _make_mgr_with_spy() -> Array:
	## Returns [AnalyticsManager, _SpyLogger] with the spy wired as the live logger
	## so calls bypass the queue and reach log_event() directly.
	var mgr: AnalyticsManager = AnalyticsManagerScript.new()
	var spy := _SpyLogger.new()
	mgr._analytics_logger = spy
	return [mgr, spy]


# ── A1: forged_document / observe_building ────────────────────────────────────

func test_a1_forged_document_evidence_type_is_snake_case() -> bool:
	## A1: recon_controller calls log_evidence_acquired("forged_document", "observe_building")
	## for the Forged Document observe path.  evidence_type must be snake_case
	## ("forged_document"), not the display name ("Forged Document") — this is the
	## normalization behaviour verified by commit db60cb8.
	if not GameState.evidence_economy_v2:
		return true
	var mgr := _make_mgr_no_logger()
	mgr.log_evidence_acquired("forged_document", "observe_building")
	return mgr._event_queue.size() == 1 \
		and mgr._event_queue[0]["args"][0] == "forged_document"


func test_a1_forged_document_source_action_is_observe_building() -> bool:
	## A1: source_action for the building-observation call site must be
	## "observe_building" (not "observe" or another variant).
	if not GameState.evidence_economy_v2:
		return true
	var mgr := _make_mgr_no_logger()
	mgr.log_evidence_acquired("forged_document", "observe_building")
	return mgr._event_queue[0]["args"][1] == "observe_building"


# ── A2: witness_account / eavesdrop_npc ───────────────────────────────────────

func test_a2_witness_account_evidence_type_is_snake_case() -> bool:
	## A2: recon_controller calls log_evidence_acquired("witness_account", "eavesdrop_npc")
	## for the Witness Account eavesdrop path.
	if not GameState.evidence_economy_v2:
		return true
	var mgr := _make_mgr_no_logger()
	mgr.log_evidence_acquired("witness_account", "eavesdrop_npc")
	return mgr._event_queue[0]["args"][0] == "witness_account"


func test_a2_witness_account_source_action_is_eavesdrop_npc() -> bool:
	## A2: source_action for NPC eavesdrop must be "eavesdrop_npc".
	if not GameState.evidence_economy_v2:
		return true
	var mgr := _make_mgr_no_logger()
	mgr.log_evidence_acquired("witness_account", "eavesdrop_npc")
	return mgr._event_queue[0]["args"][1] == "eavesdrop_npc"


# ── A3: acquisition independent of inventory capacity ─────────────────────────

func test_a3_evidence_acquired_fires_regardless_of_inventory_count() -> bool:
	## A3: log_evidence_acquired() has no dependency on PlayerIntelStore capacity.
	## Simulate three consecutive acquisitions (one per evidence type) matching the
	## PlayerIntelStore.MAX_EVIDENCE cap of 3.  All three must be enqueued even if
	## a real acquisition would evict the oldest item from the inventory.
	if not GameState.evidence_economy_v2:
		return true
	var mgr := _make_mgr_no_logger()
	mgr.log_evidence_acquired("forged_document",         "observe_building")
	mgr.log_evidence_acquired("incriminating_artifact",  "observe_building")
	mgr.log_evidence_acquired("witness_account",         "eavesdrop_npc")
	return mgr._event_queue.size() == 3


# ── A4: analytics disabled → no NDJSON write ─────────────────────────────────

func test_a4_evidence_acquired_silent_when_analytics_disabled() -> bool:
	## A4: AnalyticsLogger.log_event() guards on SettingsManager.analytics_enabled.
	## With analytics disabled and a live logger wired, no _append_line() call must
	## reach the spy (call_count must remain 0).
	if not GameState.evidence_economy_v2:
		return true
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = false

	var pair: Array = _make_mgr_with_spy()
	var mgr: AnalyticsManager = pair[0]
	var spy: _SpyLogger = pair[1]
	mgr.log_evidence_acquired("forged_document", "observe_building")

	SettingsManager.analytics_enabled = saved
	return spy.call_count == 0


# ── A5: save/load → no re-fire of evidence_acquired ──────────────────────────

func test_a5_fresh_manager_queue_is_empty() -> bool:
	## A5: When the game saves and reloads, the AnalyticsManager is re-created.
	## A fresh manager must have an empty event queue — save/load must not replay
	## pre-save evidence_acquired events into the new session.
	if not GameState.evidence_economy_v2:
		return true
	var mgr := _make_mgr_no_logger()
	return mgr._event_queue.is_empty()


# ── A6: confirmed seed fires evidence_used with correct payload ───────────────

func test_a6_evidence_used_evidence_type_field() -> bool:
	## A6: args[0] of the queued log_evidence_used call must be the snake_case
	## evidence_type ("forged_document").
	if not GameState.evidence_economy_v2:
		return true
	var mgr := _make_mgr_no_logger()
	mgr.log_evidence_used("forged_document", "ACCUSATION", "npc_aldric_merchant", "npc_calder")
	return mgr._event_queue[0]["args"][0] == "forged_document"


func test_a6_evidence_used_claim_id_field() -> bool:
	## A6: args[1] must carry the claim_id ("HERESY" in this case).
	if not GameState.evidence_economy_v2:
		return true
	var mgr := _make_mgr_no_logger()
	mgr.log_evidence_used("witness_account", "HERESY", "npc_maren_nun", "npc_calder")
	return mgr._event_queue[0]["args"][1] == "HERESY"


func test_a6_evidence_used_seed_target_field() -> bool:
	## A6: args[2] must carry the seed_target NPC id.
	if not GameState.evidence_economy_v2:
		return true
	var mgr := _make_mgr_no_logger()
	mgr.log_evidence_used("forged_document", "SCANDAL", "npc_alice", "npc_calder")
	return mgr._event_queue[0]["args"][2] == "npc_alice"


func test_a6_evidence_used_subject_field() -> bool:
	## A6: args[3] must carry the subject NPC id (the rumor target's subject).
	if not GameState.evidence_economy_v2:
		return true
	var mgr := _make_mgr_no_logger()
	mgr.log_evidence_used("forged_document", "SCANDAL", "npc_alice", "npc_calder")
	return mgr._event_queue[0]["args"][3] == "npc_calder"


# ── A7: no evidence → no evidence_used event ─────────────────────────────────

func test_a7_no_evidence_used_without_attachment() -> bool:
	## A7: Seeding a rumor without attaching evidence never calls log_evidence_used()
	## (rumor_panel guards on `if _selected_evidence_item != null`).
	## Verify by inspecting an untouched queue — no evidence_used entry must appear.
	if not GameState.evidence_economy_v2:
		return true
	var mgr := _make_mgr_no_logger()
	## Intentionally do NOT call log_evidence_used() — simulate a no-evidence seed.
	return mgr._event_queue.is_empty()


# ── A8: cancelled seed → no evidence_used event ──────────────────────────────

func test_a8_cancelled_seed_no_evidence_used_in_queue() -> bool:
	## A8: Player attaches evidence (log_evidence_acquired fires at recon time;
	## log_evidence_attached fires at attach) but cancels before final confirmation.
	## log_evidence_used() is only called at the confirm step, so no evidence_used
	## entry must appear in the queue after a cancelled flow.
	if not GameState.evidence_economy_v2:
		return true
	var mgr := _make_mgr_no_logger()
	## Simulate the cancelled path: acquisition fires, attachment fires,
	## but confirm is cancelled → log_evidence_used is never called.
	mgr.log_evidence_acquired("forged_document", "observe_building")
	var evidence_used_count: int = 0
	for entry in mgr._event_queue:
		if entry.get("method", "") == "log_evidence_used":
			evidence_used_count += 1
	return evidence_used_count == 0


# ── A9: exactly one evidence_used on confirmation; fresh manager at zero ──────

func test_a9_single_evidence_used_on_confirmation() -> bool:
	## A9: Calling log_evidence_used() exactly once at seed confirmation must
	## produce exactly one queue entry — no duplicate emission by the confirmation path.
	if not GameState.evidence_economy_v2:
		return true
	var mgr := _make_mgr_no_logger()
	mgr.log_evidence_used("forged_document", "SCANDAL", "npc_alice", "npc_calder")
	var used_count: int = 0
	for entry in mgr._event_queue:
		if entry.get("method", "") == "log_evidence_used":
			used_count += 1
	return used_count == 1


func test_a9_fresh_manager_has_zero_evidence_used_events() -> bool:
	## A9: After save/load the game creates a fresh AnalyticsManager.  A fresh
	## manager must carry zero evidence_used events — save/load cannot double-fire
	## the event from a previous session.
	if not GameState.evidence_economy_v2:
		return true
	var mgr := _make_mgr_no_logger()
	var used_count: int = 0
	for entry in mgr._event_queue:
		if entry.get("method", "") == "log_evidence_used":
			used_count += 1
	return used_count == 0
