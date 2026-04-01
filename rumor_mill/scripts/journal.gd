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

const C_PARCHMENT     := Color(0.91, 0.85, 0.70, 1.0)
const C_PANEL_BG      := Color(0.82, 0.74, 0.58, 1.0)
const C_HEADING       := Color(0.50, 0.08, 0.08, 1.0)   # iron-oxide red
const C_BODY          := Color(0.22, 0.15, 0.10, 1.0)   # warm sepia
const C_KEY           := Color(0.06, 0.04, 0.02, 1.0)   # ink black
const C_SUBKEY        := Color(0.35, 0.25, 0.15, 1.0)   # mid sepia
const C_LOCKED        := Color(0.55, 0.48, 0.38, 1.0)   # greyed parchment
const C_TAB_ACTIVE    := Color(0.65, 0.12, 0.12, 1.0)
const C_TAB_INACTIVE  := Color(0.42, 0.34, 0.22, 1.0)

# Badge colours
const C_EVALUATING    := Color(0.25, 0.45, 0.90, 1.0)   # blue
const C_SPREADING     := Color(0.10, 0.68, 0.22, 1.0)   # green
const C_STALLING      := Color(0.82, 0.50, 0.10, 1.0)   # amber
const C_CONTRADICTED  := Color(0.80, 0.10, 0.10, 1.0)   # red
const C_EXPIRED       := Color(0.48, 0.48, 0.48, 1.0)   # grey

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

## Per-rumor expand state: rumor_id → bool.
var _expanded_rumors: Dictionary = {}

## Timeline event log: Array of {tick: int, message: String}.
## External systems can push via push_timeline_event().
var _timeline_log: Array = []

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
	_is_open            = true
	_overlay_bg.visible = true
	_parchment.visible  = true
	_last_opened_tick   = _get_current_tick()
	_notification_pending = false
	_notif_dot.visible  = false
	_pause_game(true)
	_rebuild_section(_current_section)
	call_deferred("_restore_scroll")


func _close() -> void:
	_save_scroll()
	_is_open            = false
	_overlay_bg.visible = false
	_parchment.visible  = false
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
	var c := C_TAB_ACTIVE if active else C_TAB_INACTIVE
	btn.add_theme_color_override("font_color",         c)
	btn.add_theme_color_override("font_pressed_color", C_TAB_ACTIVE)
	btn.add_theme_color_override("font_hover_color",   C_HEADING)


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

	if all_rumors.is_empty():
		_add_body_label("No rumors recorded yet.\nUse the debug console to inject a rumor, or seed one via the Rumor Crafting panel.")
		return

	var npc_names: Dictionary = _build_npc_name_lookup()

	# Sort newest first.
	var sorted_rumors: Array = all_rumors.values()
	sorted_rumors.sort_custom(func(a, b): return a.created_tick > b.created_tick)

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

	var journal_status: String = _rumor_journal_status(rumor, spreaders, believers)
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
	var badge_label := Label.new()
	badge_label.text = "  Seeded: %s   Believability: %.2f   Shelf life: %d/%d ticks" % [
		seed_day_str,
		rumor.current_believability,
		ticks_elapsed,
		rumor.shelf_life_ticks
	]
	badge_label.add_theme_font_size_override("font_size", 10)
	badge_label.add_theme_color_override("font_color", status_color)
	_content_vbox.add_child(badge_label)

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


func _rumor_journal_status(rumor: Rumor, spreaders: int, believers: int) -> String:
	if rumor.current_believability < 0.05:
		return "EXPIRED"
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

	if known.is_empty():
		_add_body_label("No intelligence gathered yet.\nRight-click an NPC to Eavesdrop, or right-click a building to Observe.")
		return

	for npc_id in known:
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

		# Locked fields.
		var locked := Label.new()
		locked.text = "  Personality: [locked until Bribe action]\n  Reputation: [locked until Bribe action]"
		locked.add_theme_font_size_override("font_size", 10)
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
		mood_lbl.add_theme_font_size_override("font_size", 11)
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

	if events.size() <= 1:
		_add_body_label("No events recorded yet.")
		return

	for ev in events:
		var lbl := Label.new()
		lbl.text          = "%-22s  %s" % [_tick_to_day_str(ev["tick"]), ev["message"]]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", C_BODY)
		_content_vbox.add_child(lbl)


# ── Section 5: Objectives ─────────────────────────────────────────────────────

func _build_objectives_section() -> void:
	_add_section_header("Objectives")

	# Scenario header.
	var scenario_lbl := Label.new()
	scenario_lbl.text = "Scenario 1: The Alderman's Ruin"
	scenario_lbl.add_theme_font_size_override("font_size", 14)
	scenario_lbl.add_theme_color_override("font_color", C_HEADING)
	_content_vbox.add_child(scenario_lbl)

	var days_elapsed:    int = (_day_night_ref.current_day - 1) if _day_night_ref != null else 0
	var days_remaining:  int = max(0, 30 - days_elapsed)

	var days_lbl := Label.new()
	days_lbl.text = "Days remaining: %d" % days_remaining
	days_lbl.add_theme_font_size_override("font_size", 11)
	days_lbl.add_theme_color_override("font_color", C_BODY)
	_content_vbox.add_child(days_lbl)

	_content_vbox.add_child(HSeparator.new())

	# Win condition.
	var win_hdr := Label.new()
	win_hdr.text = "WIN CONDITION"
	win_hdr.add_theme_font_size_override("font_size", 12)
	win_hdr.add_theme_color_override("font_color", C_SPREADING)
	_content_vbox.add_child(win_hdr)

	var win_body := Label.new()
	win_body.text = (
		"  Lord Edric Fenn resigns, is removed, or loses faction confidence.\n"
		+ "  (Scenario win/fail tracking pending Sprint 6 scenario layer.)"
	)
	win_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	win_body.add_theme_font_size_override("font_size", 11)
	win_body.add_theme_color_override("font_color", C_BODY)
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
		+ "  [ ] %d days elapsed without win condition  (days remaining: %d)" % [30, days_remaining]
	)
	fail_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	fail_body.add_theme_font_size_override("font_size", 11)
	fail_body.add_theme_color_override("font_color", C_BODY)
	_content_vbox.add_child(fail_body)


# ── Notification dot ──────────────────────────────────────────────────────────

func _on_game_tick(_tick: int) -> void:
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
func push_timeline_event(tick: int, message: String) -> void:
	_timeline_log.append({"tick": tick, "message": message})
	if not _is_open and tick > _last_opened_tick:
		_notification_pending = true
		if _notif_dot != null:
			_notif_dot.visible = true


# ── Helpers ───────────────────────────────────────────────────────────────────

func _add_section_header(title: String) -> void:
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
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", C_BODY)
	_content_vbox.add_child(lbl)


func _add_key_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", C_SUBKEY)
	_content_vbox.add_child(lbl)


func _add_detail_label(parent: Control, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text          = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 10)
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
