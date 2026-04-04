extends CanvasLayer

## journal.gd — Sprint 6 Player Journal UI.
##
## Full-screen parchment overlay with five sections:
##   1. Rumors     — all seeded rumors and propagation state
##   2. Intelligence — recon data (observations + eavesdropping)
##   3. Factions   — faction mood and active rumor exposure
##   4. Timeline   — chronological event log
##   5. Objectives — scenario win/fail progress
##
## Toggle with J.  Pauses game time while open.
## Call setup(world, intel_store, day_night) from main.gd after scene ready.

# ── Palette ───────────────────────────────────────────────────────────────────

const C_PARCHMENT     := Color(0.82, 0.74, 0.58, 1.0)
const C_PANEL_BG      := Color(0.12, 0.08, 0.05, 1.0)   # dark background
const C_HEADING       := Color(0.92, 0.78, 0.12, 1.0)   # gold
const C_BODY          := Color(0.80, 0.72, 0.56, 1.0)   # warm parchment text
const C_KEY           := Color(0.90, 0.84, 0.68, 1.0)   # bright parchment
const C_SUBKEY        := Color(0.65, 0.58, 0.45, 1.0)   # mid parchment
const C_LOCKED        := Color(0.40, 0.35, 0.28, 1.0)   # muted
const C_TAB_ACTIVE    := Color(0.55, 0.38, 0.18, 1.0)   # amber-brown
const C_TAB_INACTIVE  := Color(0.20, 0.14, 0.09, 1.0)   # very dark

# Badge colours
const C_EVALUATING    := Color(0.25, 0.45, 0.90, 1.0)   # blue
const C_SPREADING     := Color(0.10, 0.68, 0.22, 1.0)   # green
const C_STALLING      := Color(0.82, 0.50, 0.10, 1.0)   # amber
const C_CONTRADICTED  := Color(0.80, 0.10, 0.10, 1.0)   # red
const C_EXPIRED       := Color(0.455, 0.431, 0.376, 1.0) # STONE_M (#746E60) — warm grey

# ── Section enum ──────────────────────────────────────────────────────────────

enum Section { RUMORS, INTELLIGENCE, FACTIONS, TIMELINE, OBJECTIVES }
const SECTION_LABELS: Array = ["Rumors", "Intelligence", "Factions", "Timeline", "Objectives"]

# ── References ────────────────────────────────────────────────────────────────

var _world_ref:        Node2D           = null
var _intel_store_ref:  PlayerIntelStore = null
var _day_night_ref:    Node             = null

# ── UI state ──────────────────────────────────────────────────────────────────

var _is_open:           bool      = false
var _current_section:   Section   = Section.RUMORS
var _scroll_positions:  Dictionary = {}   # Section → int (v_scroll pixel)
var _last_opened_tick:  int       = -1
var _notification_pending: bool   = false
var _panel_tween:          Tween  = null

## Per-rumor expand state: rumor_id → bool.
var _expanded_rumors: Dictionary = {}

## Rumors-tab filter text (persists across tab switches).
var _rumor_filter_text: String = ""

## Intelligence-tab filter text (NPC name search).
var _intel_filter_text: String = ""

## Timeline-tab filter text (keyword search).
var _timeline_filter_text: String = ""

## Hard cap on timeline log entries; oldest entries are trimmed when exceeded.
const MAX_TIMELINE_ENTRIES := 200

## Timeline event log: Array of {tick: int, message: String}.
## External systems can push via push_timeline_event(); entries are flushed at tick-end.
var _timeline_log: Array = []

## Events buffered during the current tick, flushed into _timeline_log at tick-end.
var _pending_events: Array = []

# ── Node refs ─────────────────────────────────────────────────────────────────

@onready var _overlay_bg:     ColorRect       = $OverlayBG
@onready var _parchment:      Panel           = $ParchmentPanel
@onready var _close_btn:      Button          = $ParchmentPanel/ParchmentLayout/TitleBar/CloseButton
@onready var _sidebar:        VBoxContainer   = $ParchmentPanel/ParchmentLayout/MainLayout/Sidebar
@onready var _content_scroll: ScrollContainer = $ParchmentPanel/ParchmentLayout/MainLayout/ContentScroll
@onready var _content_vbox:   VBoxContainer   = $ParchmentPanel/ParchmentLayout/MainLayout/ContentScroll/ContentVBox
@onready var _hud_button:     Panel           = $JournalHUDButton
@onready var _notif_dot:      ColorRect       = $JournalHUDButton/NotificationDot


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 12
	_overlay_bg.visible = false
	_parchment.visible  = false
	_notif_dot.visible  = false
	_content_vbox.add_theme_constant_override("separation", 4)
	_build_sidebar()
	_close_btn.pressed.connect(toggle)


func setup(world: Node2D, intel_store: PlayerIntelStore, day_night: Node) -> void:
	_world_ref       = world
	_intel_store_ref = intel_store
	_day_night_ref   = day_night
	if day_night != null:
		day_night.game_tick.connect(_on_game_tick)


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J:
			toggle()
			get_viewport().set_input_as_handled()


# ── Toggle ────────────────────────────────────────────────────────────────────

func toggle() -> void:
	if _is_open:
		_close()
	else:
		_open()


func _open() -> void:
	AudioManager.play_sfx("journal_open")
	_is_open            = true
	_overlay_bg.visible = true
	_parchment.visible  = true
	_last_opened_tick   = _get_current_tick()
	_notification_pending = false
	_notif_dot.visible  = false
	_pause_game(true)
	_rebuild_section(_current_section)
	call_deferred("_restore_scroll")
	# Animate open: fade bg + slide parchment from right.
	_overlay_bg.modulate.a = 0.0
	_parchment.modulate.a = 0.0
	_parchment.position.x += 40.0
	var _open_pos_x: float = _parchment.position.x - 40.0
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_panel_tween.tween_property(_overlay_bg, "modulate:a", 1.0, 0.18)
	_panel_tween.tween_property(_parchment, "modulate:a", 1.0, 0.20)
	_panel_tween.tween_property(_parchment, "position:x", _open_pos_x, 0.25)
	# Grab focus on the first sidebar tab so keyboard navigation works immediately.
	if _sidebar.get_child_count() > 0:
		_sidebar.get_child(0).call_deferred("grab_focus")


