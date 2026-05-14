## test_journal_witness_marker.gd — Unit tests for the journal [W] witness
## marker introduced by SPA-2606.
##
## Covers:
##   • Rumor.evidence_type defaults to "" after Rumor.create()
##   • evidence_type is a String, not null
##   • evidence_type set to "Witness Account" satisfies the [W] render condition
##   • evidence_type "" or any non-witness value does not trigger the marker
##   • Journal.C_WITNESS constant is teal #66E6B8 (R≈0.4, G≈0.902, B≈0.722, A=1.0)
##   • C_WITNESS is visually distinct from C_KEY (the normal rumor-card button colour)
##
## Rumor is a plain RefCounted class — no Node, no scene tree required.
## Journal extends CanvasLayer; instantiated without the scene tree so only
## const-level members are exercised (C_WITNESS, C_KEY).  @onready UI nodes
## remain null and are not touched.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestJournalWitnessMarker
extends RefCounted

const JournalScript := preload("res://scripts/journal.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_rumor(evidence_type: String = "") -> Rumor:
	var r := Rumor.create("r_test", "npc_a", Rumor.ClaimType.ACCUSATION, 3, 0.1, 0, 330)
	r.evidence_type = evidence_type
	return r

static func _make_journal() -> CanvasLayer:
	return JournalScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Rumor.evidence_type field (SPA-2606 data model)
		"test_evidence_type_defaults_empty_after_create",
		"test_evidence_type_is_string_type",
		"test_evidence_type_can_be_set_to_witness_account",
		# Witness marker render condition
		"test_witness_condition_true_for_witness_account",
		"test_witness_condition_false_for_empty_evidence_type",
		"test_witness_condition_false_for_observation_type",
		"test_witness_condition_false_for_eavesdrop_type",
		"test_witness_condition_false_for_partial_match",
		# Journal.C_WITNESS colour constant (SPA-2606 palette)
		"test_c_witness_red_channel_is_teal",
		"test_c_witness_green_channel_is_teal",
		"test_c_witness_blue_channel_is_teal",
		"test_c_witness_is_fully_opaque",
		"test_c_witness_differs_from_c_key",
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
# Rumor.evidence_type field (SPA-2606 data model)
# ══════════════════════════════════════════════════════════════════════════════

func test_evidence_type_defaults_empty_after_create() -> bool:
	var r := Rumor.create("r1", "npc_a", Rumor.ClaimType.SCANDAL, 2, 0.2, 0, 200)
	return r.evidence_type == ""


func test_evidence_type_is_string_type() -> bool:
	var r := Rumor.create("r1", "npc_b", Rumor.ClaimType.PRAISE, 4, 0.5, 10, 300)
	return typeof(r.evidence_type) == TYPE_STRING


func test_evidence_type_can_be_set_to_witness_account() -> bool:
	var r := _make_rumor("Witness Account")
	return r.evidence_type == "Witness Account"


# ══════════════════════════════════════════════════════════════════════════════
# Witness marker render condition
# ══════════════════════════════════════════════════════════════════════════════

func test_witness_condition_true_for_witness_account() -> bool:
	var r := _make_rumor("Witness Account")
	return r.evidence_type == "Witness Account"


func test_witness_condition_false_for_empty_evidence_type() -> bool:
	var r := _make_rumor("")
	return not (r.evidence_type == "Witness Account")


func test_witness_condition_false_for_observation_type() -> bool:
	var r := _make_rumor("Observation")
	return not (r.evidence_type == "Witness Account")


func test_witness_condition_false_for_eavesdrop_type() -> bool:
	var r := _make_rumor("Eavesdrop")
	return not (r.evidence_type == "Witness Account")


func test_witness_condition_false_for_partial_match() -> bool:
	var r := _make_rumor("witness account")
	return not (r.evidence_type == "Witness Account")


# ══════════════════════════════════════════════════════════════════════════════
# Journal.C_WITNESS colour constant (SPA-2606 palette)
# ══════════════════════════════════════════════════════════════════════════════

func test_c_witness_red_channel_is_teal() -> bool:
	var j := _make_journal()
	return abs(j.C_WITNESS.r - 0.400) < 0.001


func test_c_witness_green_channel_is_teal() -> bool:
	var j := _make_journal()
	return abs(j.C_WITNESS.g - 0.902) < 0.001


func test_c_witness_blue_channel_is_teal() -> bool:
	var j := _make_journal()
	return abs(j.C_WITNESS.b - 0.722) < 0.001


func test_c_witness_is_fully_opaque() -> bool:
	var j := _make_journal()
	return abs(j.C_WITNESS.a - 1.0) < 0.001


func test_c_witness_differs_from_c_key() -> bool:
	var j := _make_journal()
	return j.C_WITNESS != j.C_KEY
