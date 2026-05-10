## test_district_props_spawner.gd — GUT tests for DistrictPropsSpawner (SPA-2421).
##
## Covers:
##   • spawn_district() completes without error when all sprite PNGs are absent
##     (graceful fallback — art pending SPA-925).
##   • spawn_district() produces zero Sprite2D children when no sprites exist.
##   • _spawn_from_entries() adds exactly one Sprite2D child per present sprite.
##   • _spawn_from_entries() skips entries whose sprite path does not exist.
##
## Strategy:
##   - "Missing sprites" path uses any Noble Quarter district call; those PNGs
##     do not yet exist on disk, so ResourceLoader.exists() returns false and
##     the spawner must skip every entry without crashing.
##   - "Present sprite" path injects a synthetic prop entry pointing at
##     res://addons/gut/icon.png, which is a real Texture2D shipped with the
##     GUT addon and always available in this project.
##
## DistrictPropsSpawner extends Node2D.  add_child() works without a scene-tree
## parent, so child count assertions are reliable without a full scene setup.

class_name TestDistrictPropsSpawner
extends RefCounted

const SpawnerScript := preload("res://scripts/district_props_spawner.gd")

## A PNG guaranteed to exist in this project (GUT addon icon).
const KNOWN_SPRITE := "res://addons/gut/icon.png"

## A prop-dict that points at a sprite we know is present on disk.
const PRESENT_PROP: Dictionary = {
	"district": "_test_district",
	"id":       "_test_prop_present",
	"label":    "Test Prop (present sprite)",
	"sprite":   KNOWN_SPRITE,
	"offset":   Vector2i(0, 0),
	"z_index":  1,
}

## A prop-dict whose sprite does not exist (mirrors real pending art).
const MISSING_PROP: Dictionary = {
	"district": "_test_district",
	"id":       "_test_prop_missing",
	"label":    "Test Prop (missing sprite)",
	"sprite":   "res://assets/sprites/props/_nonexistent_test_prop.png",
	"offset":   Vector2i(1, 1),
	"z_index":  1,
}


# ── Test runner ────────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Graceful-missing-sprite (SPA-925 pending art scenario)
		"test_spawn_district_missing_sprites_no_crash",
		"test_spawn_district_missing_sprites_zero_children",
		# Present-sprite path
		"test_spawn_from_entries_present_sprite_adds_one_child",
		"test_spawn_from_entries_present_sprite_is_sprite2d",
		"test_spawn_from_entries_present_sprite_has_correct_name",
		# Mixed: one present + one missing
		"test_spawn_from_entries_mixed_adds_only_present",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nDistrictPropsSpawner tests: %d passed, %d failed" % [passed, failed])


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_spawner() -> Node2D:
	return SpawnerScript.new()


# ══════════════════════════════════════════════════════════════════════════════
# Graceful-missing-sprite tests (SPA-925 art pending)
# ══════════════════════════════════════════════════════════════════════════════

## spawn_district() must complete without crash when every prop sprite is absent.
## Noble Quarter has 3 registered props; none of the PNGs exist yet (SPA-925).
static func test_spawn_district_missing_sprites_no_crash() -> bool:
	var spawner := _make_spawner()
	spawner.spawn_district("Noble Quarter")
	# Reaching this line without a crash / error-stop is the pass condition.
	return true


## When no sprites exist, spawn_district() must leave the node childless.
static func test_spawn_district_missing_sprites_zero_children() -> bool:
	var spawner := _make_spawner()
	spawner.spawn_district("Noble Quarter")
	var count := spawner.get_child_count()
	if count != 0:
		push_error("test_spawn_district_missing_sprites_zero_children: expected 0 children, got %d" % count)
		return false
	return true


# ══════════════════════════════════════════════════════════════════════════════
# Present-sprite tests
# ══════════════════════════════════════════════════════════════════════════════

## _spawn_from_entries() with one present-sprite entry must add exactly one child.
static func test_spawn_from_entries_present_sprite_adds_one_child() -> bool:
	var spawner := _make_spawner()
	spawner._spawn_from_entries([PRESENT_PROP])
	var count := spawner.get_child_count()
	if count != 1:
		push_error("test_spawn_from_entries_present_sprite_adds_one_child: expected 1 child, got %d" % count)
		return false
	return true


## The spawned child must be a Sprite2D node.
static func test_spawn_from_entries_present_sprite_is_sprite2d() -> bool:
	var spawner := _make_spawner()
	spawner._spawn_from_entries([PRESENT_PROP])
	var child := spawner.get_child(0)
	if not (child is Sprite2D):
		push_error("test_spawn_from_entries_present_sprite_is_sprite2d: child is not Sprite2D")
		return false
	return true


## The spawned Sprite2D must be named after the prop id.
static func test_spawn_from_entries_present_sprite_has_correct_name() -> bool:
	var spawner := _make_spawner()
	spawner._spawn_from_entries([PRESENT_PROP])
	var child := spawner.get_child(0)
	if child.name != PRESENT_PROP["id"]:
		push_error(
			"test_spawn_from_entries_present_sprite_has_correct_name: expected name '%s', got '%s'"
			% [PRESENT_PROP["id"], child.name]
		)
		return false
	return true


# ══════════════════════════════════════════════════════════════════════════════
# Mixed entries
# ══════════════════════════════════════════════════════════════════════════════

## When entries contain one present and one missing sprite, only the present one
## is spawned (missing entry is skipped with a warning, not a crash).
static func test_spawn_from_entries_mixed_adds_only_present() -> bool:
	var spawner := _make_spawner()
	spawner._spawn_from_entries([MISSING_PROP, PRESENT_PROP])
	var count := spawner.get_child_count()
	if count != 1:
		push_error("test_spawn_from_entries_mixed_adds_only_present: expected 1 child, got %d" % count)
		return false
	var child := spawner.get_child(0)
	if child.name != PRESENT_PROP["id"]:
		push_error(
			"test_spawn_from_entries_mixed_adds_only_present: expected child '%s', got '%s'"
			% [PRESENT_PROP["id"], child.name]
		)
		return false
	return true