func _close() -> void:
	AudioManager.play_sfx("journal_close")
	_save_scroll()
	_is_open            = false
	# Animate close: quick fade.
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_panel_tween.tween_property(_overlay_bg, "modulate:a", 0.0, 0.12)
	_panel_tween.tween_property(_parchment, "modulate:a", 0.0, 0.12)
	_panel_tween.chain().tween_callback(func() -> void:
		_overlay_bg.visible = false
		_parchment.visible  = false
	)
	_pause_game(false)


# ── Sidebar tabs ──────────────────────────────────────────────────────────────

func _build_sidebar() -> void:
	for child in _sidebar.get_children():
		child.queue_free()

	for i in range(SECTION_LABELS.size()):
		var btn := Button.new()
		btn.text                  = SECTION_LABELS[i]
		btn.toggle_mode           = false
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 13)
		_apply_tab_style(btn, i == int(_current_section))
		var sec: Section = i as Section
		btn.pressed.connect(_on_tab_pressed.bind(sec))
		_sidebar.add_child(btn)

	# Push tabs to top.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sidebar.add_child(spacer)


func _apply_tab_style(btn: Button, active: bool) -> void:
	var font_color := C_HEADING if active else Color(0.68, 0.60, 0.46, 1.0)
	btn.add_theme_color_override("font_color",         font_color)
	btn.add_theme_color_override("font_pressed_color", C_HEADING)
	btn.add_theme_color_override("font_hover_color",   C_HEADING)

	var bg_color := C_TAB_ACTIVE if active else C_TAB_INACTIVE
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = bg_color
	style_normal.set_border_width_all(0)
	style_normal.set_content_margin_all(6)
	var style_hover := StyleBoxFlat.new()
	style_hover.bg_color = Color(0.40, 0.28, 0.12, 1.0)
	style_hover.set_border_width_all(0)
	style_hover.set_content_margin_all(6)
	var focus_ring := StyleBoxFlat.new()
	focus_ring.bg_color = Color(0, 0, 0, 0)
	focus_ring.draw_center = false
	focus_ring.set_border_width_all(2)
	focus_ring.border_color = Color(1.00, 0.90, 0.40, 1.0)  # gold focus ring
	btn.add_theme_stylebox_override("normal",  style_normal)
	btn.add_theme_stylebox_override("hover",   style_hover)
	btn.add_theme_stylebox_override("pressed", style_normal)
	btn.add_theme_stylebox_override("focus",   focus_ring)


func _on_tab_pressed(sec: Section) -> void:
	_save_scroll()
	_current_section = sec
	_refresh_sidebar_highlights()
	_rebuild_section(sec)
	call_deferred("_restore_scroll")


func _refresh_sidebar_highlights() -> void:
	var children := _sidebar.get_children()
	var idx := 0
	for child in children:
		if child is Button:
			_apply_tab_style(child, idx == int(_current_section))
			idx += 1


# ── Scroll preservation ───────────────────────────────────────────────────────

func _save_scroll() -> void:
	_scroll_positions[_current_section] = _content_scroll.scroll_vertical


func _restore_scroll() -> void:
	_content_scroll.scroll_vertical = _scroll_positions.get(_current_section, 0)


# ── Section dispatch ──────────────────────────────────────────────────────────

func _rebuild_section(sec: Section) -> void:
	for child in _content_vbox.get_children():
		child.queue_free()

	match sec:
		Section.RUMORS:        _build_rumors_section()
		Section.INTELLIGENCE:  _build_intel_section()
		Section.FACTIONS:      _build_factions_section()
		Section.TIMELINE:      _build_timeline_section()
		Section.OBJECTIVES:    _build_objectives_section()


# ── Section 1: Rumors ─────────────────────────────────────────────────────────

func _build_rumors_section() -> void:
	_add_section_header("Rumors")

	if _world_ref == null:
		_add_body_label("(World not connected)")
		return

	# Collect unique rumors from all NPC slots.
	var all_rumors: Dictionary = {}   # rumor_id → Rumor
	for npc in _world_ref.npcs:
		for rid in npc.rumor_slots:
			if not all_rumors.has(rid):
				all_rumors[rid] = (npc.rumor_slots[rid] as Rumor.NpcRumorSlot).rumor

	# ── Filter bar ────────────────────────────────────────────────────────────
	var filter_row := HBoxContainer.new()
	filter_row.add_theme_constant_override("separation", 4)
	_content_vbox.add_child(filter_row)

	var filter_lbl := Label.new()
	filter_lbl.text = "Filter:"
	filter_lbl.add_theme_font_size_override("font_size", 12)
	filter_lbl.add_theme_color_override("font_color", C_SUBKEY)
	filter_row.add_child(filter_lbl)

	var filter_edit := LineEdit.new()
	filter_edit.placeholder_text       = "subject or claim type…"
	filter_edit.text                   = _rumor_filter_text
	filter_edit.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	filter_edit.add_theme_font_size_override("font_size", 12)
	filter_row.add_child(filter_edit)

	var clear_btn := Button.new()
	clear_btn.text    = "×"
	clear_btn.visible = not _rumor_filter_text.is_empty()
	clear_btn.add_theme_font_size_override("font_size", 12)
	filter_row.add_child(clear_btn)

	filter_edit.text_changed.connect(func(txt: String) -> void:
		_rumor_filter_text = txt
		clear_btn.visible  = not txt.is_empty()
		call_deferred("_rebuild_section", Section.RUMORS)
	)
	clear_btn.pressed.connect(func() -> void:
		_rumor_filter_text = ""
		call_deferred("_rebuild_section", Section.RUMORS)
	)
	# ─────────────────────────────────────────────────────────────────────────

	if all_rumors.is_empty():
		_add_body_label("No rumors recorded yet.\nUse the debug console to inject a rumor, or seed one via the Rumor Crafting panel.")
		return

	var npc_names: Dictionary = _build_npc_name_lookup()

	# Sort newest first.
	var sorted_rumors: Array = all_rumors.values()
	sorted_rumors.sort_custom(func(a, b): return a.created_tick > b.created_tick)

	# Apply text filter (subject name or claim type).
	var filter_lower := _rumor_filter_text.to_lower().strip_edges()
	if not filter_lower.is_empty():
		sorted_rumors = sorted_rumors.filter(func(r: Rumor) -> bool:
			var subj_name: String = npc_names.get(r.subject_npc_id, r.subject_npc_id).to_lower()
			var claim_str: String = Rumor.ClaimType.keys()[r.claim_type].to_lower()
			return subj_name.contains(filter_lower) or claim_str.contains(filter_lower)
		)

	if sorted_rumors.is_empty():
		_add_body_label("No rumors match \"%s\"." % _rumor_filter_text)
		return

	for rumor in sorted_rumors:
		_add_rumor_card(rumor, npc_names)


