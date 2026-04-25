class_name RumorPanelClaimList
extends RefCounted

## rumor_panel_claim_list.gd — Panel 2 claim-selection list builder.
##
## Extracted from rumor_panel.gd (SPA-1014).
## Call setup() once refs are known. Call build() to populate the claim list
## container. on_select(claim_id) fires when the player clicks "Select Claim".

# ── Palette ───────────────────────────────────────────────────────────────────

const C_TEMPLATE_TEXT     := Color(0.88, 0.88, 0.80, 1.0)
const C_MUTABILITY        := Color(0.60, 0.75, 1.0,  1.0)
const C_SELECTED_CLAIM_BG := Color(0.20, 0.35, 0.60, 0.55)

const C_CLAIM_ACCUSATION := Color(1.0,  0.35, 0.25, 1.0)
const C_CLAIM_SCANDAL    := Color(1.0,  0.70, 0.10, 1.0)
const C_CLAIM_ILLNESS    := Color(0.60, 1.0,  0.55, 1.0)
const C_CLAIM_PROPHECY   := Color(0.70, 0.55, 1.0,  1.0)
const C_CLAIM_PRAISE     := Color(0.40, 0.85, 1.0,  1.0)
const C_CLAIM_DEATH      := Color(0.55, 0.55, 0.55, 1.0)
const C_CLAIM_HERESY     := Color(1.0,  0.45, 0.85, 1.0)

const C_INTENSITY_LOW  := Color(0.55, 1.0,  0.55, 1.0)
const C_INTENSITY_MED  := Color(1.0,  0.85, 0.30, 1.0)
const C_INTENSITY_HIGH := Color(1.0,  0.35, 0.25, 1.0)

# Map claim types → claim icon column (0=dagger, 1=coin, 2=speech, 3=eye, 4=hands).
const CLAIM_ICON_INDEX := {
	"accusation": 0, "death": 0,
	"scandal": 2,    "heresy": 2,
	"illness": 3,    "prophecy": 3,
	"praise": 4,
}

# ── Refs ──────────────────────────────────────────────────────────────────────

var _world_ref:      Node2D    = null
var _claim_icon_tex: Texture2D = null


func setup(world: Node2D, claim_icon_tex: Texture2D) -> void:
	_world_ref      = world
	_claim_icon_tex = claim_icon_tex


## Clears container and rebuilds the claim list, filtered by subject_faction.
## on_select(claim_id: String) is called when the player clicks "Select Claim".
func build(
		container:         VBoxContainer,
		subject_faction:   String,
		selected_claim_id: String,
		on_select:         Callable
) -> void:
	for child in container.get_children():
		child.queue_free()

	if _world_ref == null:
		return

	var claims: Array = _world_ref.get_claims()
	for claim in claims:
		var target_factions: Array = claim.get("targetFactions", [])
		# Show claim if no faction filter OR subject faction matches.
		if not target_factions.is_empty() and not subject_faction.is_empty():
			if not (subject_faction in target_factions):
				continue
		var entry := _build_entry(claim, selected_claim_id, on_select)
		container.add_child(entry)


