## test_tutorial_controller.gd — Unit tests for TutorialController (SPA-981).
##
## Covers:
##   • Step constant sizes   — STEPS_S1 (7), S2/S3/S4 (3 each), S5/S6 (2 each)
##   • STEPS alias           — STEPS points to the same content as STEPS_S1
##   • Step index constants  — STEP_OPENING..STEP_COMPLETE match expected indices
##   • Step data integrity   — every step dict has "id" and "hint" keys
##   • Initial state         — is_active()==false, get_current_step()==-1,
##                             guided_tutorial_active==false before any setup
##   • skip() with no setup  — sets _active=false without crashing (null-safe paths)
##   • setup() scenario routing — _steps length matches selected scenario
##
## TutorialController extends Node.  Instantiated with .new() — _ready() is never
## called so @onready vars stay null and there is no scene-tree dependency.
## _build_toast() adds child nodes to the orphaned controller; this is safe in
## Godot 4 (nodes without a scene tree can still have children).
##
## Run from the Godot editor:  Scene → Run Script (or call run() directly).

class_name TestTutorialController
extends RefCounted


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Step constant sizes
		"test_steps_s1_has_7_steps",
		"test_steps_s2_has_3_steps",
		"test_steps_s3_has_3_steps",
		"test_steps_s4_has_3_steps",
		"test_steps_s5_has_2_steps",
		"test_steps_s6_has_2_steps",
		# STEPS alias
		"test_steps_alias_same_size_as_s1",
		"test_steps_alias_same_ids_as_s1",
		# Step index constants
		"test_step_index_constants_correct",
		# Step data integrity
		"test_steps_s1_all_have_id_and_hint",
		"test_steps_s2_all_have_id_and_hint",
		"test_steps_s3_all_have_id_and_hint",
		"test_steps_s4_all_have_id_and_hint",
		"test_steps_s5_all_have_id_and_hint",
		"test_steps_s6_all_have_id_and_hint",
		# Initial state (no setup)
		"test_initial_is_not_active",
		"test_initial_step_is_minus_one",
		"test_initial_guided_tutorial_inactive",
		# skip() without setup
		"test_skip_without_setup_sets_not_active",
		"test_skip_without_setup_sets_guided_false",
		# setup() scenario routing
		"test_setup_scenario_1_uses_s1_steps",
		"test_setup_scenario_2_uses_s2_steps",
		"test_setup_scenario_3_uses_s3_steps",
		"test_setup_scenario_4_uses_s4_steps",
		"test_setup_scenario_5_uses_s5_steps",
		"test_setup_scenario_6_uses_s6_steps",
		"test_setup_unknown_scenario_falls_back_to_s1",
		# SPA-1241: step_completed signal
		"test_step_completed_signal_exists",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nTutorialController tests: %d passed, %d failed" % [passed, failed])


# ── helpers ──────────────────────────────────────────────────────────────────

static func _make_ctrl() -> TutorialController:
	return TutorialController.new()


## Verify every dict in an Array has both "id" and "hint" keys.
static func _steps_have_id_and_hint(steps: Array) -> bool:
	for step_def in steps:
		for key in ["id", "hint"]:
			if not step_def.has(key):
				push_error("Step missing key '%s': %s" % [key, str(step_def)])
				return false
	return true


# ── Step constant sizes ───────────────────────────────────────────────────────

static func test_steps_s1_has_7_steps() -> bool:
	if TutorialController.STEPS_S1.size() != 7:
		push_error("test_steps_s1_has_7_steps: expected 7, got %d" % TutorialController.STEPS_S1.size())
		return false
	return true


static func test_steps_s2_has_3_steps() -> bool:
	if TutorialController.STEPS_S2.size() != 3:
		push_error("test_steps_s2_has_3_steps: expected 3, got %d" % TutorialController.STEPS_S2.size())
		return false
	return true


static func test_steps_s3_has_3_steps() -> bool:
	if TutorialController.STEPS_S3.size() != 3:
		push_error("test_steps_s3_has_3_steps: expected 3, got %d" % TutorialController.STEPS_S3.size())
		return false
	return true