func _add_rumor_card(rumor: Rumor, npc_names: Dictionary) -> void:
	var rid: String = rumor.id

	# Aggregate NPC states for this rumor.
	var believers: int  = 0
	var spreaders: int  = 0
	var rejectors: int  = 0
	var prop_path: Array = []   # names of NPCs who actively know it

	if _world_ref != null:
		for npc in _world_ref.npcs:
			if not npc.rumor_slots.has(rid):
				continue
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			var nname: String = npc.npc_data.get("name", "?")
			match slot.state:
				Rumor.RumorState.BELIEVE:
					believers += 1
					prop_path.append(nname)
				Rumor.RumorState.SPREAD:
					believers += 1
					spreaders += 1
					prop_path.append(nname)
				Rumor.RumorState.ACT:
					believers += 1
					prop_path.append(nname + " [ACT]")
				Rumor.RumorState.REJECT:
					rejectors += 1
				Rumor.RumorState.EVALUATING:
					prop_path.append(nname + " [eval]")

	var is_contradicted: bool  = _is_contradicted(rumor, spreaders)
	var journal_status: String = _rumor_journal_status(rumor, spreaders, believers, is_contradicted)
	var status_color:   Color  = _rumor_status_color(journal_status)
	var subject_name:   String = npc_names.get(rumor.subject_npc_id, rumor.subject_npc_id)
	var claim_str:      String = Rumor.ClaimType.keys()[rumor.claim_type].capitalize()
	var seed_day_str:   String = _tick_to_day_str(rumor.created_tick)
	var expanded:       bool   = _expanded_rumors.get(rid, false)

	# Collapsed header row — click to expand/collapse.
	var header_btn := Button.new()
	header_btn.text = "%s — %s   [%s]   %d believers  /  %d rejectors" % [
		claim_str, subject_name, journal_status, believers, rejectors]
	header_btn.toggle_mode           = false
	header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_btn.add_theme_font_size_override("font_size", 12)
	header_btn.add_theme_color_override("font_color",         C_KEY)
	header_btn.add_theme_color_override("font_pressed_color", C_HEADING)
	header_btn.add_theme_color_override("font_hover_color",   C_HEADING)
	_content_vbox.add_child(header_btn)

	# Status / shelf-life strip.
	var ticks_elapsed: int = (_day_night_ref.current_tick - rumor.created_tick) \
		if _day_night_ref != null else 0
	var bolstered_tag: String = "   [Bolstered]" if rumor.bolstered_by_evidence else ""
	var badge_label := Label.new()
	badge_label.text = "  Seeded: %s   Believability: %.2f   Shelf life: %d/%d ticks%s" % [
		seed_day_str,
		rumor.current_believability,
		ticks_elapsed,
		rumor.shelf_life_ticks,
		bolstered_tag
	]
	badge_label.add_theme_font_size_override("font_size", 12)
	badge_label.add_theme_color_override("font_color", status_color)
	_content_vbox.add_child(badge_label)

	if rumor.bolstered_by_evidence:
		var bolster_lbl := Label.new()
		bolster_lbl.text = "  [*] Bolstered by evidence."
		bolster_lbl.add_theme_font_size_override("font_size", 12)
		bolster_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35, 1.0))
		bolster_lbl.tooltip_text = "Bolstered by evidence."
		_content_vbox.add_child(bolster_lbl)

	# "Suspect source" label — shown when this rumor was seeded by the rival agent.
	if _world_ref != null and _world_ref.propagation_engine != null:
		var lineage_entry: Dictionary = _world_ref.propagation_engine.lineage.get(rid, {})
		if lineage_entry.get("parent_id", "") == "rival":
			var suspect_lbl := Label.new()
			suspect_lbl.text = "  ⚠ Suspect source — This rumor appears to have an unknown instigator."
			suspect_lbl.add_theme_font_size_override("font_size", 12)
			suspect_lbl.add_theme_color_override("font_color", C_CONTRADICTED)
			_content_vbox.add_child(suspect_lbl)

	# Detail container — toggled by header button.
	var detail := VBoxContainer.new()
	detail.visible = expanded
	_content_vbox.add_child(detail)

	# Wire header click.
	header_btn.pressed.connect(func() -> void:
		_expanded_rumors[rid] = not _expanded_rumors.get(rid, false)
		detail.visible = _expanded_rumors[rid]
	)

	# Propagation path.
	if not prop_path.is_empty():
		_add_detail_label(detail, "  Propagation path:", C_SUBKEY)
		var path_str: String = "    " + "  →  ".join(prop_path)
		var path_lbl := Label.new()
		path_lbl.text            = path_str
		path_lbl.autowrap_mode   = TextServer.AUTOWRAP_WORD
		path_lbl.add_theme_font_size_override("font_size", 10)
		path_lbl.add_theme_color_override("font_color", C_BODY)
		detail.add_child(path_lbl)

	# Mutation log.
	var mutations: Array = _collect_mutations(rid)
	if not mutations.is_empty():
		_add_detail_label(detail, "  Mutation log:", C_SUBKEY)
		for m in mutations:
			var new_subj: String = _build_npc_name_lookup().get(m.subject_npc_id, m.subject_npc_id)
			_add_detail_label(detail,
				"    [%s] Subject → %s" % [_tick_to_day_str(m.created_tick), new_subj],
				C_BODY)

	_content_vbox.add_child(HSeparator.new())


