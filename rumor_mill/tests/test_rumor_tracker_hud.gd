## test_rumor_tracker_hud.gd — Unit tests for RumorTrackerHud (SPA-1057).
##
## Covers:
##   • Constants: MAX_ROWS, _FLASH_DURATION
##   • Palette: alpha values for reach-tier colours (C_REACH_LOW/MED/HI),
##     mutation label (C_MUT_LABEL), key NPC label (C_KEY_NPC)
##   • Initial state: _world_ref null, _panel/vbox/title null, _key_npc_flashes empty dict
##   • _on_key_npc_reached(): adds npc_name → _FLASH_DURATION to _key_npc_flashes
##   • _on_key_npc_reached(): subsequent calls overwrite (reset) the flash timer
##   • _on_game_tick(): decrements all flash timers by 1 per call
##   • _on_game_tick(): erases entries whose timer reaches ≤ 0
##   • _on_game_tick(): entries with timer > 1 are not erased
##   • _on_game_tick(): null _world_ref does not crash (_refresh returns early)
##   • _depth_dfs(): no children → 0
##   • _depth_dfs(): single live child → 1
##   • _depth_dfs(): two-level chain → 2
##   • _depth_dfs(): child not in live dict → skipped (depth stays 0)
##   • _depth_dfs(): two siblings, one dead → counts only the live one
##   • _collect_lineage(): root only (no lineage entries) → returns [root_id]
##   • _collect_lineage(): root with one child in lineage → returns both ids
##   • _collect_lineage(): two-level lineage → includes root, child, grandchild
##   • _max_descendant_depth(): empty lineage → 0
##   • _max_descendant_depth(): one live child → 1
##   • _max_descendant_depth(): child not in live_rumors → 0
##
## RumorTrackerHud extends CanvasLayer. _ready() is not called (node not in scene tree),
## so _build_ui() never runs — _panel, _vbox, _title_lbl remain null.
## _refresh() guards on null _world_ref and returns early, making _on_game_tick safe.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestRumorTrackerHud
extends RefCounted

