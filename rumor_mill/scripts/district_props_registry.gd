## district_props_registry.gd — SPA-925: Detail prop catalogue per town district.
##
## Lists 2–3 small decorative props per district to break visual monotony.
## Each entry names the sprite resource, a grid-cell offset from the district
## centroid, and a z_index relative to the ground layer.
##
## Props are registered here as the design brief; artists produce the sprites at
## res://assets/sprites/props/<id>.png.  A future DistrictPropsSpawner node can
## read this registry to instantiate Sprite2D nodes at world start.
##
## District → theme mapping (SPA-925):
##   Noble Quarter    → heraldic banners, iron gate post, stone planter
##   Church District  → candle stand, prayer shrine, flower urn
##   Market Square    → merchant sign, crate stack, produce basket
##   Civic Heart      → stone well, notice board
##   Eastern Quarter  → broken cart, laundry line, rain barrel
##
## SPA-925 — defined by Creative Director.

class_name DistrictPropsRegistry


## Each entry:
##   "district" : district label — must match a key in ScenarioEnvironmentPalette.DISTRICT_PALETTES
##   "id"       : unique snake_case prop identifier
##   "label"    : human-readable name for debug / UI
##   "sprite"   : res:// path for the Texture2D (placeholder until art is delivered)
##   "offset"   : Vector2i grid-cell offset from district centroid  (x east, y south)
##   "z_index"  : draw order (1 = above ground tiles, below NPCs)
const PROPS: Array[Dictionary] = [
	# ── Noble Quarter ─────────────────────────────────────────────────────────
	{
		"district": "Noble Quarter",
		"id":       "noble_crest_banner",
		"label":    "Heraldic Banner",
		"sprite":   "res://assets/sprites/props/noble_crest_banner.png",
		"offset":   Vector2i(-2,  0),
		"z_index":  1,
	},
	{
		"district": "Noble Quarter",
		"id":       "noble_iron_gate",
		"label":    "Iron Gate Post",
		"sprite":   "res://assets/sprites/props/noble_iron_gate.png",
		"offset":   Vector2i( 0, -2),
		"z_index":  1,
	},
	{
		"district": "Noble Quarter",
		"id":       "noble_stone_planter",
		"label":    "Stone Planter",
		"sprite":   "res://assets/sprites/props/noble_stone_planter.png",
		"offset":   Vector2i( 2,  1),
		"z_index":  1,
	},
	# ── Church District ───────────────────────────────────────────────────────
	{
		"district": "Church District",
		"id":       "church_candle_stand",
		"label":    "Candle Stand",
		"sprite":   "res://assets/sprites/props/church_candle_stand.png",
		"offset":   Vector2i(-1,  0),
		"z_index":  1,
	},
	{
		"district": "Church District",
		"id":       "church_prayer_shrine",
		"label":    "Prayer Shrine",
		"sprite":   "res://assets/sprites/props/church_prayer_shrine.png",
		"offset":   Vector2i( 1, -1),
		"z_index":  1,
	},
	{
		"district": "Church District",
		"id":       "church_flower_urn",
		"label":    "Flower Urn",
		"sprite":   "res://assets/sprites/props/church_flower_urn.png",
		"offset":   Vector2i(-1,  2),
		"z_index":  1,
	},
	# ── Market Square ─────────────────────────────────────────────────────────
	{
		"district": "Market Square",
		"id":       "market_merchant_sign",
		"label":    "Merchant Sign",
		"sprite":   "res://assets/sprites/props/market_merchant_sign.png",
		"offset":   Vector2i(-2,  1),
		"z_index":  1,
	},
	{
		"district": "Market Square",
		"id":       "market_crate_stack",
		"label":    "Crate Stack",
		"sprite":   "res://assets/sprites/props/market_crate_stack.png",
		"offset":   Vector2i( 1,  0),
		"z_index":  1,
	},
	{
		"district": "Market Square",
		"id":       "market_produce_basket",
		"label":    "Produce Basket",
		"sprite":   "res://assets/sprites/props/market_produce_basket.png",
		"offset":   Vector2i( 0,  2),
		"z_index":  1,
	},
	# ── Civic Heart (Commons) ─────────────────────────────────────────────────
	{
		"district": "Civic Heart",
		"id":       "civic_well",
		"label":    "Stone Well",
		"sprite":   "res://assets/sprites/props/civic_well.png",
		"offset":   Vector2i( 0,  0),
		"z_index":  1,
	},
	{
		"district": "Civic Heart",
		"id":       "civic_notice_board",
		"label":    "Notice Board",
		"sprite":   "res://assets/sprites/props/civic_notice_board.png",
		"offset":   Vector2i(-1,  1),
		"z_index":  1,
	},
	# ── Eastern Quarter (Slums) ───────────────────────────────────────────────
	{
		"district": "Eastern Quarter",
		"id":       "slums_broken_cart",
		"label":    "Broken Cart",
		"sprite":   "res://assets/sprites/props/slums_broken_cart.png",
		"offset":   Vector2i( 1, -1),
		"z_index":  1,
	},
	{
		"district": "Eastern Quarter",
		"id":       "slums_laundry_line",
		"label":    "Laundry Line",
		"sprite":   "res://assets/sprites/props/slums_laundry_line.png",
		"offset":   Vector2i(-2,  0),
		"z_index":  1,
	},
	{
		"district": "Eastern Quarter",
		"id":       "slums_rain_barrel",
		"label":    "Rain Barrel",
		"sprite":   "res://assets/sprites/props/slums_rain_barrel.png",
		"offset":   Vector2i( 0,  2),
		"z_index":  1,
	},
]


## Returns all prop entries for the given district label.
static func props_for_district(district_label: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for p: Dictionary in PROPS:
		if p["district"] == district_label:
			result.append(p)
	return result


## Returns all district labels that have at least one prop registered.
static func district_labels() -> Array:
	var labels: Array = []
	for p: Dictionary in PROPS:
		if not labels.has(p["district"]):
			labels.append(p["district"])
	return labels