func _is_contradicted(rumor: Rumor, spreaders: int) -> bool:
	## A rumor is CONTRADICTED when it is itself actively spreading AND another
	## rumor about the same subject NPC with opposite sentiment is also spreading.
	if spreaders == 0 or _world_ref == null:
		return false
	var this_positive: bool = Rumor.is_positive_claim(rumor.claim_type)
	for npc in _world_ref.npcs:
		for rid in npc.rumor_slots:
			if rid == rumor.id:
				continue
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			if slot.state != Rumor.RumorState.SPREAD:
				continue
			if slot.rumor.subject_npc_id != rumor.subject_npc_id:
				continue
			if Rumor.is_positive_claim(slot.rumor.claim_type) != this_positive:
				return true
	return false


func _rumor_journal_status(rumor: Rumor, spreaders: int, believers: int, is_contradicted: bool = false) -> String:
	if rumor.current_believability < 0.05:
		return "EXPIRED"
	if is_contradicted:
		return "CONTRADICTED"
	if spreaders > 0:
		return "SPREADING"
	if believers > 0:
		return "STALLING"
	return "EVALUATING"


func _rumor_status_color(status: String) -> Color:
	match status:
		"EVALUATING":   return C_EVALUATING
		"SPREADING":    return C_SPREADING
		"STALLING":     return C_STALLING
		"CONTRADICTED": return C_CONTRADICTED
		"EXPIRED":      return C_EXPIRED
	return C_BODY


func _collect_mutations(parent_rid: String) -> Array:
	## Returns all Rumor objects whose lineage_parent_id == parent_rid.
	var results: Array   = []
	var seen:    Dictionary = {}
	for npc in (_world_ref.npcs if _world_ref != null else []):
		for rid in npc.rumor_slots:
			if seen.has(rid):
				continue
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			if slot.rumor.lineage_parent_id == parent_rid:
				results.append(slot.rumor)
				seen[rid] = true
	return results


# ── Section 2: Intelligence ───────────────────────────────────────────────────

func _build_intel_section() -> void:
	_add_section_header("Intelligence")

	if _intel_store_ref == null:
		_add_body_label("(Intel store not connected)")
		return

	var npc_names:    Dictionary = _build_npc_name_lookup()
	var npc_factions: Dictionary = _build_npc_faction_lookup()

	# Group relationship intel by NPC.
	var rels_by_npc: Dictionary = {}   # npc_id → Array[RelationshipIntel]
	for key in _intel_store_ref.relationship_intel:
		var ri: PlayerIntelStore.RelationshipIntel = _intel_store_ref.relationship_intel[key]
		for nid in [ri.npc_a_id, ri.npc_b_id]:
			if not rels_by_npc.has(nid):
				rels_by_npc[nid] = []
			rels_by_npc[nid].append(ri)

	# Group location observations by NPC.
	var locs_by_npc: Dictionary = {}   # npc_id → Array[{location, tick}]
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
	var intel_filter_row := HBoxContainer.new()
	intel_filter_row.add_theme_constant_override("separation", 4)
	_content_vbox.add_child(intel_filter_row)

	var intel_filter_lbl := Label.new()
	intel_filter_lbl.text = "Filter:"
	intel_filter_lbl.add_theme_font_size_override("font_size", 12)
	intel_filter_lbl.add_theme_color_override("font_color", C_SUBKEY)
	intel_filter_row.add_child(intel_filter_lbl)

	var intel_filter_edit := LineEdit.new()
	intel_filter_edit.placeholder_text      = "NPC name…"
	intel_filter_edit.text                  = _intel_filter_text
	intel_filter_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	intel_filter_edit.add_theme_font_size_override("font_size", 12)
	intel_filter_row.add_child(intel_filter_edit)

	var intel_clear_btn := Button.new()
	intel_clear_btn.text    = "×"
	intel_clear_btn.visible = not _intel_filter_text.is_empty()
	intel_clear_btn.add_theme_font_size_override("font_size", 12)
	intel_filter_row.add_child(intel_clear_btn)

	intel_filter_edit.text_changed.connect(func(txt: String) -> void:
		_intel_filter_text = txt
		intel_clear_btn.visible = not txt.is_empty()
		call_deferred("_rebuild_section", Section.INTELLIGENCE)
	)
	intel_clear_btn.pressed.connect(func() -> void:
		_intel_filter_text = ""
		call_deferred("_rebuild_section", Section.INTELLIGENCE)
	)
	# ─────────────────────────────────────────────────────────────────────────

	if known.is_empty():
		_add_body_label("No intelligence gathered yet.\nRight-click an NPC to Eavesdrop, or right-click a building to Observe.")
		return

	# Apply name filter.
	var filter_lower := _intel_filter_text.to_lower().strip_edges()
	var filtered_npc_ids: Array = known.keys()
	if not filter_lower.is_empty():
		filtered_npc_ids = filtered_npc_ids.filter(func(nid: String) -> bool:
			return npc_names.get(nid, nid).to_lower().contains(filter_lower)
		)

	if filtered_npc_ids.is_empty():
		_add_body_label("No NPCs match \"%s\"." % _intel_filter_text)
		return

	for npc_id in filtered_npc_ids:
		var npc_name:    String = npc_names.get(npc_id, npc_id)
		var npc_faction: String = npc_factions.get(npc_id, "unknown").capitalize()

		# NPC card header.
		var hdr := Label.new()
		hdr.text = "%s — %s" % [npc_name, npc_faction]
		hdr.add_theme_font_size_override("font_size", 13)
		hdr.add_theme_color_override("font_color", C_HEADING)
		_content_vbox.add_child(hdr)

		# Relationships.
		if rels_by_npc.has(npc_id):
			_add_key_label("  Relationships known:")
			for ri in rels_by_npc[npc_id]:
				var other_id:   String = ri.npc_b_id if ri.npc_a_id == npc_id else ri.npc_a_id
				var other_name: String = npc_names.get(other_id, other_id)
				var bars_str:   String = "*".repeat(ri.bars()) + "-".repeat(3 - ri.bars())
				_add_body_label(
					"    - %s: %s [%s]  (eavesdropped %s)" % [
						other_name, ri.affinity_label.capitalize(), bars_str,
						_tick_to_day_str(ri.observed_at)
					])

		# Locations frequented.
		if locs_by_npc.has(npc_id):
			_add_key_label("  Locations frequented:")
			for obs_entry in locs_by_npc[npc_id]:
				_add_body_label(
					"    - %s: observed %s" % [
						obs_entry["location"].capitalize(),
						_tick_to_day_str(obs_entry["tick"])
					])

		# Locked fields + live reputation (debug-visible per design doc Sprint 3 note).
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
		_content_vbox.add_child(locked)

		_content_vbox.add_child(HSeparator.new())


