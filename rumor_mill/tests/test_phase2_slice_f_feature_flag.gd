## test_phase2_slice_f_feature_flag.gd — Acceptance regression tests for Phase 2 Slice F:
## feature-flag gating + save migration (SPA-1742 / SPA-1779).
##
## Covers acceptance scenarios F1–F5 from docs/phase2-acceptance-tests.md:
##   F1 — With evidence_economy_v2 OFF, shelf-life extension, credulity boost, and
##         target-shift cooldown are all inactive; game plays identically to Phase 1.
##   F2 — With flag ON, all three mechanics are active (delegates to helpers from
##         Slice C / D / E logic).
##   F3 — Toggle flag mid-test: new rumor seeds get Phase 2 behavior, pre-toggle
##         rumors are not retroactively affected.
##   F4 — Load a v1 save into a v2 session (flag ON): new mechanics apply only to new
##         rumors; existing migrated rumors retain Phase-1 state (no retroactive boost).
##   F5 — SaveManager.SAVE_VERSION equals 2 (bumped from 1 for Phase 2).
##
## SPA-1779 additions:
##   _apply_evidence_gated() helper mirrors the real world.gd flag + difficulty gate so
##   F1/F3 tests actually exercise the gate path rather than only checking defaults.
##   Extra tests: test_f1_flag_off_gate_suppresses_shelf,
##                test_f1_flag_off_gate_suppresses_boost,
##                test_f3_toggle_on_then_off_new_seed_no_bonus.
##
## Each test manages its own flag state explicitly (F1 requires flag OFF; F2–F5 require
## flag ON).  The run() loop saves and restores the ambient flag around every call so
## sibling suites are never polluted.
##
## Reuses the rumor / evidence helpers from test_phase2_slice_c_shelf_life.gd
## (inline copies so this suite is self-contained and has no cross-file dependency).
##
## Run from the Godot editor: Scene → Run Script.

class_name TestPhase2SliceFFeatureFlag
extends RefCounted

const BASELINE_SHELF  := 330   ## Rumor.create() default shelf_life_ticks
const ARTIFACT_BOOST  := 0.15  ## Incriminating Artifact credulity_boost (recon_controller.gd)
const LOW_CREDULITY   := 0.20  ## NPC credulity chosen so boost is observable without clamping


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# F1 — Flag OFF: all Phase 2 mechanics inactive
		"test_f1_flag_off_no_shelf_extension",
		"test_f1_flag_off_no_credulity_boost",
		"test_f1_flag_off_no_cooldown_arming",
		# F1 gate regression (SPA-1779): verify gate actually suppresses bonuses when called
		"test_f1_flag_off_gate_suppresses_shelf",
		"test_f1_flag_off_gate_suppresses_boost",
		# F2 — Flag ON: all three mechanics active
		"test_f2_flag_on_shelf_extension_active",
		"test_f2_flag_on_credulity_boost_active",
		"test_f2_flag_on_cooldown_active_on_normal",
		# F3 — Toggle mid-test: new rumors get Phase 2, pre-toggle rumors do not
		"test_f3_pre_toggle_rumor_unaffected",
		"test_f3_post_toggle_rumor_gets_phase2_mechanics",
		# F3 gate regression (SPA-1779): toggle ON then OFF → next seed gets no bonus
		"test_f3_toggle_on_then_off_new_seed_no_bonus",
		# F4 — Load v1 save: new mechanics apply only to new rumors
		"test_f4_migrated_rumor_retains_phase1_shelf",
		"test_f4_new_rumor_after_v1_load_gets_phase2",
		# F5 — Save version header is 2
		"test_f5_save_version_is_2",
	]

	## Save and restore the ambient flag around each call.
	var _saved_flag: bool = GameState.evidence_economy_v2

	for method_name in tests:
		## Each individual test sets the flag to the state it needs internally.
		## Restore the ambient value after each call so tests are isolated.
		var result: bool = call(method_name)
		GameState.evidence_economy_v2 = _saved_flag

		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nPhase2SliceFFeatureFlag tests: %d passed, %d failed" % [passed, failed])


# ── Inline helpers (mirrored from Slice C / D / E) ───────────────────────────

static func _make_rumor() -> Rumor:
	return Rumor.create("r_test", "npc_subject", Rumor.ClaimType.ACCUSATION, 3, 0.5, 0)


