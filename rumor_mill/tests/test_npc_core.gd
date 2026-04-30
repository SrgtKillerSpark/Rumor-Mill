## test_npc_core.gd — GUT unit tests for the core NPC data model.
##
## Covers Rumor creation/decay, NpcRumorSlot state, claim-type helpers,
## and get_worst_rumor_state() priority logic — the "brain" of the NPC
## system that does not require a scene-tree or sprite assets to exercise.
##
## Run via GUT panel (Godot editor) or headless:
##   godot --headless -s addons/gut/gut_cmdln.gd \
##         -gtest=res://tests/test_npc_core.gd -gexit
##
## Integration tests that spin up a full NPC node (sprite, label, pathfinder)
## belong in tests/integration/test_npc_integration.gd (future work).

extends GutTest

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_rumor(
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
# Rumor.create — field initialisation
# ---------------------------------------------------------------------------

func test_create_sets_id() -> void:
	var r := _make_rumor("rumor_abc")
	assert_eq(r.id, "rumor_abc")


func test_create_sets_subject() -> void:
	var r := _make_rumor("r1", "npc_tomas")
	assert_eq(r.subject_npc_id, "npc_tomas")


func test_create_sets_claim_type() -> void:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.SCANDAL)
	assert_eq(r.claim_type, Rumor.ClaimType.SCANDAL)


func test_create_clamps_intensity_low() -> void:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 0)
	assert_eq(r.intensity, 1, "intensity below 1 should be clamped to 1")


func test_create_clamps_intensity_high() -> void:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 99)
	assert_eq(r.intensity, 5, "intensity above 5 should be clamped to 5")


func test_create_clamps_mutability_low() -> void:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 3, -0.5)
	assert_eq(r.mutability, 0.0)


func test_create_clamps_mutability_high() -> void:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 3, 9.9)
	assert_eq(r.mutability, 1.0)


func test_create_sets_created_tick() -> void:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 3, 0.5, 42)
	assert_eq(r.created_tick, 42)


func test_create_sets_shelf_life() -> void:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 3, 0.5, 0, 250)
	assert_eq(r.shelf_life_ticks, 250)


func test_create_no_lineage_parent_by_default() -> void:
	var r := _make_rumor()
	assert_eq(r.lineage_parent_id, "")


func test_create_stores_lineage_parent() -> void:
	var r := Rumor.create("child", "npc_x", Rumor.ClaimType.PRAISE, 2, 0.3, 0, 100, "parent_id")
	assert_eq(r.lineage_parent_id, "parent_id")


# ---------------------------------------------------------------------------
# Rumor.base_believability
# ---------------------------------------------------------------------------

func test_base_believability_intensity_1() -> void:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 1)
	assert_almost_eq(r.base_believability(), 0.2, 0.001)


func test_base_believability_intensity_5() -> void:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 5)
	assert_almost_eq(r.base_believability(), 1.0, 0.001)


func test_create_sets_initial_believability_from_intensity() -> void:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 3)
	assert_almost_eq(r.current_believability, 0.6, 0.001)


# ---------------------------------------------------------------------------
# Rumor.decay_one_tick / is_expired
# ---------------------------------------------------------------------------

func test_fresh_rumor_not_expired() -> void:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 3, 0.5, 0, 10)
	assert_false(r.is_expired())


func test_rumor_not_expired_after_partial_decay() -> void:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 3, 0.5, 0, 10)
	for i in range(5):
		r.decay_one_tick()
	assert_false(r.is_expired(), "should not expire after half its shelf life")


func test_rumor_expired_after_full_decay() -> void:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 3, 0.5, 0, 10)
	for i in range(10):
		r.decay_one_tick()
	assert_true(r.is_expired(), "should expire after shelf_life_ticks decays")


func test_decay_reduces_believability_monotonically() -> void:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 5, 0.5, 0, 20)
	var prev := r.current_believability
	for i in range(15):
		r.decay_one_tick()
		assert_lte(r.current_believability, prev,
			"believability must never increase during decay (tick %d)" % i)
		prev = r.current_believability


func test_decay_does_not_go_below_zero() -> void:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 1, 0.5, 0, 5)
	for i in range(20):
		r.decay_one_tick()
	assert_gte(r.current_believability, 0.0)


func test_zero_shelf_life_expires_immediately_on_decay() -> void:
	var r := _make_rumor("r1", "npc_x", Rumor.ClaimType.ACCUSATION, 5, 0.5, 0, 0)
	r.decay_one_tick()
	assert_true(r.is_expired())


# ---------------------------------------------------------------------------
# Rumor.claim_type_from_string
# ---------------------------------------------------------------------------

func test_claim_type_from_string_accusation() -> void:
	assert_eq(Rumor.claim_type_from_string("accusation"), Rumor.ClaimType.ACCUSATION)


func test_claim_type_from_string_scandal() -> void:
	assert_eq(Rumor.claim_type_from_string("scandal"), Rumor.ClaimType.SCANDAL)


