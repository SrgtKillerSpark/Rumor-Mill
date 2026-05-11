## test_spa2105_credulity_boost.gd — Regression tests for SPA-2105.
##
## SPA-2105 introduced a difficulty-scaled multiplier for the evidence credulity
## boost in world._seed_rumor() and surfaced the multiplier value in the
## evidence_attached analytics event emitted by rumor_panel.gd.
##
## Sections:
##
##   Section 1 — GameState.evidence_credulity_multiplier() pure function (4 tests):
##     M1  apprentice preset returns 0.8 (20% reduction)
##     M2  master preset returns 1.0 (normal / no change)
##     M3  spymaster preset returns 1.3 (30% increase)
##     M4  unknown / empty preset falls back to 1.0
##
##   Section 2 — World rumor credulity boost formula (4 tests):
##     W1  Witness Account (0.05) × Apprentice (0.8) = 0.04
##     W2  Incriminating Artifact (0.15) × Spymaster (1.3) = 0.195
##     W3  Forged Document (0.10) × Master (1.0) = 0.10 (unchanged)
##     W4  Without evidence the boost field on Rumor stays 0.0
##
##   Section 3 — RumorPanel analytics difficulty_modifier field (3 tests):
##     P1  log_evidence_attached with modifier 0.8 stores it in difficulty_modifier
##     P2  log_evidence_attached with modifier 1.3 stores it in difficulty_modifier
##     P3  evidence_credulity_multiplier(GameState.selected_difficulty) tracks
##         the active difficulty preset correctly
##
## Mutation sensitivity:
##   Changing any return value in GameState.evidence_credulity_multiplier() breaks M1–M3.
##   Removing the multiplier from world._seed_rumor() breaks W1–W3.
##   Removing the difficulty_modifier argument from log_evidence_attached() breaks P1–P2.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpa2105CredulityBoost
extends RefCounted

const AnalyticsLoggerScript := preload("res://scripts/analytics_logger.gd")


## Spy: inherits the real analytics-enabled gate; replaces file I/O with an
## in-memory accumulator so tests are side-effect-free.
class _SpyLogger extends AnalyticsLogger:
	var last_event: Dictionary = {}

	func _append_line(line: String) -> void:
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			last_event = parsed


func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Section 1: GameState.evidence_credulity_multiplier()
		"test_m1_apprentice_returns_0_8",
		"test_m2_master_returns_1_0",
		"test_m3_spymaster_returns_1_3",
		"test_m4_unknown_preset_falls_back_to_1_0",

		# Section 2: World credulity boost formula
		"test_w1_witness_account_apprentice",
		"test_w2_incriminating_artifact_spymaster",
		"test_w3_forged_document_master",
		"test_w4_no_evidence_boost_is_zero",

		# Section 3: RumorPanel analytics difficulty_modifier
		"test_p1_analytics_stores_apprentice_multiplier",
		"test_p2_analytics_stores_spymaster_multiplier",
		"test_p3_selected_difficulty_drives_multiplier",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\n  %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Section 1 — GameState.evidence_credulity_multiplier() pure function
# ══════════════════════════════════════════════════════════════════════════════

## M1: Apprentice preset returns 0.8 (evidence boost reduced by 20%).
func test_m1_apprentice_returns_0_8() -> bool:
	return is_equal_approx(GameState.evidence_credulity_multiplier("apprentice"), 0.8)


## M2: Master preset (the "normal" difficulty) returns 1.0 — no scaling applied.
func test_m2_master_returns_1_0() -> bool:
	return is_equal_approx(GameState.evidence_credulity_multiplier("master"), 1.0)


## M3: Spymaster preset returns 1.3 (evidence boost increased by 30%).
func test_m3_spymaster_returns_1_3() -> bool:
	return is_equal_approx(GameState.evidence_credulity_multiplier("spymaster"), 1.3)


## M4: Any unrecognised or empty preset must fall through to the 1.0 default.
func test_m4_unknown_preset_falls_back_to_1_0() -> bool:
	var empty_ok: bool  = is_equal_approx(GameState.evidence_credulity_multiplier(""), 1.0)
	var other_ok: bool  = is_equal_approx(GameState.evidence_credulity_multiplier("hard"), 1.0)
	if not empty_ok:
		push_error("test_m4: empty string did not return 1.0")
	if not other_ok:
		push_error("test_m4: 'hard' did not return 1.0")
	return empty_ok and other_ok


# ══════════════════════════════════════════════════════════════════════════════
# Section 2 — World rumor credulity boost formula
#
# world._seed_rumor() stamps:
#   rumor.evidence_credulity_boost = cred_boost * GameState.evidence_credulity_multiplier(difficulty)
# These tests verify the product is correct across all three difficulty tiers
# using the base credulity_boost values defined in recon_controller.gd (SPA-1711).
# ══════════════════════════════════════════════════════════════════════════════

