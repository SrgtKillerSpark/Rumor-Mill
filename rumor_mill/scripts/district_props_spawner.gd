## district_props_spawner.gd — Instantiates district prop Sprite2Ds from the
## DistrictPropsRegistry (SPA-2421).
##
## Art assets are pending SPA-925.  Every sprite path is checked via
## ResourceLoader.exists() before loading; missing files produce a push_warning
## and are silently skipped so the scene remains playable without complete art.
##
## Public API:
##   spawn_district(district_name: String) → void
##
## Isometric world offset follows the same convention as world.gd:
##   wx = (col - row) * (TILE_W / 2)
##   wy = (col + row) * (TILE_H / 2)

class_name DistrictPropsSpawner
extends Node2D

## Half-dimensions of one isometric tile (matches world.gd TILE_SIZE = Vector2i(64, 32)).
const HALF_TILE_W := 32
const HALF_TILE_H := 16


## Spawn Sprite2D children for every registered prop in the given district.
## Props whose sprite file does not yet exist on disk are skipped with a warning.
func spawn_district(district_name: String) -> void:
	var entries := DistrictPropsRegistry.props_for_district(district_name)
	_spawn_from_entries(entries)


## Internal helper that materialises Sprite2D nodes from an array of prop dicts.
## Accepts the same dict schema as DistrictPropsRegistry.PROPS so tests can
## supply synthetic entries without touching the real registry.
func _spawn_from_entries(entries: Array[Dictionary]) -> void:
	for entry: Dictionary in entries:
		var sprite_path: String = entry["sprite"]

		if not ResourceLoader.exists(sprite_path):
			push_warning(
				"DistrictPropsSpawner: sprite not found, skipping prop '%s' (%s)" \
				% [entry["id"], sprite_path]
			)
			continue

		var texture := ResourceLoader.load(sprite_path) as Texture2D
		if texture == null:
			push_warning(
				"DistrictPropsSpawner: resource is not a Texture2D for prop '%s' (%s)" \
				% [entry["id"], sprite_path]
			)
			continue

		var offset: Vector2i = entry["offset"]
		var sprite := Sprite2D.new()
		sprite.name      = entry["id"]
		sprite.texture   = texture
		sprite.z_index   = entry["z_index"]
		sprite.position  = Vector2(
			(offset.x - offset.y) * HALF_TILE_W,
			(offset.x + offset.y) * HALF_TILE_H,
		)
		add_child(sprite)
