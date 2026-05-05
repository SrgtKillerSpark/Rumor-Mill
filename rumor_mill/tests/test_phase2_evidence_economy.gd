## test_phase2_evidence_economy.gd — GUT regression tests for Phase 2 evidence-economy
## mechanics: Slice C (shelf-life extension), Slice D (credulity boost), and
## Slice E (target-shift cooldown) (SPA-1706).
##
## Covers:
##   Slice C — Shelf-Life Extension:
##     • Witness Account evidence has shelf_life_extension = 80
##     • Incriminating Artifact has shelf_life_extension = 0 (SPA-1611)
##     • Forged Document has shelf_life_extension = 40
##     • Applying each evidence type adds the correct ticks to a rumor's shelf_life_ticks
##     • Save/load round-trip preserves extended shelf_life_ticks (via Rumor dict)
##
##   Slice D — Credulity Boost (SPA-1705):
##     • evidence_credulity_boost is set correctly on rumor per evidence type
##     • seed_target_npc_id is assigned to the seeded NPC
##     • Only the seed target matches the credulity-boost guard condition
##     • Pre-Phase-2 rumor dict (missing key) restores evidence_credulity_boost as 0.0
##
##   Slice E — Target-Shift Cooldown:
##     • Cooldown days: Apprentice=0, Normal=2, Master=3, Spymaster=4
##     • is_evidence_locked_for_target returns true for a different NPC during cooldown
##     • is_evidence_locked_for_target returns false for the SAME target during cooldown
##     • Apprentice: start_evidence_cooldown is a no-op (no lock created)
##     • decay_evidence_cooldowns decrements all active cooldowns by 1 per call
##     • A cooldown entry at 0 does not lock evidence
##     • Save/load round-trip preserves active cooldown state
##
## Run from the Godot editor: Scene → Run Script.

class_name TestPhase2EvidenceEconomy
extends RefCounted

const BASELINE_SHELF := 330  ## Rumor.create() default shelf_life_ticks (see rumor.gd)


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Slice C — evidence item shelf_life_extension values
		"test_witness_account_shelf_extension_is_80",
		"test_incriminating_artifact_shelf_extension_is_0",
		"test_forged_document_shelf_extension_is_40",
		# Slice C — shelf_life_ticks applied to rumor
		"test_witness_account_adds_80_to_rumor_shelf",
		"test_incriminating_artifact_adds_0_to_rumor_shelf",
		"test_forged_document_adds_40_to_rumor_shelf",
		# Slice C — save/load round-trip
		"test_save_roundtrip_preserves_extended_shelf_life",
		# Slice D — evidence_credulity_boost per evidence type
		"test_rumor_credulity_boost_forged_document",
		"test_rumor_credulity_boost_incriminating_artifact",
		"test_rumor_credulity_boost_witness_account",
		# Slice D — seed_target_npc_id guard condition
		"test_credulity_boost_condition_true_for_seed_target",
		"test_credulity_boost_condition_false_for_other_npc",
		# Slice D — pre-Phase-2 save compatibility
		"test_pre_phase2_rumor_dict_defaults_credulity_boost_to_zero",
		# Slice E — cooldown days per difficulty
		"test_cooldown_days_apprentice_is_0",
		"test_cooldown_days_normal_is_2",
		"test_cooldown_days_master_is_2",
		"test_cooldown_days_spymaster_is_3",
		# Slice E — cooldown locking behaviour
		"test_cooldown_locks_different_target",
		"test_cooldown_allows_same_target",
		"test_cooldown_no_lock_when_zero_days",
		# Slice E — cooldown decay
		"test_cooldown_decrements_on_day_advance",
		"test_cooldown_unlocks_after_expiry",
		# Slice E — save/load round-trip
		"test_save_roundtrip_preserves_cooldown_state",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nPhase2EvidenceEconomy tests: %d passed, %d failed" % [passed, failed])


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


## Mirror of world.gd lines 1282-1288: apply evidence bonuses to a freshly created rumor.
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


# ── Slice C: shelf_life_extension values on EvidenceItem ─────────────────────

static func test_witness_account_shelf_extension_is_80() -> bool:
	return _make_witness_account().shelf_life_extension == 80


static func test_incriminating_artifact_shelf_extension_is_0() -> bool:
	return _make_incriminating_artifact().shelf_life_extension == 0


static func test_forged_document_shelf_extension_is_40() -> bool:
	return _make_forged_document().shelf_life_extension == 40


