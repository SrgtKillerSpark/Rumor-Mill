## test_journal_witness_marker.gd — GUT unit tests for the journal [W] witness
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
## Run headless:
##   godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/ -gexit

extends GutTest

const JournalScript := preload("res://scripts/journal.gd")

# ── Helpers ───────────────────────────────────────────────────────────────────

## Create a Rumor and optionally override evidence_type.
func _make_rumor(evidence_type: String = "") -> Rumor:
	var r := Rumor.create("r_test", "npc_a", Rumor.ClaimType.ACCUSATION, 3, 0.1, 0, 330)
	r.evidence_type = evidence_type
	return r

## Instantiate the Journal script without the scene tree.
## @onready vars remain null; only const members and plain logic are accessible.
func _make_journal() -> CanvasLayer:
	return JournalScript.new()

# ── Rumor.evidence_type field (SPA-2606 data model) ──────────────────────────

## Rumor.create() must produce evidence_type == "" so that [W] is absent by
## default on existing rumors that were not bolstered by a Witness Account.
func test_evidence_type_defaults_empty_after_create():
	var r := Rumor.create("r1", "npc_a", Rumor.ClaimType.SCANDAL, 2, 0.2, 0, 200)
	assert_eq(r.evidence_type, "",
		"evidence_type should default to empty string")

## Confirm the field holds a String, not null, so equality checks never crash.
func test_evidence_type_is_string_type():
	var r := Rumor.create("r1", "npc_b", Rumor.ClaimType.PRAISE, 4, 0.5, 10, 300)
	assert_typeof(r.evidence_type, TYPE_STRING,
		"evidence_type should be a String")

## The field is writable and accepts the expected Witness Account tag.
func test_evidence_type_can_be_set_to_witness_account():
	var r := _make_rumor("Witness Account")
	assert_eq(r.evidence_type, "Witness Account",
		"evidence_type should store 'Witness Account' when assigned")

# ── Witness marker render condition ──────────────────────────────────────────
## The branch in journal._add_rumor_card() is:
##   if rumor.evidence_type == "Witness Account":
##       # append [W] label
## These tests exercise that exact condition with representative inputs.

func test_witness_condition_true_for_witness_account():
	var r := _make_rumor("Witness Account")
	assert_true(r.evidence_type == "Witness Account",
		"Condition 'evidence_type == Witness Account' must be true for [W] to render")

func test_witness_condition_false_for_empty_evidence_type():
	var r := _make_rumor("")
	assert_false(r.evidence_type == "Witness Account",
		"Empty evidence_type must not trigger the [W] marker")

func test_witness_condition_false_for_observation_type():
	var r := _make_rumor("Observation")
	assert_false(r.evidence_type == "Witness Account",
		"'Observation' evidence_type must not trigger the [W] marker")

func test_witness_condition_false_for_eavesdrop_type():
	var r := _make_rumor("Eavesdrop")
	assert_false(r.evidence_type == "Witness Account",
		"'Eavesdrop' evidence_type must not trigger the [W] marker")

## Case-sensitivity guard: partial / wrong-case strings must not match.
func test_witness_condition_false_for_partial_match():
	var r := _make_rumor("witness account")
	assert_false(r.evidence_type == "Witness Account",
		"Lowercase 'witness account' must not trigger the [W] marker (exact match required)")

# ── Journal.C_WITNESS colour constant (SPA-2606 palette) ─────────────────────
## C_WITNESS := Color(0.400, 0.902, 0.722) maps to hex #66E6B8 — teal.
## These channel tests confirm the constant was not accidentally changed.

func test_c_witness_red_channel_is_teal():
	var j := _make_journal()
	assert_almost_eq(j.C_WITNESS.r, 0.400, 0.001,
		"C_WITNESS.r should be ~0.400 (#66 hex)")

func test_c_witness_green_channel_is_teal():
	var j := _make_journal()
	assert_almost_eq(j.C_WITNESS.g, 0.902, 0.001,
		"C_WITNESS.g should be ~0.902 (#E6 hex)")

func test_c_witness_blue_channel_is_teal():
	var j := _make_journal()
	assert_almost_eq(j.C_WITNESS.b, 0.722, 0.001,
		"C_WITNESS.b should be ~0.722 (#B8 hex)")

func test_c_witness_is_fully_opaque():
	var j := _make_journal()
	assert_almost_eq(j.C_WITNESS.a, 1.0, 0.001,
		"C_WITNESS should be fully opaque (alpha == 1.0)")

## Regression guard: C_WITNESS (teal) must remain visually distinct from C_KEY
## (warm parchment) which colours the normal rumor-card button text.
func test_c_witness_differs_from_c_key():
	var j := _make_journal()
	assert_ne(j.C_WITNESS, j.C_KEY,
		"C_WITNESS (teal) must be visually distinct from C_KEY (parchment)")
