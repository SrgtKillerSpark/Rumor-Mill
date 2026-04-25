## test_building_tooltip.gd — Unit tests for building_tooltip.gd (SPA-1026).
##
## Covers:
##   • Color palette constants: C_BG, C_BORDER, C_TITLE, C_LABEL, C_HINT
##   • Layout constants: OFFSET, PANEL_W, FADE_IN_SEC, FADE_OUT_SEC, BUILDING_HIT_TILES
##   • Initial instance state (before _ready()): _world_ref, _flavor_text,
##     _current_loc, _fade_tween, _panel, all label refs
##   • setup(): stores world reference
##   • _world_to_cell(): pure isometric coordinate conversion
##
## building_tooltip.gd extends CanvasLayer (no class_name — loaded via preload).
## _ready() is NOT called (node not added to scene tree).  _process() and
## _keep_near_cursor() require a live viewport and are not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestBuildingTooltip
extends RefCounted

const BuildingTooltipScript := preload("res://scripts/building_tooltip.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_bt() -> CanvasLayer:
	return BuildingTooltipScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

static func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Color constants
		"test_c_bg_colour",
		"test_c_border_colour",
		"test_c_title_colour",
		"test_c_label_colour",
		"test_c_hint_colour",
		# Layout constants
		"test_offset_value",
		"test_panel_w",
		"test_fade_in_sec",
		"test_fade_out_sec",
		"test_building_hit_tiles",
		# Initial state (before _ready())
		"test_initial_world_ref_null",
		"test_initial_flavor_text_empty",
		"test_initial_current_loc_empty",
		"test_initial_fade_tween_null",
		"test_initial_panel_null",
		"test_initial_name_lbl_null",
		"test_initial_desc_lbl_null",
		"test_initial_npc_count_lbl_null",
		"test_initial_hint_lbl_null",
		# setup()
		"test_setup_stores_world_ref",
		# _world_to_cell() — isometric conversion
		"test_world_to_cell_origin",
		"test_world_to_cell_east_tile",
		"test_world_to_cell_north_tile",
		"test_world_to_cell_128_0",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nBuildingTooltip tests: %d passed, %d failed" % [passed, failed])


# ── Color constants ───────────────────────────────────────────────────────────

static func test_c_bg_colour() -> bool:
	return _make_bt().C_BG == Color(0.10, 0.07, 0.05, 0.93)


static func test_c_border_colour() -> bool:
	return _make_bt().C_BORDER == Color(0.55, 0.38, 0.18, 1.0)


static func test_c_title_colour() -> bool:
	return _make_bt().C_TITLE == Color(0.92, 0.78, 0.12, 1.0)


static func test_c_label_colour() -> bool:
	return _make_bt().C_LABEL == Color(0.82, 0.75, 0.60, 1.0)


static func test_c_hint_colour() -> bool:
	return _make_bt().C_HINT == Color(0.90, 0.75, 0.40, 0.85)


# ── Layout constants ──────────────────────────────────────────────────────────

static func test_offset_value() -> bool:
	return _make_bt().OFFSET == Vector2(18, -95)


static func test_panel_w() -> bool:
	return _make_bt().PANEL_W == 300


static func test_fade_in_sec() -> bool:
	return absf(_make_bt().FADE_IN_SEC - 0.12) < 0.001


static func test_fade_out_sec() -> bool:
	return absf(_make_bt().FADE_OUT_SEC - 0.10) < 0.001


static func test_building_hit_tiles() -> bool:
	return _make_bt().BUILDING_HIT_TILES == 2


# ── Initial state (before _ready()) ──────────────────────────────────────────

static func test_initial_world_ref_null() -> bool:
	return _make_bt()._world_ref == null


## _flavor_text is loaded in _ready() — must be empty on a bare instance.
static func test_initial_flavor_text_empty() -> bool:
	return _make_bt()._flavor_text.is_empty()


static func test_initial_current_loc_empty() -> bool:
	return _make_bt()._current_loc == ""


static func test_initial_fade_tween_null() -> bool:
	return _make_bt()._fade_tween == null


static func test_initial_panel_null() -> bool:
	return _make_bt()._panel == null


static func test_initial_name_lbl_null() -> bool:
	return _make_bt()._name_lbl == null


static func test_initial_desc_lbl_null() -> bool:
	return _make_bt()._desc_lbl == null


static func test_initial_npc_count_lbl_null() -> bool:
	return _make_bt()._npc_count_lbl == null


static func test_initial_hint_lbl_null() -> bool:
	return _make_bt()._hint_lbl == null


# ── setup() ───────────────────────────────────────────────────────────────────

static func test_setup_stores_world_ref() -> bool:
	var bt := _make_bt()
	var stub := Node2D.new()
	bt.setup(stub)
	var ok := bt._world_ref == stub
	stub.free()
	return ok


# ── _world_to_cell() — isometric coordinate conversion ───────────────────────
#
# Formula: cx = x/64 + y/32,  cy = y/32 - x/64
# Results are rounded to the nearest integer.

## Origin → cell (0, 0).
static func test_world_to_cell_origin() -> bool:
	var result: Vector2i = _make_bt()._world_to_cell(Vector2(0.0, 0.0))
	if result != Vector2i(0, 0):
		push_error("test_world_to_cell_origin: expected (0,0), got %s" % result)
		return false
	return true


## (64, 32) → cx = 64/64 + 32/32 = 2,  cy = 32/32 - 64/64 = 0 → (2, 0).
static func test_world_to_cell_east_tile() -> bool:
	var result: Vector2i = _make_bt()._world_to_cell(Vector2(64.0, 32.0))
	if result != Vector2i(2, 0):
		push_error("test_world_to_cell_east_tile: expected (2,0), got %s" % result)
		return false
	return true


## (0, 32) → cx = 0 + 32/32 = 1,  cy = 32/32 - 0 = 1 → (1, 1).
static func test_world_to_cell_north_tile() -> bool:
	var result: Vector2i = _make_bt()._world_to_cell(Vector2(0.0, 32.0))
	if result != Vector2i(1, 1):
		push_error("test_world_to_cell_north_tile: expected (1,1), got %s" % result)
		return false
	return true


## (128, 0) → cx = 128/64 + 0 = 2,  cy = 0 - 128/64 = -2 → (2, -2).
static func test_world_to_cell_128_0() -> bool:
	var result: Vector2i = _make_bt()._world_to_cell(Vector2(128.0, 0.0))
	if result != Vector2i(2, -2):
		push_error("test_world_to_cell_128_0: expected (2,-2), got %s" % result)
		return false
	return true
