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
const C_LOCKED        := Color(0.60, 0.55, 0.45, 1.0)   # locked — WCAG AA: ~5.5:1 vs C_PANEL_BG
const C_TAB_ACTIVE    := Color(0.55, 0.38, 0.18, 1.0)   # amber-brown
const C_TAB_INACTIVE  := Color(0.20, 0.14, 0.09, 1.0)   # very dark

# Badge colours
const C_EVALUATING    := Color(0.25, 0.45, 0.90, 1.0)   # blue
const C_SPREADING     := Color(0.10, 0.68, 0.22, 1.0)   # green
const C_STALLING      := Color(0.82, 0.50, 0.10, 1.0)   # amber
const C_CONTRADICTED  := Color(0.80, 0.10, 0.10, 1.0)   # red
const C_EXPIRED       := Color(0.455, 0.431, 0.376, 1.0) # STONE_M (#746E60) — warm grey

# ── Section enum ──────────────────────────────────────────────────────────────

enum Section { RUMORS, INTELLIGENCE, FACTIONS, TIMELINE, OBJECTIVES, MILESTONES }
const SECTION_LABELS: Array = ["Rumors", "Intelligence", "Factions", "Timeline", "Objectives", "Milestones"]

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
var _dot_pulse_tween:      Tween  = null

## Per-rumor expand state: rumor_id → bool.
var _expanded_rumors: Dictionary = {}

## State-change tracking: rumor_id → last-seen journal status string.
## Snapshotted on journal close so we can diff on next open.
var _rumor_last_status: Dictionary = {}

## Rumor IDs whose status changed since last journal visit.
## Populated on _open(), cleared on _close().
var _changed_rumor_ids: Dictionary = {}

## Summary of transitions since last visit: {status_string → count}.
var _transition_summary: Dictionary = {}

## Rumors-tab filter text (persists across tab switches).
var _rumor_filter_text: String = ""

## Rumors-tab status filter: "" = all, or one of the status strings.
var _rumor_status_filter: String = ""

## Rumors-tab sort order: true = newest first (default), false = oldest first.
var _rumor_sort_newest: bool = true

## Intelligence-tab filter text (NPC name search).
var _intel_filter_text: String = ""

## Timeline-tab filter text (keyword search).
var _timeline_filter_text: String = ""

## Timeline-tab sort order: true = newest first, false = oldest first (default).
var _timeline_sort_newest: bool = false

## Timeline-tab "Today" filter: when true, only show events from the current day.
var _timeline_today_filter: bool = false

## Hard cap on timeline log entries; oldest entries are trimmed when exceeded.
const MAX_TIMELINE_ENTRIES := 200

## Timeline event log: Array of {tick: int, message: String}.
## External systems can push via push_timeline_event(); entries are flushed at tick-end.
var _timeline_log: Array = []

## Events buffered during the current tick, flushed into _timeline_log at tick-end.
var _pending_events: Array = []

## Hard cap on milestone log entries.
const MAX_MILESTONE_ENTRIES := 100

## Milestone log: Array of {text: String, color_packed: int, reward_text: String}.
## Populated via push_milestone_event() called by MilestoneNotifier.
var _milestone_log: Array = []

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
	_content_vbox.add_theme_constant_override("separation", 5)
	_build_sidebar()
	_close_btn.pressed.connect(toggle)


func setup(world: Node2D, intel_store: PlayerIntelStore, day_night: Node) -> void:
	_world_ref       = world
	_intel_store_ref = intel_store
	_day_night_ref   = day_night
	if day_night != null:
		day_night.game_tick.connect(_on_game_tick)


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J:
			toggle()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and _is_open:
			_close()
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
	_stop_dot_pulse()
	_compute_status_diff()
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
	_panel_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
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
	# Snapshot current statuses so next open can detect changes.
	_rumor_last_status = _snapshot_rumor_statuses()
	_changed_rumor_ids.clear()
	_transition_summary.clear()
	# Animate close: quick fade.
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_panel_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
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

	# SPA-769: Tooltip text for journal tab buttons.
	var _tab_tooltips: Array = [
		"Rumors\nAll rumors you have seeded. Track their spread and filter by status.",
		"Intelligence\nObservations and eavesdropping data collected through recon actions.",
		"Factions\nThe three town factions and how your rumors are shifting their influence.",
		"Timeline\nA chronological log of events, rumors seeded, and NPC state changes.",
		"Objectives\nYour scenario win and fail conditions, with current progress.",
		"Milestones\nNotable achievements unlocked during this run.",
	]
	for i in range(SECTION_LABELS.size()):
		var btn := Button.new()
		btn.text                  = SECTION_LABELS[i]
		btn.toggle_mode           = false
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 13)
		if i < _tab_tooltips.size():
			btn.tooltip_text = _tab_tooltips[i]
		_apply_tab_style(btn, i == int(_current_section))
		var sec: Section = i as Section
		btn.pressed.connect(_on_tab_pressed.bind(sec))
		_sidebar.add_child(btn)

	# Wire focus neighbors so arrow/Tab keys cycle through the sidebar tabs.
	var tab_buttons: Array[Button] = []
	for child in _sidebar.get_children():
		if child is Button:
			tab_buttons.append(child)
	for i in tab_buttons.size():
		var prev_idx: int = (i - 1) % tab_buttons.size()
		var next_idx: int = (i + 1) % tab_buttons.size()
		tab_buttons[i].focus_neighbor_top    = tab_buttons[prev_idx].get_path()
		tab_buttons[i].focus_neighbor_bottom = tab_buttons[next_idx].get_path()
		tab_buttons[i].focus_next            = tab_buttons[next_idx].get_path()
		tab_buttons[i].focus_previous        = tab_buttons[prev_idx].get_path()

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
		Section.MILESTONES:    _build_milestones_section()


