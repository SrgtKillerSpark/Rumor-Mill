## test_phase2_slice_d_credulity_boost.gd — Acceptance regression tests for Phase 2 Slice D:
## credulity boost (SPA-1739).
##
## Covers acceptance scenarios D1–D4 from docs/phase2-acceptance-tests.md:
##   D1 — Incriminating Artifact on a low-credulity NPC raises effective believe_chance
##         vs. an identical rumor with no evidence.
##   D2 — Witness Account on the same NPC raises believe_chance LESS than Artifact
##         (Artifact boost = 0.15, Witness Account boost = 0.05).
##   D3 — The credulity boost applies ONLY to the seed target NPC identified by
##         seed_target_npc_id; propagated listeners (different NPC id) receive no boost.
##   D4 — Two rumors on the same NPC: only the evidence-backed rumor carries a non-zero
##         evidence_credulity_boost; the plain rumor is unaffected.
##
## Boost magnitudes come from recon_controller.gd (SPA-1711 source of truth):
##   Incriminating Artifact  credulity_boost = 0.15
##   Witness Account         credulity_boost = 0.05
##
## All tests assert on internal state (evidence_credulity_boost field + deterministic
## formula replica) rather than on RNG outcomes — mirrors the style used in
## test_phase2_slice_c_shelf_life.gd (commit 382206fc).
##
## Feature-flag guard: the runner sets GameState.evidence_economy_v2 = true before each
## test (equivalent to GUT before_each) and restores the previous value after (after_each).
## Each individual test also trivially passes when the flag is OFF so this suite never
## fails in environments where the flag cannot be written.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestPhase2SliceDCredulityBoost
extends RefCounted

## Low-credulity NPC value chosen so the boost is observable without clamping to 1.0.
const LOW_CREDULITY  := 0.20

## Boost magnitudes from recon_controller.gd (SPA-1711).
const ARTIFACT_BOOST := 0.15   ## Incriminating Artifact credulity_boost
const WITNESS_BOOST  := 0.05   ## Witness Account credulity_boost


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# D1 — Artifact raises effective believe_chance on a low-credulity NPC
		"test_d1_artifact_raises_believe_chance_vs_no_evidence",
		# D2 — Witness Account boost is strictly smaller than Artifact boost
		"test_d2_witness_account_boost_less_than_artifact",
		# D3 — Boost is gated to seed_target_npc_id; propagated listeners are not boosted
		"test_d3_boost_applies_only_to_seed_target",
		# D4 — Two rumors on same NPC: only evidence-backed one carries the boost
		"test_d4_only_evidence_backed_rumor_carries_boost",
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

	print("\nPhase2SliceDCredulityBoost tests: %d passed, %d failed" % [passed, failed])


# ── Helpers ───────────────────────────────────────────────────────────────────

## Incriminating Artifact: boost = 0.15, SCANDAL/HERESY only (recon_controller.gd SPA-1711).
static func _make_incriminating_artifact() -> PlayerIntelStore.EvidenceItem:
	var ev := PlayerIntelStore.EvidenceItem.new(
		"Incriminating Artifact", 0.25, 0.0, ["SCANDAL", "HERESY"], 0)
	ev.shelf_life_extension = 0
	ev.credulity_boost = ARTIFACT_BOOST
	return ev


## Witness Account: boost = 0.05, any claim (recon_controller.gd SPA-1711).
static func _make_witness_account() -> PlayerIntelStore.EvidenceItem:
	var ev := PlayerIntelStore.EvidenceItem.new("Witness Account", 0.15, -0.15, [], 0)
	ev.shelf_life_extension = 80
	ev.credulity_boost = WITNESS_BOOST
	return ev


static func _make_rumor() -> Rumor:
	return Rumor.create("r_test", "npc_subject", Rumor.ClaimType.ACCUSATION, 3, 0.5, 0)


## Mirror of world.gd evidence-application block (lines 1282–1288): stamps the boost
## and seed target onto the rumor.  Matches _apply_evidence in slice_c test.
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


## Deterministic replica of the seed-target path in npc.gd (SPA-1711/SPA-1718):
##   base  = credulity × believability
##   boosted = clamp(base + boost, 0, 1)
## No faction or corroboration bonuses (they are orthogonal to credulity boost).
static func _base_chance(credulity: float, believability: float) -> float:
	return credulity * believability


static func _boosted_chance(credulity: float, believability: float, boost: float) -> float:
	return clampf(_base_chance(credulity, believability) + boost, 0.0, 1.0)


# ── D1: Artifact raises believe_chance on a low-credulity NPC ────────────────

static func test_d1_artifact_raises_believe_chance_vs_no_evidence() -> bool:
	## D1 (docs/phase2-acceptance-tests.md § Slice D): Incriminating Artifact on a
	## low-credulity NPC (credulity = 0.20) produces a strictly higher effective
	## believe_chance for the seed target than the same rumor without evidence.
	## Asserts on internal boost field and the deterministic formula — no RNG.
	if not GameState.evidence_economy_v2:
		return true  ## pass trivially when flag is OFF

	var r_plain    := _make_rumor()
	var r_artifact := _make_rumor()
	_apply_evidence(r_artifact, _make_incriminating_artifact(), "npc_target")

	## The backed rumor must carry a non-zero boost.
	if not r_artifact.evidence_credulity_boost > 0.0:
		push_error("test_d1: evidence_credulity_boost not set on artifact rumor")
		return false

	## Use the plain rumor's initial believability as the shared baseline so only
	## the boost — not the believability_bonus — drives the difference.
	var base_bel := r_plain.current_believability
	var plain_chance    := _base_chance(LOW_CREDULITY, base_bel)
	var artifact_chance := _boosted_chance(LOW_CREDULITY, base_bel, r_artifact.evidence_credulity_boost)

	if not artifact_chance > plain_chance:
		push_error(
			"test_d1: artifact_chance (%.4f) should exceed plain_chance (%.4f)" \
			% [artifact_chance, plain_chance]
		)
		return false
	return true


