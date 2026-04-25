## test_district_overlay.gd — Unit tests for district_overlay.gd (SPA-1042).
##
## Covers:
##   • Tile constants: TILE_W=64, TILE_H=32
##   • DISTRICTS: 5 entries, each has label/x1/y1/x2/y2 keys
##   • _iso(x, y): pure isometric-to-screen conversion
##       formula: Vector2((x-y)*(TILE_W/2), (x+y)*(TILE_H/2))
##
## Run from the Godot editor: Scene → Run Script.

class_name TestDistrictOverlay
extends RefCounted

const DistrictOverlayScript := preload("res://scripts/district_overlay.gd")


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_do() -> Node2D:
	return DistrictOverlayScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# Tile constants
		"test_tile_w",
		"test_tile_h",
		# DISTRICTS
		"test_districts_count",
		"test_districts_all_have_label",
		"test_districts_all_have_bounds",
		# _iso() pure conversion
		"test_iso_origin",
		"test_iso_one_zero",
		"test_iso_zero_one",
		"test_iso_two_two",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nDistrictOverlay tests: %d passed, %d failed" % [passed, failed])


# ── Tile constants ────────────────────────────────────────────────────────────

static func test_tile_w() -> bool:
	var d := _make_do()
	var ok := d.TILE_W == 64
	d.free()
	return ok


static func test_tile_h() -> bool:
	var d := _make_do()
	var ok := d.TILE_H == 32
	d.free()
	return ok


# ── DISTRICTS ─────────────────────────────────────────────────────────────────

static func test_districts_count() -> bool:
	var d := _make_do()
	var ok := d.DISTRICTS.size() == 5
	d.free()
	return ok


static func test_districts_all_have_label() -> bool:
	var d := _make_do()
	var ok := true
	for dist in d.DISTRICTS:
		if not dist.has("label") or (dist["label"] as String).is_empty():
			ok = false
			break
	d.free()
	return ok


static func test_districts_all_have_bounds() -> bool:
	var d := _make_do()
	var ok := true
	for dist in d.DISTRICTS:
		if not (dist.has("x1") and dist.has("y1") and dist.has("x2") and dist.has("y2")):
			ok = false
			break
	d.free()
	return ok


# ── _iso() pure conversion ────────────────────────────────────────────────────
#
# formula: Vector2((x - y) * (TILE_W / 2), (x + y) * (TILE_H / 2))
# TILE_W=64, TILE_H=32 → TILE_W/2=32, TILE_H/2=16

## _iso(0, 0) → (0, 0)
static func test_iso_origin() -> bool:
	var d := _make_do()
	var got: Vector2 = d._iso(0, 0)
	var ok := got.is_equal_approx(Vector2(0.0, 0.0))
	d.free()
	return ok


## _iso(1, 0) → ((1-0)*32, (1+0)*16) = (32, 16)
static func test_iso_one_zero() -> bool:
	var d := _make_do()
	var got: Vector2 = d._iso(1, 0)
	var ok := got.is_equal_approx(Vector2(32.0, 16.0))
	d.free()
	return ok


## _iso(0, 1) → ((0-1)*32, (0+1)*16) = (-32, 16)
static func test_iso_zero_one() -> bool:
	var d := _make_do()
	var got: Vector2 = d._iso(0, 1)
	var ok := got.is_equal_approx(Vector2(-32.0, 16.0))
	d.free()
	return ok


## _iso(2, 2) → ((2-2)*32, (2+2)*16) = (0, 64)
static func test_iso_two_two() -> bool:
	var d := _make_do()
	var got: Vector2 = d._iso(2, 2)
	var ok := got.is_equal_approx(Vector2(0.0, 64.0))
	d.free()
	return ok