# ── Section 1: Rumors ─────────────────────────────────────────────────────────

func _build_rumors_section() -> void:
	_add_section_header("Rumors")

	if _world_ref == null:
		_add_body_label("(World not connected)")
		return

	# ── What's New banner ────────────────────────────────────────────────────
	if not _transition_summary.is_empty():
		var banner_panel := PanelContainer.new()
		var banner_style := StyleBoxFlat.new()
		banner_style.bg_color = Color(0.18, 0.14, 0.08, 0.95)
		banner_style.border_color = C_HEADING
		banner_style.set_border_width_all(1)
		banner_style.set_corner_radius_all(3)
		banner_style.set_content_margin_all(6)
		banner_panel.add_theme_stylebox_override("panel", banner_style)
		_content_vbox.add_child(banner_panel)

		var banner_vbox := VBoxContainer.new()
		banner_panel.add_child(banner_vbox)

		var banner_title := Label.new()
		banner_title.text = "What's Changed"
		banner_title.add_theme_font_size_override("font_size", 13)
		banner_title.add_theme_color_override("font_color", C_HEADING)
		banner_vbox.add_child(banner_title)

		var parts: Array = []
		for st in _transition_summary:
			var cnt: int = _transition_summary[st]
			parts.append("%d now %s" % [cnt, st.capitalize()])
		var summary_lbl := Label.new()
		summary_lbl.text = "  " + ", ".join(parts) + " since last check"
		summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		summary_lbl.add_theme_font_size_override("font_size", 12)
		summary_lbl.add_theme_color_override("font_color", C_KEY)
		banner_vbox.add_child(summary_lbl)

		# Auto-dismiss after 5 seconds of unpaused time so the banner stays
		# visible for its full duration even when the scene tree is paused.
		var banner_timer := get_tree().create_timer(5.0, true)
		banner_timer.timeout.connect(func() -> void:
			if is_instance_valid(banner_panel):
				var tw := create_tween()
				tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				tw.tween_property(banner_panel, "modulate:a", 0.0, 0.3)
				tw.tween_callback(banner_panel.queue_free)
		)

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

	# ── Status filter buttons ────────────────────────────────────────────────
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 3)
	_content_vbox.add_child(status_row)

	var status_lbl := Label.new()
	status_lbl.text = "Status:"
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", C_SUBKEY)
	status_row.add_child(status_lbl)

	# Pre-compute per-status counts for badge display.
	var _status_counts: Dictionary = {}
	var _total_rumor_count: int = all_rumors.size()
	for _cnt_rid in all_rumors:
		var _cr: Rumor = all_rumors[_cnt_rid]
		var _cspr: int = 0
		var _cbel: int = 0
		if _world_ref != null:
			for npc in _world_ref.npcs:
				if npc.rumor_slots.has(_cnt_rid):
					var _cslot: Rumor.NpcRumorSlot = npc.rumor_slots[_cnt_rid]
					if _cslot.state == Rumor.RumorState.SPREAD:
						_cspr += 1; _cbel += 1
					elif _cslot.state == Rumor.RumorState.BELIEVE or _cslot.state == Rumor.RumorState.ACT:
						_cbel += 1
		var _cis_cont: bool = _is_contradicted(_cr, _cspr)
		var _cst: String = _rumor_journal_status(_cr, _cspr, _cbel, _cis_cont)
		_status_counts[_cst] = _status_counts.get(_cst, 0) + 1

	var status_options: Array = ["", "EVALUATING", "SPREADING", "STALLING", "CONTRADICTED", "EXPIRED"]
	var status_labels: Array  = ["All", "Evaluating", "Spreading", "Stalling", "Contradicted", "Expired"]
	for si in range(status_options.size()):
		var sbtn := Button.new()
		var _btn_count: int = _total_rumor_count if status_options[si] == "" else _status_counts.get(status_options[si], 0)
		sbtn.text = "%s (%d)" % [status_labels[si], _btn_count]
		sbtn.add_theme_font_size_override("font_size", 12)
		var is_active: bool = _rumor_status_filter == status_options[si]
		var sbtn_style := StyleBoxFlat.new()
		sbtn_style.set_content_margin_all(3)
		if is_active:
			sbtn_style.bg_color = C_TAB_ACTIVE
			sbtn.add_theme_color_override("font_color", C_HEADING)
		else:
			sbtn_style.bg_color = C_TAB_INACTIVE
			sbtn.add_theme_color_override("font_color", C_SUBKEY)
		sbtn.add_theme_stylebox_override("normal", sbtn_style)
		var captured_status: String = status_options[si]
		sbtn.pressed.connect(func() -> void:
			_rumor_status_filter = captured_status
			call_deferred("_rebuild_section", Section.RUMORS)
		)
		# Wire focus neighbours so arrow keys cycle through the status buttons.
		sbtn.focus_mode = Control.FOCUS_ALL
		status_row.add_child(sbtn)

	# ── Sort toggle ──────────────────────────────────────────────────────────
	var sort_btn := Button.new()
	sort_btn.text = "↓ Newest" if _rumor_sort_newest else "↑ Oldest"
	sort_btn.add_theme_font_size_override("font_size", 12)
	sort_btn.add_theme_color_override("font_color", C_KEY)
	sort_btn.focus_mode = Control.FOCUS_ALL
	sort_btn.pressed.connect(func() -> void:
		_rumor_sort_newest = not _rumor_sort_newest
		call_deferred("_rebuild_section", Section.RUMORS)
	)
	status_row.add_child(sort_btn)

	# ─────────────────────────────────────────────────────────────────────────

	if all_rumors.is_empty():
		_add_body_label("No rumors recorded yet.\nUse the debug console to inject a rumor, or seed one via the Rumor Crafting panel.")
		return

	var npc_names: Dictionary = _build_npc_name_lookup()

	# Sort by creation tick (newest or oldest first).
	var sorted_rumors: Array = all_rumors.values()
	if _rumor_sort_newest:
		sorted_rumors.sort_custom(func(a, b): return a.created_tick > b.created_tick)
	else:
		sorted_rumors.sort_custom(func(a, b): return a.created_tick < b.created_tick)

	# Apply text filter (subject name or claim type).
	var filter_lower := _rumor_filter_text.to_lower().strip_edges()
	if not filter_lower.is_empty():
		sorted_rumors = sorted_rumors.filter(func(r: Rumor) -> bool:
			var subj_name: String = npc_names.get(r.subject_npc_id, r.subject_npc_id).to_lower()
			var claim_str: String = Rumor.ClaimType.keys()[r.claim_type].to_lower()
			return subj_name.contains(filter_lower) or claim_str.contains(filter_lower)
		)

	# Apply status filter — compute status for each rumor to match.
	if not _rumor_status_filter.is_empty():
		sorted_rumors = sorted_rumors.filter(func(r: Rumor) -> bool:
			var spr: int = 0
			var bel: int = 0
			if _world_ref != null:
				for npc in _world_ref.npcs:
					if npc.rumor_slots.has(r.id):
						var slot: Rumor.NpcRumorSlot = npc.rumor_slots[r.id]
						if slot.state == Rumor.RumorState.SPREAD:
							spr += 1; bel += 1
						elif slot.state == Rumor.RumorState.BELIEVE or slot.state == Rumor.RumorState.ACT:
							bel += 1
			var is_cont: bool = _is_contradicted(r, spr)
			var st: String = _rumor_journal_status(r, spr, bel, is_cont)
			return st == _rumor_status_filter
		)

	if sorted_rumors.is_empty():
		var hint := _rumor_filter_text if not _rumor_filter_text.is_empty() else _rumor_status_filter
		_add_body_label("No rumors match \"%s\"." % hint)
		return

	for rumor in sorted_rumors:
		_add_rumor_card(rumor, npc_names)