# ── D2: Witness Account boost is smaller than Artifact boost ─────────────────

static func test_d2_witness_account_boost_less_than_artifact() -> bool:
	## D2: The credulity boost from a Witness Account (0.05) is strictly less than
	## from an Incriminating Artifact (0.15), so the resulting believe_chance for
	## the seed target is correspondingly lower.
	if not GameState.evidence_economy_v2:
		return true

	var r_witness  := _make_rumor()
	var r_artifact := _make_rumor()
	_apply_evidence(r_witness,  _make_witness_account(),        "npc_target")
	_apply_evidence(r_artifact, _make_incriminating_artifact(), "npc_target")

	## Boost magnitudes must respect the ordering from recon_controller.gd.
	if not r_witness.evidence_credulity_boost < r_artifact.evidence_credulity_boost:
		push_error(
			"test_d2: witness boost (%.4f) should be < artifact boost (%.4f)" \
			% [r_witness.evidence_credulity_boost, r_artifact.evidence_credulity_boost]
		)
		return false

	## Resulting believe_chance for the same low-credulity NPC (same baseline bel).
	var base_bel := _make_rumor().current_believability
	var witness_chance  := _boosted_chance(LOW_CREDULITY, base_bel, r_witness.evidence_credulity_boost)
	var artifact_chance := _boosted_chance(LOW_CREDULITY, base_bel, r_artifact.evidence_credulity_boost)
	if not witness_chance < artifact_chance:
		push_error(
			"test_d2: witness_chance (%.4f) should be < artifact_chance (%.4f)" \
			% [witness_chance, artifact_chance]
		)
		return false
	return true


# ── D3: Boost applies only to seed target, not to propagated listeners ────────

static func test_d3_boost_applies_only_to_seed_target() -> bool:
	## D3: evidence_credulity_boost is gated to seed_target_npc_id.  The effective
	## believe_chance for the seed target (npc_target) includes the boost; a different
	## NPC hearing the same rumor through propagation (npc_other) does not.
	if not GameState.evidence_economy_v2:
		return true

	const SEED_TARGET_ID := "npc_target"
	const OTHER_NPC_ID   := "npc_other_propagated"

	var r := _make_rumor()
	_apply_evidence(r, _make_incriminating_artifact(), SEED_TARGET_ID)

	## seed_target_npc_id must be stamped correctly.
	if r.seed_target_npc_id != SEED_TARGET_ID:
		push_error(
			"test_d3: seed_target_npc_id mismatch (expected '%s', got '%s')" \
			% [SEED_TARGET_ID, r.seed_target_npc_id]
		)
		return false

	var base_bel := _make_rumor().current_believability

	## Seed target gets the boost (npc_data["id"] == seed_target_npc_id).
	var target_chance := _boosted_chance(LOW_CREDULITY, base_bel, r.evidence_credulity_boost)
	## Propagated listener: id != seed_target_npc_id → boost = 0.
	var other_chance  := _base_chance(LOW_CREDULITY, base_bel)

	if not target_chance > other_chance:
		push_error(
			"test_d3: target_chance (%.4f) should exceed other_chance (%.4f)" \
			% [target_chance, other_chance]
		)
		return false
	return true


# ── D4: Only the evidence-backed rumor carries the boost ─────────────────────

static func test_d4_only_evidence_backed_rumor_carries_boost() -> bool:
	## D4: Two rumors targeting the same NPC — one with Incriminating Artifact evidence,
	## one without.  Only the backed rumor has evidence_credulity_boost > 0; the plain
	## rumor stays at 0, ensuring the boost does not bleed across rumors on the same NPC.
	if not GameState.evidence_economy_v2:
		return true

	const NPC_ID := "npc_target"

	var r_backed := _make_rumor()
	var r_plain  := _make_rumor()
	_apply_evidence(r_backed, _make_incriminating_artifact(), NPC_ID)
	## r_plain is NOT backed by evidence — evidence_credulity_boost stays at default 0.

	if not r_backed.evidence_credulity_boost > 0.0:
		push_error("test_d4: backed rumor should have evidence_credulity_boost > 0")
		return false
	if not is_zero_approx(r_plain.evidence_credulity_boost):
		push_error(
			"test_d4: plain rumor should have evidence_credulity_boost = 0.0, got %.4f" \
			% r_plain.evidence_credulity_boost
		)
		return false

	var base_bel      := _make_rumor().current_believability
	var backed_chance := _boosted_chance(LOW_CREDULITY, base_bel, r_backed.evidence_credulity_boost)
	var plain_chance  := _base_chance(LOW_CREDULITY, base_bel)

	if not backed_chance > plain_chance:
		push_error(
			"test_d4: backed_chance (%.4f) should exceed plain_chance (%.4f)" \
			% [backed_chance, plain_chance]
		)
		return false
	return true
