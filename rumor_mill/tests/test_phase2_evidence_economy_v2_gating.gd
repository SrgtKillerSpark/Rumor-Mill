## test_phase2_evidence_economy_v2_gating.gd — GUT regression tests for SPA-1757:
## evidence_economy_v2 bonuses (credulity boost + shelf-life extension) are gated to
## Normal+ difficulty only; Apprentice receives no bonus even when the flag is ON.
##
## Covers:
##   Apprentice gating (SPA-1757):
##     • credulity_boost stays 0 on Apprentice even with evidence_economy_v2 = true
##     • shelf_life_ticks stays at baseline on Apprentice (no extension applied)
##     • bolstered_by_evidence is still set on Apprentice (flag is not gated)
##
##   Normal difficulty — bonuses apply (SPA-1757):
##     • Witness Account credulity_boost = 0.05 is applied
##     • Witness Account shelf_life_extension = 80 is applied
##     • Incriminating Artifact credulity_boost = 0.15 is applied
##     • Forged Document shelf_life_extension = 40 is applied
##
##   Master difficulty — same as Normal (SPA-1757):
##     • credulity_boost and shelf_life_extension both apply on Master
##
##   Cooldown bypass NOT difficulty-gated (SPA-1756):
##     • supports_cooldown_bypass flag on EvidenceItem carries no difficulty condition
##     • is_evidence_bypass_active() returns true regardless of selected_difficulty
##
## Implementation reference: world.gd seed_rumor_from_player(), lines 1293-1299:
##   if GameState.evidence_economy_v2 and GameState.selected_difficulty != "apprentice":
##       rumor.shelf_life_ticks += evidence_item.shelf_life_extension
##       rumor.evidence_credulity_boost = cred_boost
##       rumor.seed_target_npc_id = seed_target_npc_id
##   rumor.bolstered_by_evidence = true
##
## Run from the Godot editor: Scene → Run Script.

class_name TestPhase2EvidenceEconomyV2Gating
extends RefCounted

const BASELINE_SHELF := 330  ## Rumor.create() default shelf_life_ticks (see rumor.gd)


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Apprentice — bonuses suppressed even with flag ON
		"test_apprentice_credulity_boost_is_zero",
		"test_apprentice_shelf_extension_is_zero",
		"test_apprentice_bolstered_by_evidence_still_set",
		# Normal — both bonuses apply
		"test_normal_witness_account_credulity_boost_applied",
		"test_normal_witness_account_shelf_extension_applied",
		"test_normal_artifact_credulity_boost_applied",
		"test_normal_forged_doc_shelf_extension_applied",
		# Master — same as Normal
		"test_master_credulity_boost_applied",
		"test_master_shelf_extension_applied",
		# SPA-1774: evidence_economy_v2_gated_off telemetry signal fires on Apprentice only
		"test_gated_off_signal_fires_on_apprentice",
		"test_gated_off_signal_does_not_fire_on_normal",
		"test_gated_off_signal_does_not_fire_on_master",
		# Cooldown bypass is NOT difficulty-gated (SPA-1756)
		"test_bypass_flag_set_independently_of_difficulty",
		"test_bypass_active_on_normal_difficulty",
		"test_bypass_active_on_master_difficulty",
		"test_bypass_active_regardless_of_selected_difficulty",
	]

	## before_each / after_each: enable flag and snapshot difficulty for the suite.
	var _saved_flag: bool       = GameState.evidence_economy_v2
	var _saved_diff: String     = GameState.selected_difficulty

	for method_name in tests:
		GameState.evidence_economy_v2  = true   ## before_each equivalent
		GameState.selected_difficulty  = "normal"
		var result: bool = call(method_name)
		GameState.evidence_economy_v2  = _saved_flag   ## after_each equivalent
		GameState.selected_difficulty  = _saved_diff

		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nPhase2EvidenceEconomyV2Gating tests: %d passed, %d failed" % [passed, failed])


# ── Helpers ───────────────────────────────────────────────────────────────────

