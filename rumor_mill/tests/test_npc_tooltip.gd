## test_npc_tooltip.gd — Unit tests for npc_tooltip.gd (SPA-1026).
##
## Covers:
##   • FACTION_LABEL: 3 entries (merchant, noble, clergy) with correct display names
##   • FACTION_COLOR: 3 entries matching FACTION_LABEL keys
##   • STATE_LABEL: 9 entries (0–8), spot-checks for Unaware/Believes/Spreading
##   • STATE_COLOR: 9 entries (0–8)
##   • STATE_ICON: 9 entries (0–8), spot-checks for known icons
##   • Atlas/portrait constants: STATE_ICON_COUNT, PANEL_W, PANEL_H,
##     PORTRAIT_W, PORTRAIT_H, PORTRAIT_COLS
##   • Timing constants: FADE_IN_SEC, FADE_OUT_SEC
##   • Initial instance state (before _ready()): _visible_flag, _world_ref,
##     _flavor_text, _panel, _fade_tween, _portrait_tex, _state_icon_tex
##
## npc_tooltip.gd extends CanvasLayer (no class_name — loaded via preload).
## _ready() is NOT called (node not added to scene tree) so texture loading,
## signal wiring, and panel building do not execute.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestNpcTooltip
extends RefCounted

const NpcTooltipScript := preload("res://scripts/npc_tooltip.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_nt() -> CanvasLayer:
	return NpcTooltipScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# FACTION_LABEL
		"test_faction_label_has_three_entries",
		"test_faction_label_merchant",
		"test_faction_label_noble",
		"test_faction_label_clergy",
		# FACTION_COLOR
		"test_faction_color_has_three_entries",
		"test_faction_color_has_merchant_key",
		"test_faction_color_has_noble_key",
		"test_faction_color_has_clergy_key",
		# STATE_LABEL
		"test_state_label_has_nine_entries",
		"test_state_label_0_is_unaware",
		"test_state_label_1_is_evaluating",
		"test_state_label_2_is_believes",
		"test_state_label_4_is_spreading",
		"test_state_label_8_is_defending",
		# STATE_COLOR
		"test_state_color_has_nine_entries",
		# STATE_ICON
		"test_state_icon_has_nine_entries",
		"test_state_icon_2_is_checkmark",
		"test_state_icon_3_is_cross",
		# Atlas / portrait constants
		"test_state_icon_count",
		"test_panel_w",
		"test_panel_h",
		"test_portrait_w",
		"test_portrait_h",
		"test_portrait_cols",
		# Timing constants
		"test_fade_in_sec",
		"test_fade_out_sec",
		# Initial state (before _ready())
		"test_initial_visible_flag_false",
		"test_initial_world_ref_null",
		"test_initial_flavor_text_empty",
		"test_initial_panel_null",
		"test_initial_fade_tween_null",
		"test_initial_portrait_tex_null",
		"test_initial_state_icon_tex_null",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nNpcTooltip tests: %d passed, %d failed" % [passed, failed])


# ── FACTION_LABEL ─────────────────────────────────────────────────────────────

static func test_faction_label_has_three_entries() -> bool:
	var count := _make_nt().FACTION_LABEL.size()
	if count != 3:
		push_error("test_faction_label_has_three_entries: expected 3, got %d" % count)
		return false
	return true


static func test_faction_label_merchant() -> bool:
	return _make_nt().FACTION_LABEL.get("merchant", "") == "Merchant"


static func test_faction_label_noble() -> bool:
	return _make_nt().FACTION_LABEL.get("noble", "") == "Noble"


static func test_faction_label_clergy() -> bool:
	return _make_nt().FACTION_LABEL.get("clergy", "") == "Clergy"


# ── FACTION_COLOR ─────────────────────────────────────────────────────────────

static func test_faction_color_has_three_entries() -> bool:
	return _make_nt().FACTION_COLOR.size() == 3


static func test_faction_color_has_merchant_key() -> bool:
	return _make_nt().FACTION_COLOR.has("merchant")


static func test_faction_color_has_noble_key() -> bool:
	return _make_nt().FACTION_COLOR.has("noble")


static func test_faction_color_has_clergy_key() -> bool:
	return _make_nt().FACTION_COLOR.has("clergy")


# ── STATE_LABEL ───────────────────────────────────────────────────────────────

static func test_state_label_has_nine_entries() -> bool:
	var count := _make_nt().STATE_LABEL.size()
	if count != 9:
		push_error("test_state_label_has_nine_entries: expected 9, got %d" % count)
		return false
	return true


static func test_state_label_0_is_unaware() -> bool:
	return _make_nt().STATE_LABEL.get(0, "") == "Unaware"


static func test_state_label_1_is_evaluating() -> bool:
	return _make_nt().STATE_LABEL.get(1, "") == "Evaluating"


static func test_state_label_2_is_believes() -> bool:
	return _make_nt().STATE_LABEL.get(2, "") == "Believes"


static func test_state_label_4_is_spreading() -> bool:
	return _make_nt().STATE_LABEL.get(4, "") == "Spreading"


static func test_state_label_8_is_defending() -> bool:
	return _make_nt().STATE_LABEL.get(8, "") == "Defending"


# ── STATE_COLOR ───────────────────────────────────────────────────────────────

static func test_state_color_has_nine_entries() -> bool:
	var count := _make_nt().STATE_COLOR.size()
	if count != 9:
		push_error("test_state_color_has_nine_entries: expected 9, got %d" % count)
		return false
	return true


# ── STATE_ICON ────────────────────────────────────────────────────────────────

static func test_state_icon_has_nine_entries() -> bool:
	var count := _make_nt().STATE_ICON.size()
	if count != 9:
		push_error("test_state_icon_has_nine_entries: expected 9, got %d" % count)
		return false
	return true


## State 2 (Believes) uses a checkmark icon.
static func test_state_icon_2_is_checkmark() -> bool:
	return _make_nt().STATE_ICON.get(2, "") == "✓"


## State 3 (Rejecting) uses a cross icon.
static func test_state_icon_3_is_cross() -> bool:
	return _make_nt().STATE_ICON.get(3, "") == "✕"


# ── Atlas / portrait constants ────────────────────────────────────────────────

static func test_state_icon_count() -> bool:
	return _make_nt().STATE_ICON_COUNT == 9


static func test_panel_w() -> bool:
	return _make_nt().PANEL_W == 300


static func test_panel_h() -> bool:
	return _make_nt().PANEL_H == 180


static func test_portrait_w() -> bool:
	return _make_nt().PORTRAIT_W == 64


static func test_portrait_h() -> bool:
	return _make_nt().PORTRAIT_H == 80


static func test_portrait_cols() -> bool:
	return _make_nt().PORTRAIT_COLS == 6


# ── Timing constants ──────────────────────────────────────────────────────────

static func test_fade_in_sec() -> bool:
	return absf(_make_nt().FADE_IN_SEC - 0.12) < 0.001


static func test_fade_out_sec() -> bool:
	return absf(_make_nt().FADE_OUT_SEC - 0.10) < 0.001


# ── Initial state (before _ready()) ──────────────────────────────────────────

static func test_initial_visible_flag_false() -> bool:
	return _make_nt()._visible_flag == false


static func test_initial_world_ref_null() -> bool:
	return _make_nt()._world_ref == null


## _flavor_text is populated in _ready() via _load_flavor_text(); must be empty before that.
static func test_initial_flavor_text_empty() -> bool:
	return _make_nt()._flavor_text.is_empty()


static func test_initial_panel_null() -> bool:
	return _make_nt()._panel == null


static func test_initial_fade_tween_null() -> bool:
	return _make_nt()._fade_tween == null


## Textures are loaded in _ready(); both must be null on a bare instance.
static func test_initial_portrait_tex_null() -> bool:
	return _make_nt()._portrait_tex == null


static func test_initial_state_icon_tex_null() -> bool:
	return _make_nt()._state_icon_tex == null