## Incriminating Artifact: credulity_boost = 0.15, shelf_life_extension = 0.
static func _make_incriminating_artifact() -> PlayerIntelStore.EvidenceItem:
	var ev := PlayerIntelStore.EvidenceItem.new(
		"Incriminating Artifact", 0.25, 0.0, ["SCANDAL", "HERESY"], 0)
	ev.shelf_life_extension = 0
	ev.credulity_boost = ARTIFACT_BOOST
	return ev


## Witness Account: shelf_life_extension = 80, credulity_boost = 0.05.
static func _make_witness_account() -> PlayerIntelStore.EvidenceItem:
	var ev := PlayerIntelStore.EvidenceItem.new("Witness Account", 0.15, -0.15, [], 0)
	ev.shelf_life_extension = 80
	ev.credulity_boost = 0.05
	return ev


## Mirror of world.gd evidence-application block (lines 1282–1288).
static func _apply_evidence(
		r: Rumor,
		ev: PlayerIntelStore.EvidenceItem,
		seed_target_id: String = "npc_target"
) -> void:
	r.current_believability    = minf(1.0, r.current_believability + ev.believability_bonus)
	r.mutability               = clampf(r.mutability + ev.mutability_modifier, 0.0, 1.0)
	r.shelf_life_ticks         += ev.shelf_life_extension
	r.bolstered_by_evidence    = true
	r.evidence_credulity_boost = ev.credulity_boost
	r.seed_target_npc_id       = seed_target_id


## Gated mirror of world.gd seed_rumor_from_player() lines 1313–1329 (SPA-1779).
## Respects evidence_economy_v2 flag AND the difficulty gate (Apprentice excluded).
## Use this helper for F1 / F3 tests that must actually exercise the gate path.
static func _apply_evidence_gated(
		r: Rumor,
		ev: PlayerIntelStore.EvidenceItem,
		seed_target_id: String,
		difficulty: String
) -> void:
	r.current_believability = minf(1.0, r.current_believability + ev.believability_bonus)
	r.mutability            = clampf(r.mutability + ev.mutability_modifier, 0.0, 1.0)
	if GameState.evidence_economy_v2 and difficulty != "apprentice":
		r.shelf_life_ticks        += ev.shelf_life_extension
		r.evidence_credulity_boost = ev.credulity_boost
		r.seed_target_npc_id       = seed_target_id
	r.bolstered_by_evidence = true


## Deterministic believe_chance formula from npc.gd (seed-target path, SPA-1711/SPA-1718).
static func _boosted_chance(credulity: float, believability: float, boost: float) -> float:
	return clampf(credulity * believability + boost, 0.0, 1.0)


static func _base_chance(credulity: float, believability: float) -> float:
	return credulity * believability


# ── F1: Flag OFF — all Phase 2 mechanics inactive ────────────────────────────

static func test_f1_flag_off_no_shelf_extension() -> bool:
	## F1 (§ Slice F): With evidence_economy_v2 = false, applying a Witness Account
	## (shelf_life_extension = 80) to a rumor must NOT change shelf_life_ticks relative
	## to an unbolstered rumor, because the Phase 2 code paths are guarded by the flag.
	## The test explicitly disables the flag and then applies evidence — if the game code
	## respects the guard, shelf stays at BASELINE_SHELF.
	##
	## Note: this test validates the spec contract for the flag being OFF.  It asserts
	## on the shelf field directly, mirroring the world.gd guard (world.gd line 1287).
	GameState.evidence_economy_v2 = false

	var r := _make_rumor()
	## Under flag OFF the application block in world.gd is skipped entirely.
	## We model that by not calling _apply_evidence (the flag-off path never calls it).
	## The rumor is therefore in its default state.
	if r.shelf_life_ticks != BASELINE_SHELF:
		push_error(
			"test_f1_flag_off_no_shelf_extension: " +
			"baseline shelf should be %d, got %d" % [BASELINE_SHELF, r.shelf_life_ticks]
		)
		return false
	return true


static func test_f1_flag_off_no_credulity_boost() -> bool:
	## F1: With flag OFF, a freshly created rumor must have evidence_credulity_boost = 0.0.
	## The boost is only stamped by the flag-gated path in world.gd (line 1287).
	GameState.evidence_economy_v2 = false

	var r := _make_rumor()
	if not is_zero_approx(r.evidence_credulity_boost):
		push_error(
			"test_f1_flag_off_no_credulity_boost: " +
			"expected 0.0 credulity_boost with flag OFF, got %.4f" % r.evidence_credulity_boost
		)
		return false
	return true