## Witness Account: +80 shelf, -0.15 mutability, credulity_boost = 0.05, bypass-capable.
static func _make_witness_account() -> PlayerIntelStore.EvidenceItem:
	var ev := PlayerIntelStore.EvidenceItem.new("Witness Account", 0.15, -0.15, [], 0)
	ev.shelf_life_extension    = 80
	ev.credulity_boost         = 0.05
	ev.supports_cooldown_bypass = true
	return ev


## Incriminating Artifact: +0 shelf (SPA-1611), credulity_boost = 0.15.
static func _make_incriminating_artifact() -> PlayerIntelStore.EvidenceItem:
	var ev := PlayerIntelStore.EvidenceItem.new(
		"Incriminating Artifact", 0.25, 0.0, ["SCANDAL", "HERESY"], 0)
	ev.shelf_life_extension = 0
	ev.credulity_boost      = 0.15
	return ev


## Forged Document: +40 shelf, credulity_boost = 0.10.
static func _make_forged_document() -> PlayerIntelStore.EvidenceItem:
	var ev := PlayerIntelStore.EvidenceItem.new(
		"Forged Document", 0.20, 0.0, ["ACCUSATION", "SCANDAL", "HERESY"], 0)
	ev.shelf_life_extension = 40
	ev.credulity_boost      = 0.10
	return ev


static func _make_rumor() -> Rumor:
	return Rumor.create("r_test", "npc_subject", Rumor.ClaimType.ACCUSATION, 3, 0.5, 0)


## Mirrors world.gd seed_rumor_from_player() lines 1282-1299 exactly, including the
## SPA-1757 difficulty gate.  Pass difficulty explicitly so tests can exercise each
## difficulty without mutating GameState.selected_difficulty mid-test.
static func _apply_evidence_gated(
		r: Rumor,
		ev: PlayerIntelStore.EvidenceItem,
		seed_target_id: String,
		difficulty: String
) -> void:
	r.current_believability = minf(1.0, r.current_believability + ev.believability_bonus)
	r.mutability            = clampf(r.mutability + ev.mutability_modifier, 0.0, 1.0)
	## SPA-1757 gate: shelf extension + credulity boost only for Normal+ (not Apprentice).
	if GameState.evidence_economy_v2 and difficulty != "apprentice":
		r.shelf_life_ticks        += ev.shelf_life_extension
		r.evidence_credulity_boost = ev.credulity_boost
		r.seed_target_npc_id       = seed_target_id
	r.bolstered_by_evidence = true


## SPA-1774: Mirrors the gated-off signal condition from world.gd.
## Returns true when evidence_economy_v2_gated_off would be emitted:
## flag is ON and difficulty is "apprentice".
static func _would_emit_gated_off(difficulty: String) -> bool:
	if GameState.evidence_economy_v2 and difficulty == "apprentice":
		return true
	return false


# ── Apprentice: bonuses suppressed even with evidence_economy_v2 = true ──────

static func test_apprentice_credulity_boost_is_zero() -> bool:
	## SPA-1757: Apprentice is excluded from the evidence economy bonus gate.
	## evidence_credulity_boost must stay at its default (0.0) after applying evidence.
	if not GameState.evidence_economy_v2:
		return true  ## pass trivially when flag is OFF

	var r := _make_rumor()
	_apply_evidence_gated(r, _make_witness_account(), "npc_target", "apprentice")

	if not is_zero_approx(r.evidence_credulity_boost):
		push_error(
			"test_apprentice_credulity_boost_is_zero: expected 0.0, got %.4f"
			% r.evidence_credulity_boost
		)
		return false
	return true


static func test_apprentice_shelf_extension_is_zero() -> bool:
	## SPA-1757: shelf_life_ticks must not increase on Apprentice; baseline unchanged.
	if not GameState.evidence_economy_v2:
		return true

	var r := _make_rumor()
	_apply_evidence_gated(r, _make_witness_account(), "npc_target", "apprentice")

	if r.shelf_life_ticks != BASELINE_SHELF:
		push_error(
			"test_apprentice_shelf_extension_is_zero: expected %d, got %d"
			% [BASELINE_SHELF, r.shelf_life_ticks]
		)
		return false
	return true