static func test_steps_s4_has_3_steps() -> bool:
	if TutorialController.STEPS_S4.size() != 3:
		push_error("test_steps_s4_has_3_steps: expected 3, got %d" % TutorialController.STEPS_S4.size())
		return false
	return true


static func test_steps_s5_has_2_steps() -> bool:
	if TutorialController.STEPS_S5.size() != 2:
		push_error("test_steps_s5_has_2_steps: expected 2, got %d" % TutorialController.STEPS_S5.size())
		return false
	return true


static func test_steps_s6_has_2_steps() -> bool:
	if TutorialController.STEPS_S6.size() != 2:
		push_error("test_steps_s6_has_2_steps: expected 2, got %d" % TutorialController.STEPS_S6.size())
		return false
	return true


# ── STEPS alias ───────────────────────────────────────────────────────────────

static func test_steps_alias_same_size_as_s1() -> bool:
	if TutorialController.STEPS.size() != TutorialController.STEPS_S1.size():
		push_error("test_steps_alias_same_size_as_s1: STEPS.size()=%d STEPS_S1.size()=%d" % [
			TutorialController.STEPS.size(), TutorialController.STEPS_S1.size()])
		return false
	return true


static func test_steps_alias_same_ids_as_s1() -> bool:
	for i in range(TutorialController.STEPS.size()):
		var alias_id: String = TutorialController.STEPS[i]["id"]
		var s1_id:    String = TutorialController.STEPS_S1[i]["id"]
		if alias_id != s1_id:
			push_error("test_steps_alias_same_ids_as_s1: index %d: '%s' != '%s'" % [i, alias_id, s1_id])
			return false
	return true


# ── Step index constants ──────────────────────────────────────────────────────

static func test_step_index_constants_correct() -> bool:
	# Verify each named constant maps to the right position in STEPS_S1.
	var expected := {
		TutorialController.STEP_OPENING:       "gtut_opening",
		TutorialController.STEP_EXPLORE:       "gtut_explore",
		TutorialController.STEP_OBSERVE_INTEL: "gtut_observe_intel",
		TutorialController.STEP_EAVESDROP:     "gtut_eavesdrop",
		TutorialController.STEP_CRAFT_RUMOR:   "gtut_craft_rumor",
		TutorialController.STEP_WATCH_SPREAD:  "gtut_watch_spread",
		TutorialController.STEP_COMPLETE:      "gtut_complete",
	}
	for idx in expected:
		var expected_id: String = expected[idx]
		var actual_id:   String = TutorialController.STEPS_S1[idx]["id"]
		if actual_id != expected_id:
			push_error("test_step_index_constants_correct: step[%d] id='%s', expected='%s'" % [
				idx, actual_id, expected_id])
			return false
	return true


# ── Step data integrity ───────────────────────────────────────────────────────

static func test_steps_s1_all_have_id_and_hint() -> bool:
	return _steps_have_id_and_hint(TutorialController.STEPS_S1)


static func test_steps_s2_all_have_id_and_hint() -> bool:
	return _steps_have_id_and_hint(TutorialController.STEPS_S2)


static func test_steps_s3_all_have_id_and_hint() -> bool:
	return _steps_have_id_and_hint(TutorialController.STEPS_S3)


static func test_steps_s4_all_have_id_and_hint() -> bool:
	return _steps_have_id_and_hint(TutorialController.STEPS_S4)


static func test_steps_s5_all_have_id_and_hint() -> bool:
	return _steps_have_id_and_hint(TutorialController.STEPS_S5)


static func test_steps_s6_all_have_id_and_hint() -> bool:
	return _steps_have_id_and_hint(TutorialController.STEPS_S6)


# ── Initial state (before setup) ──────────────────────────────────────────────

static func test_initial_is_not_active() -> bool:
	var ctrl := _make_ctrl()
	return not ctrl.is_active()


static func test_initial_step_is_minus_one() -> bool:
	var ctrl := _make_ctrl()
	if ctrl.get_current_step() != -1:
		push_error("test_initial_step_is_minus_one: expected -1, got %d" % ctrl.get_current_step())
		return false
	return true