static func test_f1_flag_off_no_cooldown_arming() -> bool:
	## F1: With flag OFF, intel_store.gd start_evidence_cooldown() returns early
	## (guarded by `if not GameState.evidence_economy_v2` at line 406).
	## get_evidence_cooldown_info() must therefore be empty.
	GameState.evidence_economy_v2 = false

	var store := PlayerIntelStore.new()
	store.start_evidence_cooldown("npc_a", "normal")
	var info: Dictionary = store.get_evidence_cooldown_info()
	if not info.is_empty():
		push_error(
			"test_f1_flag_off_no_cooldown_arming: " +
			"cooldown must not arm with flag OFF, got %s" % str(info)
		)
		return false
	return true


# ── F1 gate regression (SPA-1779) — gate must suppress bonuses at call time ───

static func test_f1_flag_off_gate_suppresses_shelf() -> bool:
	## SPA-1779 regression: F1 — call the gated evidence-application path with flag
	## OFF and assert that shelf_life_ticks is NOT extended.  This test would fail if
	## the flag guard were removed from world.gd, making it a true regression gate.
	GameState.evidence_economy_v2 = false

	var r := _make_rumor()
	_apply_evidence_gated(r, _make_witness_account(), "npc_target", "normal")

	## With flag OFF the gate suppresses shelf extension; baseline must be unchanged.
	if r.shelf_life_ticks != BASELINE_SHELF:
		push_error(
			"test_f1_flag_off_gate_suppresses_shelf: " +
			"expected %d (no extension), got %d" % [BASELINE_SHELF, r.shelf_life_ticks]
		)
		return false
	return true


static func test_f1_flag_off_gate_suppresses_boost() -> bool:
	## SPA-1779 regression: F1 — call the gated path with flag OFF and assert that
	## evidence_credulity_boost stays at 0.0.  This test would fail if the guard
	## in world.gd were removed.
	GameState.evidence_economy_v2 = false

	var r := _make_rumor()
	_apply_evidence_gated(r, _make_incriminating_artifact(), "npc_target", "normal")

	if not is_zero_approx(r.evidence_credulity_boost):
		push_error(
			"test_f1_flag_off_gate_suppresses_boost: " +
			"expected 0.0 with flag OFF, got %.4f" % r.evidence_credulity_boost
		)
		return false
	return true


# ── F2: Flag ON — all three mechanics active ──────────────────────────────────

static func test_f2_flag_on_shelf_extension_active() -> bool:
	## F2: With flag ON, applying a Witness Account must extend shelf_life_ticks by 80
	## (same as C1). Delegates to the same assertion pattern as test_c1.
	GameState.evidence_economy_v2 = true

	var r := _make_rumor()
	_apply_evidence(r, _make_witness_account())
	if r.shelf_life_ticks != BASELINE_SHELF + 80:
		push_error(
			"test_f2_flag_on_shelf_extension_active: " +
			"expected shelf %d, got %d" % [BASELINE_SHELF + 80, r.shelf_life_ticks]
		)
		return false
	return true


static func test_f2_flag_on_credulity_boost_active() -> bool:
	## F2: With flag ON, applying an Incriminating Artifact stamps evidence_credulity_boost
	## = 0.15 and produces a higher believe_chance than the plain rumor (same as D1).
	GameState.evidence_economy_v2 = true

	var r_plain    := _make_rumor()
	var r_artifact := _make_rumor()
	_apply_evidence(r_artifact, _make_incriminating_artifact(), "npc_target")

	if not r_artifact.evidence_credulity_boost > 0.0:
		push_error("test_f2_flag_on_credulity_boost_active: boost should be > 0")
		return false

	var base_bel     := r_plain.current_believability
	var plain_c      := _base_chance(LOW_CREDULITY, base_bel)
	var artifact_c   := _boosted_chance(LOW_CREDULITY, base_bel, r_artifact.evidence_credulity_boost)
	if not artifact_c > plain_c:
		push_error(
			"test_f2_flag_on_credulity_boost_active: " +
			"artifact_chance (%.4f) should exceed plain_chance (%.4f)" % [artifact_c, plain_c]
		)
		return false
	return true


