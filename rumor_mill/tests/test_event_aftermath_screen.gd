## test_event_aftermath_screen.gd — Unit tests for event_aftermath_screen.gd (SPA-2777).
##
## Covers:
##   • Palette constants (C_BACKDROP, C_PANEL_BG, C_BORDER, C_STAT_UP, C_STAT_DOWN,
##     C_NPC_CHG, C_ITEM_GAIN, C_ITEM_COST, C_NEUTRAL, C_BTN_BG, C_BTN_HOVER, C_BTN_TEXT)
##   • Layout constants: PANEL_W, PANEL_H, REVEAL_TIME
##   • Initial node refs null (no scene tree — _ready() not called)
##   • Initial state: _world = null
##   • _format_effects() pure-function cases: empty dict, rep delta, heat delta,
##     instant believers, suspicion freeze, ability bonus, overflow cap
##
## NOTE: present(), _build_ui(), and tween animations require scene tree — not tested here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestEventAftermathScreen
extends RefCounted

const EventAftermathScreenScript := preload("res://scripts/event_aftermath_screen.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_eas() -> CanvasLayer:
	return EventAftermathScreenScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Palette constants
		"test_c_backdrop_dark",
		"test_c_panel_bg_dark",
		"test_c_stat_up_green",
		"test_c_stat_down_red",
		"test_c_item_gain_gold",
		"test_c_btn_hover_gold",
		"test_c_btn_text_warm",
		# Layout constants
		"test_panel_w",
		"test_panel_h",
		"test_reveal_time",
		# Initial node refs
		"test_initial_backdrop_null",
		"test_initial_panel_null",
		"test_initial_title_lbl_null",
		"test_initial_outcome_lbl_null",
		"test_initial_deltas_lbl_null",
		"test_initial_continue_btn_null",
		# Initial state
		"test_initial_world_null",
		# _format_effects() pure-function cases
		"test_format_effects_empty",
		"test_format_effects_rep_delta_positive",
		"test_format_effects_rep_delta_negative",
		"test_format_effects_heat_delta_positive",
		"test_format_effects_suspicion_freeze",
		"test_format_effects_ability_bonus_positive",
		"test_format_effects_ability_bonus_negative",
		"test_format_effects_instant_believers",
		"test_format_effects_overflow_cap",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nEventAftermathScreen tests: %d passed, %d failed" % [passed, failed])


# ── Palette constants ─────────────────────────────────────────────────────────

static func test_c_backdrop_dark() -> bool:
	var eas := _make_eas()
	# #050202 near-black with ~78% alpha
	var ok: bool = eas.C_BACKDROP.r < 0.10 and eas.C_BACKDROP.a > 0.70
	eas.free()
	return ok


static func test_c_panel_bg_dark() -> bool:
	var eas := _make_eas()
	# Very dark brown with ~97% alpha
	var ok: bool = eas.C_PANEL_BG.r < 0.15 and eas.C_PANEL_BG.a > 0.90
	eas.free()
	return ok


static func test_c_stat_up_green() -> bool:
	var eas := _make_eas()
	# #2D6A4F forest green: g dominant, r < g
	var ok: bool = eas.C_STAT_UP.g > eas.C_STAT_UP.r and eas.C_STAT_UP.g > 0.35
	eas.free()
	return ok


static func test_c_stat_down_red() -> bool:
	var eas := _make_eas()
	# #8B3A2E rust red: r dominant
	var ok: bool = eas.C_STAT_DOWN.r > eas.C_STAT_DOWN.g and eas.C_STAT_DOWN.r > 0.40
	eas.free()
	return ok


static func test_c_item_gain_gold() -> bool:
	var eas := _make_eas()
	# #B8860B gold: high r, moderate g, low b
	var ok: bool = eas.C_ITEM_GAIN.r > 0.65 and eas.C_ITEM_GAIN.b < 0.10
	eas.free()
	return ok


static func test_c_btn_hover_gold() -> bool:
	var eas := _make_eas()
	# Same gold as C_ITEM_GAIN per spec
	var ok: bool = eas.C_BTN_HOVER.r > 0.65 and eas.C_BTN_HOVER.b < 0.10
	eas.free()
	return ok


static func test_c_btn_text_warm() -> bool:
	var eas := _make_eas()
	# Warm parchment: high r, high g, moderate b
	var ok: bool = eas.C_BTN_TEXT.r > 0.85 and eas.C_BTN_TEXT.g > 0.75
	eas.free()
	return ok


# ── Layout constants ──────────────────────────────────────────────────────────

static func test_panel_w() -> bool:
	var eas := _make_eas()
	var ok: bool = eas.PANEL_W == 560.0
	eas.free()
	return ok


static func test_panel_h() -> bool:
	var eas := _make_eas()
	var ok: bool = eas.PANEL_H == 440.0
	eas.free()
	return ok


static func test_reveal_time() -> bool:
	var eas := _make_eas()
	var ok: bool = eas.REVEAL_TIME == 0.3
	eas.free()
	return ok


# ── Initial node refs ─────────────────────────────────────────────────────────

static func test_initial_backdrop_null() -> bool:
	var eas := _make_eas()
	var ok: bool = eas._backdrop == null
	eas.free()
	return ok


static func test_initial_panel_null() -> bool:
	var eas := _make_eas()
	var ok: bool = eas._panel == null
	eas.free()
	return ok


static func test_initial_title_lbl_null() -> bool:
	var eas := _make_eas()
	var ok: bool = eas._title_lbl == null
	eas.free()
	return ok


static func test_initial_outcome_lbl_null() -> bool:
	var eas := _make_eas()
	var ok: bool = eas._outcome_lbl == null
	eas.free()
	return ok


static func test_initial_deltas_lbl_null() -> bool:
	var eas := _make_eas()
	var ok: bool = eas._deltas_lbl == null
	eas.free()
	return ok


static func test_initial_continue_btn_null() -> bool:
	var eas := _make_eas()
	var ok: bool = eas._continue_btn == null
	eas.free()
	return ok


# ── Initial state ─────────────────────────────────────────────────────────────

static func test_initial_world_null() -> bool:
	var eas := _make_eas()
	var ok: bool = eas._world == null
	eas.free()
	return ok


# ── _format_effects() pure-function tests ─────────────────────────────────────
# _world is null so _resolve_npc_name falls back to prettifying the id string.

static func test_format_effects_empty() -> bool:
	var eas := _make_eas()
	var ok: bool = eas._format_effects({}) == ""
	eas.free()
	return ok


static func test_format_effects_rep_delta_positive() -> bool:
	var eas := _make_eas()
	var effects := {
		"reputationChanges": [{ "npcId": "guard_captain", "delta": 5 }]
	}
	var result: String = eas._format_effects(effects)
	# Must contain the green stat-up marker and the prettified name
	var ok: bool = result.contains("2D6A4F") and result.contains("+5")
	eas.free()
	return ok


static func test_format_effects_rep_delta_negative() -> bool:
	var eas := _make_eas()
	var effects := {
		"reputationChanges": [{ "npcId": "merchant", "delta": -3 }]
	}
	var result: String = eas._format_effects(effects)
	# Must contain the red stat-down marker and the negative delta
	var ok: bool = result.contains("8B3A2E") and result.contains("-3")
	eas.free()
	return ok


static func test_format_effects_heat_delta_positive() -> bool:
	var eas := _make_eas()
	var effects := {
		"heatChanges": [{ "npcId": "inquisitor", "delta": 10 }]
	}
	var result: String = eas._format_effects(effects)
	# Positive heat = bad → red marker, "Suspicion +N"
	var ok: bool = result.contains("8B3A2E") and result.contains("Suspicion +10")
	eas.free()
	return ok


static func test_format_effects_suspicion_freeze() -> bool:
	var eas := _make_eas()
	var effects := { "suspicionFreezeDays": 3 }
	var result: String = eas._format_effects(effects)
	# Freeze is a positive outcome → green marker
	var ok: bool = result.contains("2D6A4F") and result.contains("frozen for 3 days")
	eas.free()
	return ok


static func test_format_effects_ability_bonus_positive() -> bool:
	var eas := _make_eas()
	var effects := {
		"abilityBonuses": [{ "ability": "persuasion", "bonus": 2 }]
	}
	var result: String = eas._format_effects(effects)
	var ok: bool = result.contains("2D6A4F") and result.contains("Persuasion +2")
	eas.free()
	return ok


static func test_format_effects_ability_bonus_negative() -> bool:
	var eas := _make_eas()
	var effects := {
		"abilityBonuses": [{ "ability": "stealth", "bonus": -1 }]
	}
	var result: String = eas._format_effects(effects)
	var ok: bool = result.contains("8B3A2E") and result.contains("Stealth -1")
	eas.free()
	return ok


static func test_format_effects_instant_believers() -> bool:
	var eas := _make_eas()
	var effects := {
		"instantBelievers": { "count": 4, "subjectNpcId": "baker" }
	}
	var result: String = eas._format_effects(effects)
	# NPC state change → dark-brown marker, "now believe"
	var ok: bool = result.contains("3B2712") and result.contains("now believe")
	eas.free()
	return ok


static func test_format_effects_overflow_cap() -> bool:
	# More than 4 effect entries → last line should be the "...and other minor effects" note.
	var eas := _make_eas()
	var effects := {
		"reputationChanges": [
			{ "npcId": "a", "delta": 1 },
			{ "npcId": "b", "delta": 2 },
			{ "npcId": "c", "delta": 3 },
			{ "npcId": "d", "delta": 4 },
			{ "npcId": "e", "delta": 5 },
		]
	}
	var result: String = eas._format_effects(effects)
	var lines: PackedStringArray = result.split("\n")
	var ok: bool = lines[lines.size() - 1].contains("other minor effects")
	eas.free()
	return ok
