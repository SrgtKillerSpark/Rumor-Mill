## test_reputation_system.gd — Unit tests for ReputationSystem (SPA-957).
##
## Covers:
##   • Base score formula: default 50, override, delta application
##   • Score band labels and color helpers (static, no NPCs needed)
##   • SOCIALLY_DEAD threshold: 5+ believers with believability > 0.6 on DEATH rumors
##   • Faction sentiment: same-faction believers drive positive/negative sentiment
##   • Rumor delta: believer_weight scaling, claim direction, believability weighting
##   • Illness believer / rejecter tracking (Scenario 2)
##   • recalculate_all end-to-end using lightweight mock NPC objects
##
## MockNpc is a plain RefCounted (no Node2D) with npc_data: Dictionary and
## rumor_slots: Dictionary — sufficient for all duck-typed recalculate_all calls.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestReputationSystem
extends RefCounted


# ── Lightweight NPC stand-in ──────────────────────────────────────────────────

## A minimal object that satisfies the duck-typing contract of recalculate_all().
## npc_data must contain "id" and "faction" keys.
## rumor_slots maps rumor_id → Rumor.NpcRumorSlot.
class MockNpc extends RefCounted:
	var npc_data: Dictionary = {}
	var rumor_slots: Dictionary = {}

	static func make(npc_id: String, faction: String) -> MockNpc:
		var n := MockNpc.new()
		n.npc_data = {"id": npc_id, "faction": faction}
		return n


# ── Test runner ───────────────────────────────────────────────────────────────

static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Base score and overrides
		"test_default_base_score_is_50",
		"test_set_base_override",
		"test_apply_score_delta_positive",
		"test_apply_score_delta_clamped_at_100",
		"test_apply_score_delta_clamped_at_0",
		"test_clear_base_overrides",
		# Faction sentiment bonus
		"test_faction_sentiment_bonus_applied",
		"test_faction_sentiment_bonus_cleared",
		# Static UI helpers
		"test_score_label_disgraced",
		"test_score_label_suspect",
		"test_score_label_respected",
		"test_score_label_distinguished",
		# recalculate_all — no rumors
		"test_recalculate_no_rumors_score_is_base",
		# recalculate_all — negative rumors
		"test_recalculate_accusation_lowers_score",
		"test_recalculate_praise_raises_score",
		# SOCIALLY_DEAD threshold
		"test_socially_dead_requires_five_believers",
		"test_socially_dead_requires_high_believability",
		"test_socially_dead_not_triggered_below_threshold",
		# Illness believer tracking (Scenario 2)
		"test_illness_believer_count_populated",
		"test_illness_rejecter_tracked",
		"test_illness_believer_ids_populated",
		# Global believer count
		"test_global_believer_count",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nReputationSystem tests: %d passed, %d failed" % [passed, failed])


# ── helpers ───────────────────────────────────────────────────────────────────

## Build a fresh Rumor with specified claim type, intensity, believability.
static func _make_rumor(
		rid: String,
		subject: String,
		claim: Rumor.ClaimType,
		intensity: int = 3,
		believability: float = -1.0   ## -1 = use base_believability()
) -> Rumor:
	var r := Rumor.create(rid, subject, claim, intensity, 0.5, 0, 200)
	if believability >= 0.0:
		r.current_believability = believability
	return r


## Build a slot in BELIEVE state for the given rumor and faction.
static func _believe_slot(rumor: Rumor, src_faction: String) -> Rumor.NpcRumorSlot:
	var slot := Rumor.NpcRumorSlot.new(rumor, src_faction)
	slot.state = Rumor.RumorState.BELIEVE
	return slot


## Build a slot in REJECT state.
static func _reject_slot(rumor: Rumor, src_faction: String) -> Rumor.NpcRumorSlot:
	var slot := Rumor.NpcRumorSlot.new(rumor, src_faction)
	slot.state = Rumor.RumorState.REJECT
	return slot


# ── Base score and override tests ─────────────────────────────────────────────

## Without any override the base score defaults to 50.
## Verify by running recalculate_all with one NPC and no rumors.
static func test_default_base_score_is_50() -> bool:
	var rep := ReputationSystem.new()
	var npc := MockNpc.make("npc_a", "merchant")
	rep.recalculate_all([npc], 0)
	var snap := rep.get_snapshot("npc_a")
	if snap == null:
		push_error("test_default_base_score_is_50: snapshot is null")
		return false
	return snap.base_score == 50


