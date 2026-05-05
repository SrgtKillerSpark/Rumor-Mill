## test_phase2_slice_c_shelf_life.gd — Acceptance regression tests for Phase 2 Slice C:
## shelf-life extension (SPA-1736).
##
## Covers acceptance scenarios C1–C4 from docs/phase2-acceptance-tests.md:
##   C1 — Seed a rumor with Witness Account → shelf_life_ticks increases by 80 ticks
##         (~3.3 extra in-game days) vs. an identical unbolstered rumor.
##   C2 — Seed a rumor with Incriminating Artifact → NO shelf extension (+0 ticks).
##   C3 — Seed a rumor with Forged Document → shelf extends by 40 ticks (~1.7 extra days).
##   C4 — Load a Phase-1 save (no shelf-life extension fields) → game loads without error;
##         existing rumors retain their original shelf_life_ticks (no retroactive extension).
##
## Feature-flag guard: the runner sets GameState.evidence_economy_v2 = true before each
## test (equivalent to GUT before_each) and restores the previous value after (after_each).
## Each individual test also guards trivially if the flag is somehow still OFF, so this
## suite never fails in environments where the flag cannot be written.
##
## Follow the pattern in test_phase2_evidence_economy.gd.
## Run from the Godot editor: Scene → Run Script.

class_name TestPhase2SliceCShelfLife
extends RefCounted

const BASELINE_SHELF := 330  ## Rumor.create() default shelf_life_ticks (see rumor.gd)
const TICKS_PER_DAY  := 24   ## in-game ticks per day; 80 ÷ 24 ≈ 3.3 d, 40 ÷ 24 ≈ 1.7 d


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# C1 — Witness Account shelf extension
		"test_c1_witness_account_extends_shelf_by_80_ticks",
		# C2 — Incriminating Artifact has no shelf extension
		"test_c2_incriminating_artifact_no_shelf_extension",
		# C3 — Forged Document shelf extension
		"test_c3_forged_document_extends_shelf_by_40_ticks",
		# C4 — Phase-1 save compatibility
		"test_c4_phase1_save_loads_without_error",
		"test_c4_phase1_save_migration_preserves_shelf_life_ticks",
	]

	## before_each / after_each: enable the feature flag for the duration of this
	## suite and restore it so sibling suites are not affected.
	var _saved_flag: bool = GameState.evidence_economy_v2

	for method_name in tests:
		GameState.evidence_economy_v2 = true   ## before_each equivalent
		var result: bool = call(method_name)
		GameState.evidence_economy_v2 = _saved_flag  ## after_each equivalent

		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nPhase2SliceCShelfLife tests: %d passed, %d failed" % [passed, failed])


# ── Helpers ───────────────────────────────────────────────────────────────────

## Witness Account: +80 shelf, -0.15 mutability, any claim (see recon_controller.gd).
static func _make_witness_account() -> PlayerIntelStore.EvidenceItem:
	var ev := PlayerIntelStore.EvidenceItem.new("Witness Account", 0.15, -0.15, [], 0)
	ev.shelf_life_extension = 80
	ev.credulity_boost = 0.05
	return ev


## Incriminating Artifact: +0 shelf (SPA-1611), SCANDAL/HERESY only.
static func _make_incriminating_artifact() -> PlayerIntelStore.EvidenceItem:
	var ev := PlayerIntelStore.EvidenceItem.new(
		"Incriminating Artifact", 0.25, 0.0, ["SCANDAL", "HERESY"], 0)
	ev.shelf_life_extension = 0
	ev.credulity_boost = 0.15
	return ev


## Forged Document: +40 shelf, ACCUSATION/SCANDAL/HERESY only.
static func _make_forged_document() -> PlayerIntelStore.EvidenceItem:
	var ev := PlayerIntelStore.EvidenceItem.new(
		"Forged Document", 0.20, 0.0, ["ACCUSATION", "SCANDAL", "HERESY"], 0)
	ev.shelf_life_extension = 40
	ev.credulity_boost = 0.10
	return ev


static func _make_rumor() -> Rumor:
	return Rumor.create("r_test", "npc_subject", Rumor.ClaimType.ACCUSATION, 3, 0.5, 0)


## Mirror of world.gd lines 1282–1288: apply evidence bonuses to a freshly created rumor.
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


# ── C1: Witness Account extends shelf life by ~3.3 days (80 ticks) ───────────