# ── Section 3: Factions ───────────────────────────────────────────────────────

func _build_factions_section() -> void:
	_add_section_header("Factions")

	if _world_ref == null:
		_add_body_label("(World not connected)")
		return

	const FACTION_DISPLAY := {
		"merchant": "The Merchant Guild",
		"noble":    "The Noble House",
		"clergy":   "The Clergy",
	}

	for faction_id in ["merchant", "noble", "clergy"]:
		var display_name: String = FACTION_DISPLAY[faction_id]

		var member_count:    int        = 0
		var active_by_rumor: Dictionary = {}   # rumor_id → believers in faction

		for npc in _world_ref.npcs:
			if npc.npc_data.get("faction", "") != faction_id:
				continue
			member_count += 1
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
		_content_vbox.add_child(hdr)

		var mood_lbl := Label.new()
		mood_lbl.text = "  Faction mood: %s" % mood
		mood_lbl.add_theme_font_size_override("font_size", 12)
		mood_lbl.add_theme_color_override("font_color", mood_color)
		_content_vbox.add_child(mood_lbl)

		# Active rumors.
		if active_by_rumor.is_empty():
			_add_body_label("  No active rumors affecting this faction.")
		else:
			_add_key_label("  Active rumors affecting faction:")
			for rid in active_by_rumor:
				var rumor: Rumor = _get_rumor_by_id(rid)
				if rumor == null:
					continue
				var claim_str: String = Rumor.ClaimType.keys()[rumor.claim_type].capitalize()
				_add_body_label("    - %s [%s]: %d member(s) in BELIEVE" % [
					claim_str, rid, active_by_rumor[rid]])

		_content_vbox.add_child(HSeparator.new())


func _get_rumor_by_id(rid: String) -> Rumor:
	if _world_ref == null:
		return null
	for npc in _world_ref.npcs:
		if npc.rumor_slots.has(rid):
			return (npc.rumor_slots[rid] as Rumor.NpcRumorSlot).rumor
	return null


# ── Section 4: Timeline ───────────────────────────────────────────────────────

func _build_timeline_section() -> void:
	_add_section_header("Timeline")

	var events: Array = []

	# Always include game start.
	events.append({"tick": 0, "message": "Game started."})

	# External push-log events (e.g. from scenario system).
	events.append_array(_timeline_log)

	# Derive rumor-origin and mutation events from NPC slots.
	var seen_rumors: Dictionary = {}
	for npc in (_world_ref.npcs if _world_ref != null else []):
		for rid in npc.rumor_slots:
			if seen_rumors.has(rid):
				continue
			seen_rumors[rid] = true
			var rumor: Rumor = (npc.rumor_slots[rid] as Rumor.NpcRumorSlot).rumor
			var claim_str: String = Rumor.ClaimType.keys()[rumor.claim_type].capitalize()
			if rumor.lineage_parent_id == "":
				events.append({
					"tick": rumor.created_tick,
					"message": "Rumor seeded: [%s] %s" % [claim_str, rid]
				})
			else:
				events.append({
					"tick": rumor.created_tick,
					"message": "Mutation: %s branched from %s" % [rid, rumor.lineage_parent_id]
				})

	# Derive intel observations.
	if _intel_store_ref != null:
		for loc_id in _intel_store_ref.location_intel:
			for obs in _intel_store_ref.location_intel[loc_id]:
				events.append({
					"tick": obs.observed_at,
					"message": "Recon: Observed %s (%d NPC(s) present)." % [
						loc_id.capitalize(), obs.npcs_seen.size()]
				})
		for key in _intel_store_ref.relationship_intel:
			var ri: PlayerIntelStore.RelationshipIntel = _intel_store_ref.relationship_intel[key]
			events.append({
				"tick": ri.observed_at,
				"message": "Recon: Eavesdropped on %s ↔ %s (%s)." % [
					ri.npc_a_name, ri.npc_b_name, ri.affinity_label]
			})

	# Sort ascending.
	events.sort_custom(func(a, b) -> bool: return a["tick"] < b["tick"])

	# ── Timeline filter bar ───────────────────────────────────────────────────
	var tl_filter_row := HBoxContainer.new()
	tl_filter_row.add_theme_constant_override("separation", 4)
	_content_vbox.add_child(tl_filter_row)

	var tl_filter_lbl := Label.new()
	tl_filter_lbl.text = "Filter:"
	tl_filter_lbl.add_theme_font_size_override("font_size", 12)
	tl_filter_lbl.add_theme_color_override("font_color", C_SUBKEY)
	tl_filter_row.add_child(tl_filter_lbl)

	var tl_filter_edit := LineEdit.new()
	tl_filter_edit.placeholder_text      = "keyword…"
	tl_filter_edit.text                  = _timeline_filter_text
	tl_filter_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl_filter_edit.add_theme_font_size_override("font_size", 12)
	tl_filter_row.add_child(tl_filter_edit)

	var tl_clear_btn := Button.new()
	tl_clear_btn.text    = "×"
	tl_clear_btn.visible = not _timeline_filter_text.is_empty()
	tl_clear_btn.add_theme_font_size_override("font_size", 12)
	tl_filter_row.add_child(tl_clear_btn)

	tl_filter_edit.text_changed.connect(func(txt: String) -> void:
		_timeline_filter_text = txt
		tl_clear_btn.visible = not txt.is_empty()
		call_deferred("_rebuild_section", Section.TIMELINE)
	)
	tl_clear_btn.pressed.connect(func() -> void:
		_timeline_filter_text = ""
		call_deferred("_rebuild_section", Section.TIMELINE)
	)
	# ─────────────────────────────────────────────────────────────────────────

	if events.size() <= 1:
		_add_body_label("No events recorded yet.")
		return

	# Apply keyword filter.
	var tl_filter_lower := _timeline_filter_text.to_lower().strip_edges()
	var filtered_events: Array = events
	if not tl_filter_lower.is_empty():
		filtered_events = events.filter(func(ev: Dictionary) -> bool:
			return ev["message"].to_lower().contains(tl_filter_lower)
		)

	if filtered_events.is_empty():
		_add_body_label("No events match \"%s\"." % _timeline_filter_text)
		return

	# Render events with day-break sub-headers.
	var tpd: int = 24
	if _day_night_ref != null and "ticks_per_day" in _day_night_ref:
		tpd = _day_night_ref.ticks_per_day
	var current_day := -1
	for ev in filtered_events:
		var event_day: int = ev["tick"] / tpd + 1
		if event_day != current_day:
			current_day = event_day
			var day_hdr := Label.new()
			day_hdr.text = "── Day %d ──" % event_day
			day_hdr.add_theme_font_size_override("font_size", 12)
			day_hdr.add_theme_color_override("font_color", C_SUBKEY)
			_content_vbox.add_child(day_hdr)
		var lbl := Label.new()
		lbl.text          = "  %s  %s" % [_tick_to_day_str(ev["tick"]), ev["message"]]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", C_BODY)
		_content_vbox.add_child(lbl)