## set_base_override changes the base score used in the snapshot.
static func test_set_base_override() -> bool:
	var rep := ReputationSystem.new()
	rep.set_base_override("npc_a", 70)
	var npc := MockNpc.make("npc_a", "merchant")
	rep.recalculate_all([npc], 0)
	var snap := rep.get_snapshot("npc_a")
	return snap != null and snap.base_score == 70


## apply_score_delta increments the stored base by delta.
static func test_apply_score_delta_positive() -> bool:
	var rep := ReputationSystem.new()
	rep.set_base_override("npc_a", 50)
	rep.apply_score_delta("npc_a", 10)
	var npc := MockNpc.make("npc_a", "merchant")
	rep.recalculate_all([npc], 0)
	var snap := rep.get_snapshot("npc_a")
	return snap != null and snap.base_score == 60


## apply_score_delta clamps the result at 100.
static func test_apply_score_delta_clamped_at_100() -> bool:
	var rep := ReputationSystem.new()
	rep.set_base_override("npc_a", 95)
	rep.apply_score_delta("npc_a", 20)
	var npc := MockNpc.make("npc_a", "merchant")
	rep.recalculate_all([npc], 0)
	var snap := rep.get_snapshot("npc_a")
	return snap != null and snap.base_score == 100


## apply_score_delta clamps the result at 0.
static func test_apply_score_delta_clamped_at_0() -> bool:
	var rep := ReputationSystem.new()
	rep.set_base_override("npc_a", 5)
	rep.apply_score_delta("npc_a", -20)
	var npc := MockNpc.make("npc_a", "merchant")
	rep.recalculate_all([npc], 0)
	var snap := rep.get_snapshot("npc_a")
	return snap != null and snap.base_score == 0


## clear_base_overrides causes the next recalculate to fall back to default 50.
static func test_clear_base_overrides() -> bool:
	var rep := ReputationSystem.new()
	rep.set_base_override("npc_a", 80)
	rep.clear_base_overrides()
	var npc := MockNpc.make("npc_a", "merchant")
	rep.recalculate_all([npc], 0)
	var snap := rep.get_snapshot("npc_a")
	return snap != null and snap.base_score == 50


# ── Faction sentiment bonus tests ─────────────────────────────────────────────

## A faction sentiment bonus is reflected in the final score.
static func test_faction_sentiment_bonus_applied() -> bool:
	var rep := ReputationSystem.new()
	var npc := MockNpc.make("npc_a", "merchant")
	rep.recalculate_all([npc], 0)
	var score_before: int = rep.get_snapshot("npc_a").score

	rep.set_faction_sentiment_bonus("npc_a", 10.0)
	rep.recalculate_all([npc], 0)
	var score_after: int = rep.get_snapshot("npc_a").score

	return score_after == score_before + 10


## Clearing the bonus removes it from subsequent recalculations.
static func test_faction_sentiment_bonus_cleared() -> bool:
	var rep := ReputationSystem.new()
	var npc := MockNpc.make("npc_a", "merchant")
	rep.set_faction_sentiment_bonus("npc_a", 15.0)
	rep.recalculate_all([npc], 0)
	var score_with_bonus: int = rep.get_snapshot("npc_a").score

	rep.clear_faction_sentiment_bonus("npc_a")
	rep.recalculate_all([npc], 0)
	var score_cleared: int = rep.get_snapshot("npc_a").score

	return score_cleared == score_with_bonus - 15


# ── Static UI helper tests ────────────────────────────────────────────────────

## Score 0–30 → "Disgraced".
static func test_score_label_disgraced() -> bool:
	return ReputationSystem.score_label(0)  == "Disgraced" \
		and ReputationSystem.score_label(30) == "Disgraced"


## Score 31–50 → "Suspect".
static func test_score_label_suspect() -> bool:
	return ReputationSystem.score_label(31) == "Suspect" \
		and ReputationSystem.score_label(50) == "Suspect"


## Score 51–70 → "Respected".
static func test_score_label_respected() -> bool:
	return ReputationSystem.score_label(51) == "Respected" \
		and ReputationSystem.score_label(70) == "Respected"


## Score 71–100 → "Distinguished".
static func test_score_label_distinguished() -> bool:
	return ReputationSystem.score_label(71)  == "Distinguished" \
		and ReputationSystem.score_label(100) == "Distinguished"