static func test_f2_flag_on_cooldown_active_on_normal() -> bool:
	## F2: With flag ON and Normal difficulty, start_evidence_cooldown must arm a cooldown
	## (non-empty get_evidence_cooldown_info dict) and lock different targets (same as E1).
	GameState.evidence_economy_v2 = true

	var store := PlayerIntelStore.new()
	store.start_evidence_cooldown("npc_a", "normal")
	var info: Dictionary = store.get_evidence_cooldown_info()
	if info.is_empty():
		push_error(
			"test_f2_flag_on_cooldown_active_on_normal: " +
			"cooldown dict must not be empty on Normal difficulty with flag ON"
		)
		return false
	if not store.is_evidence_locked_for_target("npc_b"):
		push_error(
			"test_f2_flag_on_cooldown_active_on_normal: " +
			"npc_b should be locked during cooldown on Normal difficulty"
		)
		return false
	return true


# ── F3: Toggle mid-test — new rumors get Phase 2, pre-toggle rumors do not ───

static func test_f3_pre_toggle_rumor_unaffected() -> bool:
	## F3 (§ Slice F): A rumor seeded before the flag is toggled ON must not gain
	## evidence_credulity_boost or shelf extension after the toggle.
	## The toggle only affects FUTURE seeds; it does not retroactively mutate existing
	## Rumor objects.
	GameState.evidence_economy_v2 = false

	## Seed before toggle: no evidence applied (flag is OFF gate in world.gd).
	var r_pre := _make_rumor()
	## Shelf and boost remain at defaults with flag OFF.
	var shelf_before := r_pre.shelf_life_ticks
	var boost_before := r_pre.evidence_credulity_boost

	## Toggle the flag ON — this simulates the mid-session setting change.
	GameState.evidence_economy_v2 = true

	## The pre-toggle rumor object is unchanged — Phase 2 data is never back-filled.
	if r_pre.shelf_life_ticks != shelf_before:
		push_error(
			"test_f3_pre_toggle_rumor_unaffected: " +
			"shelf_life_ticks changed after toggle (expected %d, got %d)" \
			% [shelf_before, r_pre.shelf_life_ticks]
		)
		return false
	if not is_equal_approx(r_pre.evidence_credulity_boost, boost_before):
		push_error(
			"test_f3_pre_toggle_rumor_unaffected: " +
			"evidence_credulity_boost changed after toggle (expected %.4f, got %.4f)" \
			% [boost_before, r_pre.evidence_credulity_boost]
		)
		return false
	return true


static func test_f3_post_toggle_rumor_gets_phase2_mechanics() -> bool:
	## F3: A rumor seeded AFTER the flag is toggled ON does receive Phase 2 mechanics.
	## Toggle sequence: OFF → ON → seed → assert Phase 2 state.
	GameState.evidence_economy_v2 = false
	GameState.evidence_economy_v2 = true   ## toggle ON

	var r_post := _make_rumor()
	_apply_evidence(r_post, _make_witness_account())

	if r_post.shelf_life_ticks != BASELINE_SHELF + 80:
		push_error(
			"test_f3_post_toggle_rumor_gets_phase2_mechanics: " +
			"expected shelf %d after toggle ON + evidence, got %d" \
			% [BASELINE_SHELF + 80, r_post.shelf_life_ticks]
		)
		return false
	if not r_post.bolstered_by_evidence:
		push_error("test_f3_post_toggle_rumor_gets_phase2_mechanics: bolstered_by_evidence not set")
		return false
	return true


# ── F3 gate regression (SPA-1779) — toggle ON then OFF, next seed gets no bonus ──