# ── Section 5: Objectives ─────────────────────────────────────────────────────

func _build_objectives_section() -> void:
	_add_section_header("Objectives")

	# Pull reputation snapshots and scenario manager (may be null early in game).
	var rep: ReputationSystem = null
	var sm:  ScenarioManager  = null
	if _world_ref != null and "reputation_system" in _world_ref:
		rep = _world_ref.reputation_system
	if _world_ref != null and "scenario_manager" in _world_ref:
		sm = _world_ref.scenario_manager

	var days_elapsed: int = (_day_night_ref.current_day - 1) if _day_night_ref != null else 0

	# Per-scenario day limits (from scenarios.json); used for cross-scenario display.
	const S1_DAYS := 30
	const S2_DAYS := 20
	const S3_DAYS := 25
	const S4_DAYS := 20

	var s1_days_remaining: int = max(0, S1_DAYS - days_elapsed)
	var s2_days_remaining: int = max(0, S2_DAYS - days_elapsed)
	var s3_days_remaining: int = max(0, S3_DAYS - days_elapsed)
	var s4_days_remaining: int = max(0, S4_DAYS - days_elapsed)

	var edric_snap:  ReputationSystem.ReputationSnapshot = rep.get_snapshot("edric_fenn")  if rep != null else null
	var calder_snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot("calder_fenn") if rep != null else null
	var tomas_snap:  ReputationSystem.ReputationSnapshot = rep.get_snapshot("tomas_reeve") if rep != null else null
	var aldous_snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot("aldous_prior") if rep != null else null
	var vera_snap:   ReputationSystem.ReputationSnapshot = rep.get_snapshot("vera_midwife")  if rep != null else null
	var finn_snap:   ReputationSystem.ReputationSnapshot = rep.get_snapshot("finn_monk")     if rep != null else null

	var active_scenario_id: String = ""
	if _world_ref != null and "active_scenario_id" in _world_ref:
		active_scenario_id = _world_ref.active_scenario_id

	var s1_state := ScenarioManager.ScenarioState.ACTIVE
	if sm != null:
		s1_state = sm.scenario_1_state

	var s4_state := ScenarioManager.ScenarioState.ACTIVE
	if sm != null:
		s4_state = sm.scenario_4_state

	# ── Scenario 1 ────────────────────────────────────────────────────────
	var s1_lbl := Label.new()
	s1_lbl.text = "Scenario 1: The Alderman's Ruin"
	s1_lbl.add_theme_font_size_override("font_size", 14)
	s1_lbl.add_theme_color_override("font_color", C_HEADING)
	_content_vbox.add_child(s1_lbl)

	if active_scenario_id == "scenario_1" or active_scenario_id.is_empty():
		var days_lbl := Label.new()
		days_lbl.text = "Days remaining: %d / %d" % [s1_days_remaining, S1_DAYS]
		days_lbl.add_theme_font_size_override("font_size", 12)
		days_lbl.add_theme_color_override("font_color", C_BODY)
		_content_vbox.add_child(days_lbl)

	_content_vbox.add_child(HSeparator.new())

	# Win condition.
	var win_hdr := Label.new()
	win_hdr.text = "WIN CONDITION"
	win_hdr.add_theme_font_size_override("font_size", 12)
	win_hdr.add_theme_color_override("font_color", C_SPREADING)
	_content_vbox.add_child(win_hdr)

	var edric_score_str := "50"
	var edric_band_str  := "Respected"
	if edric_snap != null:
		edric_score_str = str(edric_snap.score)
		edric_band_str  = ReputationSystem.score_label(edric_snap.score)

	var s1_win_status := "[ACTIVE]"
	var s1_win_color  := C_BODY
	match s1_state:
		ScenarioManager.ScenarioState.WON:
			s1_win_status = "[WON]"
			s1_win_color  = C_SPREADING
		ScenarioManager.ScenarioState.FAILED:
			s1_win_status = "[FAILED]"
			s1_win_color  = C_CONTRADICTED

	var win_body := Label.new()
	win_body.text = (
		"  Lord Edric Fenn reputation drops below %d.\n"
		+ "  Current:  %s / 100  — %s  %s\n"
		+ "  Target:   < %d (Disgraced — faction loyalty collapses)"
	) % [ScenarioManager.S1_WIN_EDRIC_BELOW, edric_score_str, edric_band_str, s1_win_status, ScenarioManager.S1_WIN_EDRIC_BELOW]
	win_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	win_body.add_theme_font_size_override("font_size", 12)
	win_body.add_theme_color_override("font_color", s1_win_color)
	_content_vbox.add_child(win_body)

	_content_vbox.add_child(HSeparator.new())

	# Fail conditions.
	var fail_hdr := Label.new()
	fail_hdr.text = "FAIL CONDITIONS"
	fail_hdr.add_theme_font_size_override("font_size", 12)
	fail_hdr.add_theme_color_override("font_color", C_CONTRADICTED)
	_content_vbox.add_child(fail_hdr)

	var fail_body := Label.new()
	fail_body.text = (
		"  [ ] Identified as rumor source by Sergeant Bram — suspicion: LOW\n"
		+ "  [ ] %d days elapsed without win condition  (days remaining: %d)"
	) % [S1_DAYS, s1_days_remaining]
	fail_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	fail_body.add_theme_font_size_override("font_size", 12)
	fail_body.add_theme_color_override("font_color", C_BODY)
	_content_vbox.add_child(fail_body)

	_content_vbox.add_child(HSeparator.new())

	# ── Scenario 2 ────────────────────────────────────────────────────────
	var s2_state := ScenarioManager.ScenarioState.ACTIVE
	if sm != null:
		s2_state = sm.scenario_2_state

	var s2_lbl := Label.new()
	s2_lbl.text = "Scenario 2: The Plague Scare"
	s2_lbl.add_theme_font_size_override("font_size", 14)
	s2_lbl.add_theme_color_override("font_color", C_HEADING)
	_content_vbox.add_child(s2_lbl)

	var s2_win_status := "[ACTIVE]"
	var s2_win_color  := C_BODY
	match s2_state:
		ScenarioManager.ScenarioState.WON:
			s2_win_status = "[WON]"
			s2_win_color  = C_SPREADING
		ScenarioManager.ScenarioState.FAILED:
			s2_win_status = "[FAILED]"
			s2_win_color  = C_CONTRADICTED

	var s2_win_hdr := Label.new()
	s2_win_hdr.text = "WIN CONDITION"
	s2_win_hdr.add_theme_font_size_override("font_size", 12)
	s2_win_hdr.add_theme_color_override("font_color", C_SPREADING)
	_content_vbox.add_child(s2_win_hdr)

	var illness_count := 0
	if sm != null and rep != null:
		illness_count = sm.get_scenario_2_progress(rep).get("illness_believer_count", 0)

	var s2_win_body := Label.new()
	s2_win_body.text = (
		"  %d / %d townsfolk believe Alys Herbwife is spreading illness.  %s"
	) % [illness_count, ScenarioManager.S2_WIN_ILLNESS_MIN, s2_win_status]
	s2_win_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s2_win_body.add_theme_font_size_override("font_size", 12)
	s2_win_body.add_theme_color_override("font_color", s2_win_color)
	_content_vbox.add_child(s2_win_body)

	_content_vbox.add_child(HSeparator.new())

	var s2_fail_hdr := Label.new()
	s2_fail_hdr.text = "FAIL CONDITIONS"
	s2_fail_hdr.add_theme_font_size_override("font_size", 12)
	s2_fail_hdr.add_theme_color_override("font_color", C_CONTRADICTED)
	_content_vbox.add_child(s2_fail_hdr)

	var maren_rejected := rep != null and rep.has_illness_rejecter(ScenarioManager.ALYS_HERBWIFE_ID, ScenarioManager.MAREN_NUN_ID)
	var s2_timed_out   := s2_days_remaining == 0

	var s2_fail_body := Label.new()
	s2_fail_body.text = (
		"  %s Sister Maren contradicts illness rumors about Alys Herbwife\n"
		+ "  %s %d days elapsed without win condition  (days remaining: %d)"
	) % ["[x]" if maren_rejected else "[ ]",
		"[x]" if s2_timed_out else "[ ]", S2_DAYS, s2_days_remaining]
	s2_fail_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s2_fail_body.add_theme_font_size_override("font_size", 12)
	s2_fail_body.add_theme_color_override("font_color", C_BODY)
	_content_vbox.add_child(s2_fail_body)

	_content_vbox.add_child(HSeparator.new())

	# ── Scenario 3 ────────────────────────────────────────────────────────
	var s3_suffix := "  (upcoming)" if active_scenario_id != "scenario_3" else ""
	var s3_lbl := Label.new()
	s3_lbl.text = "Scenario 3: The Succession%s" % s3_suffix
	s3_lbl.add_theme_font_size_override("font_size", 14)
	s3_lbl.add_theme_color_override("font_color", C_HEADING)
	_content_vbox.add_child(s3_lbl)

	if active_scenario_id == "scenario_3":
		var s3_days_lbl := Label.new()
		s3_days_lbl.text = "Days remaining: %d / %d" % [s3_days_remaining, S3_DAYS]
		s3_days_lbl.add_theme_font_size_override("font_size", 12)
		s3_days_lbl.add_theme_color_override("font_color", C_BODY)
		_content_vbox.add_child(s3_days_lbl)

	var calder_score_str := "50"
	var calder_band_str  := "Respected"
	if calder_snap != null:
		calder_score_str = str(calder_snap.score)
		calder_band_str  = ReputationSystem.score_label(calder_snap.score)

	var tomas_score_str := "50"
	var tomas_band_str  := "Respected"
	if tomas_snap != null:
		tomas_score_str = str(tomas_snap.score)
		tomas_band_str  = ReputationSystem.score_label(tomas_snap.score)

	var s3_body := Label.new()
	s3_body.text = (
		"  WIN:  Calder Fenn \u2265 %d  AND  Tomas Reeve \u2264 %d\n"
		+ "  FAIL: Calder Fenn < 40\n\n"
		+ "  Calder Fenn:   %s / 100  — %s  (target: \u2265%d)\n"
		+ "  Tomas Reeve:   %s / 100  — %s  (target: \u2264%d)"
	) % [ScenarioManager.S3_WIN_CALDER_MIN, ScenarioManager.S3_WIN_TOMAS_MAX,
		calder_score_str, calder_band_str, ScenarioManager.S3_WIN_CALDER_MIN,
		tomas_score_str, tomas_band_str, ScenarioManager.S3_WIN_TOMAS_MAX]
	s3_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s3_body.add_theme_font_size_override("font_size", 12)
	s3_body.add_theme_color_override("font_color", C_BODY)
	_content_vbox.add_child(s3_body)

	_content_vbox.add_child(HSeparator.new())

	# ── Scenario 4 ────────────────────────────────────────────────────────
	var s4_suffix := "  (upcoming)" if active_scenario_id != "scenario_4" else ""
	var s4_lbl := Label.new()
	s4_lbl.text = "Scenario 4: The Holy Inquisition%s" % s4_suffix
	s4_lbl.add_theme_font_size_override("font_size", 14)
	s4_lbl.add_theme_color_override("font_color", C_HEADING)
	_content_vbox.add_child(s4_lbl)

	var s4_win_status := "[ACTIVE]"
	var s4_win_color  := C_BODY
	match s4_state:
		ScenarioManager.ScenarioState.WON:
			s4_win_status = "[WON]"
			s4_win_color  = C_SPREADING
		ScenarioManager.ScenarioState.FAILED:
			s4_win_status = "[FAILED]"
			s4_win_color  = C_CONTRADICTED

	if active_scenario_id == "scenario_4":
		var s4_days_lbl := Label.new()
		s4_days_lbl.text = "Days remaining: %d / %d" % [s4_days_remaining, S4_DAYS]
		s4_days_lbl.add_theme_font_size_override("font_size", 12)
		s4_days_lbl.add_theme_color_override("font_color", C_BODY)
		_content_vbox.add_child(s4_days_lbl)

	_content_vbox.add_child(HSeparator.new())

	var s4_win_hdr := Label.new()
	s4_win_hdr.text = "WIN CONDITION"
	s4_win_hdr.add_theme_font_size_override("font_size", 12)
	s4_win_hdr.add_theme_color_override("font_color", C_SPREADING)
	_content_vbox.add_child(s4_win_hdr)

	var aldous_score_str := "50"
	var aldous_band_str  := "Respected"
	if aldous_snap != null:
		aldous_score_str = str(aldous_snap.score)
		aldous_band_str  = ReputationSystem.score_label(aldous_snap.score)

	var vera_score_str := "50"
	var vera_band_str  := "Respected"
	if vera_snap != null:
		vera_score_str = str(vera_snap.score)
		vera_band_str  = ReputationSystem.score_label(vera_snap.score)

	var finn_score_str := "50"
	var finn_band_str  := "Respected"
	if finn_snap != null:
		finn_score_str = str(finn_snap.score)
		finn_band_str  = ReputationSystem.score_label(finn_snap.score)

	var s4_win_body := Label.new()
	s4_win_body.text = (
		"  All three accused survive %d days with reputation \u2265 %d.  %s\n\n"
		+ "  Aldous Prior:  %s / 100  \u2014 %s\n"
		+ "  Vera Midwife:  %s / 100  \u2014 %s\n"
		+ "  Finn Monk:     %s / 100  \u2014 %s\n"
		+ "  Floor: \u2265 %d  (all three must stay above this)"
	) % [S4_DAYS, ScenarioManager.S4_WIN_REP_MIN, s4_win_status,
		aldous_score_str, aldous_band_str,
		vera_score_str, vera_band_str,
		finn_score_str, finn_band_str,
		ScenarioManager.S4_WIN_REP_MIN]
	s4_win_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s4_win_body.add_theme_font_size_override("font_size", 12)
	s4_win_body.add_theme_color_override("font_color", s4_win_color)
	_content_vbox.add_child(s4_win_body)

	_content_vbox.add_child(HSeparator.new())

	var s4_fail_hdr := Label.new()
	s4_fail_hdr.text = "FAIL CONDITIONS"
	s4_fail_hdr.add_theme_font_size_override("font_size", 12)
	s4_fail_hdr.add_theme_color_override("font_color", C_CONTRADICTED)
	_content_vbox.add_child(s4_fail_hdr)

	var s4_fail_body := Label.new()
	s4_fail_body.text = (
		"  [ ] Any accused NPC drops below %d reputation\n"
		+ "  [ ] %d days elapsed without all three surviving  (days remaining: %d)"
	) % [ScenarioManager.S4_FAIL_REP_BELOW, S4_DAYS, s4_days_remaining]
	s4_fail_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s4_fail_body.add_theme_font_size_override("font_size", 12)
	s4_fail_body.add_theme_color_override("font_color", C_BODY)
	_content_vbox.add_child(s4_fail_body)


