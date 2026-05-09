## test_npc_core.gd — Unit tests for the core NPC data model.
##
## Covers Rumor creation/decay, NpcRumorSlot state, claim-type helpers,
## and get_worst_rumor_state() priority logic — the "brain" of the NPC
## system that does not require a scene-tree or sprite assets to exercise.
##
## Integration tests that spin up a full NPC node (sprite, label, pathfinder)
## belong in tests/integration/test_npc_integration.gd (future work).

class_name TestNpcCore
extends RefCounted

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _make_rumor(
		rid: String = "r1",
		subject: String = "npc_edric",
		ctype: Rumor.ClaimType = Rumor.ClaimType.ACCUSATION,
		intensity: int = 3,
		mutability: float = 0.5,
		tick: int = 0,
		shelf: int = 100
) -> Rumor:
	return Rumor.create(rid, subject, ctype, intensity, mutability, tick, shelf)


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Rumor.create — field initialisation
		"test_create_sets_id",
		"test_create_sets_subject",
		"test_create_sets_claim_type",
		"test_create_clamps_intensity_low",
		"test_create_clamps_intensity_high",
		"test_create_clamps_mutability_low",
		"test_create_clamps_mutability_high",
		"test_create_sets_created_tick",
		"test_create_sets_shelf_life",
		"test_create_no_lineage_parent_by_default",
		"test_create_stores_lineage_parent",
		# Rumor.base_believability
		"test_base_believability_intensity_1",
		"test_base_believability_intensity_5",
		"test_create_sets_initial_believability_from_intensity",
		# Rumor.decay_one_tick / is_expired
		"test_fresh_rumor_not_expired",
		"test_rumor_not_expired_after_partial_decay",
		"test_rumor_expired_after_full_decay",
		"test_decay_reduces_believability_monotonically",
		"test_decay_does_not_go_below_zero",
		"test_zero_shelf_life_expires_immediately_on_decay",
		# Rumor.claim_type_from_string
		"test_claim_type_from_string_accusation",
		"test_claim_type_from_string_scandal",
		"test_claim_type_from_string_illness",
		"test_claim_type_from_string_prophecy",
		"test_claim_type_from_string_praise",
		"test_claim_type_from_string_death",
		"test_claim_type_from_string_heresy",
		"test_claim_type_from_string_blackmail",
		"test_claim_type_from_string_secret_alliance",
		"test_claim_type_from_string_forbidden_romance",
		"test_claim_type_from_string_unknown_defaults_to_accusation",
		"test_claim_type_from_string_is_case_insensitive",
		# Rumor.is_positive_claim
		"test_praise_is_positive",
		"test_prophecy_is_positive",
		"test_accusation_is_negative",
		"test_scandal_is_negative",
		"test_death_is_negative",
		"test_heresy_is_negative",
		# Rumor.state_name
		"test_state_name_evaluating",
		"test_state_name_believe",
		"test_state_name_spread",
		"test_state_name_expired",
		# Rumor.NpcRumorSlot — initialisation
		"test_npc_rumor_slot_init_state_is_evaluating",
		"test_npc_rumor_slot_stores_rumor",
		"test_npc_rumor_slot_stores_source_faction",
		"test_npc_rumor_slot_ticks_in_state_starts_at_zero",
		"test_npc_rumor_slot_heard_from_count_starts_at_one",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\n  NpcCore: %d passed, %d failed" % [passed, failed])


# ===========================================================================
# Rumor.create — field initialisation
# ===========================================================================

static func test_create_sets_id() -> bool:
	var r := _make_rumor("rumor_abc")
	return r.id == "rumor_abc"


static func test_create_sets_subject() -> bool:
	var r := _make_rumor("r1", "npc_tomas")
	return r.subject_npc_id == "npc_tomas"


static func test_create_sets_claim_type() -> bool:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.SCANDAL)
	return r.claim_type == Rumor.ClaimType.SCANDAL


static func test_create_clamps_intensity_low() -> bool:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 0)
	return r.intensity == 1


static func test_create_clamps_intensity_high() -> bool:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 99)
	return r.intensity == 5


static func test_create_clamps_mutability_low() -> bool:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 3, -0.5)
	return r.mutability == 0.0


static func test_create_clamps_mutability_high() -> bool:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 3, 9.9)
	return r.mutability == 1.0


static func test_create_sets_created_tick() -> bool:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 3, 0.5, 42)
	return r.created_tick == 42


static func test_create_sets_shelf_life() -> bool:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 3, 0.5, 0, 250)
	return r.shelf_life_ticks == 250


static func test_create_no_lineage_parent_by_default() -> bool:
	var r := _make_rumor()
	return r.lineage_parent_id == ""


static func test_create_stores_lineage_parent() -> bool:
	var r := Rumor.create("child", "npc_x", Rumor.ClaimType.PRAISE, 2, 0.3, 0, 100, "parent_id")
	return r.lineage_parent_id == "parent_id"


# ===========================================================================
# Rumor.base_believability
# ===========================================================================

static func test_base_believability_intensity_1() -> bool:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 1)
	return absf(r.base_believability() - 0.2) < 0.001


static func test_base_believability_intensity_5() -> bool:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 5)
	return absf(r.base_believability() - 1.0) < 0.001


static func test_create_sets_initial_believability_from_intensity() -> bool:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 3)
	return absf(r.current_believability - 0.6) < 0.001


# ===========================================================================
# Rumor.decay_one_tick / is_expired
# ===========================================================================

static func test_fresh_rumor_not_expired() -> bool:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 3, 0.5, 0, 10)
	return not r.is_expired()


static func test_rumor_not_expired_after_partial_decay() -> bool:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 3, 0.5, 0, 10)
	for i in range(5):
		r.decay_one_tick()
	return not r.is_expired()