func _add_rumor_card(rumor: Rumor, npc_names: Dictionary) -> void:
	var rid: String = rumor.id

	# Aggregate NPC states for this rumor.
	var believers: int  = 0
	var spreaders: int  = 0
	var rejectors: int  = 0
	var prop_path: Array = []          # names of NPCs who actively know it
	var spreader_set: Dictionary = {}  # nname → true for currently SPREAD NPCs

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
					spreader_set[nname] = true
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

	# ── State-change left-border accent ─────────────────────────────────────
	var _card_has_change: bool = _changed_rumor_ids.has(rid)
	if _card_has_change:
		var accent_bar := ColorRect.new()
		accent_bar.custom_minimum_size = Vector2(0, 2)
		accent_bar.color = C_HEADING if _is_positive_transition(journal_status) else C_CONTRADICTED
		_content_vbox.add_child(accent_bar)

	# Collapsed header row — click to expand/collapse.
	var header_btn := Button.new()
	var _change_marker: String = " *" if _card_has_change else ""
	header_btn.text = "%s — %s   [%s]   %d believers  /  %d rejectors%s" % [
		claim_str, subject_name, journal_status, believers, rejectors, _change_marker]
	header_btn.toggle_mode           = false
	header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_btn.add_theme_font_size_override("font_size", 12)
	header_btn.add_theme_color_override("font_color",         C_KEY)
	header_btn.add_theme_color_override("font_pressed_color", C_HEADING)
	header_btn.add_theme_color_override("font_hover_color",   C_HEADING)

	if _card_has_change:
		var hdr_style := StyleBoxFlat.new()
		hdr_style.set_content_margin_all(4)
		hdr_style.bg_color = Color(0.15, 0.11, 0.06, 1.0)
		hdr_style.border_color = C_HEADING if _is_positive_transition(journal_status) else C_CONTRADICTED
		hdr_style.set_border_width_all(0)
		hdr_style.border_width_left = 3
		header_btn.add_theme_stylebox_override("normal", hdr_style)

	# Card wrapper with background tint based on rumor status.
	var card_panel := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.set_corner_radius_all(4)
	card_style.content_margin_left   = 4.0
	card_style.content_margin_right  = 4.0
	card_style.content_margin_top    = 4.0
	card_style.content_margin_bottom = 4.0
	match journal_status:
		"SPREADING", "EVALUATING":
			card_style.bg_color = Color(0.22, 0.16, 0.08, 0.55)  # warm amber tint
		"EXPIRED", "CONTRADICTED":
			card_style.bg_color = Color(0.14, 0.14, 0.12, 0.55)  # desaturated grey tint
		_:
			card_style.bg_color = Color(0.18, 0.13, 0.07, 0.55)  # neutral dark
	card_panel.add_theme_stylebox_override("panel", card_style)
	_content_vbox.add_child(card_panel)
	var card_vbox := VBoxContainer.new()
	card_panel.add_child(card_vbox)

	card_vbox.add_child(header_btn)

	# Believability gauge — thin bar showing current_believability (0–1).
	var bel_bar := ProgressBar.new()
	bel_bar.min_value                = 0.0
	bel_bar.max_value                = 1.0
	bel_bar.value                    = rumor.current_believability
	bel_bar.show_percentage          = false
	bel_bar.custom_minimum_size      = Vector2(0, 8)
	bel_bar.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	var bel_fill_color: Color
	if rumor.current_believability > 0.6:
		bel_fill_color = Color(0.10, 0.68, 0.22, 1.0)   # green
	elif rumor.current_believability >= 0.3:
		bel_fill_color = Color(0.82, 0.50, 0.10, 1.0)   # amber
	else:
		bel_fill_color = Color(0.80, 0.10, 0.10, 1.0)   # red
	var bel_fill_style := StyleBoxFlat.new()
	bel_fill_style.bg_color = bel_fill_color
	var bel_bg_style := StyleBoxFlat.new()
	bel_bg_style.bg_color = Color(0.20, 0.15, 0.10, 1.0)
	bel_bar.add_theme_stylebox_override("fill", bel_fill_style)
	bel_bar.add_theme_stylebox_override("background", bel_bg_style)
	card_vbox.add_child(bel_bar)

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
	card_vbox.add_child(badge_label)

	# Shelf life decay bar — thin bar showing ticks elapsed vs total shelf life.
	if rumor.shelf_life_ticks > 0:
		var shelf_bar := ProgressBar.new()
		shelf_bar.min_value             = 0.0
		shelf_bar.max_value             = float(rumor.shelf_life_ticks)
		shelf_bar.value                 = float(ticks_elapsed)
		shelf_bar.show_percentage       = false
		shelf_bar.custom_minimum_size   = Vector2(0, 5)
		shelf_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var shelf_fill_style := StyleBoxFlat.new()
		shelf_fill_style.bg_color = Color(0.55, 0.38, 0.18, 1.0)  # amber-brown
		var shelf_bg_style := StyleBoxFlat.new()
		shelf_bg_style.bg_color = Color(0.20, 0.15, 0.10, 1.0)
		shelf_bar.add_theme_stylebox_override("fill", shelf_fill_style)
		shelf_bar.add_theme_stylebox_override("background", shelf_bg_style)
		card_vbox.add_child(shelf_bar)

	if rumor.bolstered_by_evidence:
		var bolster_lbl := Label.new()
		bolster_lbl.text = "  [*] Bolstered by evidence."
		bolster_lbl.add_theme_font_size_override("font_size", 12)
		bolster_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35, 1.0))
		bolster_lbl.tooltip_text = "Bolstered by evidence."
		card_vbox.add_child(bolster_lbl)

	# "Suspect source" label — shown when this rumor was seeded by the rival agent.
	if _world_ref != null and _world_ref.propagation_engine != null:
		var lineage_entry: Dictionary = _world_ref.propagation_engine.lineage.get(rid, {})
		if lineage_entry.get("parent_id", "") == "rival":
			var suspect_lbl := Label.new()
			suspect_lbl.text = "  ⚠ Suspect source — This rumor appears to have an unknown instigator."
			suspect_lbl.add_theme_font_size_override("font_size", 12)
			suspect_lbl.add_theme_color_override("font_color", C_CONTRADICTED)
			card_vbox.add_child(suspect_lbl)

	# Detail container — toggled by header button.
	var detail := VBoxContainer.new()
	detail.visible = expanded
	card_vbox.add_child(detail)

	# Wire header click.
	header_btn.pressed.connect(func() -> void:
		_expanded_rumors[rid] = not _expanded_rumors.get(rid, false)
		detail.visible = _expanded_rumors[rid]
	)

	# Propagation path — active spreaders (● bold) vs past believers (regular).
	if not prop_path.is_empty():
		_add_detail_label(detail, "  Propagation path:", C_SUBKEY)
		var path_lbl := RichTextLabel.new()
		path_lbl.bbcode_enabled      = true
		path_lbl.fit_content         = true
		path_lbl.autowrap_mode       = TextServer.AUTOWRAP_WORD
		path_lbl.add_theme_font_size_override("normal_font_size", 12)
		path_lbl.add_theme_color_override("default_color", C_BODY)
		var parts: Array = []
		for pname in prop_path:
			if spreader_set.has(pname):
				parts.append("[b]● %s[/b]" % pname)
			else:
				parts.append(pname)
		path_lbl.text = "    " + "  →  ".join(parts)
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


