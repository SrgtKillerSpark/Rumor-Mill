class_name JournalIntelSection
extends RefCounted

## journal_intel_section.gd — Intelligence tab content builder for Journal.
##
## Extracted from journal.gd (SPA-1003). Owns the NPC name filter for the
## Intelligence tab and all recon display logic.
##
## Call setup() once refs are known. Call build(content_vbox, rebuild_cb) to
## populate the content area for the current tab.

# ── Palette ───────────────────────────────────────────────────────────────────

const C_HEADING  := Color(0.92, 0.78, 0.12, 1.0)
const C_BODY     := Color(0.80, 0.72, 0.56, 1.0)
const C_KEY      := Color(0.90, 0.84, 0.68, 1.0)
const C_SUBKEY   := Color(0.65, 0.58, 0.45, 1.0)
const C_LOCKED   := Color(0.40, 0.35, 0.28, 1.0)

# ── State ─────────────────────────────────────────────────────────────────────

## NPC name filter text (persists across tab switches).
var _filter_text: String = ""

# ── Refs ──────────────────────────────────────────────────────────────────────

var _world_ref:       Node2D           = null
var _intel_store_ref: PlayerIntelStore = null
var _day_night_ref:   Node             = null


func setup(world: Node2D, intel_store: PlayerIntelStore, day_night: Node) -> void:
	_world_ref       = world
	_intel_store_ref = intel_store
	_day_night_ref   = day_night


