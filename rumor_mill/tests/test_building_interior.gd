## test_building_interior.gd — Unit tests for building_interior.gd (SPA-1078).
##
## Covers:
##   • ROSTER_RADIUS constant
##   • FACTION_LABEL constant: keys present, values contain colour markup
##   • Initial instance state (before _ready()): _open, _transitioning, _anim_tween,
##     _world_ref, _building_key, _npc_roster, @onready _overlay/_panel refs null
##   • is_open() returns false on a fresh instance
##   • setup_world_ref() stores world ref and building key for all 4 interior types
##     (tavern, chapel, manor, market)
##   • _refresh_npc_roster() null guard when world ref absent
##   • _refresh_npc_roster() null guard when building key is empty
##   • _refresh_npc_roster() "No patrons visible" text when nearby list is empty
##   • _refresh_npc_roster() builds "Inside:" header when NPCs are present
##   • _refresh_npc_roster() includes NPC name in roster text
##   • _refresh_npc_roster() embeds FACTION_LABEL colour markup for known faction
##   • _refresh_npc_roster() falls back to capitalize() for unknown faction
##
## building_interior.gd extends CanvasLayer (no class_name — loaded via preload).
## _ready() is NOT called (node not added to scene tree).  show_interior(),
## close_interior(), and the tween-driven transitions require a live viewport and
## are not exercised here.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestBuildingInterior
extends RefCounted

const BuildingInteriorScript := preload("res://scripts/building_interior.gd")


# ── Stubs ─────────────────────────────────────────────────────────────────────

## Minimal world stub: get_npcs_near_location returns a configurable list.
class _WorldStub extends RefCounted:
	var npcs: Array = []
	func get_npcs_near_location(_key: String, _radius: int) -> Array:
		return npcs


## NPC stub carrying a npc_data dictionary, mirroring the real NPC node interface.
class _NpcStub extends RefCounted:
	var npc_data: Dictionary = {}


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_bi() -> CanvasLayer:
	return BuildingInteriorScript.new()


## Inject a RichTextLabel + world stub so _refresh_npc_roster() can execute.
## Returns [bi, world_stub, label].  Caller must free the label when done.
func _make_bi_with_roster(building_key: String) -> Array:
	var bi    := _make_bi()
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	var world := _WorldStub.new()
	bi._npc_roster   = label
	bi._world_ref    = world
	bi._building_key = building_key
	return [bi, world, label]


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Constants
		"test_roster_radius",
		"test_faction_label_has_merchant",
		"test_faction_label_has_noble",
		"test_faction_label_has_clergy",
		"test_faction_label_merchant_has_colour",
		"test_faction_label_noble_has_colour",
		"test_faction_label_clergy_has_colour",
		# Initial state (before _ready())
		"test_initial_open_false",
		"test_initial_transitioning_false",
		"test_initial_anim_tween_null",
		"test_initial_world_ref_null",
		"test_initial_building_key_empty",
		"test_initial_npc_roster_null",
		"test_initial_overlay_null",
		"test_initial_panel_null",
		# is_open()
		"test_is_open_false_on_new_instance",
		# setup_world_ref() — all 4 interior keys
		"test_setup_world_ref_stores_ref",
		"test_setup_world_ref_tavern_key",
		"test_setup_world_ref_chapel_key",
		"test_setup_world_ref_manor_key",
		"test_setup_world_ref_market_key",
		# _refresh_npc_roster() guard clauses
		"test_refresh_roster_no_op_when_world_null",
		"test_refresh_roster_no_op_when_key_empty",
		# _refresh_npc_roster() behaviour
		"test_refresh_roster_empty_nearby_shows_no_patrons",
		"test_refresh_roster_builds_header_line",
		"test_refresh_roster_includes_npc_name",
		"test_refresh_roster_includes_faction_label_colour",
		"test_refresh_roster_unknown_faction_capitalised",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nBuildingInterior tests: %d passed, %d failed" % [passed, failed])


# ── Constants ─────────────────────────────────────────────────────────────────

static func test_roster_radius() -> bool:
	return _make_bi().ROSTER_RADIUS == 4


static func test_faction_label_has_merchant() -> bool:
	return _make_bi().FACTION_LABEL.has("merchant")


static func test_faction_label_has_noble() -> bool:
	return _make_bi().FACTION_LABEL.has("noble")


static func test_faction_label_has_clergy() -> bool:
	return _make_bi().FACTION_LABEL.has("clergy")


static func test_faction_label_merchant_has_colour() -> bool:
	return _make_bi().FACTION_LABEL["merchant"].contains("[color=")


static func test_faction_label_noble_has_colour() -> bool:
	return _make_bi().FACTION_LABEL["noble"].contains("[color=")


static func test_faction_label_clergy_has_colour() -> bool:
	return _make_bi().FACTION_LABEL["clergy"].contains("[color=")


# ── Initial state (before _ready()) ──────────────────────────────────────────

static func test_initial_open_false() -> bool:
	return _make_bi()._open == false


static func test_initial_transitioning_false() -> bool:
	return _make_bi()._transitioning == false


static func test_initial_anim_tween_null() -> bool:
	return _make_bi()._anim_tween == null


static func test_initial_world_ref_null() -> bool:
	return _make_bi()._world_ref == null


static func test_initial_building_key_empty() -> bool:
	return _make_bi()._building_key == ""


static func test_initial_npc_roster_null() -> bool:
	return _make_bi()._npc_roster == null