## Build a snapshot of every rumor's current journal status.
func _snapshot_rumor_statuses() -> Dictionary:
	var result: Dictionary = {}
	if _world_ref == null:
		return result
	var all_rumors: Dictionary = {}
	for npc in _world_ref.npcs:
		for rid in npc.rumor_slots:
			if not all_rumors.has(rid):
				all_rumors[rid] = npc.rumor_slots[rid].rumor
	for rid in all_rumors:
		var rumor: Rumor = all_rumors[rid]
		var spr: int = 0
		var bel: int = 0
		for npc in _world_ref.npcs:
			if npc.rumor_slots.has(rid):
				var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
				if slot.state == Rumor.RumorState.SPREAD:
					spr += 1; bel += 1
				elif slot.state == Rumor.RumorState.BELIEVE or slot.state == Rumor.RumorState.ACT:
					bel += 1
		var is_cont: bool = _is_contradicted(rumor, spr)
		result[rid] = _rumor_journal_status(rumor, spr, bel, is_cont)
	return result


## Compare current statuses against _rumor_last_status.  Populates
## _changed_rumor_ids and _transition_summary for the current open session.
func _compute_status_diff() -> void:
	_changed_rumor_ids.clear()
	_transition_summary.clear()
	var current: Dictionary = _snapshot_rumor_statuses()
	for rid in current:
		var cur_st: String = current[rid]
		if _rumor_last_status.has(rid):
			var old_st: String = _rumor_last_status[rid]
			if old_st != cur_st:
				_changed_rumor_ids[rid] = true
				_transition_summary[cur_st] = _transition_summary.get(cur_st, 0) + 1
		# New rumors (not seen before) are NOT flagged as transitions — only
		# status *changes* on known rumors count.


