## faction_palette.gd — Canonical color palette for faction influence map overlays.
##
## Usage:
##   var col: Color = FactionPalette.zone_color("clergy")
##
## Colors are semi-transparent so they can be layered as TileMap modulate
## overlays without obscuring underlying tile art.  Badge colors are the
## opaque equivalents used in UI shields and legend entries.
##
## Factions defined here extend the three gameplay factions (clergy, merchant,
## noble) with guards, commoners, and underworld to support richer map
## visualisation in future scenarios.
##
## SPA-712 — defined by Creative Director.

class_name FactionPalette


## Semi-transparent zone overlay colors (alpha ≈ 0.38 for legible overlay).
const ZONE_COLORS: Dictionary = {
	"clergy":     Color(0.72, 0.64, 0.90, 0.38),  # Violet-lavender  — ecclesiastical purple
	"merchant":   Color(0.90, 0.66, 0.18, 0.38),  # Amber-gold       — coin and trade
	"noble":      Color(0.20, 0.32, 0.80, 0.38),  # Royal blue       — heraldic blue field
	"guard":      Color(0.50, 0.50, 0.50, 0.38),  # Iron-grey        — armour and order
	"commoner":   Color(0.38, 0.68, 0.30, 0.38),  # Earthy green     — fields and labour
	"underworld": Color(0.60, 0.18, 0.18, 0.38),  # Deep crimson     — shadows and crime
}

## Fully-opaque badge / legend colors (matches ui_faction_badges.png shield fills).
const BADGE_COLORS: Dictionary = {
	"clergy":     Color(0.58, 0.46, 0.80, 1.0),
	"merchant":   Color(0.85, 0.58, 0.12, 1.0),
	"noble":      Color(0.16, 0.26, 0.72, 1.0),
	"guard":      Color(0.44, 0.44, 0.44, 1.0),
	"commoner":   Color(0.30, 0.58, 0.22, 1.0),
	"underworld": Color(0.52, 0.12, 0.12, 1.0),
}

## Human-readable display names.
const DISPLAY_NAMES: Dictionary = {
	"clergy":     "The Church",
	"merchant":   "Merchant Guild",
	"noble":      "Nobility",
	"guard":      "Town Guard",
	"commoner":   "Commoners",
	"underworld": "Underworld",
}


## Returns the semi-transparent zone overlay Color for the given faction id.
## Falls back to a neutral grey if the id is unknown.
static func zone_color(faction_id: String) -> Color:
	return ZONE_COLORS.get(faction_id, Color(0.5, 0.5, 0.5, 0.35))


## Returns the opaque badge Color for the given faction id.
static func badge_color(faction_id: String) -> Color:
	return BADGE_COLORS.get(faction_id, Color(0.5, 0.5, 0.5, 1.0))


## Returns the display name for the given faction id.
static func display_name(faction_id: String) -> String:
	return DISPLAY_NAMES.get(faction_id, faction_id.capitalize())


## Returns an array of all known faction ids.
static func all_ids() -> Array:
	return ZONE_COLORS.keys()