## Build the Intelligence tab content into content_vbox.
## rebuild_cb is called (deferred) whenever the user changes the name filter.
func build(content_vbox: VBoxContainer, rebuild_cb: Callable) -> void:
	_add_section_header(content_vbox, "Intelligence")

	if _intel_store_ref == null:
		_add_body_label(content_vbox, "(Intel store not connected)")
		return

	var npc_names:    Dictionary = _build_npc_name_lookup()
	var npc_factions: Dictionary = _build_npc_faction_lookup()

	# Group relationship intel by NPC.
	var rels_by_npc: Dictionary = {}
	for key in _intel_store_ref.relationship_intel:
		var ri: PlayerIntelStore.RelationshipIntel = _intel_store_ref.relationship_intel[key]
		for nid in [ri.npc_a_id, ri.npc_b_id]:
			if not rels_by_npc.has(nid):
				rels_by_npc[nid] = []
			rels_by_npc[nid].append(ri)

	# Group location observations by NPC.
	var locs_by_npc: Dictionary = {}
	for loc_id in _intel_store_ref.location_intel:
		for obs in _intel_store_ref.location_intel[loc_id]:
			for entry in obs.npcs_seen:
				var nid: String = entry.get("npc_id", "")
				if nid.is_empty():
					continue
				if not locs_by_npc.has(nid):
					locs_by_npc[nid] = []
				locs_by_npc[nid].append({"location": loc_id, "tick": obs.observed_at})

	# Union of all known NPCs.
	var known: Dictionary = {}
	for nid in rels_by_npc:
		known[nid] = true
	for nid in locs_by_npc:
		known[nid] = true

	# ── Filter bar ────────────────────────────────────────────────────────────
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 4)
	content_vbox.add_child(filter_row)

	var filter_lbl := Label.new()
	filter_lbl.text = "Filter:"
	filter_lbl.add_theme_font_size_override("font_size", 12)
	filter_lbl.add_theme_color_override("font_color", C_SUBKEY)
	filter_row.add_child(filter_lbl)

	var filter_edit := LineEdit.new()
	filter_edit.placeholder_text      = "NPC name…"
	filter_edit.text                  = _filter_text
	filter_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_edit.add_theme_font_size_override("font_size", 12)
	filter_row.add_child(filter_edit)

	var clear_btn := Button.new()
	clear_btn.text    = "×"
	clear_btn.visible = not _filter_text.is_empty()
	clear_btn.add_theme_font_size_override("font_size", 12)
	filter_row.add_child(clear_btn)

	filter_edit.text_changed.connect(func(txt: String) -> void:
		_filter_text = txt
		clear_btn.visible = not txt.is_empty()
		rebuild_cb.call_deferred()
	)
	clear_btn.pressed.connect(func() -> void:
		_filter_text = ""
		rebuild_cb.call_deferred()
	)
	# ─────────────────────────────────────────────────────────────────────────

	if known.is_empty():
		_add_body_label(content_vbox, "No intelligence gathered yet.\nRight-click an NPC to Eavesdrop, or right-click a building to Observe.")
		return

	# Apply name filter.
	var filter_lower := _filter_text.to_lower().strip_edges()
	var filtered_npc_ids: Array = known.keys()
	if not filter_lower.is_empty():
		filtered_npc_ids = filtered_npc_ids.filter(func(nid: String) -> bool:
			return npc_names.get(nid, nid).to_lower().contains(filter_lower)
		)

	if filtered_npc_ids.is_empty():
		_add_body_label(content_vbox, "No NPCs match \"%s\"." % _filter_text)
		return

	for npc_id in filtered_npc_ids:
		var npc_name:    String = npc_names.get(npc_id, npc_id)
		var npc_faction: String = npc_factions.get(npc_id, "unknown").capitalize()

		var card_spacer := Control.new()
		card_spacer.custom_minimum_size = Vector2(0, 4)
		content_vbox.add_child(card_spacer)
		var hdr := Label.new()
		hdr.text = "%s — %s" % [npc_name, npc_faction]
		hdr.add_theme_font_size_override("font_size", 14)
		hdr.add_theme_color_override("font_color", C_HEADING)
		content_vbox.add_child(hdr)

		# Relationships.
		if rels_by_npc.has(npc_id):
			_add_key_label(content_vbox, "  Relationships known:")
			for ri in rels_by_npc[npc_id]:
				var other_id:   String = ri.npc_b_id if ri.npc_a_id == npc_id else ri.npc_a_id
				var other_name: String = npc_names.get(other_id, other_id)
				var bars_str:   String = "*".repeat(ri.bars()) + "-".repeat(3 - ri.bars())
				_add_body_label(content_vbox,
					"    - %s: %s [%s]  (eavesdropped %s)" % [
						other_name, ri.affinity_label.capitalize(), bars_str,
						_tick_to_day_str(ri.observed_at)
					])

		# Locations frequented.
		if locs_by_npc.has(npc_id):
			_add_key_label(content_vbox, "  Locations frequented:")
			for obs_entry in locs_by_npc[npc_id]:
				_add_body_label(content_vbox,
					"    - %s: observed %s" % [
						obs_entry["location"].capitalize(),
						_tick_to_day_str(obs_entry["tick"])
					])

		# Locked fields + live reputation.
		var locked := Label.new()
		var rep_text := "  Reputation: [locked until Bribe action]"
		if _world_ref != null and "reputation_system" in _world_ref and _world_ref.reputation_system != null:
			var snap: ReputationSystem.ReputationSnapshot = _world_ref.reputation_system.get_snapshot(npc_id)
			if snap != null:
				var band := ReputationSystem.score_label(snap.score)
				var dead_tag := " [SOCIALLY DEAD]" if snap.is_socially_dead else ""
				rep_text = "  Reputation: %d / 100  — %s%s" % [snap.score, band, dead_tag]
		locked.text = "  Personality: [locked until Bribe action]\n" + rep_text
		locked.add_theme_font_size_override("font_size", 12)
		locked.add_theme_color_override("font_color", C_LOCKED)
		content_vbox.add_child(locked)

		content_vbox.add_child(HSeparator.new())


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


func _build_npc_name_lookup() -> Dictionary:
	var result: Dictionary = {}
	if _world_ref == null:
		return result
	for npc in _world_ref.npcs:
		result[npc.npc_data.get("id", "")] = npc.npc_data.get("name", "?")
	return result


func _build_npc_faction_lookup() -> Dictionary:
	var result: Dictionary = {}
	if _world_ref == null:
		return result
	for npc in _world_ref.npcs:
		result[npc.npc_data.get("id", "")] = npc.npc_data.get("faction", "unknown")
	return result


func _tick_to_day_str(tick: int) -> String:
	var tpd: int = 24
	if _day_night_ref != null and "ticks_per_day" in _day_night_ref:
		tpd = _day_night_ref.ticks_per_day
	var day:          int    = tick / tpd + 1
	var hour_of_day:  int    = tick % tpd
	var period:       String = "AM" if hour_of_day < 12 else "PM"
	var display_hour: int    = hour_of_day % 12
	if display_hour == 0:
		display_hour = 12
	return "Day %d, %02d:00 %s" % [day, display_hour, period]