## Returns true if a transition to this status is "positive" (desirable).
func _is_positive_transition(status: String) -> bool:
	return status == "SPREADING" or status == "EVALUATING"


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

		# NPC card header — slightly larger with top margin for visual grouping.
		var card_spacer := Control.new()
		card_spacer.custom_minimum_size = Vector2(0, 4)
		_content_vbox.add_child(card_spacer)
		var hdr := Label.new()
		hdr.text = "%s — %s" % [npc_name, npc_faction]
		hdr.add_theme_font_size_override("font_size", 14)
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
		_content_vbox.add_child(hdr)

		var mood_lbl := Label.new()
		mood_lbl.text = "  Faction mood: %s" % mood
		mood_lbl.add_theme_font_size_override("font_size", 13)
		mood_lbl.add_theme_color_override("font_color", mood_color)
		_content_vbox.add_child(mood_lbl)

		# Per-NPC reputation bars (visual).
		if rep_sys != null:
			_add_key_label("  Member Reputation:")
			for npc in faction_npcs:
				var npc_id: String = npc.npc_data.get("id", "")
				var npc_name: String = npc.npc_data.get("name", npc_id)
				var snap = rep_sys.get_snapshot(npc_id) if not npc_id.is_empty() else null
				var score: int = snap.score if snap != null else 50
				var is_dead: bool = snap.is_socially_dead if snap != null else false

				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 6)
				_content_vbox.add_child(row)

				# NPC name
				var nlbl := Label.new()
				nlbl.text = "    " + npc_name
				nlbl.custom_minimum_size = Vector2(130, 0)
				nlbl.add_theme_font_size_override("font_size", 13)
				nlbl.add_theme_color_override("font_color", C_KEY)
				row.add_child(nlbl)

				# Reputation bar background
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

				# Reputation bar fill
				var bar_fill := ColorRect.new()
				bar_fill.anchor_bottom = 1.0
				bar_fill.anchor_right = clampf(float(score) / 100.0, 0.0, 1.0)
				# Colour gradient: green → amber → red based on score.
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

				# Score label
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

	# Sort by tick (direction determined by _timeline_sort_newest).
	if _timeline_sort_newest:
		events.sort_custom(func(a, b) -> bool: return a["tick"] > b["tick"])
	else:
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

	# ── Sort toggle + Today filter ───────────────────────────────────────────
	var tl_controls_row := HBoxContainer.new()
	tl_controls_row.add_theme_constant_override("separation", 6)
	_content_vbox.add_child(tl_controls_row)

	var tl_sort_btn := Button.new()
	tl_sort_btn.text = "↓ Newest" if _timeline_sort_newest else "↑ Oldest"
	tl_sort_btn.add_theme_font_size_override("font_size", 12)
	tl_sort_btn.add_theme_color_override("font_color", C_KEY)
	tl_sort_btn.focus_mode = Control.FOCUS_ALL
	tl_sort_btn.pressed.connect(func() -> void:
		_timeline_sort_newest = not _timeline_sort_newest
		call_deferred("_rebuild_section", Section.TIMELINE)
	)
	tl_controls_row.add_child(tl_sort_btn)

	var tl_today_btn := Button.new()
	tl_today_btn.text = "☀ Today" if not _timeline_today_filter else "☀ Today ✓"
	tl_today_btn.add_theme_font_size_override("font_size", 12)
	tl_today_btn.add_theme_color_override("font_color", Color(0.92, 0.78, 0.12, 1.0) if _timeline_today_filter else C_SUBKEY)
	tl_today_btn.focus_mode = Control.FOCUS_ALL
	tl_today_btn.pressed.connect(func() -> void:
		_timeline_today_filter = not _timeline_today_filter
		call_deferred("_rebuild_section", Section.TIMELINE)
	)
	tl_controls_row.add_child(tl_today_btn)
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

	# Apply "Today" filter — keep only events from the current in-game day.
	if _timeline_today_filter:
		var today_tpd: int = 24
		if _day_night_ref != null and "ticks_per_day" in _day_night_ref:
			today_tpd = _day_night_ref.ticks_per_day
		var today_day: int = 1
		if _day_night_ref != null and "current_day" in _day_night_ref:
			today_day = _day_night_ref.current_day
		filtered_events = filtered_events.filter(func(ev: Dictionary) -> bool:
			return (ev["tick"] / today_tpd + 1) == today_day
		)

	if filtered_events.is_empty():
		if _timeline_today_filter and tl_filter_lower.is_empty():
			_add_body_label("No events today yet.")
		elif not tl_filter_lower.is_empty():
			_add_body_label("No events match \"%s\"." % _timeline_filter_text)
		else:
			_add_body_label("No events recorded yet.")
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

	# Read day limit from ScenarioManager to avoid hardcoded drift.
	var _sm_days: int = sm.get_days_allowed() if sm != null else 30
	var days_remaining: int = max(0, _sm_days - days_elapsed)

	# Fallback day limits for inactive-scenario labels (used when showing all objectives).
	const S1_DAYS := 30
	const S2_DAYS := 20
	const S3_DAYS := 25
	const S4_DAYS := 20
	const S5_DAYS := 25
	const S6_DAYS := 22

	var s1_days_remaining: int = max(0, S1_DAYS - days_elapsed)
	var s2_days_remaining: int = max(0, S2_DAYS - days_elapsed)
	var s3_days_remaining: int = max(0, S3_DAYS - days_elapsed)
	var s4_days_remaining: int = max(0, S4_DAYS - days_elapsed)
	var s5_days_remaining: int = max(0, S5_DAYS - days_elapsed)
	var s6_days_remaining: int = max(0, S6_DAYS - days_elapsed)

	var edric_snap:  ReputationSystem.ReputationSnapshot = rep.get_snapshot("edric_fenn")  if rep != null else null
	var calder_snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot("calder_fenn") if rep != null else null
	var tomas_snap:  ReputationSystem.ReputationSnapshot = rep.get_snapshot("tomas_reeve") if rep != null else null
	var aldous_snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot("aldous_prior") if rep != null else null
	var vera_snap:   ReputationSystem.ReputationSnapshot = rep.get_snapshot("vera_midwife")  if rep != null else null
	var finn_snap:   ReputationSystem.ReputationSnapshot = rep.get_snapshot("finn_monk")     if rep != null else null
	var aldric_snap: ReputationSystem.ReputationSnapshot = rep.get_snapshot("aldric_vane")   if rep != null else null
	var marta_snap:  ReputationSystem.ReputationSnapshot = rep.get_snapshot("marta_coin")    if rep != null else null

	var active_scenario_id: String = ""
	if _world_ref != null and "active_scenario_id" in _world_ref:
		active_scenario_id = _world_ref.active_scenario_id

	var s1_state := ScenarioManager.ScenarioState.ACTIVE
	if sm != null:
		s1_state = sm.scenario_1_state

	var s4_state := ScenarioManager.ScenarioState.ACTIVE
	if sm != null:
		s4_state = sm.scenario_4_state

	var s5_state := ScenarioManager.ScenarioState.ACTIVE
	if sm != null:
		s5_state = sm.scenario_5_state

	var s6_state := ScenarioManager.ScenarioState.ACTIVE
	if sm != null:
		s6_state = sm.scenario_6_state

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
	) % [sm.S1_WIN_EDRIC_BELOW, edric_score_str, edric_band_str, s1_win_status, sm.S1_WIN_EDRIC_BELOW]
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
	) % [illness_count, sm.s2_win_illness_min if sm != null else ScenarioManager.S2_WIN_ILLNESS_MIN_DEFAULT, s2_win_status]
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

	var maren_rejected := rep != null and rep.has_illness_rejecter(sm.ALYS_HERBWIFE_ID, sm.MAREN_NUN_ID)
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
	) % [sm.S3_WIN_CALDER_MIN, sm.S3_WIN_TOMAS_MAX,
		calder_score_str, calder_band_str, sm.S3_WIN_CALDER_MIN,
		tomas_score_str, tomas_band_str, sm.S3_WIN_TOMAS_MAX]
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
	) % [S4_DAYS, sm.S4_WIN_REP_MIN, s4_win_status,
		aldous_score_str, aldous_band_str,
		vera_score_str, vera_band_str,
		finn_score_str, finn_band_str,
		sm.S4_WIN_REP_MIN]
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
	) % [sm.S4_FAIL_REP_BELOW, S4_DAYS, s4_days_remaining]
	s4_fail_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s4_fail_body.add_theme_font_size_override("font_size", 12)
	s4_fail_body.add_theme_color_override("font_color", C_BODY)
	_content_vbox.add_child(s4_fail_body)

	# ── Scenario 5 ────────────────────────────────────────────────────────
	var s5_suffix := "  (upcoming)" if active_scenario_id != "scenario_5" else ""
	var s5_lbl := Label.new()
	s5_lbl.text = "Scenario 5: The Election%s" % s5_suffix
	s5_lbl.add_theme_font_size_override("font_size", 14)
	s5_lbl.add_theme_color_override("font_color", C_HEADING)
	_content_vbox.add_child(s5_lbl)

	if active_scenario_id == "scenario_5":
		var s5_days_lbl := Label.new()
		s5_days_lbl.text = "Days remaining: %d / %d" % [s5_days_remaining, S5_DAYS]
		s5_days_lbl.add_theme_font_size_override("font_size", 12)
		s5_days_lbl.add_theme_color_override("font_color", C_BODY)
		_content_vbox.add_child(s5_days_lbl)

	_content_vbox.add_child(HSeparator.new())

	var s5_win_hdr := Label.new()
	s5_win_hdr.text = "WIN CONDITION"
	s5_win_hdr.add_theme_font_size_override("font_size", 12)
	s5_win_hdr.add_theme_color_override("font_color", C_SPREADING)
	_content_vbox.add_child(s5_win_hdr)

	var s5_win_status := ""
	var s5_win_color  := C_BODY
	match s5_state:
		ScenarioManager.ScenarioState.WON:
			s5_win_status = "[WON]"
			s5_win_color  = C_SPREADING
		ScenarioManager.ScenarioState.FAILED:
			s5_win_status = "[FAILED]"
			s5_win_color  = C_CONTRADICTED

	var aldric_score_str := "48"
	var aldric_band_str  := "Suspect"
	if aldric_snap != null:
		aldric_score_str = str(aldric_snap.score)
		aldric_band_str  = ReputationSystem.score_label(aldric_snap.score)

	var edric_s5_str := "58"
	var edric_s5_band := "Respected"
	if edric_snap != null:
		edric_s5_str = str(edric_snap.score)
		edric_s5_band = ReputationSystem.score_label(edric_snap.score)

	var tomas_s5_str := "45"
	var tomas_s5_band := "Suspect"
	if tomas_snap != null:
		tomas_s5_str = str(tomas_snap.score)
		tomas_s5_band = ReputationSystem.score_label(tomas_snap.score)

	var s5_win_body := Label.new()
	s5_win_body.text = (
		"  Aldric Vane must reach \u2265 %d rep AND be the highest of three candidates.  %s\n"
		+ "  Both rivals must drop below %d.\n\n"
		+ "  Aldric Vane:  %s / 100  \u2014 %s\n"
		+ "  Edric Fenn:   %s / 100  \u2014 %s\n"
		+ "  Tomas Reeve:  %s / 100  \u2014 %s\n"
		+ "  Endorsement: Day %d (Prior Aldous grants +%d to leader)"
	) % [sm.S5_WIN_ALDRIC_MIN if sm != null else 65, s5_win_status,
		sm.S5_WIN_RIVALS_MAX if sm != null else 45,
		aldric_score_str, aldric_band_str,
		edric_s5_str, edric_s5_band,
		tomas_s5_str, tomas_s5_band,
		sm.S5_ENDORSEMENT_DAY if sm != null else 13, sm.S5_ENDORSEMENT_BONUS if sm != null else 8]
	s5_win_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s5_win_body.add_theme_font_size_override("font_size", 12)
	s5_win_body.add_theme_color_override("font_color", s5_win_color)
	_content_vbox.add_child(s5_win_body)

	_content_vbox.add_child(HSeparator.new())

	var s5_fail_hdr := Label.new()
	s5_fail_hdr.text = "FAIL CONDITIONS"
	s5_fail_hdr.add_theme_font_size_override("font_size", 12)
	s5_fail_hdr.add_theme_color_override("font_color", C_CONTRADICTED)
	_content_vbox.add_child(s5_fail_hdr)

	var s5_fail_body := Label.new()
	s5_fail_body.text = (
		"  [ ] Aldric Vane drops below %d reputation\n"
		+ "  [ ] %d days elapsed without Aldric winning the election  (days remaining: %d)"
	) % [sm.S5_FAIL_ALDRIC_BELOW if sm != null else 30, S5_DAYS, s5_days_remaining]
	s5_fail_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s5_fail_body.add_theme_font_size_override("font_size", 12)
	s5_fail_body.add_theme_color_override("font_color", C_BODY)
	_content_vbox.add_child(s5_fail_body)

	# ── Scenario 6 ────────────────────────────────────────────────────────
	var s6_suffix := "  (upcoming)" if active_scenario_id != "scenario_6" else ""
	var s6_lbl := Label.new()
	s6_lbl.text = "Scenario 6: The Merchant's Debt%s" % s6_suffix
	s6_lbl.add_theme_font_size_override("font_size", 14)
	s6_lbl.add_theme_color_override("font_color", C_HEADING)
	_content_vbox.add_child(s6_lbl)

	if active_scenario_id == "scenario_6":
		var s6_days_lbl := Label.new()
		s6_days_lbl.text = "Days remaining: %d / %d" % [s6_days_remaining, S6_DAYS]
		s6_days_lbl.add_theme_font_size_override("font_size", 12)
		s6_days_lbl.add_theme_color_override("font_color", C_BODY)
		_content_vbox.add_child(s6_days_lbl)

	_content_vbox.add_child(HSeparator.new())

	var s6_win_hdr := Label.new()
	s6_win_hdr.text = "WIN CONDITION"
	s6_win_hdr.add_theme_font_size_override("font_size", 12)
	s6_win_hdr.add_theme_color_override("font_color", C_SPREADING)
	_content_vbox.add_child(s6_win_hdr)

	var s6_win_status := ""
	var s6_win_color  := C_BODY
	match s6_state:
		ScenarioManager.ScenarioState.WON:
			s6_win_status = "[WON]"
			s6_win_color  = C_SPREADING
		ScenarioManager.ScenarioState.FAILED:
			s6_win_status = "[FAILED]"
			s6_win_color  = C_CONTRADICTED

	var aldric_s6_str := "55"
	var aldric_s6_band := "Respected"
	if aldric_snap != null:
		aldric_s6_str = str(aldric_snap.score)
		aldric_s6_band = ReputationSystem.score_label(aldric_snap.score)

	var marta_score_str := "52"
	var marta_band_str  := "Respected"
	if marta_snap != null:
		marta_score_str = str(marta_snap.score)
		marta_band_str  = ReputationSystem.score_label(marta_snap.score)

	var s6_win_body := Label.new()
	s6_win_body.text = (
		"  Expose Aldric Vane (rep \u2264 %d) and protect Marta Coin (rep \u2265 %d).  %s\n\n"
		+ "  Aldric Vane:  %s / 100  \u2014 %s\n"
		+ "  Marta Coin:   %s / 100  \u2014 %s\n"
		+ "  Heat ceiling: %d  (guards on Aldric's payroll)"
	) % [sm.S6_WIN_ALDRIC_MAX if sm != null else 30,
		sm.S6_WIN_MARTA_MIN if sm != null else 60, s6_win_status,
		aldric_s6_str, aldric_s6_band,
		marta_score_str, marta_band_str,
		int(sm.S6_EXPOSED_HEAT) if sm != null else 60]
	s6_win_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s6_win_body.add_theme_font_size_override("font_size", 12)
	s6_win_body.add_theme_color_override("font_color", s6_win_color)
	_content_vbox.add_child(s6_win_body)

	_content_vbox.add_child(HSeparator.new())

	var s6_fail_hdr := Label.new()
	s6_fail_hdr.text = "FAIL CONDITIONS"
	s6_fail_hdr.add_theme_font_size_override("font_size", 12)
	s6_fail_hdr.add_theme_color_override("font_color", C_CONTRADICTED)
	_content_vbox.add_child(s6_fail_hdr)

	var s6_fail_body := Label.new()
	s6_fail_body.text = (
		"  [ ] Marta Coin drops below %d reputation  (silenced)\n"
		+ "  [ ] Heat reaches %d  (exposed by guards)\n"
		+ "  [ ] %d days elapsed without meeting both targets  (days remaining: %d)"
	) % [sm.S6_FAIL_MARTA_BELOW if sm != null else 30,
		int(sm.S6_EXPOSED_HEAT) if sm != null else 60,
		S6_DAYS, s6_days_remaining]
	s6_fail_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	s6_fail_body.add_theme_font_size_override("font_size", 12)
	s6_fail_body.add_theme_color_override("font_color", C_BODY)
	_content_vbox.add_child(s6_fail_body)


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
	if _has_new_entries_since(_last_opened_tick) or _has_status_transitions():
		_notification_pending = true
		_show_notification_dot()


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