static func test_rumor_expired_after_full_decay() -> bool:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 3, 0.5, 0, 10)
	for i in range(10):
		r.decay_one_tick()
	return r.is_expired()


static func test_decay_reduces_believability_monotonically() -> bool:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 5, 0.5, 0, 20)
	var prev := r.current_believability
	for i in range(15):
		r.decay_one_tick()
		if r.current_believability > prev:
			return false
		prev = r.current_believability
	return true


static func test_decay_does_not_go_below_zero() -> bool:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 1, 0.5, 0, 5)
	for i in range(20):
		r.decay_one_tick()
	return r.current_believability >= 0.0


static func test_zero_shelf_life_expires_immediately_on_decay() -> bool:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 5, 0.5, 0, 0)
	r.decay_one_tick()
	return r.is_expired()


# ===========================================================================
# Rumor.claim_type_from_string
# ===========================================================================

static func test_claim_type_from_string_accusation() -> bool:
	return Rumor.claim_type_from_string("accusation") == Rumor.ClaimType.ACCUSATION


static func test_claim_type_from_string_scandal() -> bool:
	return Rumor.claim_type_from_string("scandal") == Rumor.ClaimType.SCANDAL


static func test_claim_type_from_string_illness() -> bool:
	return Rumor.claim_type_from_string("illness") == Rumor.ClaimType.ILLNESS


static func test_claim_type_from_string_prophecy() -> bool:
	return Rumor.claim_type_from_string("prophecy") == Rumor.ClaimType.PROPHECY


static func test_claim_type_from_string_praise() -> bool:
	return Rumor.claim_type_from_string("praise") == Rumor.ClaimType.PRAISE


static func test_claim_type_from_string_death() -> bool:
	return Rumor.claim_type_from_string("death") == Rumor.ClaimType.DEATH


static func test_claim_type_from_string_heresy() -> bool:
	return Rumor.claim_type_from_string("heresy") == Rumor.ClaimType.HERESY


static func test_claim_type_from_string_blackmail() -> bool:
	return Rumor.claim_type_from_string("blackmail") == Rumor.ClaimType.BLACKMAIL


static func test_claim_type_from_string_secret_alliance() -> bool:
	return Rumor.claim_type_from_string("secret_alliance") == Rumor.ClaimType.SECRET_ALLIANCE


static func test_claim_type_from_string_forbidden_romance() -> bool:
	return Rumor.claim_type_from_string("forbidden_romance") == Rumor.ClaimType.FORBIDDEN_ROMANCE


static func test_claim_type_from_string_unknown_defaults_to_accusation() -> bool:
	return Rumor.claim_type_from_string("nonsense_xyz") == Rumor.ClaimType.ACCUSATION


static func test_claim_type_from_string_is_case_insensitive() -> bool:
	return (
		Rumor.claim_type_from_string("PRAISE") == Rumor.ClaimType.PRAISE
		and Rumor.claim_type_from_string("Heresy") == Rumor.ClaimType.HERESY
	)


# ===========================================================================
# Rumor.is_positive_claim
# ===========================================================================

static func test_praise_is_positive() -> bool:
	return Rumor.is_positive_claim(Rumor.ClaimType.PRAISE)


static func test_prophecy_is_positive() -> bool:
	return Rumor.is_positive_claim(Rumor.ClaimType.PROPHECY)


static func test_accusation_is_negative() -> bool:
	return not Rumor.is_positive_claim(Rumor.ClaimType.ACCUSATION)


static func test_scandal_is_negative() -> bool:
	return not Rumor.is_positive_claim(Rumor.ClaimType.SCANDAL)


static func test_death_is_negative() -> bool:
	return not Rumor.is_positive_claim(Rumor.ClaimType.DEATH)


static func test_heresy_is_negative() -> bool:
	return not Rumor.is_positive_claim(Rumor.ClaimType.HERESY)


# ===========================================================================
# Rumor.state_name
# ===========================================================================

static func test_state_name_evaluating() -> bool:
	return Rumor.state_name(Rumor.RumorState.EVALUATING) == "EVALUATING"


static func test_state_name_believe() -> bool:
	return Rumor.state_name(Rumor.RumorState.BELIEVE) == "BELIEVE"


static func test_state_name_spread() -> bool:
	return Rumor.state_name(Rumor.RumorState.SPREAD) == "SPREAD"


static func test_state_name_expired() -> bool:
	return Rumor.state_name(Rumor.RumorState.EXPIRED) == "EXPIRED"


# ===========================================================================
# Rumor.NpcRumorSlot — initialisation
# ===========================================================================

static func test_npc_rumor_slot_init_state_is_evaluating() -> bool:
	var r := _make_rumor()
	var slot := Rumor.NpcRumorSlot.new(r, "merchant")
	return slot.state == Rumor.RumorState.EVALUATING


static func test_npc_rumor_slot_stores_rumor() -> bool:
	var r := _make_rumor("r_slot")
	var slot := Rumor.NpcRumorSlot.new(r, "noble")
	return slot.rumor.id == "r_slot"


static func test_npc_rumor_slot_stores_source_faction() -> bool:
	var r := _make_rumor()
	var slot := Rumor.NpcRumorSlot.new(r, "clergy")
	return slot.source_faction == "clergy"


static func test_npc_rumor_slot_ticks_in_state_starts_at_zero() -> bool:
	var r := _make_rumor()
	var slot := Rumor.NpcRumorSlot.new(r, "merchant")
	return slot.ticks_in_state == 0


static func test_npc_rumor_slot_heard_from_count_starts_at_one() -> bool:
	var r := _make_rumor()
	var slot := Rumor.NpcRumorSlot.new(r, "merchant")
	return slot.heard_from_count == 1
