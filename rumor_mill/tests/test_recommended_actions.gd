## test_recommended_actions.gd — Unit tests for JournalRecommendedActions (SPA-2653).
##
## Covers:
##   • _has_clergy_investigating() static helper:
##     - empty NPC list → false
##     - clergy investigator with EVALUATING illness/alys rumor → true
##     - clergy investigator with wrong claim type (ACCUSATION) → false
##     - clergy investigator with wrong subject NPC → false
##     - clergy investigator with non-EVALUATING state (REJECT) → false
##     - non-clergy NPC with matching rumor → false
##     - clergy NPC without role=investigator → false
##     - null entry in NPC list → does not crash, returns false
##     - multiple NPCs, only one matches → true
##
## SPA-2618 coverage: contradiction-risk suggestion fires before contradiction lands.
##
## JournalRecommendedActions._has_clergy_investigating() is a static method
## that accepts a plain Array — no scene-tree dependency. Tests can be run as
## a standalone GDScript (Scene → Run Script) or via the test runner.

class_name TestRecommendedActions
extends RefCounted


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		"test_empty_list_returns_false",
		"test_clergy_investigator_evaluating_illness_alys_returns_true",
		"test_clergy_investigator_wrong_claim_type_returns_false",
		"test_clergy_investigator_wrong_subject_returns_false",
		"test_clergy_investigator_reject_state_returns_false",
		"test_non_clergy_faction_returns_false",
		"test_clergy_no_investigator_role_returns_false",
		"test_null_npc_entry_no_crash",
		"test_multiple_npcs_one_match_returns_true",
		"test_clergy_investigator_believe_state_returns_false",
		"test_clergy_investigator_defending_state_returns_false",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nRecommendedActions tests: %d passed, %d failed" % [passed, failed])


# ── helpers ──────────────────────────────────────────────────────────────────

## Minimal NPC mock: a RefCounted that exposes npc_data and rumor_slots
## via property access (dictionary-based, compatible with `in` and `.get()`).
class MockNpc extends RefCounted:
	var npc_data: Dictionary = {}
	var rumor_slots: Dictionary = {}


## Build a Rumor with the given claim_type and subject_npc_id.
static func _make_rumor(claim_type: Rumor.ClaimType, subject_id: String) -> Rumor:
	return Rumor.create(
		"test_rumor_%d" % randi(),
		subject_id,
		claim_type,
		2,      # intensity
		0.5,    # mutability
		0       # tick
	)


## Build a slot in EVALUATING state (the state set by NpcRumorSlot._init).
static func _make_slot(rumor: Rumor) -> Rumor.NpcRumorSlot:
	return Rumor.NpcRumorSlot.new(rumor, "")


## Build a clergy investigator NPC with an illness/alys rumor in EVALUATING state.
static func _make_investigating_clergy(alys_id: String) -> MockNpc:
	var npc := MockNpc.new()
	npc.npc_data = {"id": "maren_nun", "faction": "clergy", "role": "investigator"}
	var r := _make_rumor(Rumor.ClaimType.ILLNESS, alys_id)
	var slot := _make_slot(r)
	npc.rumor_slots["r0"] = slot
	return npc


# ── tests ────────────────────────────────────────────────────────────────────

static func test_empty_list_returns_false() -> bool:
	return JournalRecommendedActions._has_clergy_investigating([], "alys_herbwife") == false


static func test_clergy_investigator_evaluating_illness_alys_returns_true() -> bool:
	# SPA-2618: primary trigger — clergy investigator evaluating illness/alys → warn player.
	var npc := _make_investigating_clergy("alys_herbwife")
	var result := JournalRecommendedActions._has_clergy_investigating([npc], "alys_herbwife")
	if not result:
		push_error("test_clergy_investigator_evaluating_illness_alys_returns_true: expected true")
		return false
	return true


static func test_clergy_investigator_wrong_claim_type_returns_false() -> bool:
	var npc := MockNpc.new()
	npc.npc_data = {"id": "maren_nun", "faction": "clergy", "role": "investigator"}
	var r := _make_rumor(Rumor.ClaimType.ACCUSATION, "alys_herbwife")
	var slot := _make_slot(r)
	npc.rumor_slots["r0"] = slot
	return JournalRecommendedActions._has_clergy_investigating([npc], "alys_herbwife") == false