## Returns true if any rumor's status differs from the last-seen snapshot.
func _has_status_transitions() -> bool:
	if _rumor_last_status.is_empty() or _world_ref == null:
		return false
	var current: Dictionary = _snapshot_rumor_statuses()
	for rid in current:
		if _rumor_last_status.has(rid) and _rumor_last_status[rid] != current[rid]:
			return true
	return false


func _show_notification_dot() -> void:
	if _notif_dot == null:
		return
	_notif_dot.visible = true
	_start_dot_pulse()


func _start_dot_pulse() -> void:
	_stop_dot_pulse()
	_dot_pulse_tween = create_tween().set_loops()
	_dot_pulse_tween.tween_property(_notif_dot, "modulate:a", 0.4, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_dot_pulse_tween.tween_property(_notif_dot, "modulate:a", 1.0, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_dot_pulse() -> void:
	if _dot_pulse_tween != null and _dot_pulse_tween.is_valid():
		_dot_pulse_tween.kill()
		_dot_pulse_tween = null
	if _notif_dot != null:
		_notif_dot.modulate.a = 1.0


# ── Public API ────────────────────────────────────────────────────────────────

## Called by scenario or world systems to record a named timeline event.
## Events are buffered in _pending_events and flushed to _timeline_log at tick-end.
func push_timeline_event(tick: int, message: String) -> void:
	_pending_events.append({"tick": tick, "message": message})
	if not _is_open and tick > _last_opened_tick:
		_notification_pending = true
		_show_notification_dot()


## Open the journal directly to the Timeline tab with optional pre-set filters.
## If filter_text is non-empty, the keyword filter is pre-filled.
## If today is true, the Today quick-filter is auto-activated and sort set to newest-first.
func open_to_timeline(filter_text: String = "", today: bool = false) -> void:
	_timeline_filter_text  = filter_text
	_timeline_today_filter = today
	if today:
		_timeline_sort_newest = true
	_current_section = Section.TIMELINE
	if not _is_open:
		_open()
	else:
		_refresh_sidebar_highlights()
		_rebuild_section(Section.TIMELINE)


## Called by SaveManager after a load to restore the persisted timeline log.
## Replaces _timeline_log in-place; clears any buffered pending events.
func restore_timeline(entries: Array) -> void:
	_timeline_log   = entries.duplicate(true)
	_pending_events.clear()


## Record a narrative milestone in the Milestones journal tab.
## Called by MilestoneNotifier when a milestone popup is shown.
## reward_text is the human-readable reward string (e.g. "+1 bribe charge"), or "".
func push_milestone_event(text: String, color: Color, reward_text: String = "") -> void:
	_milestone_log.append({
		"text":        text,
		"color_packed": color.to_html(false),
		"reward_text": reward_text,
	})
	if _milestone_log.size() > MAX_MILESTONE_ENTRIES:
		_milestone_log = _milestone_log.slice(_milestone_log.size() - MAX_MILESTONE_ENTRIES)
	if not _is_open:
		_notification_pending = true
		_show_notification_dot()


## Returns the milestone log for serialisation by SaveManager.
func get_milestone_log() -> Array:
	return _milestone_log.duplicate(true)


## Called by SaveManager after a load to restore the persisted milestone log.
func restore_milestones(entries: Array) -> void:
	_milestone_log = entries.duplicate(true)


# ── Section 6: Milestones ─────────────────────────────────────────────────────

func _build_milestones_section() -> void:
	_add_section_header("Milestones")

	if _milestone_log.is_empty():
		_add_body_label("No milestones reached yet — keep spreading those rumors.")
		return

	# Show newest first.
	var entries: Array = _milestone_log.duplicate()
	entries.reverse()

	for entry: Dictionary in entries:
		var text:        String = str(entry.get("text",        ""))
		var color_html:  String = str(entry.get("color_packed", ""))
		var reward_text: String = str(entry.get("reward_text", ""))

		var text_color := Color(0.85, 0.78, 0.55, 1.0)   # parchment fallback
		if not color_html.is_empty():
			text_color = Color.html(color_html)

		var row_panel := PanelContainer.new()
		var row_style := StyleBoxFlat.new()
		row_style.bg_color = Color(0.10, 0.07, 0.04, 0.92)
		row_style.border_color = Color(text_color.r, text_color.g, text_color.b, 0.30)
		row_style.set_border_width_all(1)
		row_style.set_corner_radius_all(2)
		row_style.set_content_margin_all(7)
		row_panel.add_theme_stylebox_override("panel", row_style)
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content_vbox.add_child(row_panel)

		var row_vbox := VBoxContainer.new()
		row_vbox.add_theme_constant_override("separation", 3)
		row_panel.add_child(row_vbox)

		var text_lbl := Label.new()
		text_lbl.text          = text
		text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_lbl.add_theme_font_size_override("font_size", 14)
		text_lbl.add_theme_color_override("font_color", text_color)
		row_vbox.add_child(text_lbl)

		if not reward_text.is_empty():
			var reward_lbl := Label.new()
			reward_lbl.text = reward_text
			reward_lbl.add_theme_font_size_override("font_size", 12)
			reward_lbl.add_theme_color_override("font_color", Color(0.68, 0.92, 0.40, 1.0))
			row_vbox.add_child(reward_lbl)

		var sep := Control.new()
		sep.custom_minimum_size = Vector2(0, 3)
		_content_vbox.add_child(sep)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _add_section_header(title: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	_content_vbox.add_child(spacer)
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", C_HEADING)
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.3))
	_content_vbox.add_child(lbl)
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	_content_vbox.add_child(sep)


func _add_body_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text          = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C_BODY)
	lbl.add_theme_constant_override("line_spacing", 3)
	_content_vbox.add_child(lbl)


func _add_key_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C_KEY)
	_content_vbox.add_child(lbl)


func _add_detail_label(parent: Control, text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text          = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_constant_override("line_spacing", 2)
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