const RumorTrackerHudScript := preload("res://scripts/rumor_tracker_hud.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_hud() -> CanvasLayer:
	return RumorTrackerHudScript.new()


## Return a PropagationEngine with empty lineage and live_rumors.
static func _make_engine() -> PropagationEngine:
	return PropagationEngine.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Constants
		"test_max_rows_constant",
		"test_flash_duration_constant",

		# Palette alpha checks
		"test_c_reach_low_alpha_one",
		"test_c_reach_med_alpha_one",
		"test_c_reach_hi_alpha_one",
		"test_c_mut_label_alpha_one",
		"test_c_key_npc_alpha_one",

		# Initial state
		"test_initial_world_ref_null",
		"test_initial_panel_null",
		"test_initial_vbox_null",
		"test_initial_title_lbl_null",
		"test_initial_key_npc_flashes_empty",

		# _on_key_npc_reached
		"test_key_npc_reached_adds_flash_entry",
		"test_key_npc_reached_sets_flash_duration",
		"test_key_npc_reached_resets_existing_timer",

		# _on_game_tick
		"test_game_tick_decrements_flash_timer",
		"test_game_tick_erases_entry_at_zero",
		"test_game_tick_does_not_erase_positive_timer",
		"test_game_tick_null_world_no_crash",

		# _depth_dfs
		"test_depth_dfs_no_children_returns_zero",
		"test_depth_dfs_single_live_child_returns_one",
		"test_depth_dfs_two_level_chain_returns_two",
		"test_depth_dfs_dead_child_skipped",
		"test_depth_dfs_two_siblings_one_dead_returns_one",

		# _collect_lineage
		"test_collect_lineage_root_only",
		"test_collect_lineage_includes_one_child",
		"test_collect_lineage_two_level_depth",

		# _max_descendant_depth
		"test_max_depth_empty_lineage_returns_zero",
		"test_max_depth_one_live_child_returns_one",
		"test_max_depth_dead_child_returns_zero",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nRumorTrackerHud tests: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# Constants
# ══════════════════════════════════════════════════════════════════════════════

static func test_max_rows_constant() -> bool:
	var hud := _make_hud()
	var ok := hud.MAX_ROWS == 4
	hud.free()
	return ok


static func test_flash_duration_constant() -> bool:
	var hud := _make_hud()
	var ok := hud._FLASH_DURATION == 8
	hud.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# Palette alpha checks
# ══════════════════════════════════════════════════════════════════════════════

static func test_c_reach_low_alpha_one() -> bool:
	var hud := _make_hud()
	var ok := is_equal_approx(hud.C_REACH_LOW.a, 1.0)
	hud.free()
	return ok


static func test_c_reach_med_alpha_one() -> bool:
	var hud := _make_hud()
	var ok := is_equal_approx(hud.C_REACH_MED.a, 1.0)
	hud.free()
	return ok


static func test_c_reach_hi_alpha_one() -> bool:
	var hud := _make_hud()
	var ok := is_equal_approx(hud.C_REACH_HI.a, 1.0)
	hud.free()
	return ok


static func test_c_mut_label_alpha_one() -> bool:
	var hud := _make_hud()
	var ok := is_equal_approx(hud.C_MUT_LABEL.a, 1.0)
	hud.free()
	return ok


static func test_c_key_npc_alpha_one() -> bool:
	var hud := _make_hud()
	var ok := is_equal_approx(hud.C_KEY_NPC.a, 1.0)
	hud.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# Initial state
# ══════════════════════════════════════════════════════════════════════════════

static func test_initial_world_ref_null() -> bool:
	var hud := _make_hud()
	var ok := hud._world_ref == null
	hud.free()
	return ok


static func test_initial_panel_null() -> bool:
	var hud := _make_hud()
	# _build_ui() is called from _ready() which is skipped outside the scene tree.
	var ok := hud._panel == null
	hud.free()
	return ok


static func test_initial_vbox_null() -> bool:
	var hud := _make_hud()
	var ok := hud._vbox == null
	hud.free()
	return ok


static func test_initial_title_lbl_null() -> bool:
	var hud := _make_hud()
	var ok := hud._title_lbl == null
	hud.free()
	return ok


static func test_initial_key_npc_flashes_empty() -> bool:
	var hud := _make_hud()
	var ok := hud._key_npc_flashes.is_empty()
	hud.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# _on_key_npc_reached
# ══════════════════════════════════════════════════════════════════════════════

## Calling _on_key_npc_reached adds the NPC name to the flash dict.
static func test_key_npc_reached_adds_flash_entry() -> bool:
	var hud := _make_hud()
	hud._on_key_npc_reached("Aldric", "rp_test")
	var ok := hud._key_npc_flashes.has("Aldric")
	hud.free()
	return ok


## The flash timer is initialised to _FLASH_DURATION.
static func test_key_npc_reached_sets_flash_duration() -> bool:
	var hud := _make_hud()
	hud._on_key_npc_reached("Mira", "rp_test")
	var ok := hud._key_npc_flashes["Mira"] == hud._FLASH_DURATION
	hud.free()
	return ok


## A second call overwrites (resets) the timer for the same NPC.
static func test_key_npc_reached_resets_existing_timer() -> bool:
	var hud := _make_hud()
	hud._on_key_npc_reached("Aldric", "rp_a")
	# Manually wind the timer down as if ticks have passed.
	hud._key_npc_flashes["Aldric"] = 2
	# Second reach resets it.
	hud._on_key_npc_reached("Aldric", "rp_b")
	var ok := hud._key_npc_flashes["Aldric"] == hud._FLASH_DURATION
	hud.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# _on_game_tick
# ══════════════════════════════════════════════════════════════════════════════

## Each call to _on_game_tick decrements flash timers by 1.
static func test_game_tick_decrements_flash_timer() -> bool:
	var hud := _make_hud()
	hud._key_npc_flashes["Bjorn"] = 5
	hud._on_game_tick(1)
	var ok := hud._key_npc_flashes.get("Bjorn", -99) == 4
	hud.free()
	return ok


## An entry is erased when its timer decrements to 0.
static func test_game_tick_erases_entry_at_zero() -> bool:
	var hud := _make_hud()
	hud._key_npc_flashes["Lena"] = 1
	hud._on_game_tick(1)
	var ok := not hud._key_npc_flashes.has("Lena")
	hud.free()
	return ok


## Entries with a timer > 1 survive a single tick.
static func test_game_tick_does_not_erase_positive_timer() -> bool:
	var hud := _make_hud()
	hud._key_npc_flashes["Vance"] = 3
	hud._on_game_tick(1)
	var ok := hud._key_npc_flashes.has("Vance")
	hud.free()
	return ok


## _on_game_tick with null _world_ref must not crash (_refresh guards and returns early).
static func test_game_tick_null_world_no_crash() -> bool:
	var hud := _make_hud()
	# _world_ref is null by default — _refresh() will return immediately.
	hud._on_game_tick(0)
	hud.free()
	return true


# ══════════════════════════════════════════════════════════════════════════════
# _depth_dfs
# ══════════════════════════════════════════════════════════════════════════════

## Node with no children in the map → depth 0.
static func test_depth_dfs_no_children_returns_zero() -> bool:
	var hud := _make_hud()
	var result: int = hud._depth_dfs("root", {}, {})
	hud.free()
	return result == 0


## Single live child → depth 1.
static func test_depth_dfs_single_live_child_returns_one() -> bool:
	var hud := _make_hud()
	var children := {"root": ["child"]}
	var live := {"child": true}
	var result: int = hud._depth_dfs("root", children, live)
	hud.free()
	return result == 1


## root → child → grandchild (all live) → depth 2.
static func test_depth_dfs_two_level_chain_returns_two() -> bool:
	var hud := _make_hud()
	var children := {"root": ["mid"], "mid": ["leaf"]}
	var live := {"mid": true, "leaf": true}
	var result: int = hud._depth_dfs("root", children, live)
	hud.free()
	return result == 2


## Child not in live dict → not counted; result stays 0.
static func test_depth_dfs_dead_child_skipped() -> bool:
	var hud := _make_hud()
	var children := {"root": ["dead"]}
	var live: Dictionary = {}
	var result: int = hud._depth_dfs("root", children, live)
	hud.free()
	return result == 0


## Two siblings: one live, one dead → max depth is 1 (the live sibling).
static func test_depth_dfs_two_siblings_one_dead_returns_one() -> bool:
	var hud := _make_hud()
	var children := {"root": ["live_child", "dead_child"]}
	var live := {"live_child": true}
	var result: int = hud._depth_dfs("root", children, live)
	hud.free()
	return result == 1


# ══════════════════════════════════════════════════════════════════════════════
# _collect_lineage
# ══════════════════════════════════════════════════════════════════════════════

## Root with no entries in lineage → result contains only the root id.
static func test_collect_lineage_root_only() -> bool:
	var hud := _make_hud()
	var engine := _make_engine()
	# No entries in lineage means no children map entries for "rp_a".
	var result: Array = hud._collect_lineage("rp_a", engine)
	hud.free()
	return result.size() == 1 and result[0] == "rp_a"


## Root with one child in lineage → result contains root and child.
static func test_collect_lineage_includes_one_child() -> bool:
	var hud := _make_hud()
	var engine := _make_engine()
	# "rp_a_m1" has lineage parent "rp_a".
	engine.lineage["rp_a_m1"] = {"parent_id": "rp_a"}
	var result: Array = hud._collect_lineage("rp_a", engine)
	hud.free()
	return result.size() == 2 and result.has("rp_a") and result.has("rp_a_m1")


## Two-level chain: root → child → grandchild all included.
static func test_collect_lineage_two_level_depth() -> bool:
	var hud := _make_hud()
	var engine := _make_engine()
	engine.lineage["rp_a_m1"]    = {"parent_id": "rp_a"}
	engine.lineage["rp_a_m1_m1"] = {"parent_id": "rp_a_m1"}
	var result: Array = hud._collect_lineage("rp_a", engine)
	hud.free()
	return result.size() == 3 \
		and result.has("rp_a") \
		and result.has("rp_a_m1") \
		and result.has("rp_a_m1_m1")


# ══════════════════════════════════════════════════════════════════════════════
# _max_descendant_depth
# ══════════════════════════════════════════════════════════════════════════════

## No lineage entries → no children map → depth 0.
static func test_max_depth_empty_lineage_returns_zero() -> bool:
	var hud := _make_hud()
	var engine := _make_engine()
	var depth: int = hud._max_descendant_depth("rp_x", engine)
	hud.free()
	return depth == 0


## Root with one live child in lineage → depth 1.
static func test_max_depth_one_live_child_returns_one() -> bool:
	var hud := _make_hud()
	var engine := _make_engine()
	engine.lineage["rp_a_m1"] = {"parent_id": "rp_a"}
	engine.live_rumors["rp_a_m1"] = Rumor.new()
	var depth: int = hud._max_descendant_depth("rp_a", engine)
	hud.free()
	return depth == 1


## Root with one child in lineage but child not in live_rumors → depth 0.
static func test_max_depth_dead_child_returns_zero() -> bool:
	var hud := _make_hud()
	var engine := _make_engine()
	engine.lineage["rp_a_m1"] = {"parent_id": "rp_a"}
	# live_rumors is empty — child is "dead"
	var depth: int = hud._max_descendant_depth("rp_a", engine)
	hud.free()
	return depth == 0