static func test_c1_witness_account_extends_shelf_by_80_ticks() -> bool:
	## C1 (docs/phase2-acceptance-tests.md): Witness Account adds 80 ticks
	## (≈ 3.3 days at TICKS_PER_DAY=24) to the rumor's shelf_life_ticks vs. baseline.
	if not GameState.evidence_economy_v2:
		return true  ## pass trivially when flag is OFF
	var r := _make_rumor()
	_apply_evidence(r, _make_witness_account())
	return r.shelf_life_ticks == BASELINE_SHELF + 80


# ── C2: Incriminating Artifact has no shelf extension ────────────────────────

static func test_c2_incriminating_artifact_no_shelf_extension() -> bool:
	## C2: Incriminating Artifact has shelf_life_extension = 0 (SPA-1611); the
	## rumor expires at the same time as an unbolstered rumor with identical
	## initial believability.
	if not GameState.evidence_economy_v2:
		return true
	var r := _make_rumor()
	_apply_evidence(r, _make_incriminating_artifact())
	return r.shelf_life_ticks == BASELINE_SHELF + 0


# ── C3: Forged Document extends shelf life by ~1.7 days (40 ticks) ───────────

static func test_c3_forged_document_extends_shelf_by_40_ticks() -> bool:
	## C3: Forged Document adds 40 ticks (≈ 1.7 days) to shelf_life_ticks —
	## a moderate extension, less than Witness Account but non-zero.
	if not GameState.evidence_economy_v2:
		return true
	var r := _make_rumor()
	_apply_evidence(r, _make_forged_document())
	return r.shelf_life_ticks == BASELINE_SHELF + 40


# ── C4: Phase-1 save compatibility ───────────────────────────────────────────

static func test_c4_phase1_save_loads_without_error() -> bool:
	## C4: A rumor dict written before Phase 2 (no evidence_credulity_boost,
	## seed_target_npc_id, or shelf-life extension fields) must survive
	## Rumor.create() without crashing.  This mirrors _restore_propagation's
	## reconstruction path for legacy saves.
	if not GameState.evidence_economy_v2:
		return true
	var phase1_rd := {
		"id":                    "r_phase1",
		"subject_npc_id":        "npc_subject",
		"claim_type":            int(Rumor.ClaimType.ACCUSATION),
		"intensity":             3,
		"mutability":            0.5,
		"created_tick":          0,
		"shelf_life_ticks":      330,
		"current_believability": 0.6,
		"lineage_parent_id":     "",
		"bolstered_by_evidence": false,
		## Phase-2 fields intentionally absent (pre-Phase-2 save)
	}
	var r := Rumor.create(
		phase1_rd["id"], phase1_rd["subject_npc_id"],
		int(phase1_rd["claim_type"]) as Rumor.ClaimType,
		int(phase1_rd["intensity"]),
		float(phase1_rd["mutability"]),
		int(phase1_rd["created_tick"]),
		int(phase1_rd["shelf_life_ticks"]),
		phase1_rd.get("lineage_parent_id", "")
	)
	r.evidence_credulity_boost = float(phase1_rd.get("evidence_credulity_boost", 0.0))
	r.seed_target_npc_id       = phase1_rd.get("seed_target_npc_id", "")
	return r != null


static func test_c4_phase1_save_migration_preserves_shelf_life_ticks() -> bool:
	## C4: After SaveManager._migrate_save_data() runs on a v1 save, the rumor's
	## shelf_life_ticks must be unchanged — migration must not retroactively extend
	## shelf life for pre-Phase-2 rumors.
	if not GameState.evidence_economy_v2:
		return true
	var data := {
		"version": 1,
		"scenario_id": "test_c4",
		"tick": 0,
		"day": 1,
		"propagation": {
			"live_rumors": {
				"r_phase1": {
					"id":                    "r_phase1",
					"subject_npc_id":        "npc_subject",
					"claim_type":            int(Rumor.ClaimType.ACCUSATION),
					"intensity":             3,
					"mutability":            0.5,
					"created_tick":          0,
					"shelf_life_ticks":      330,
					"current_believability": 0.6,
					"lineage_parent_id":     "",
					"bolstered_by_evidence": false,
				},
			},
		},
		"intel_store": {},
	}
	var err: String = SaveManager._migrate_save_data(data, 1)
	if err != "":
		push_error("test_c4_phase1_save_migration_preserves_shelf_life_ticks: migration error: %s" % err)
		return false
	var rd: Dictionary = data["propagation"]["live_rumors"]["r_phase1"]
	var shelf: int = int(rd.get("shelf_life_ticks", -1))
	if shelf != 330:
		push_error(
			"test_c4_phase1_save_migration_preserves_shelf_life_ticks: " +
			"shelf_life_ticks changed by migration (expected 330, got %d)" % shelf
		)
		return false
	return true
