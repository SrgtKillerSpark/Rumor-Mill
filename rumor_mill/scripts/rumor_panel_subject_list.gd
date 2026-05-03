class_name RumorPanelSubjectList
extends RefCounted

## rumor_panel_subject_list.gd — Panel 1 subject-selection list builder.
##
## Extracted from rumor_panel.gd (SPA-1014).
## Call setup() once refs are known. Call build() to populate the NPC list
## container. on_select(npc_id) fires when the player clicks "Select as Subject".

# ── Palette ───────────────────────────────────────────────────────────────────

const C_NPC_NAME            := Color(0.88, 0.80, 0.60, 1.0)
const C_LOCKED              := Color(0.42, 0.38, 0.30, 1.0)
const C_SELECTED_SUBJECT_BG := Color(0.20, 0.45, 0.20, 0.55)
const C_RELATION_SUSPICIOUS := Color(1.0,  0.40, 0.35, 1.0)
const C_RELATION_ALLIED     := Color(0.35, 1.0,  0.45, 1.0)
const C_RELATION_NEUTRAL    := Color(0.95, 0.95, 0.40, 1.0)
const C_FACTION_MERCHANT    := Color(1.0,  0.80, 0.20, 1.0)
const C_FACTION_NOBLE       := Color(0.40, 0.60, 1.0,  1.0)
const C_FACTION_CLERGY      := Color(0.90, 0.90, 0.90, 1.0)

# Portrait atlas layout: 6 cols × 5 rows of 64×80 cells (SPA-591 Art Pass 12).
const PORTRAIT_W    := 64
const PORTRAIT_H    := 80
const PORTRAIT_COLS := 6

# ── Refs ──────────────────────────────────────────────────────────────────────

var _world_ref:       Node2D           = null
var _intel_store_ref: PlayerIntelStore = null
var _portrait_tex:    Texture2D        = null


func setup(world: Node2D, intel_store: PlayerIntelStore, portrait_tex: Texture2D) -> void:
	_world_ref       = world
	_intel_store_ref = intel_store
	_portrait_tex    = portrait_tex


## Clears container and rebuilds the NPC subject list.
## on_select(npc_id: String) is called when the player clicks "Select as Subject".
func build(
		container:        VBoxContainer,
		selected_subject: String,
		on_select:        Callable
) -> void:
	for child in container.get_children():
		child.queue_free()

	if _world_ref == null or _intel_store_ref == null:
		return

	for npc in _world_ref.npcs:
		var npc_id:      String = npc.npc_data.get("id",          "")
		var npc_name:    String = npc.npc_data.get("name",        "")
		var faction:     String = npc.npc_data.get("faction",     "")
		var portrait_id: int    = npc.npc_data.get("portrait_id", 0)
		var rels: Array = _intel_store_ref.get_relationships_for_npc(npc_id)

		var entry := _build_entry(npc_id, npc_name, faction, portrait_id, rels, selected_subject, on_select)
		container.add_child(entry)


func _build_entry(
		npc_id:           String,
		npc_name:         String,
		faction:          String,
		portrait_id:      int,
		rels:             Array,
		selected_subject: String,
		on_select:        Callable
) -> Control:
	var outer := PanelContainer.new()

	if npc_id == selected_subject:
		var style := StyleBoxFlat.new()
		style.bg_color = C_SELECTED_SUBJECT_BG
		outer.add_theme_stylebox_override("panel", style)

	var hbox_main := HBoxContainer.new()
	hbox_main.add_theme_constant_override("separation", 8)
	outer.add_child(hbox_main)

	var portrait_rect := _make_portrait_rect(portrait_id)
	hbox_main.add_child(portrait_rect)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_main.add_child(vbox)

	# Header row: faction swatch + name + faction label.
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var swatch_panel := Panel.new()
	swatch_panel.custom_minimum_size = Vector2(18, 18)
	swatch_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sw_col := _faction_color(faction)
	var sw_style := StyleBoxFlat.new()
	sw_style.bg_color = sw_col
	sw_style.set_corner_radius_all(3)
	sw_style.set_border_width_all(1)
	sw_style.border_color = Color(sw_col.r * 0.6, sw_col.g * 0.6, sw_col.b * 0.6, 0.8)
	swatch_panel.add_theme_stylebox_override("panel", sw_style)
	header.add_child(swatch_panel)

	var name_lbl := Label.new()
	name_lbl.text = "  " + npc_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", C_NPC_NAME)
	name_lbl.add_theme_constant_override("outline_size", 1)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	header.add_child(name_lbl)

	var faction_lbl := Label.new()
	faction_lbl.text = "  [" + faction.capitalize() + "]"
	faction_lbl.add_theme_font_size_override("font_size", 13)
	faction_lbl.add_theme_color_override("font_color", _faction_color(faction))
	header.add_child(faction_lbl)

	# Relationship rows.
	if rels.is_empty():
		var lock_lbl := Label.new()
		lock_lbl.text = "    🔒 Relationship: Unknown"
		lock_lbl.add_theme_font_size_override("font_size", 12)
		lock_lbl.add_theme_color_override("font_color", C_LOCKED)
		vbox.add_child(lock_lbl)
	else:
		for intel in rels:
			var other_name: String
			if intel.npc_a_id == npc_id:
				other_name = intel.npc_b_name
			else:
				other_name = intel.npc_a_name

			var bar_str := "[" + "*".repeat(intel.bars()) + " ".repeat(3 - intel.bars()) + "]"
			var prefix: String
			var color: Color
			if intel.affinity_label == "suspicious":
				prefix = "    [!] Suspicious of: "
				color  = C_RELATION_SUSPICIOUS
			elif intel.affinity_label == "allied":
				prefix = "    [*] Close with: "
				color  = C_RELATION_ALLIED
			else:
				prefix = "    [~] Knows: "
				color  = C_RELATION_NEUTRAL

			var rel_lbl := Label.new()
			rel_lbl.text = "%s%s  %s (%s)" % [
				prefix, other_name, bar_str, intel.strength_label()
			]
			rel_lbl.add_theme_font_size_override("font_size", 12)
			rel_lbl.add_theme_color_override("font_color", color)
			vbox.add_child(rel_lbl)

	vbox.add_child(HSeparator.new())

	var btn := Button.new()
	btn.text = "Select as Subject"
	btn.add_theme_font_size_override("font_size", 12)
	var captured_id := npc_id
	btn.pressed.connect(func():
		AudioManager.play_ui("click")
		on_select.call(captured_id)
	)
	vbox.add_child(btn)

	return outer


func _make_portrait_rect(portrait_id: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.custom_minimum_size = Vector2(48, 60)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _portrait_tex != null:
		var col: int = portrait_id % PORTRAIT_COLS
		var row: int = portrait_id / PORTRAIT_COLS
		var atlas := AtlasTexture.new()
		atlas.atlas = _portrait_tex
		atlas.region = Rect2(col * PORTRAIT_W, row * PORTRAIT_H, PORTRAIT_W, PORTRAIT_H)
		rect.texture = atlas
	return rect


static func _faction_color(faction: String) -> Color:
	match faction:
		"merchant": return C_FACTION_MERCHANT
		"noble":    return C_FACTION_NOBLE
		"clergy":   return C_FACTION_CLERGY
		_:          return Color.WHITE