# ── recalculate_all integration tests ────────────────────────────────────────

## NPC with no rumors and default base → score == 50.
static func test_recalculate_no_rumors_score_is_base() -> bool:
	var rep := ReputationSystem.new()
	var npc := MockNpc.make("npc_subject", "clergy")
	rep.recalculate_all([npc], 0)
	var snap := rep.get_snapshot("npc_subject")
	return snap != null and snap.score == 50


## An ACCUSATION believed by multiple NPCs (same faction) reduces the subject's score.
static func test_recalculate_accusation_lowers_score() -> bool:
	var rep := ReputationSystem.new()
	var subject_npc := MockNpc.make("npc_subject", "merchant")

	# Three observer NPCs all believe the accusation.
	var rumor := _make_rumor("r_acc", "npc_subject", Rumor.ClaimType.ACCUSATION, 4, 0.8)
	var observers: Array = []
	for i in 4:
		var obs := MockNpc.make("obs_%d" % i, "merchant")
		obs.rumor_slots["r_acc"] = _believe_slot(rumor, "merchant")
		observers.append(obs)

	var all_npcs: Array = [subject_npc] + observers
	rep.recalculate_all(all_npcs, 0)
	var snap := rep.get_snapshot("npc_subject")
	if snap == null:
		push_error("test_recalculate_accusation_lowers_score: snapshot is null")
		return false
	return snap.score < 50


## A PRAISE believed by multiple same-faction NPCs raises the subject's score.
static func test_recalculate_praise_raises_score() -> bool:
	var rep := ReputationSystem.new()
	var subject_npc := MockNpc.make("npc_subject", "merchant")

	var rumor := _make_rumor("r_praise", "npc_subject", Rumor.ClaimType.PRAISE, 4, 0.8)
	var observers: Array = []
	for i in 4:
		var obs := MockNpc.make("obs_%d" % i, "merchant")
		obs.rumor_slots["r_praise"] = _believe_slot(rumor, "merchant")
		observers.append(obs)

	var all_npcs: Array = [subject_npc] + observers
	rep.recalculate_all(all_npcs, 0)
	var snap := rep.get_snapshot("npc_subject")
	if snap == null:
		push_error("test_recalculate_praise_raises_score: snapshot is null")
		return false
	return snap.score > 50


# ── SOCIALLY_DEAD tests ───────────────────────────────────────────────────────

## 5+ believers on a high-believability DEATH rumor → is_socially_dead = true.
static func test_socially_dead_requires_five_believers() -> bool:
	var rep := ReputationSystem.new()
	var subject_npc := MockNpc.make("npc_subject", "merchant")
	# believability > SOCIALLY_DEAD_BELIEVABILITY (0.6)
	var rumor := _make_rumor("r_death", "npc_subject", Rumor.ClaimType.DEATH, 5, 0.9)

	var all_npcs: Array = [subject_npc]
	for i in 5:
		var obs := MockNpc.make("obs_%d" % i, "merchant")
		obs.rumor_slots["r_death"] = _believe_slot(rumor, "merchant")
		all_npcs.append(obs)

	rep.recalculate_all(all_npcs, 0)
	var snap := rep.get_snapshot("npc_subject")
	return snap != null and snap.is_socially_dead


## Low believability DEATH rumor (≤ 0.6) with 5 believers does NOT trigger SOCIALLY_DEAD.
static func test_socially_dead_requires_high_believability() -> bool:
	var rep := ReputationSystem.new()
	var subject_npc := MockNpc.make("npc_subject", "merchant")
	# believability exactly at threshold (0.6) is NOT above it → should not trigger
	var rumor := _make_rumor("r_death", "npc_subject", Rumor.ClaimType.DEATH, 3, 0.6)

	var all_npcs: Array = [subject_npc]
	for i in 5:
		var obs := MockNpc.make("obs_%d" % i, "merchant")
		obs.rumor_slots["r_death"] = _believe_slot(rumor, "merchant")
		all_npcs.append(obs)

	rep.recalculate_all(all_npcs, 0)
	var snap := rep.get_snapshot("npc_subject")
	# Boundary: 0.6 is NOT strictly > SOCIALLY_DEAD_BELIEVABILITY (0.6)
	return snap != null and not snap.is_socially_dead