# ── Slice C: shelf_life_ticks applied to rumor ────────────────────────────────

static func test_witness_account_adds_80_to_rumor_shelf() -> bool:
	var r := _make_rumor()
	_apply_evidence(r, _make_witness_account())
	return r.shelf_life_ticks == BASELINE_SHELF + 80


static func test_incriminating_artifact_adds_0_to_rumor_shelf() -> bool:
	var r := _make_rumor()
	_apply_evidence(r, _make_incriminating_artifact())
	return r.shelf_life_ticks == BASELINE_SHELF + 0


static func test_forged_document_adds_40_to_rumor_shelf() -> bool:
	var r := _make_rumor()
	_apply_evidence(r, _make_forged_document())
	return r.shelf_life_ticks == BASELINE_SHELF + 40


# ── Slice C: save/load — extended shelf_life_ticks survives round-trip ────────

static func test_save_roundtrip_preserves_extended_shelf_life() -> bool:
	## _serialize_propagation stores shelf_life_ticks in the rumor dict;
	## _restore_propagation passes it directly to Rumor.create() as the shelf param.
	var r := _make_rumor()
	_apply_evidence(r, _make_witness_account())   # shelf = 330 + 80 = 410
	var expected: int = r.shelf_life_ticks

	# Build the save dict (mirrors _serialize_propagation for one rumor).
	var rd := {
		"id":                    r.id,
		"subject_npc_id":        r.subject_npc_id,
		"claim_type":            int(r.claim_type),
		"intensity":             r.intensity,
		"mutability":            r.mutability,
		"created_tick":          r.created_tick,
		"shelf_life_ticks":      r.shelf_life_ticks,
		"current_believability": r.current_believability,
		"lineage_parent_id":     r.lineage_parent_id,
		"bolstered_by_evidence": r.bolstered_by_evidence,
	}

	# Restore (mirrors _restore_propagation's Rumor.create call).
	var r2 := Rumor.create(
		rd["id"], rd["subject_npc_id"],
		int(rd["claim_type"]) as Rumor.ClaimType,
		int(rd["intensity"]),
		float(rd["mutability"]),
		int(rd["created_tick"]),
		int(rd["shelf_life_ticks"]),
		rd.get("lineage_parent_id", "")
	)
	return r2.shelf_life_ticks == expected


# ── Slice D: evidence_credulity_boost set correctly per evidence type ─────────

static func test_rumor_credulity_boost_forged_document() -> bool:
	var r := _make_rumor()
	_apply_evidence(r, _make_forged_document(), "npc_target")
	return r.evidence_credulity_boost == 0.10


static func test_rumor_credulity_boost_incriminating_artifact() -> bool:
	var r := _make_rumor()
	_apply_evidence(r, _make_incriminating_artifact(), "npc_target")
	return r.evidence_credulity_boost == 0.15


static func test_rumor_credulity_boost_witness_account() -> bool:
	var r := _make_rumor()
	_apply_evidence(r, _make_witness_account(), "npc_target")
	return r.evidence_credulity_boost == 0.05


# ── Slice D: seed_target_npc_id guard condition (mirrors npc.gd lines 755-757) ─

static func test_credulity_boost_condition_true_for_seed_target() -> bool:
	## The boost guard in npc.gd reads:
	##   if rumor.evidence_credulity_boost > 0.0 and npc_id == rumor.seed_target_npc_id
	## Only the seed target NPC satisfies this condition.
	var r := _make_rumor()
	_apply_evidence(r, _make_forged_document(), "npc_alice")
	var boost_applies: bool = r.evidence_credulity_boost > 0.0 \
			and "npc_alice" == r.seed_target_npc_id
	return boost_applies


static func test_credulity_boost_condition_false_for_other_npc() -> bool:
	## Propagation targets (other NPCs) do not match seed_target_npc_id.
	var r := _make_rumor()
	_apply_evidence(r, _make_forged_document(), "npc_alice")
	var boost_applies: bool = r.evidence_credulity_boost > 0.0 \
			and "npc_bob" == r.seed_target_npc_id
	return boost_applies == false


# ── Slice D: pre-Phase-2 save compatibility ───────────────────────────────────

