## test_rumor.gd — Unit tests for the Rumor data model (SPA-1041).
##
## Covers:
##   • Rumor.create(): id, subject, claim_type, intensity, believability, shelf_life
##   • base_believability(): intensity / 5.0
##   • is_expired(): true when current_believability <= 0
##   • decay_one_tick(): decrements believability by 1/shelf_life each tick
##   • is_positive_claim(): PRAISE and PROPHECY only
##   • claim_type_name(): string representation for every ClaimType
##   • NpcRumorSlot: initial state after construction
##
## Strategy: Rumor is a plain RefCounted class — no Node inheritance, no scene tree.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestRumor
extends RefCounted


# ── helpers ───────────────────────────────────────────────────────────────────

static func _make(
		rumor_id: String = "r1",
		subject: String = "npc_a",
		claim: Rumor.ClaimType = Rumor.ClaimType.ACCUSATION,
		intensity: int = 3,
		shelf: int = 330
) -> Rumor:
	return Rumor.create(rumor_id, subject, claim, intensity, 0.1, 0, shelf)


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# ── Rumor.create ──
		"test_create_sets_id",
		"test_create_sets_subject_npc_id",
		"test_create_sets_claim_type",
		"test_create_sets_intensity",
		"test_create_sets_shelf_life",
		"test_create_sets_initial_believability_from_intensity",
		"test_create_sets_lineage_parent_id",

		# ── base_believability ──
		"test_base_believability_intensity_1",
		"test_base_believability_intensity_5",
		"test_base_believability_intensity_3",

		# ── is_expired ──
		"test_is_expired_false_when_fresh",
		"test_is_expired_true_when_believability_zero",
		"test_is_expired_true_when_believability_negative",

		# ── decay_one_tick ──
		"test_decay_reduces_believability",
		"test_decay_amount_equals_one_over_shelf_life",
		"test_decay_does_not_go_below_zero",

		# ── is_positive_claim ──
		"test_praise_is_positive",
		"test_prophecy_is_positive",
		"test_accusation_is_not_positive",
		"test_scandal_is_not_positive",
		"test_illness_is_not_positive",
		"test_heresy_is_not_positive",
		"test_blackmail_is_not_positive",
		"test_death_is_not_positive",
		"test_secret_alliance_is_not_positive",
		"test_forbidden_romance_is_not_positive",

		# ── claim_type_name ──
		"test_claim_type_name_accusation",
		"test_claim_type_name_scandal",
		"test_claim_type_name_illness",
		"test_claim_type_name_praise",
		"test_claim_type_name_prophecy",
		"test_claim_type_name_death",
		"test_claim_type_name_heresy",
		"test_claim_type_name_blackmail",
		"test_claim_type_name_secret_alliance",
		"test_claim_type_name_forbidden_romance",

		# ── NpcRumorSlot ──
		"test_slot_initial_state_is_unaware",
		"test_slot_initial_ticks_in_state_is_zero",
		"test_slot_initial_heard_from_count_is_zero",
		"test_slot_stores_rumor_ref",
		"test_slot_stores_source_faction",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			print("  FAIL  %s" % method_name)
			failed += 1

	print("\n  %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Rumor.create
# ══════════════════════════════════════════════════════════════════════════════

func test_create_sets_id() -> bool:
	var r := _make("my_rumor")
	return r.id == "my_rumor"


func test_create_sets_subject_npc_id() -> bool:
	var r := _make("r1", "npc_villain")
	return r.subject_npc_id == "npc_villain"


func test_create_sets_claim_type() -> bool:
	var r := _make("r1", "s", Rumor.ClaimType.SCANDAL)
	return r.claim_type == Rumor.ClaimType.SCANDAL


func test_create_sets_intensity() -> bool:
	var r := _make("r1", "s", Rumor.ClaimType.ACCUSATION, 4)
	return r.intensity == 4


func test_create_sets_shelf_life() -> bool:
	var r := _make("r1", "s", Rumor.ClaimType.ACCUSATION, 3, 200)
	return r.shelf_life_ticks == 200


func test_create_sets_initial_believability_from_intensity() -> bool:
	var r := _make("r1", "s", Rumor.ClaimType.ACCUSATION, 5)
	# intensity 5 → base_believability = 5/5 = 1.0
	return absf(r.current_believability - 1.0) < 0.001


func test_create_sets_lineage_parent_id() -> bool:
	var r := Rumor.create("r1", "s", Rumor.ClaimType.ACCUSATION, 3, 0.1, 0, 330, "parent_r")
	return r.lineage_parent_id == "parent_r"


# ══════════════════════════════════════════════════════════════════════════════
# base_believability
# ══════════════════════════════════════════════════════════════════════════════

func test_base_believability_intensity_1() -> bool:
	var r := _make("r1", "s", Rumor.ClaimType.ACCUSATION, 1)
	return absf(r.base_believability() - 0.2) < 0.001


func test_base_believability_intensity_5() -> bool:
	var r := _make("r1", "s", Rumor.ClaimType.ACCUSATION, 5)
	return absf(r.base_believability() - 1.0) < 0.001


func test_base_believability_intensity_3() -> bool:
	var r := _make("r1", "s", Rumor.ClaimType.ACCUSATION, 3)
	return absf(r.base_believability() - 0.6) < 0.001


# ══════════════════════════════════════════════════════════════════════════════
# is_expired
# ══════════════════════════════════════════════════════════════════════════════

func test_is_expired_false_when_fresh() -> bool:
	var r := _make()
	return r.is_expired() == false


func test_is_expired_true_when_believability_zero() -> bool:
	var r := _make()
	r.current_believability = 0.0
	return r.is_expired() == true


func test_is_expired_true_when_believability_negative() -> bool:
	var r := _make()
	r.current_believability = -0.1
	return r.is_expired() == true


# ══════════════════════════════════════════════════════════════════════════════
# decay_one_tick
# ══════════════════════════════════════════════════════════════════════════════

func test_decay_reduces_believability() -> bool:
	var r := _make("r1", "s", Rumor.ClaimType.ACCUSATION, 3, 100)
	var before := r.current_believability
	r.decay_one_tick()
	return r.current_believability < before


func test_decay_amount_equals_one_over_shelf_life() -> bool:
	var shelf := 100
	var r := _make("r1", "s", Rumor.ClaimType.ACCUSATION, 3, shelf)
	var before := r.current_believability
	r.decay_one_tick()
	var delta := before - r.current_believability
	var expected := 1.0 / float(shelf)
	return absf(delta - expected) < 0.0001


func test_decay_does_not_go_below_zero() -> bool:
	var r := _make()
	r.current_believability = 0.001
	r.shelf_life_ticks = 1  # decay = 1.0 per tick — would go very negative
	r.decay_one_tick()
	return r.current_believability >= 0.0


# ══════════════════════════════════════════════════════════════════════════════
# is_positive_claim
# ══════════════════════════════════════════════════════════════════════════════

func test_praise_is_positive() -> bool:
	return Rumor.is_positive_claim(Rumor.ClaimType.PRAISE) == true


func test_prophecy_is_positive() -> bool:
	return Rumor.is_positive_claim(Rumor.ClaimType.PROPHECY) == true


func test_accusation_is_not_positive() -> bool:
	return Rumor.is_positive_claim(Rumor.ClaimType.ACCUSATION) == false


func test_scandal_is_not_positive() -> bool:
	return Rumor.is_positive_claim(Rumor.ClaimType.SCANDAL) == false


func test_illness_is_not_positive() -> bool:
	return Rumor.is_positive_claim(Rumor.ClaimType.ILLNESS) == false


func test_heresy_is_not_positive() -> bool:
	return Rumor.is_positive_claim(Rumor.ClaimType.HERESY) == false


func test_blackmail_is_not_positive() -> bool:
	return Rumor.is_positive_claim(Rumor.ClaimType.BLACKMAIL) == false


func test_death_is_not_positive() -> bool:
	return Rumor.is_positive_claim(Rumor.ClaimType.DEATH) == false


func test_secret_alliance_is_not_positive() -> bool:
	return Rumor.is_positive_claim(Rumor.ClaimType.SECRET_ALLIANCE) == false


func test_forbidden_romance_is_not_positive() -> bool:
	return Rumor.is_positive_claim(Rumor.ClaimType.FORBIDDEN_ROMANCE) == false


# ══════════════════════════════════════════════════════════════════════════════
# claim_type_name
# ══════════════════════════════════════════════════════════════════════════════

func test_claim_type_name_accusation() -> bool:
	return not Rumor.claim_type_name(Rumor.ClaimType.ACCUSATION).is_empty()


func test_claim_type_name_scandal() -> bool:
	return not Rumor.claim_type_name(Rumor.ClaimType.SCANDAL).is_empty()


func test_claim_type_name_illness() -> bool:
	return not Rumor.claim_type_name(Rumor.ClaimType.ILLNESS).is_empty()


func test_claim_type_name_praise() -> bool:
	return not Rumor.claim_type_name(Rumor.ClaimType.PRAISE).is_empty()


func test_claim_type_name_prophecy() -> bool:
	return not Rumor.claim_type_name(Rumor.ClaimType.PROPHECY).is_empty()


func test_claim_type_name_death() -> bool:
	return not Rumor.claim_type_name(Rumor.ClaimType.DEATH).is_empty()


func test_claim_type_name_heresy() -> bool:
	return not Rumor.claim_type_name(Rumor.ClaimType.HERESY).is_empty()


func test_claim_type_name_blackmail() -> bool:
	return not Rumor.claim_type_name(Rumor.ClaimType.BLACKMAIL).is_empty()


func test_claim_type_name_secret_alliance() -> bool:
	return not Rumor.claim_type_name(Rumor.ClaimType.SECRET_ALLIANCE).is_empty()


func test_claim_type_name_forbidden_romance() -> bool:
	return not Rumor.claim_type_name(Rumor.ClaimType.FORBIDDEN_ROMANCE).is_empty()


# ══════════════════════════════════════════════════════════════════════════════
# NpcRumorSlot
# ══════════════════════════════════════════════════════════════════════════════

func test_slot_initial_state_is_unaware() -> bool:
	var r := _make()
	var slot := Rumor.NpcRumorSlot.new(r, "merchant")
	return slot.state == Rumor.RumorState.UNAWARE


func test_slot_initial_ticks_in_state_is_zero() -> bool:
	var r := _make()
	var slot := Rumor.NpcRumorSlot.new(r, "merchant")
	return slot.ticks_in_state == 0


func test_slot_initial_heard_from_count_is_zero() -> bool:
	var r := _make()
	var slot := Rumor.NpcRumorSlot.new(r, "merchant")
	return slot.heard_from_count == 0


func test_slot_stores_rumor_ref() -> bool:
	var r := _make("slot_rumor")
	var slot := Rumor.NpcRumorSlot.new(r, "noble")
	return slot.rumor == r


func test_slot_stores_source_faction() -> bool:
	var r := _make()
	var slot := Rumor.NpcRumorSlot.new(r, "clergy")
	return slot.source_faction == "clergy"