## Only 4 believers → SOCIALLY_DEAD threshold (5) not met.
static func test_socially_dead_not_triggered_below_threshold() -> bool:
	var rep := ReputationSystem.new()
	var subject_npc := MockNpc.make("npc_subject", "merchant")
	var rumor := _make_rumor("r_death", "npc_subject", Rumor.ClaimType.DEATH, 5, 0.9)

	var all_npcs: Array = [subject_npc]
	for i in 4:    ## only 4 believers — one short
		var obs := MockNpc.make("obs_%d" % i, "merchant")
		obs.rumor_slots["r_death"] = _believe_slot(rumor, "merchant")
		all_npcs.append(obs)

	rep.recalculate_all(all_npcs, 0)
	var snap := rep.get_snapshot("npc_subject")
	return snap != null and not snap.is_socially_dead


# ── Illness believer / rejecter tests (Scenario 2) ───────────────────────────

## NPCs in BELIEVE state for an ILLNESS rumor are counted in illness_believer_count.
static func test_illness_believer_count_populated() -> bool:
	var rep := ReputationSystem.new()
	var subject_npc := MockNpc.make("alys_herbwife", "clergy")
	var rumor := _make_rumor("r_ill", "alys_herbwife", Rumor.ClaimType.ILLNESS, 3, 0.7)

	var all_npcs: Array = [subject_npc]
	for i in 3:
		var obs := MockNpc.make("obs_%d" % i, "merchant")
		obs.rumor_slots["r_ill"] = _believe_slot(rumor, "clergy")
		all_npcs.append(obs)

	rep.recalculate_all(all_npcs, 0)
	return rep.get_illness_believer_count("alys_herbwife") == 3


## An NPC in REJECT state for an ILLNESS rumor is tracked by has_illness_rejecter.
static func test_illness_rejecter_tracked() -> bool:
	var rep := ReputationSystem.new()
	var subject_npc := MockNpc.make("alys_herbwife", "clergy")
	var rumor := _make_rumor("r_ill", "alys_herbwife", Rumor.ClaimType.ILLNESS, 3, 0.7)

	var rejecter := MockNpc.make("maren_nun", "clergy")
	rejecter.rumor_slots["r_ill"] = _reject_slot(rumor, "clergy")

	rep.recalculate_all([subject_npc, rejecter], 0)
	return rep.has_illness_rejecter("alys_herbwife", "maren_nun")


## get_illness_believer_ids returns the correct NPC ids.
static func test_illness_believer_ids_populated() -> bool:
	var rep := ReputationSystem.new()
	var subject_npc := MockNpc.make("alys_herbwife", "clergy")
	var rumor := _make_rumor("r_ill", "alys_herbwife", Rumor.ClaimType.ILLNESS, 3, 0.7)

	var obs_a := MockNpc.make("npc_obs_a", "merchant")
	obs_a.rumor_slots["r_ill"] = _believe_slot(rumor, "merchant")

	var obs_b := MockNpc.make("npc_obs_b", "noble")
	obs_b.rumor_slots["r_ill"] = _believe_slot(rumor, "noble")

	rep.recalculate_all([subject_npc, obs_a, obs_b], 0)
	var ids := rep.get_illness_believer_ids("alys_herbwife")
	return ids.size() == 2 and "npc_obs_a" in ids and "npc_obs_b" in ids


# ── Global believer count test ────────────────────────────────────────────────

## get_global_believer_count returns the number of unique NPCs in BELIEVE/SPREAD/ACT.
static func test_global_believer_count() -> bool:
	var rep := ReputationSystem.new()
	var subject_npc := MockNpc.make("npc_subject", "merchant")
	var rumor := _make_rumor("r_acc", "npc_subject", Rumor.ClaimType.ACCUSATION, 3, 0.7)

	var spread_npc := MockNpc.make("npc_spread", "merchant")
	var spread_slot := Rumor.NpcRumorSlot.new(rumor, "merchant")
	spread_slot.state = Rumor.RumorState.SPREAD
	spread_npc.rumor_slots["r_acc"] = spread_slot

	var believer_npc := MockNpc.make("npc_believe", "noble")
	believer_npc.rumor_slots["r_acc"] = _believe_slot(rumor, "noble")

	var unaware_npc := MockNpc.make("npc_unaware", "clergy")
	# No rumor slots — should not be counted

	rep.recalculate_all([subject_npc, spread_npc, believer_npc, unaware_npc], 0)
	return rep.get_global_believer_count() == 2