# ── Notification dot ──────────────────────────────────────────────────────────

func _on_game_tick(_tick: int) -> void:
	# Tick-end flush: move buffered events into the log, then trim to cap.
	if not _pending_events.is_empty():
		_timeline_log.append_array(_pending_events)
		_pending_events.clear()
		if _timeline_log.size() > MAX_TIMELINE_ENTRIES:
			_timeline_log = _timeline_log.slice(_timeline_log.size() - MAX_TIMELINE_ENTRIES)

	if _is_open or _notification_pending:
		return
	if _has_new_entries_since(_last_opened_tick):
		_notification_pending = true
		if _notif_dot != null:
			_notif_dot.visible = true


func _has_new_entries_since(since_tick: int) -> bool:
	if since_tick < 0:
		return false
	if _world_ref != null:
		for npc in _world_ref.npcs:
			for rid in npc.rumor_slots:
				var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
				if slot.rumor.created_tick > since_tick:
					return true
	if _intel_store_ref != null:
		for loc_id in _intel_store_ref.location_intel:
			for obs in _intel_store_ref.location_intel[loc_id]:
				if obs.observed_at > since_tick:
					return true
		for key in _intel_store_ref.relationship_intel:
			var ri: PlayerIntelStore.RelationshipIntel = _intel_store_ref.relationship_intel[key]
			if ri.observed_at > since_tick:
				return true
	return false