static func test_initial_guided_tutorial_inactive() -> bool:
	var ctrl := _make_ctrl()
	return not ctrl.guided_tutorial_active


# ── skip() without setup ──────────────────────────────────────────────────────

static func test_skip_without_setup_sets_not_active() -> bool:
	var ctrl := _make_ctrl()
	ctrl.skip()
	return not ctrl.is_active()


static func test_skip_without_setup_sets_guided_false() -> bool:
	var ctrl := _make_ctrl()
	ctrl.guided_tutorial_active = true  # force it on
	ctrl.skip()
	return not ctrl.guided_tutorial_active


# ── setup() scenario routing ──────────────────────────────────────────────────

## After setup() the internal _steps array must match the expected scenario sequence.
## We pass null for all refs — setup() guards each dependency independently.

static func _setup_ctrl_for_scenario(scenario_id: String) -> TutorialController:
	var ctrl := _make_ctrl()
	ctrl.setup(null, null, null, null, null, null, null, scenario_id)
	return ctrl


static func test_setup_scenario_1_uses_s1_steps() -> bool:
	var ctrl := _setup_ctrl_for_scenario("scenario_1")
	if ctrl._steps.size() != TutorialController.STEPS_S1.size():
		push_error("test_setup_scenario_1_uses_s1_steps: expected %d steps, got %d" % [
			TutorialController.STEPS_S1.size(), ctrl._steps.size()])
		return false
	return true


static func test_setup_scenario_2_uses_s2_steps() -> bool:
	var ctrl := _setup_ctrl_for_scenario("scenario_2")
	if ctrl._steps.size() != TutorialController.STEPS_S2.size():
		push_error("test_setup_scenario_2_uses_s2_steps: expected %d steps, got %d" % [
			TutorialController.STEPS_S2.size(), ctrl._steps.size()])
		return false
	return true


static func test_setup_scenario_3_uses_s3_steps() -> bool:
	var ctrl := _setup_ctrl_for_scenario("scenario_3")
	if ctrl._steps.size() != TutorialController.STEPS_S3.size():
		push_error("test_setup_scenario_3_uses_s3_steps: expected %d steps, got %d" % [
			TutorialController.STEPS_S3.size(), ctrl._steps.size()])
		return false
	return true


static func test_setup_scenario_4_uses_s4_steps() -> bool:
	var ctrl := _setup_ctrl_for_scenario("scenario_4")
	if ctrl._steps.size() != TutorialController.STEPS_S4.size():
		push_error("test_setup_scenario_4_uses_s4_steps: expected %d steps, got %d" % [
			TutorialController.STEPS_S4.size(), ctrl._steps.size()])
		return false
	return true


static func test_setup_scenario_5_uses_s5_steps() -> bool:
	var ctrl := _setup_ctrl_for_scenario("scenario_5")
	if ctrl._steps.size() != TutorialController.STEPS_S5.size():
		push_error("test_setup_scenario_5_uses_s5_steps: expected %d steps, got %d" % [
			TutorialController.STEPS_S5.size(), ctrl._steps.size()])
		return false
	return true


static func test_setup_scenario_6_uses_s6_steps() -> bool:
	var ctrl := _setup_ctrl_for_scenario("scenario_6")
	if ctrl._steps.size() != TutorialController.STEPS_S6.size():
		push_error("test_setup_scenario_6_uses_s6_steps: expected %d steps, got %d" % [
			TutorialController.STEPS_S6.size(), ctrl._steps.size()])
		return false
	return true


static func test_setup_unknown_scenario_falls_back_to_s1() -> bool:
	var ctrl := _setup_ctrl_for_scenario("scenario_99")
	if ctrl._steps.size() != TutorialController.STEPS_S1.size():
		push_error("test_setup_unknown_scenario_falls_back_to_s1: expected S1 size %d, got %d" % [
			TutorialController.STEPS_S1.size(), ctrl._steps.size()])
		return false
	return true


# ── SPA-1241: step_completed signal ──────────────────────────────────────────

static func test_step_completed_signal_exists() -> bool:
	var ctrl := _make_ctrl()
	return ctrl.has_signal("step_completed")