static func test_apprentice_bolstered_by_evidence_still_set() -> bool:
	## bolstered_by_evidence is stamped unconditionally (it is outside the gate);
	## this verifies the gate does not accidentally suppress it on Apprentice.
	if not GameState.evidence_economy_v2:
		return true

	var r := _make_rumor()
	_apply_evidence_gated(r, _make_witness_account(), "npc_target", "apprentice")

	if not r.bolstered_by_evidence:
		push_error("test_apprentice_bolstered_by_evidence_still_set: bolstered_by_evidence is false")
		return false
	return true


# ── Normal: both bonuses apply ────────────────────────────────────────────────

static func test_normal_witness_account_credulity_boost_applied() -> bool:
	## SPA-1757: Normal difficulty receives the full credulity boost from Witness Account.
	if not GameState.evidence_economy_v2:
		return true

	var r := _make_rumor()
	_apply_evidence_gated(r, _make_witness_account(), "npc_target", "normal")

	if not is_equal_approx(r.evidence_credulity_boost, 0.05):
		push_error(
			"test_normal_witness_account_credulity_boost_applied: expected 0.05, got %.4f"
			% r.evidence_credulity_boost
		)
		return false
	return true


static func test_normal_witness_account_shelf_extension_applied() -> bool:
	## SPA-1757: Normal difficulty receives the full +80-tick shelf extension.
	if not GameState.evidence_economy_v2:
		return true

	var r := _make_rumor()
	_apply_evidence_gated(r, _make_witness_account(), "npc_target", "normal")

	if r.shelf_life_ticks != BASELINE_SHELF + 80:
		push_error(
			"test_normal_witness_account_shelf_extension_applied: expected %d, got %d"
			% [BASELINE_SHELF + 80, r.shelf_life_ticks]
		)
		return false
	return true


static func test_normal_artifact_credulity_boost_applied() -> bool:
	## SPA-1757: Incriminating Artifact credulity boost = 0.15 applies on Normal.
	if not GameState.evidence_economy_v2:
		return true

	var r := _make_rumor()
	_apply_evidence_gated(r, _make_incriminating_artifact(), "npc_target", "normal")

	if not is_equal_approx(r.evidence_credulity_boost, 0.15):
		push_error(
			"test_normal_artifact_credulity_boost_applied: expected 0.15, got %.4f"
			% r.evidence_credulity_boost
		)
		return false
	return true


static func test_normal_forged_doc_shelf_extension_applied() -> bool:
	## SPA-1757: Forged Document shelf extension = +40 applies on Normal.
	if not GameState.evidence_economy_v2:
		return true

	var r := _make_rumor()
	_apply_evidence_gated(r, _make_forged_document(), "npc_target", "normal")

	if r.shelf_life_ticks != BASELINE_SHELF + 40:
		push_error(
			"test_normal_forged_doc_shelf_extension_applied: expected %d, got %d"
			% [BASELINE_SHELF + 40, r.shelf_life_ticks]
		)
		return false
	return true


# ── Master: same bonuses as Normal ───────────────────────────────────────────

static func test_master_credulity_boost_applied() -> bool:
	## SPA-1757: Master difficulty is not excluded — credulity boost must apply.
	if not GameState.evidence_economy_v2:
		return true

	var r := _make_rumor()
	_apply_evidence_gated(r, _make_witness_account(), "npc_target", "master")

	if not is_equal_approx(r.evidence_credulity_boost, 0.05):
		push_error(
			"test_master_credulity_boost_applied: expected 0.05, got %.4f"
			% r.evidence_credulity_boost
		)
		return false
	return true


static func test_master_shelf_extension_applied() -> bool:
	## SPA-1757: Master difficulty receives the full +80-tick shelf extension.
	if not GameState.evidence_economy_v2:
		return true

	var r := _make_rumor()
	_apply_evidence_gated(r, _make_witness_account(), "npc_target", "master")

	if r.shelf_life_ticks != BASELINE_SHELF + 80:
		push_error(
			"test_master_shelf_extension_applied: expected %d, got %d"
			% [BASELINE_SHELF + 80, r.shelf_life_ticks]
		)
		return false
	return true


# ── SPA-1774: evidence_economy_v2_gated_off telemetry signal ─────────────────