func test_claim_type_from_string_illness() -> void:
	assert_eq(Rumor.claim_type_from_string("illness"), Rumor.ClaimType.ILLNESS)


func test_claim_type_from_string_prophecy() -> void:
	assert_eq(Rumor.claim_type_from_string("prophecy"), Rumor.ClaimType.PROPHECY)


func test_claim_type_from_string_praise() -> void:
	assert_eq(Rumor.claim_type_from_string("praise"), Rumor.ClaimType.PRAISE)


func test_claim_type_from_string_death() -> void:
	assert_eq(Rumor.claim_type_from_string("death"), Rumor.ClaimType.DEATH)


func test_claim_type_from_string_heresy() -> void:
	assert_eq(Rumor.claim_type_from_string("heresy"), Rumor.ClaimType.HERESY)


func test_claim_type_from_string_blackmail() -> void:
	assert_eq(Rumor.claim_type_from_string("blackmail"), Rumor.ClaimType.BLACKMAIL)


func test_claim_type_from_string_secret_alliance() -> void:
	assert_eq(Rumor.claim_type_from_string("secret_alliance"), Rumor.ClaimType.SECRET_ALLIANCE)


func test_claim_type_from_string_forbidden_romance() -> void:
	assert_eq(Rumor.claim_type_from_string("forbidden_romance"), Rumor.ClaimType.FORBIDDEN_ROMANCE)


func test_claim_type_from_string_unknown_defaults_to_accusation() -> void:
	assert_eq(Rumor.claim_type_from_string("nonsense_xyz"), Rumor.ClaimType.ACCUSATION)


func test_claim_type_from_string_is_case_insensitive() -> void:
	assert_eq(Rumor.claim_type_from_string("PRAISE"), Rumor.ClaimType.PRAISE)
	assert_eq(Rumor.claim_type_from_string("Heresy"), Rumor.ClaimType.HERESY)


# ---------------------------------------------------------------------------
# Rumor.is_positive_claim
# ---------------------------------------------------------------------------

func test_praise_is_positive() -> void:
	assert_true(Rumor.is_positive_claim(Rumor.ClaimType.PRAISE))


func test_prophecy_is_positive() -> void:
	assert_true(Rumor.is_positive_claim(Rumor.ClaimType.PROPHECY))


func test_accusation_is_negative() -> void:
	assert_false(Rumor.is_positive_claim(Rumor.ClaimType.ACCUSATION))


func test_scandal_is_negative() -> void:
	assert_false(Rumor.is_positive_claim(Rumor.ClaimType.SCANDAL))


func test_death_is_negative() -> void:
	assert_false(Rumor.is_positive_claim(Rumor.ClaimType.DEATH))


func test_heresy_is_negative() -> void:
	assert_false(Rumor.is_positive_claim(Rumor.ClaimType.HERESY))


# ---------------------------------------------------------------------------
# Rumor.state_name
# ---------------------------------------------------------------------------

func test_state_name_evaluating() -> void:
	assert_eq(Rumor.state_name(Rumor.RumorState.EVALUATING), "EVALUATING")


func test_state_name_believe() -> void:
	assert_eq(Rumor.state_name(Rumor.RumorState.BELIEVE), "BELIEVE")


func test_state_name_spread() -> void:
	assert_eq(Rumor.state_name(Rumor.RumorState.SPREAD), "SPREAD")


func test_state_name_expired() -> void:
	assert_eq(Rumor.state_name(Rumor.RumorState.EXPIRED), "EXPIRED")


# ---------------------------------------------------------------------------
# Rumor.NpcRumorSlot — initialisation
# ---------------------------------------------------------------------------

func test_npc_rumor_slot_init_state_is_evaluating() -> void:
	var r := _make_rumor()
	var slot := Rumor.NpcRumorSlot.new(r, "merchant")
	assert_eq(slot.state, Rumor.RumorState.EVALUATING)


func test_npc_rumor_slot_stores_rumor() -> void:
	var r := _make_rumor("r_slot")
	var slot := Rumor.NpcRumorSlot.new(r, "noble")
	assert_eq(slot.rumor.id, "r_slot")


func test_npc_rumor_slot_stores_source_faction() -> void:
	var r := _make_rumor()
	var slot := Rumor.NpcRumorSlot.new(r, "clergy")
	assert_eq(slot.source_faction, "clergy")


func test_npc_rumor_slot_ticks_in_state_starts_at_zero() -> void:
	var r := _make_rumor()
	var slot := Rumor.NpcRumorSlot.new(r, "merchant")
	assert_eq(slot.ticks_in_state, 0)


func test_npc_rumor_slot_heard_from_count_starts_at_one() -> void:
	var r := _make_rumor()
	var slot := Rumor.NpcRumorSlot.new(r, "merchant")
	assert_eq(slot.heard_from_count, 1)
