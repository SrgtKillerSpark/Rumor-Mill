## scenario_environment_palette.gd — SPA-925: Per-scenario and per-district
## environment tint palettes.
##
## Follows the same pattern as FactionPalette (SPA-712): static dictionaries
## with named accessor methods.  The district entries here are the authoritative
## colour source for district_overlay.gd — edit them here to repaint all overlays.
##
## Scenario moods are applied as a multiplicative world canvas modulate (all
## child nodes share the tint).  Values are kept close to white so the shift is
## atmospheric rather than garish; ±10–15% per channel reads clearly without
## muddying the art.
##
## SPA-925 — defined by Creative Director.

class_name ScenarioEnvironmentPalette


## World canvas modulate tint per scenario.
## Applied with a smooth 2-second tween in TownMoodController.apply_scenario_mood().
const SCENARIO_MOODS: Dictionary = {
	"scenario_1": {
		"name":        "Tutorial",
		"description": "Bright and clear — a new spymaster's hopeful dawn.",
		"canvas_tint": Color(1.00, 1.00, 1.00, 1.0),   # neutral; no shift
	},
	"scenario_2": {
		"name":        "Plague",
		"description": "Sickly green undertone — pestilence hangs in the air.",
		"canvas_tint": Color(0.88, 0.96, 0.84, 1.0),   # muted green cast
	},
	"scenario_3": {
		"name":        "Rival",
		"description": "Cooler and starker — shadows sharpen under rivalry.",
		"canvas_tint": Color(0.84, 0.84, 0.90, 1.0),   # cool blue-grey contrast
	},
	"scenario_4": {
		"name":        "Faction",
		"description": "Competing warm and cool hues paint the divided town.",
		"canvas_tint": Color(0.98, 0.95, 0.90, 1.0),   # gentle warm ivory
	},
	"scenario_5": {
		"name":        "Guild",
		"description": "Rich and prosperous — candlelit halls and amber streets.",
		"canvas_tint": Color(1.00, 0.94, 0.82, 1.0),   # warm amber glow
	},
	"scenario_6": {
		"name":        "Corruption",
		"description": "Deep shadows and blood-red accents — corruption festers.",
		"canvas_tint": Color(0.88, 0.80, 0.80, 1.0),   # shadowed red tinge
	},
}

## Per-district overlay palette.
## "fill"   — semi-transparent zone fill (alpha ≈ 0.09).
## "border" — district outline (alpha ≈ 0.32).
##
## Thematic brief (SPA-925):
##   Market Square    = warm amber
##   Noble Quarter    = cool blue-grey
##   Church District  = muted gold
##   Eastern Quarter  = desaturated brown  (Slums)
##   Civic Heart      = neutral green      (Commons)
const DISTRICT_PALETTES: Dictionary = {
	"Noble Quarter": {
		"fill":   Color(0.26, 0.36, 0.72, 0.09),   # cool royal blue
		"border": Color(0.26, 0.36, 0.72, 0.32),
	},
	"Church District": {
		"fill":   Color(0.78, 0.68, 0.30, 0.09),   # muted gold
		"border": Color(0.78, 0.68, 0.30, 0.32),
	},
	"Market Square": {
		"fill":   Color(0.88, 0.58, 0.14, 0.09),   # warm amber
		"border": Color(0.88, 0.58, 0.14, 0.32),
	},
	"Civic Heart": {
		"fill":   Color(0.34, 0.60, 0.28, 0.09),   # neutral green (Commons)
		"border": Color(0.34, 0.60, 0.28, 0.32),
	},
	"Eastern Quarter": {
		"fill":   Color(0.46, 0.36, 0.24, 0.09),   # desaturated brown (Slums)
		"border": Color(0.46, 0.36, 0.24, 0.32),
	},
}


## Returns the world canvas modulate Color for the given scenario id.
## Falls back to white (no tint) for unknown ids.
static func scenario_canvas_tint(scenario_id: String) -> Color:
	var mood: Dictionary = SCENARIO_MOODS.get(scenario_id, {})
	return mood.get("canvas_tint", Color(1.0, 1.0, 1.0, 1.0))


## Returns a human-readable mood name for the given scenario id.
static func scenario_mood_name(scenario_id: String) -> String:
	var mood: Dictionary = SCENARIO_MOODS.get(scenario_id, {})
	return mood.get("name", "Unknown")


## Returns the semi-transparent fill Color for the named district overlay.
## Falls back to a neutral grey if the district label is unknown.
static func district_fill(district_label: String) -> Color:
	var pal: Dictionary = DISTRICT_PALETTES.get(district_label, {})
	return pal.get("fill", Color(0.5, 0.5, 0.5, 0.07))


## Returns the border Color for the named district overlay.
static func district_border(district_label: String) -> Color:
	var pal: Dictionary = DISTRICT_PALETTES.get(district_label, {})
	return pal.get("border", Color(0.5, 0.5, 0.5, 0.24))


## Returns an array of all defined scenario ids in narrative order.
static func all_scenario_ids() -> Array:
	return SCENARIO_MOODS.keys()


## Returns an array of all defined district labels.
static func all_district_labels() -> Array:
	return DISTRICT_PALETTES.keys()