# ── Public API ────────────────────────────────────────────────────────────────

## Called by scenario or world systems to record a named timeline event.
## Events are buffered in _pending_events and flushed to _timeline_log at tick-end.
func push_timeline_event(tick: int, message: String) -> void:
	_pending_events.append({"tick": tick, "message": message})
	if not _is_open and tick > _last_opened_tick:
		_notification_pending = true
		if _notif_dot != null:
			_notif_dot.visible = true


## Called by SaveManager after a load to restore the persisted timeline log.
## Replaces _timeline_log in-place; clears any buffered pending events.
func restore_timeline(entries: Array) -> void:
	_timeline_log   = entries.duplicate(true)
	_pending_events.clear()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _add_section_header(title: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	_content_vbox.add_child(spacer)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", C_HEADING)
	_content_vbox.add_child(lbl)
	_content_vbox.add_child(HSeparator.new())


func _add_body_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text          = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", C_BODY)
	_content_vbox.add_child(lbl)


func _add_key_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", C_SUBKEY)
	_content_vbox.add_child(lbl)


func _add_detail_label(parent: Control, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text          = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
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


func _get_current_tick() -> int:
	if _day_night_ref != null and "current_tick" in _day_night_ref:
		return _day_night_ref.current_tick
	return 0


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


func _pause_game(paused: bool) -> void:
	if _day_night_ref != null and _day_night_ref.has_method("set_paused"):
		_day_night_ref.set_paused(paused)
