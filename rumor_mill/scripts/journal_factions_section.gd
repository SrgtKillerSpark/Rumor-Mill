class_name JournalFactionsSection
extends RefCounted

## journal_factions_section.gd — Factions tab content builder for Journal.
##
## Extracted from journal.gd (SPA-1003). Displays faction mood, per-NPC
## reputation bars, and active-rumor exposure for the three town factions.
##
## Call setup() once refs are known. Call build(content_vbox) to populate the
## content area for the current tab.

# ── Palette ───────────────────────────────────────────────────────────────────

const C_HEADING      := Color(0.92, 0.78, 0.12, 1.0)
const C_BODY         := Color(0.80, 0.72, 0.56, 1.0)
const C_KEY          := Color(0.90, 0.84, 0.68, 1.0)
const C_SUBKEY       := Color(0.65, 0.58, 0.45, 1.0)
const C_SPREADING    := Color(0.10, 0.68, 0.22, 1.0)
const C_STALLING     := Color(0.82, 0.50, 0.10, 1.0)
const C_CONTRADICTED := Color(0.80, 0.10, 0.10, 1.0)

# ── Refs ──────────────────────────────────────────────────────────────────────

var _world_ref: Node2D = null


func setup(world: Node2D) -> void:
	_world_ref = world


## Build the Factions tab content into content_vbox.
func build(content_vbox: VBoxContainer) -> void:
	_add_section_header(content_vbox, "Factions")

	if _world_ref == null:
		_add_body_label(content_vbox, "(World not connected)")
		return

	const FACTION_DISPLAY := {
		"merchant": "The Merchant Guild",
		"noble":    "The Noble House",
		"clergy":   "The Clergy",
	}
	const FACTION_ACCENT := {
		"merchant": Color(0.784, 0.635, 0.180, 1.0),
		"noble":    Color(0.55, 0.65, 1.00, 1.0),
		"clergy":   Color(0.55, 0.80, 0.95, 1.0),
	}

	var rep_sys = _world_ref.reputation_system if "reputation_system" in _world_ref else null

	for faction_id in ["merchant", "noble", "clergy"]:
		var display_name: String = FACTION_DISPLAY[faction_id]
		var accent: Color = FACTION_ACCENT[faction_id]

		var member_count:    int        = 0
		var active_by_rumor: Dictionary = {}
		var faction_npcs:    Array      = []

		for npc in _world_ref.npcs:
			if npc.npc_data.get("faction", "") != faction_id:
				continue
			member_count += 1
			faction_npcs.append(npc)
			for rid in npc.rumor_slots:
				var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
				if slot.state in [Rumor.RumorState.BELIEVE,
								   Rumor.RumorState.SPREAD,
								   Rumor.RumorState.ACT]:
					if not active_by_rumor.has(rid):
						active_by_rumor[rid] = 0
					active_by_rumor[rid] += 1

		# Derive faction mood from rumor exposure.
		var active_count: int = active_by_rumor.size()
		var mood: String
		if   active_count == 0: mood = "Calm"
		elif active_count == 1: mood = "Unsettled"
		elif active_count <= 3: mood = "Agitated"
		else:                   mood = "Hostile"

		var mood_color: Color
		match mood:
			"Calm":      mood_color = C_SPREADING
			"Unsettled": mood_color = C_STALLING
			_:           mood_color = C_CONTRADICTED

		# Faction header.
		var hdr := Label.new()
		hdr.text = "%s  |  %d members" % [display_name, member_count]
		hdr.add_theme_font_size_override("font_size", 14)
		hdr.add_theme_color_override("font_color", C_HEADING)
		content_vbox.add_child(hdr)

		var mood_lbl := Label.new()
		mood_lbl.text = "  Faction mood: %s" % mood
		mood_lbl.add_theme_font_size_override("font_size", 13)
		mood_lbl.add_theme_color_override("font_color", mood_color)
		content_vbox.add_child(mood_lbl)

		# Per-NPC reputation bars (visual).
		if rep_sys != null:
			_add_key_label(content_vbox, "  Member Reputation:")
			for npc in faction_npcs:
				var npc_id: String = npc.npc_data.get("id", "")
				var npc_name: String = npc.npc_data.get("name", npc_id)
				var snap = rep_sys.get_snapshot(npc_id) if not npc_id.is_empty() else null
				var score: int = snap.score if snap != null else 50
				var is_dead: bool = snap.is_socially_dead if snap != null else false

				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 6)
				content_vbox.add_child(row)

				var nlbl := Label.new()
				nlbl.text = "    " + npc_name
				nlbl.custom_minimum_size = Vector2(130, 0)
				nlbl.add_theme_font_size_override("font_size", 13)
				nlbl.add_theme_color_override("font_color", C_KEY)
				row.add_child(nlbl)

				# Reputation bar background.
				var bar_bg := Panel.new()
				bar_bg.custom_minimum_size = Vector2(140, 14)
				bar_bg.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				var bg_style := StyleBoxFlat.new()
				bg_style.bg_color = Color(0.18, 0.12, 0.06, 1.0)
				bg_style.set_corner_radius_all(3)
				bg_style.set_border_width_all(1)
				bg_style.border_color = Color(0.35, 0.25, 0.12, 0.5)
				bar_bg.add_theme_stylebox_override("panel", bg_style)
				row.add_child(bar_bg)

				# Reputation bar fill.
				var bar_fill := ColorRect.new()
				bar_fill.anchor_bottom = 1.0
				bar_fill.anchor_right = clampf(float(score) / 100.0, 0.0, 1.0)
				var bar_color: Color
				if is_dead:
					bar_color = Color(0.60, 0.15, 0.15, 1.0)
				elif score >= 60:
					bar_color = Color(0.35, 0.80, 0.40, 1.0)
				elif score >= 40:
					bar_color = accent
				elif score >= 25:
					bar_color = Color(0.95, 0.65, 0.20, 1.0)
				else:
					bar_color = Color(0.90, 0.30, 0.20, 1.0)
				bar_fill.color = bar_color
				bar_bg.add_child(bar_fill)

				# Score label.
				var score_lbl := Label.new()
				var tier: String
				if score >= 71:
					tier = "Distinguished"
				elif score >= 51:
					tier = "Respected"
				elif score >= 31:
					tier = "Suspect"
				else:
					tier = "Disgraced"
				score_lbl.text = "%d — %s" % [score, tier]
				if is_dead:
					score_lbl.text += " [DEAD]"
				score_lbl.add_theme_font_size_override("font_size", 12)
				score_lbl.add_theme_color_override("font_color", bar_color)
				row.add_child(score_lbl)

		# Active rumors.
		if active_by_rumor.is_empty():
			_add_body_label(content_vbox, "  No active rumors affecting this faction.")
		else:
			_add_key_label(content_vbox, "  Active rumors affecting faction:")
			for rid in active_by_rumor:
				var rumor: Rumor = _get_rumor_by_id(rid)
				if rumor == null:
					continue
				var claim_str: String = Rumor.ClaimType.keys()[rumor.claim_type].capitalize()
				_add_body_label(content_vbox, "    - %s [%s]: %d member(s) in BELIEVE" % [
					claim_str, rid, active_by_rumor[rid]])

		content_vbox.add_child(HSeparator.new())


func _get_rumor_by_id(rid: String) -> Rumor:
	if _world_ref == null:
		return null
	for npc in _world_ref.npcs:
		if npc.rumor_slots.has(rid):
			return (npc.rumor_slots[rid] as Rumor.NpcRumorSlot).rumor
	return null


# ── UI helpers ────────────────────────────────────────────────────────────────

func _add_section_header(parent: VBoxContainer, title: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	parent.add_child(spacer)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", C_HEADING)
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.3))
	parent.add_child(lbl)
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	parent.add_child(sep)


func _add_body_label(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text          = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C_BODY)
	lbl.add_theme_constant_override("line_spacing", 3)
	parent.add_child(lbl)


func _add_key_label(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C_KEY)
	parent.add_child(lbl)