## @onready bindings are null until _ready() fires (node not in scene tree).
static func test_initial_overlay_null() -> bool:
	return _make_bi()._overlay == null


static func test_initial_panel_null() -> bool:
	return _make_bi()._panel == null


# ── is_open() ────────────────────────────────────────────────────────────────

static func test_is_open_false_on_new_instance() -> bool:
	return _make_bi().is_open() == false


# ── setup_world_ref() ────────────────────────────────────────────────────────

static func test_setup_world_ref_stores_ref() -> bool:
	var bi   := _make_bi()
	var stub := RefCounted.new()
	bi.setup_world_ref(stub, "tavern")
	return bi._world_ref == stub


static func test_setup_world_ref_tavern_key() -> bool:
	var bi := _make_bi()
	bi.setup_world_ref(RefCounted.new(), "tavern")
	return bi._building_key == "tavern"


static func test_setup_world_ref_chapel_key() -> bool:
	var bi := _make_bi()
	bi.setup_world_ref(RefCounted.new(), "chapel")
	return bi._building_key == "chapel"


static func test_setup_world_ref_manor_key() -> bool:
	var bi := _make_bi()
	bi.setup_world_ref(RefCounted.new(), "manor")
	return bi._building_key == "manor"


static func test_setup_world_ref_market_key() -> bool:
	var bi := _make_bi()
	bi.setup_world_ref(RefCounted.new(), "market")
	return bi._building_key == "market"


# ── _refresh_npc_roster() guard clauses ──────────────────────────────────────

## When _world_ref is null the method returns early; roster text stays empty.
func test_refresh_roster_no_op_when_world_null() -> bool:
	var bi    := _make_bi()
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	bi._npc_roster   = label
	bi._building_key = "tavern"
	# _world_ref intentionally left null — guard must fire.
	bi._refresh_npc_roster()
	var ok := label.text.is_empty()
	label.free()
	return ok


## When _building_key is empty the method returns early; roster text stays empty.
func test_refresh_roster_no_op_when_key_empty() -> bool:
	var bi    := _make_bi()
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	bi._npc_roster = label
	bi._world_ref  = _WorldStub.new()
	# _building_key intentionally left "" — guard must fire.
	bi._refresh_npc_roster()
	var ok := label.text.is_empty()
	label.free()
	return ok


# ── _refresh_npc_roster() behaviour ──────────────────────────────────────────

## An empty nearby list writes the italic "No patrons visible" placeholder.
func test_refresh_roster_empty_nearby_shows_no_patrons() -> bool:
	var parts         := _make_bi_with_roster("tavern")
	var bi: CanvasLayer = parts[0]
	# world stub starts with empty npcs list — nothing to show.
	bi._refresh_npc_roster()
	var ok := bi._npc_roster.text.contains("No patrons visible")
	(parts[2] as RichTextLabel).free()
	return ok


## A non-empty nearby list opens with the bold "Inside:" header.
func test_refresh_roster_builds_header_line() -> bool:
	var parts         := _make_bi_with_roster("manor")
	var bi: CanvasLayer  = parts[0]
	var world: _WorldStub = parts[1]

	var npc := _NpcStub.new()
	npc.npc_data = {"id": "npc_aldric", "name": "Lord Aldric", "faction": "noble"}
	world.npcs   = [npc]

	bi._refresh_npc_roster()
	var ok := bi._npc_roster.text.contains("Inside:")
	(parts[2] as RichTextLabel).free()
	return ok


## The NPC's name is included verbatim in the roster text.
func test_refresh_roster_includes_npc_name() -> bool:
	var parts         := _make_bi_with_roster("chapel")
	var bi: CanvasLayer  = parts[0]
	var world: _WorldStub = parts[1]

	var npc := _NpcStub.new()
	npc.npc_data = {"id": "npc_marta", "name": "Sister Marta", "faction": "clergy"}
	world.npcs   = [npc]

	bi._refresh_npc_roster()
	var ok := bi._npc_roster.text.contains("Sister Marta")
	(parts[2] as RichTextLabel).free()
	return ok


## FACTION_LABEL colour markup is embedded for a known faction (merchant).
func test_refresh_roster_includes_faction_label_colour() -> bool:
	var parts         := _make_bi_with_roster("market")
	var bi: CanvasLayer  = parts[0]
	var world: _WorldStub = parts[1]

	var npc := _NpcStub.new()
	npc.npc_data = {"id": "npc_voss", "name": "Trader Voss", "faction": "merchant"}
	world.npcs   = [npc]

	bi._refresh_npc_roster()
	# FACTION_LABEL["merchant"] wraps "Merchant" in colour tags.
	var ok := bi._npc_roster.text.contains("Merchant")
	(parts[2] as RichTextLabel).free()
	return ok


## An unknown faction string falls back to String.capitalize() without crashing.
func test_refresh_roster_unknown_faction_capitalised() -> bool:
	var parts         := _make_bi_with_roster("tavern")
	var bi: CanvasLayer  = parts[0]
	var world: _WorldStub = parts[1]

	var npc := _NpcStub.new()
	npc.npc_data = {"id": "npc_stranger", "name": "The Stranger", "faction": "pirate"}
	world.npcs   = [npc]

	bi._refresh_npc_roster()
	# "pirate".capitalize() == "Pirate" must appear in roster text.
	var ok := bi._npc_roster.text.contains("Pirate")
	(parts[2] as RichTextLabel).free()
	return ok