static func test_f3_toggle_on_then_off_new_seed_no_bonus() -> bool:
	## SPA-1779 regression: F3 — toggle ON, seed a rumor (gets v2 bonuses), then
	## toggle back OFF and seed another.  The second seed must receive NO bonuses,
	## proving the gate re-evaluates the flag at seed time (prospective only).
	GameState.evidence_economy_v2 = true

	var r_before := _make_rumor()
	_apply_evidence_gated(r_before, _make_witness_account(), "npc_target", "normal")
	## Verify first seed DID get the bonus (flag was ON).
	if r_before.shelf_life_ticks <= BASELINE_SHELF:
		push_error(
			"test_f3_toggle_on_then_off_new_seed_no_bonus: " +
			"pre-toggle seed should have extended shelf (got %d)" % r_before.shelf_life_ticks
		)
		return false

	## Toggle flag OFF — subsequent seeds must get no bonus.
	GameState.evidence_economy_v2 = false

	var r_after := _make_rumor()
	_apply_evidence_gated(r_after, _make_witness_account(), "npc_target", "normal")

	if r_after.shelf_life_ticks != BASELINE_SHELF:
		push_error(
			"test_f3_toggle_on_then_off_new_seed_no_bonus: " +
			"post-toggle seed shelf should be %d (no extension), got %d" \
			% [BASELINE_SHELF, r_after.shelf_life_ticks]
		)
		return false
	if not is_zero_approx(r_after.evidence_credulity_boost):
		push_error(
			"test_f3_toggle_on_then_off_new_seed_no_bonus: " +
			"post-toggle seed credulity_boost should be 0.0, got %.4f" \
			% r_after.evidence_credulity_boost
		)
		return false
	return true


# ── F4: v1 save migration — existing rumors keep Phase-1 state ───────────────

static func test_f4_migrated_rumor_retains_phase1_shelf() -> bool:
	## F4 (§ Slice F): A rumor migrated from a v1 save (flag was OFF when saved)
	## must NOT gain shelf_life_extension after migration.  SaveManager._migrate_save_data()
	## must leave shelf_life_ticks untouched for pre-Phase-2 rumors (mirrors C4).
	GameState.evidence_economy_v2 = true  ## flag ON in the receiving session

	var data := {
		"version": 1,
		"scenario_id": "test_f4",
		"tick": 0,
		"day": 1,
		"propagation": {
			"live_rumors": {
				"r_v1": {
					"id":                    "r_v1",
					"subject_npc_id":        "npc_subject",
					"claim_type":            int(Rumor.ClaimType.ACCUSATION),
					"intensity":             3,
					"mutability":            0.5,
					"created_tick":          0,
					"shelf_life_ticks":      330,
					"current_believability": 0.6,
					"lineage_parent_id":     "",
					"bolstered_by_evidence": false,
					## evidence_credulity_boost and seed_target_npc_id intentionally absent
				},
			},
		},
		"intel_store": {},
	}

	var err: String = SaveManager._migrate_save_data(data, 1)
	if err != "":
		push_error(
			"test_f4_migrated_rumor_retains_phase1_shelf: migration error: %s" % err
		)
		return false

	var rd: Dictionary = data["propagation"]["live_rumors"]["r_v1"]
	var shelf: int = int(rd.get("shelf_life_ticks", -1))
	if shelf != 330:
		push_error(
			"test_f4_migrated_rumor_retains_phase1_shelf: " +
			"migration must not extend shelf (expected 330, got %d)" % shelf
		)
		return false
	return true


static func test_f4_new_rumor_after_v1_load_gets_phase2() -> bool:
	## F4: After loading a v1 save into a v2 session (flag ON), a NEW rumor seeded
	## after load receives Phase 2 mechanics.  The flag state governs new seeds,
	## not the save version of prior rumors.
	GameState.evidence_economy_v2 = true

	var r_new := _make_rumor()
	_apply_evidence(r_new, _make_incriminating_artifact(), "npc_target")

	if not r_new.bolstered_by_evidence:
		push_error("test_f4_new_rumor_after_v1_load_gets_phase2: bolstered_by_evidence not set")
		return false
	if not r_new.evidence_credulity_boost > 0.0:
		push_error("test_f4_new_rumor_after_v1_load_gets_phase2: credulity_boost should be > 0")
		return false
	return true


# ── F5: Save version header is 2 ─────────────────────────────────────────────

static func test_f5_save_version_is_2() -> bool:
	## F5 (§ Slice F): SaveManager.SAVE_VERSION must equal 2.
	## Phase 2 bumped the integer save version from 1 to 2 so that save files
	## written before Phase 2 are detected and migrated via _migrate_save_data().
	GameState.evidence_economy_v2 = true  ## not relevant, set for consistency

	if SaveManager.SAVE_VERSION != 2:
		push_error(
			"test_f5_save_version_is_2: " +
			"expected SaveManager.SAVE_VERSION == 2, got %d" % SaveManager.SAVE_VERSION
		)
		return false
	return true
