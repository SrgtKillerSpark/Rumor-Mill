extends CanvasLayer

## rumor_panel.gd — Sprint 3 Panel 1: Rumor Crafting – Subject Selection.
##
## Press R (handled by ReconHUD) to toggle.
## Displays all NPCs with faction badges and known relationship data.
## NPCs without any eavesdrop intel show a lock-icon placeholder.
##
## Call setup(world, intel_store) after the scene tree is ready.

@onready var panel:      Panel          = $Panel
@onready var title_label: Label         = $Panel/VBox/TitleLabel
@onready var hint_label:  Label         = $Panel/VBox/HintLabel
@onready var npc_list:   VBoxContainer  = $Panel/VBox/Scroll/NPCList

var _world_ref:       Node2D           = null
var _intel_store_ref: PlayerIntelStore = null


func _ready() -> void:
	layer = 15
	panel.visible = false


func setup(world: Node2D, intel_store: PlayerIntelStore) -> void:
	_world_ref       = world
	_intel_store_ref = intel_store


func toggle() -> void:
	panel.visible = not panel.visible
	if panel.visible:
		_rebuild_list()


# ── List builder ──────────────────────────────────────────────────────────────

func _rebuild_list() -> void:
	# Clear previous entries.
	for child in npc_list.get_children():
		child.queue_free()

	if _world_ref == null or _intel_store_ref == null:
		return

	for npc in _world_ref.npcs:
		var npc_id:   String = npc.npc_data.get("id",      "")
		var npc_name: String = npc.npc_data.get("name",    "")
		var faction:  String = npc.npc_data.get("faction", "")
		var rels: Array = _intel_store_ref.get_relationships_for_npc(npc_id)

		var entry := _build_entry(npc_id, npc_name, faction, rels)
		npc_list.add_child(entry)


func _build_entry(
		npc_id:   String,
		npc_name: String,
		faction:  String,
		rels:     Array
) -> Control:
	var outer := PanelContainer.new()

	var vbox := VBoxContainer.new()
	outer.add_child(vbox)

	# ── Header row: colour swatch + name + faction ──────────────────────────
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(14, 14)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.color = _faction_color(faction)
	header.add_child(swatch)

	var name_lbl := Label.new()
	name_lbl.text = "  " + npc_name
	name_lbl.add_theme_font_size_override("font_size", 11)
	header.add_child(name_lbl)

	var faction_lbl := Label.new()
	faction_lbl.text = "  [" + faction.capitalize() + "]"
	faction_lbl.add_theme_font_size_override("font_size", 10)
	faction_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1.0))
	header.add_child(faction_lbl)

	# ── Relationship rows ───────────────────────────────────────────────────
	if rels.is_empty():
		var lock_lbl := Label.new()
		lock_lbl.text = "    [Lock] Relationship: Unknown"
		lock_lbl.add_theme_font_size_override("font_size", 10)
		lock_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45, 1.0))
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
				color  = Color(1.0, 0.40, 0.35, 1.0)
			elif intel.affinity_label == "allied":
				prefix = "    [*] Close with: "
				color  = Color(0.35, 1.0, 0.45, 1.0)
			else:
				prefix = "    [~] Knows: "
				color  = Color(0.95, 0.95, 0.40, 1.0)

			var rel_lbl := Label.new()
			rel_lbl.text = "%s%s  %s (%s)" % [
				prefix, other_name, bar_str, intel.strength_label()
			]
			rel_lbl.add_theme_font_size_override("font_size", 10)
			rel_lbl.add_theme_color_override("font_color", color)
			vbox.add_child(rel_lbl)

	# Thin separator between NPCs.
	vbox.add_child(HSeparator.new())

	return outer


static func _faction_color(faction: String) -> Color:
	match faction:
		"merchant": return Color(1.0, 0.80, 0.20, 1.0)
		"noble":    return Color(0.40, 0.60, 1.0,  1.0)
		"clergy":   return Color(0.90, 0.90, 0.90, 1.0)
		_:          return Color.WHITE