func _build_entry(
		claim:             Dictionary,
		selected_claim_id: String,
		on_select:         Callable
) -> Control:
	var claim_id:   String = claim.get("id",           "?")
	var type_str:   String = claim.get("type",         "?")
	var tmpl_text:  String = claim.get("templateText", "")
	var intensity:  int    = int(claim.get("intensity",  3))
	var mutability: float  = float(claim.get("mutability", 3)) / 5.0

	var outer := PanelContainer.new()

	if claim_id == selected_claim_id:
		var style := StyleBoxFlat.new()
		style.bg_color = C_SELECTED_CLAIM_BG
		outer.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	outer.add_child(vbox)

	# Type badge + icon + ID.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	vbox.add_child(header)

	var icon_rect := _make_claim_icon_rect(type_str)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(icon_rect)

	var type_lbl := Label.new()
	type_lbl.text = "[%s]  %s" % [type_str.to_upper(), claim_id]
	type_lbl.add_theme_font_size_override("font_size", 12)
	type_lbl.add_theme_color_override("font_color", _claim_type_color(type_str))
	header.add_child(type_lbl)

	# Template text (the actual rumor wording).
	var tmpl_lbl := Label.new()
	tmpl_lbl.text = '  "' + tmpl_text + '"'
	tmpl_lbl.add_theme_font_size_override("font_size", 12)
	tmpl_lbl.add_theme_color_override("font_color", C_TEMPLATE_TEXT)
	tmpl_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(tmpl_lbl)

	# Stats row: intensity + mutability + base believability.
	var stats_row := HBoxContainer.new()
	vbox.add_child(stats_row)

	var inten_lbl := Label.new()
	inten_lbl.text = "  Intensity: " + "█".repeat(intensity) + "░".repeat(5 - intensity)
	inten_lbl.add_theme_font_size_override("font_size", 12)
	inten_lbl.add_theme_color_override("font_color", _intensity_color(intensity))
	stats_row.add_child(inten_lbl)

	var mut_bars: int = roundi(mutability * 5.0)
	var mut_lbl := Label.new()
	mut_lbl.text = "   Mutability: " + "█".repeat(mut_bars) + "░".repeat(5 - mut_bars)
	mut_lbl.add_theme_font_size_override("font_size", 12)
	mut_lbl.add_theme_color_override("font_color", C_MUTABILITY)
	stats_row.add_child(mut_lbl)

	# Base believability hint — helps player assess claim strength before seed target.
	var base_belief: int = roundi(float(intensity) / 5.0 * 100.0)
	var belief_hint := Label.new()
	belief_hint.text = "   Base Belief: %d%%" % base_belief
	belief_hint.add_theme_font_size_override("font_size", 12)
	var bhint_color: Color
	if base_belief >= 60:
		bhint_color = Color(0.40, 0.90, 0.45, 1.0)
	elif base_belief >= 40:
		bhint_color = Color(0.95, 0.80, 0.30, 1.0)
	else:
		bhint_color = Color(0.95, 0.45, 0.25, 1.0)
	belief_hint.add_theme_color_override("font_color", bhint_color)
	stats_row.add_child(belief_hint)

	vbox.add_child(HSeparator.new())

	var btn := Button.new()
	btn.text = "Select Claim"
	btn.add_theme_font_size_override("font_size", 12)
	var captured_id := claim_id
	btn.pressed.connect(func():
		AudioManager.play_sfx("ui_click")
		on_select.call(captured_id)
	)
	vbox.add_child(btn)

	return outer


func _make_claim_icon_rect(type_str: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _claim_icon_tex != null:
		var idx: int = CLAIM_ICON_INDEX.get(type_str.to_lower(), -1)
		if idx >= 0:
			# Derive icon size from atlas: total width / 5 icons.
			var icon_w: int = int(_claim_icon_tex.get_width()) / 5
			var icon_h: int = int(_claim_icon_tex.get_height())
			rect.custom_minimum_size = Vector2(icon_w, icon_h)
			var atlas := AtlasTexture.new()
			atlas.atlas = _claim_icon_tex
			atlas.region = Rect2(idx * icon_w, 0, icon_w, icon_h)
			rect.texture = atlas
		else:
			rect.custom_minimum_size = Vector2(16, 16)
	else:
		rect.custom_minimum_size = Vector2(16, 16)
	return rect


static func _claim_type_color(type_str: String) -> Color:
	match type_str.to_lower():
		"accusation": return C_CLAIM_ACCUSATION
		"scandal":    return C_CLAIM_SCANDAL
		"illness":    return C_CLAIM_ILLNESS
		"prophecy":   return C_CLAIM_PROPHECY
		"praise":     return C_CLAIM_PRAISE
		"death":      return C_CLAIM_DEATH
		"heresy":     return C_CLAIM_HERESY
		_:            return Color.WHITE


static func _intensity_color(intensity: int) -> Color:
	match intensity:
		1, 2: return C_INTENSITY_LOW
		3:    return C_INTENSITY_MED
		4, 5: return C_INTENSITY_HIGH
		_:    return Color.WHITE