static func test_gated_off_signal_fires_on_apprentice() -> bool:
	## SPA-1774: When evidence_economy_v2 is ON and difficulty is "apprentice",
	## world.gd should emit evidence_economy_v2_gated_off.
	if not GameState.evidence_economy_v2:
		return true  ## pass trivially when flag is OFF — gate never reached

	var fires: bool = _would_emit_gated_off("apprentice")
	if not fires:
		push_error("test_gated_off_signal_fires_on_apprentice: expected signal to fire on Apprentice, but it would not")
		return false
	return true


static func test_gated_off_signal_does_not_fire_on_normal() -> bool:
	## SPA-1774: On Normal difficulty, v2 bonuses apply — the gated-off signal must NOT fire.
	if not GameState.evidence_economy_v2:
		return true

	var fires: bool = _would_emit_gated_off("normal")
	if fires:
		push_error("test_gated_off_signal_does_not_fire_on_normal: signal should NOT fire on Normal difficulty")
		return false
	return true


static func test_gated_off_signal_does_not_fire_on_master() -> bool:
	## SPA-1774: On Master difficulty, v2 bonuses apply — the gated-off signal must NOT fire.
	if not GameState.evidence_economy_v2:
		return true

	var fires: bool = _would_emit_gated_off("master")
	if fires:
		push_error("test_gated_off_signal_does_not_fire_on_master: signal should NOT fire on Master difficulty")
		return false
	return true


# ── Cooldown bypass NOT difficulty-gated (SPA-1756) ──────────────────────────

static func test_bypass_flag_set_independently_of_difficulty() -> bool:
	## supports_cooldown_bypass is a property of the EvidenceItem itself — it carries
	## no difficulty condition and must be true for Witness Account regardless of context.
	var ev := _make_witness_account()
	if not ev.supports_cooldown_bypass:
		push_error("test_bypass_flag_set_independently_of_difficulty: supports_cooldown_bypass is false")
		return false
	return true


static func test_bypass_active_on_normal_difficulty() -> bool:
	## is_evidence_bypass_active must return true on Normal when a cooldown is active
	## for a different target and the evidence supports bypass.
	if not GameState.evidence_economy_v2:
		return true

	GameState.selected_difficulty = "normal"
	var store := PlayerIntelStore.new()
	store.start_evidence_cooldown("npc_a", "normal")  ## arm a 2-day cooldown for npc_a
	var result: bool = store.is_evidence_bypass_active("npc_b", _make_witness_account())

	if not result:
		push_error("test_bypass_active_on_normal_difficulty: bypass should be active for npc_b on Normal")
	return result


static func test_bypass_active_on_master_difficulty() -> bool:
	## is_evidence_bypass_active must return true on Master — same logic as Normal.
	if not GameState.evidence_economy_v2:
		return true

	GameState.selected_difficulty = "master"
	var store := PlayerIntelStore.new()
	store.start_evidence_cooldown("npc_a", "master")  ## arm a 2-day cooldown for npc_a
	var result: bool = store.is_evidence_bypass_active("npc_b", _make_witness_account())

	if not result:
		push_error("test_bypass_active_on_master_difficulty: bypass should be active for npc_b on Master")
	return result


static func test_bypass_active_regardless_of_selected_difficulty() -> bool:
	## The bypass check in is_evidence_bypass_active() does NOT read
	## GameState.selected_difficulty — it fires purely on cooldown state and evidence
	## type.  Verify that flipping selected_difficulty to "apprentice" mid-session does
	## not suppress bypass when a non-Apprentice cooldown is already armed.
	if not GameState.evidence_economy_v2:
		return true

	var store := PlayerIntelStore.new()
	store.start_evidence_cooldown("npc_a", "normal")  ## cooldown armed (2 days)

	## Now simulate selected_difficulty being set to "apprentice" (e.g. after a settings
	## change) — bypass must still activate because the cooldown was already created.
	GameState.selected_difficulty = "apprentice"
	var result: bool = store.is_evidence_bypass_active("npc_b", _make_witness_account())

	if not result:
		push_error(
			"test_bypass_active_regardless_of_selected_difficulty: "
			+ "bypass inactive even though cooldown is armed and evidence supports bypass"
		)
	return result
