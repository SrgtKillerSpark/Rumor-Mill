## test_game_state.gd — Unit tests for GameState difficulty helpers (SPA-987).
##
## Covers:
##   • get_difficulty_modifiers returns correct dictionary for each preset
##   • apprentice modifiers are more lenient than master
##   • spymaster modifiers are harder than master
##   • unknown preset falls back to master defaults
##   • all expected keys are present in every preset
##
## GameState extends Node (autoload), but get_difficulty_modifiers is static,
## so all tests call it without instantiating a Node.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestGameState
extends RefCounted


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Key presence
		"test_apprentice_has_all_keys",
		"test_master_has_all_keys",
		"test_spymaster_has_all_keys",
		"test_unknown_preset_has_all_keys",
		# Apprentice values
		"test_apprentice_whisper_bonus_positive",
		"test_apprentice_action_bonus_positive",
		"test_apprentice_heat_decay_greater_than_master",
		"test_apprentice_days_bonus_positive",
		"test_apprentice_rival_cooldown_offset_positive",
		# Master (default) values
		"test_master_whisper_bonus_zero",
		"test_master_action_bonus_zero",
		"test_master_heat_decay_is_6",
		"test_master_days_bonus_zero",
		"test_master_rival_cooldown_offset_zero",
		# Spymaster values
		"test_spymaster_whisper_bonus_negative",
		"test_spymaster_action_bonus_negative",
		"test_spymaster_heat_decay_less_than_master",
		"test_spymaster_days_bonus_negative",
		"test_spymaster_rival_cooldown_offset_negative",
		# Unknown preset fallback
		"test_unknown_preset_matches_master",
		# Symmetry: apprentice vs spymaster are mirror opposites for integer fields
		"test_apprentice_spymaster_integer_fields_mirror",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nGameState tests: %d passed, %d failed" % [passed, failed])


# ── Helpers ───────────────────────────────────────────────────────────────────

const EXPECTED_KEYS: Array = [
	"whisper_bonus",
	"action_bonus",
	"heat_decay",
	"days_bonus",
	"rival_cooldown_offset",
	"inquisitor_cooldown_offset",
	"illness_escalation_offset",
]


static func _has_all_keys(d: Dictionary) -> bool:
	for k in EXPECTED_KEYS:
		if not d.has(k):
			push_error("Missing key: %s" % k)
			return false
	return true


# ── Key presence ──────────────────────────────────────────────────────────────

static func test_apprentice_has_all_keys() -> bool:
	return _has_all_keys(GameState.get_difficulty_modifiers("apprentice"))


static func test_master_has_all_keys() -> bool:
	return _has_all_keys(GameState.get_difficulty_modifiers("master"))


static func test_spymaster_has_all_keys() -> bool:
	return _has_all_keys(GameState.get_difficulty_modifiers("spymaster"))


static func test_unknown_preset_has_all_keys() -> bool:
	return _has_all_keys(GameState.get_difficulty_modifiers("nonexistent"))


# ── Apprentice values ─────────────────────────────────────────────────────────

static func test_apprentice_whisper_bonus_positive() -> bool:
	return GameState.get_difficulty_modifiers("apprentice")["whisper_bonus"] > 0


static func test_apprentice_action_bonus_positive() -> bool:
	return GameState.get_difficulty_modifiers("apprentice")["action_bonus"] > 0


static func test_apprentice_heat_decay_greater_than_master() -> bool:
	var appr: float = GameState.get_difficulty_modifiers("apprentice")["heat_decay"]
	var master: float = GameState.get_difficulty_modifiers("master")["heat_decay"]
	return appr > master


static func test_apprentice_days_bonus_positive() -> bool:
	return GameState.get_difficulty_modifiers("apprentice")["days_bonus"] > 0


static func test_apprentice_rival_cooldown_offset_positive() -> bool:
	return GameState.get_difficulty_modifiers("apprentice")["rival_cooldown_offset"] > 0


# ── Master (default) values ───────────────────────────────────────────────────

static func test_master_whisper_bonus_zero() -> bool:
	return GameState.get_difficulty_modifiers("master")["whisper_bonus"] == 0


static func test_master_action_bonus_zero() -> bool:
	return GameState.get_difficulty_modifiers("master")["action_bonus"] == 0


static func test_master_heat_decay_is_6() -> bool:
	return GameState.get_difficulty_modifiers("master")["heat_decay"] == 6.0


static func test_master_days_bonus_zero() -> bool:
	return GameState.get_difficulty_modifiers("master")["days_bonus"] == 0


static func test_master_rival_cooldown_offset_zero() -> bool:
	return GameState.get_difficulty_modifiers("master")["rival_cooldown_offset"] == 0


# ── Spymaster values ──────────────────────────────────────────────────────────

static func test_spymaster_whisper_bonus_negative() -> bool:
	return GameState.get_difficulty_modifiers("spymaster")["whisper_bonus"] < 0


static func test_spymaster_action_bonus_negative() -> bool:
	return GameState.get_difficulty_modifiers("spymaster")["action_bonus"] < 0


static func test_spymaster_heat_decay_less_than_master() -> bool:
	var spy: float = GameState.get_difficulty_modifiers("spymaster")["heat_decay"]
	var master: float = GameState.get_difficulty_modifiers("master")["heat_decay"]
	return spy < master


static func test_spymaster_days_bonus_negative() -> bool:
	return GameState.get_difficulty_modifiers("spymaster")["days_bonus"] < 0


static func test_spymaster_rival_cooldown_offset_negative() -> bool:
	return GameState.get_difficulty_modifiers("spymaster")["rival_cooldown_offset"] < 0


# ── Unknown preset fallback ───────────────────────────────────────────────────

## An unrecognised preset string should fall through to master defaults.
static func test_unknown_preset_matches_master() -> bool:
	var unknown := GameState.get_difficulty_modifiers("unknown_xyz")
	var master  := GameState.get_difficulty_modifiers("master")
	for k in EXPECTED_KEYS:
		if unknown[k] != master[k]:
			push_error("test_unknown_preset_matches_master: key '%s' differs" % k)
			return false
	return true


# ── Symmetry check ────────────────────────────────────────────────────────────

## For every integer bonus/offset field, apprentice and spymaster should be
## exact mirror opposites (sum == 0), reflecting the symmetric design intent.
static func test_apprentice_spymaster_integer_fields_mirror() -> bool:
	var appr := GameState.get_difficulty_modifiers("apprentice")
	var spy  := GameState.get_difficulty_modifiers("spymaster")
	var mirror_keys := [
		"whisper_bonus", "action_bonus", "days_bonus",
		"rival_cooldown_offset", "inquisitor_cooldown_offset", "illness_escalation_offset"
	]
	for k in mirror_keys:
		if appr[k] + spy[k] != 0:
			push_error("test_apprentice_spymaster_integer_fields_mirror: key '%s' not mirrored (%d + %d != 0)" % [k, appr[k], spy[k]])
			return false
	return true