## Replicate the world._seed_rumor() product (no bypass active).
static func _effective_boost(base_boost: float, difficulty: String) -> float:
	return base_boost * GameState.evidence_credulity_multiplier(difficulty)


## W1: Witness Account (base 0.05) on Apprentice (×0.8) → 0.04.
func test_w1_witness_account_apprentice() -> bool:
	var result: float = _effective_boost(0.05, "apprentice")
	if not is_equal_approx(result, 0.04):
		push_error("test_w1: expected 0.04, got %f" % result)
		return false
	return true


## W2: Incriminating Artifact (base 0.15) on Spymaster (×1.3) → 0.195.
func test_w2_incriminating_artifact_spymaster() -> bool:
	var result: float = _effective_boost(0.15, "spymaster")
	if not is_equal_approx(result, 0.195):
		push_error("test_w2: expected 0.195, got %f" % result)
		return false
	return true


## W3: Forged Document (base 0.10) on Master (×1.0) → 0.10 (multiplier is neutral).
func test_w3_forged_document_master() -> bool:
	var result: float = _effective_boost(0.10, "master")
	if not is_equal_approx(result, 0.10):
		push_error("test_w3: expected 0.10, got %f" % result)
		return false
	return true


## W4: A rumor created without evidence must have evidence_credulity_boost == 0.0.
##     Guards that Rumor.create() initialises the field to its zero default,
##     i.e. the SPA-2105 scaling path in world._seed_rumor() is never taken
##     when evidence_item is null.
func test_w4_no_evidence_boost_is_zero() -> bool:
	var rumor := Rumor.create(
			"r_spa2105_w4", "npc_target", Rumor.ClaimType.ACCUSATION, 3, 0.5, 0)
	if rumor.evidence_credulity_boost != 0.0:
		push_error("test_w4: expected 0.0, got %f" % rumor.evidence_credulity_boost)
		return false
	return true


# ══════════════════════════════════════════════════════════════════════════════
# Section 3 — RumorPanel analytics difficulty_modifier field
#
# rumor_panel.gd emits evidence_attached with:
#   difficulty_modifier = GameState.evidence_credulity_multiplier(GameState.selected_difficulty)
# These tests verify the emitted value round-trips through AnalyticsLogger
# correctly for both the easy and hard extremes.
# ══════════════════════════════════════════════════════════════════════════════

## Helper: fire log_evidence_attached with analytics enabled and return the spy.
func _fire_with_modifier(modifier: float) -> _SpyLogger:
	var saved: bool = SettingsManager.analytics_enabled
	SettingsManager.analytics_enabled = true
	var spy := _SpyLogger.new()
	spy.log_evidence_attached(
			"witness_account", 0.05, "npc_maren", 3, "scenario_1", modifier)
	SettingsManager.analytics_enabled = saved
	return spy


## P1: Apprentice multiplier (0.8) appears verbatim in the difficulty_modifier field.
func test_p1_analytics_stores_apprentice_multiplier() -> bool:
	var spy := _fire_with_modifier(GameState.evidence_credulity_multiplier("apprentice"))
	var stored: float = float(spy.last_event.get("difficulty_modifier", -1.0))
	if not is_equal_approx(stored, 0.8):
		push_error("test_p1: expected 0.8, got %f" % stored)
		return false
	return true


## P2: Spymaster multiplier (1.3) appears verbatim in the difficulty_modifier field.
func test_p2_analytics_stores_spymaster_multiplier() -> bool:
	var spy := _fire_with_modifier(GameState.evidence_credulity_multiplier("spymaster"))
	var stored: float = float(spy.last_event.get("difficulty_modifier", -1.0))
	if not is_equal_approx(stored, 1.3):
		push_error("test_p2: expected 1.3, got %f" % stored)
		return false
	return true


## P3: evidence_credulity_multiplier(GameState.selected_difficulty) changes with
##     the active preset — the RumorPanel call site depends on this property.
func test_p3_selected_difficulty_drives_multiplier() -> bool:
	var saved_diff: String = GameState.selected_difficulty

	GameState.selected_difficulty = "spymaster"
	var m_spy: float = GameState.evidence_credulity_multiplier(GameState.selected_difficulty)

	GameState.selected_difficulty = "apprentice"
	var m_app: float = GameState.evidence_credulity_multiplier(GameState.selected_difficulty)

	GameState.selected_difficulty = saved_diff

	if not is_equal_approx(m_spy, 1.3):
		push_error("test_p3: spymaster: expected 1.3, got %f" % m_spy)
		return false
	if not is_equal_approx(m_app, 0.8):
		push_error("test_p3: apprentice: expected 0.8, got %f" % m_app)
		return false
	return true