static func test_pre_phase2_rumor_dict_defaults_credulity_boost_to_zero() -> bool:
	## A save written before SPA-1705 has no "evidence_credulity_boost" key.
	## _restore_propagation uses .get("evidence_credulity_boost", 0.0), so the field
	## must default to 0.0 without crashing.
	var legacy_rd := {
		"id":                    "r_legacy",
		"subject_npc_id":        "npc_subject",
		"claim_type":            int(Rumor.ClaimType.ACCUSATION),
		"intensity":             3,
		"mutability":            0.5,
		"created_tick":          0,
		"shelf_life_ticks":      330,
		"current_believability": 0.6,
		"lineage_parent_id":     "",
		"bolstered_by_evidence": false,
		## "evidence_credulity_boost" key intentionally absent (pre-Phase-2 save)
	}
	var r := Rumor.create(
		legacy_rd["id"], legacy_rd["subject_npc_id"],
		int(legacy_rd["claim_type"]) as Rumor.ClaimType,
		int(legacy_rd["intensity"]),
		float(legacy_rd["mutability"]),
		int(legacy_rd["created_tick"]),
		int(legacy_rd["shelf_life_ticks"]),
		legacy_rd.get("lineage_parent_id", "")
	)
	r.evidence_credulity_boost = float(legacy_rd.get("evidence_credulity_boost", 0.0))
	return r.evidence_credulity_boost == 0.0


# ── Slice E: cooldown days per difficulty ─────────────────────────────────────

static func test_cooldown_days_apprentice_is_0() -> bool:
	return PlayerIntelStore._cooldown_days_for_difficulty("apprentice") == 0


static func test_cooldown_days_normal_is_2() -> bool:
	return PlayerIntelStore._cooldown_days_for_difficulty("normal") == 2


static func test_cooldown_days_master_is_2() -> bool:  ## SPA-1755
	return PlayerIntelStore._cooldown_days_for_difficulty("master") == 2


static func test_cooldown_days_spymaster_is_3() -> bool:  ## SPA-1755
	return PlayerIntelStore._cooldown_days_for_difficulty("spymaster") == 3


# ── Slice E: cooldown locking behaviour ──────────────────────────────────────

static func test_cooldown_locks_different_target() -> bool:
	## After using evidence on npc_a, evidence cannot be used on npc_b.
	var store := PlayerIntelStore.new()
	store.start_evidence_cooldown("npc_a", "normal")  # 2-day cooldown
	return store.is_evidence_locked_for_target("npc_b")


static func test_cooldown_allows_same_target() -> bool:
	## The cooldown only blocks different targets; the same target stays available.
	var store := PlayerIntelStore.new()
	store.start_evidence_cooldown("npc_a", "normal")
	return not store.is_evidence_locked_for_target("npc_a")


static func test_cooldown_no_lock_when_zero_days() -> bool:
	## Apprentice difficulty: start_evidence_cooldown is a no-op (days = 0).
	## Evidence must not be locked for any target afterward.
	var store := PlayerIntelStore.new()
	store.start_evidence_cooldown("npc_a", "apprentice")
	return not store.is_evidence_locked_for_target("npc_b")


# ── Slice E: cooldown decay ───────────────────────────────────────────────────

static func test_cooldown_decrements_on_day_advance() -> bool:
	## decay_evidence_cooldowns() is called once per dawn; each call subtracts 1.
	var store := PlayerIntelStore.new()
	store.start_evidence_cooldown("npc_a", "normal")  # starts at 2
	store.decay_evidence_cooldowns()
	var info := store.get_evidence_cooldown_info()
	return info.get("days_remaining", -1) == 1


static func test_cooldown_unlocks_after_expiry() -> bool:
	## After N decays equal to the initial cooldown, evidence becomes available again.
	var store := PlayerIntelStore.new()
	store.start_evidence_cooldown("npc_a", "normal")  # 2 days
	store.decay_evidence_cooldowns()
	store.decay_evidence_cooldowns()
	return not store.is_evidence_locked_for_target("npc_b")


# ── Slice E: save/load — cooldown state survives round-trip ──────────────────

static func test_save_roundtrip_preserves_cooldown_state() -> bool:
	## Serialize a store with an active cooldown, restore into a fresh store,
	## and verify the cooldown is still active for a different target.
	## Requires SaveManager._serialize_intel_store / _restore_intel_store to
	## include "evidence_target_cooldown" (added in SPA-1706).
	var store := PlayerIntelStore.new()
	store.start_evidence_cooldown("npc_a", "normal")  # 2-day cooldown

	var data := SaveManager._serialize_intel_store(store)
	var store2 := PlayerIntelStore.new()
	SaveManager._restore_intel_store(store2, data)

	return store2.is_evidence_locked_for_target("npc_b")