static func test_clergy_investigator_wrong_subject_returns_false() -> bool:
	var npc := MockNpc.new()
	npc.npc_data = {"id": "maren_nun", "faction": "clergy", "role": "investigator"}
	var r := _make_rumor(Rumor.ClaimType.ILLNESS, "some_other_npc")
	var slot := _make_slot(r)
	npc.rumor_slots["r0"] = slot
	return JournalRecommendedActions._has_clergy_investigating([npc], "alys_herbwife") == false


static func test_clergy_investigator_reject_state_returns_false() -> bool:
	# Dismiss condition: once clergy NPC leaves EVALUATING (e.g. REJECT/DEFENDING),
	# the suggestion should stop firing.
	var npc := MockNpc.new()
	npc.npc_data = {"id": "maren_nun", "faction": "clergy", "role": "investigator"}
	var r := _make_rumor(Rumor.ClaimType.ILLNESS, "alys_herbwife")
	var slot := _make_slot(r)
	slot.state = Rumor.RumorState.REJECT
	npc.rumor_slots["r0"] = slot
	return JournalRecommendedActions._has_clergy_investigating([npc], "alys_herbwife") == false


static func test_non_clergy_faction_returns_false() -> bool:
	var npc := MockNpc.new()
	npc.npc_data = {"id": "tomas_reeve", "faction": "merchant", "role": "investigator"}
	var r := _make_rumor(Rumor.ClaimType.ILLNESS, "alys_herbwife")
	var slot := _make_slot(r)
	npc.rumor_slots["r0"] = slot
	return JournalRecommendedActions._has_clergy_investigating([npc], "alys_herbwife") == false


static func test_clergy_no_investigator_role_returns_false() -> bool:
	# A clergy NPC without role=investigator (e.g. the base Maren before scenario applies)
	# must not trigger the suggestion.
	var npc := MockNpc.new()
	npc.npc_data = {"id": "maren_nun", "faction": "clergy", "role": "Nun/Healer"}
	var r := _make_rumor(Rumor.ClaimType.ILLNESS, "alys_herbwife")
	var slot := _make_slot(r)
	npc.rumor_slots["r0"] = slot
	return JournalRecommendedActions._has_clergy_investigating([npc], "alys_herbwife") == false


static func test_null_npc_entry_no_crash() -> bool:
	# A null entry in the NPC list must not crash — graceful skip.
	var result := JournalRecommendedActions._has_clergy_investigating([null], "alys_herbwife")
	return result == false


static func test_multiple_npcs_one_match_returns_true() -> bool:
	var merchant := MockNpc.new()
	merchant.npc_data = {"id": "sybil_oats", "faction": "merchant", "role": "vendor"}
	var investigator := _make_investigating_clergy("alys_herbwife")
	var bystander := MockNpc.new()
	bystander.npc_data = {"id": "finn_monk", "faction": "clergy", "role": "Young Monk"}
	var result := JournalRecommendedActions._has_clergy_investigating(
		[merchant, investigator, bystander], "alys_herbwife"
	)
	if not result:
		push_error("test_multiple_npcs_one_match_returns_true: expected true with one matching investigator")
		return false
	return true


static func test_clergy_investigator_believe_state_returns_false() -> bool:
	# BELIEVE is not EVALUATING — suggestion should not fire.
	var npc := MockNpc.new()
	npc.npc_data = {"id": "maren_nun", "faction": "clergy", "role": "investigator"}
	var r := _make_rumor(Rumor.ClaimType.ILLNESS, "alys_herbwife")
	var slot := _make_slot(r)
	slot.state = Rumor.RumorState.BELIEVE
	npc.rumor_slots["r0"] = slot
	return JournalRecommendedActions._has_clergy_investigating([npc], "alys_herbwife") == false


static func test_clergy_investigator_defending_state_returns_false() -> bool:
	# DEFENDING = contradiction already fired; dismiss condition met.
	var npc := MockNpc.new()
	npc.npc_data = {"id": "maren_nun", "faction": "clergy", "role": "investigator"}
	var r := _make_rumor(Rumor.ClaimType.ILLNESS, "alys_herbwife")
	var slot := _make_slot(r)
	slot.state = Rumor.RumorState.DEFENDING
	npc.rumor_slots["r0"] = slot
	return JournalRecommendedActions._has_clergy_investigating([npc], "alys_herbwife") == false
