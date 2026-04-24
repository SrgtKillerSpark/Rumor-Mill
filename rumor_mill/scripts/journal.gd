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
##
## Section content is delegated to five dedicated modules (SPA-1003):
##   JournalRumorsSection, JournalIntelSection, JournalFactionsSection,
##   JournalTimelineSection, JournalObjectivesSection.

# ── Palette ───────────────────────────────────────────────────────────────────

const C_PARCHMENT     := Color(0.82, 0.74, 0.58, 1.0)
const C_PANEL_BG      := Color(0.12, 0.08, 0.05, 1.0)
const C_HEADING       := Color(0.92, 0.78, 0.12, 1.0)
const C_BODY          := Color(0.80, 0.72, 0.56, 1.0)
const C_KEY           := Color(0.90, 0.84, 0.68, 1.0)
const C_SUBKEY        := Color(0.65, 0.58, 0.45, 1.0)
const C_LOCKED        := Color(0.40, 0.35, 0.28, 1.0)
const C_TAB_ACTIVE    := Color(0.55, 0.38, 0.18, 1.0)
const C_TAB_INACTIVE  := Color(0.20, 0.14, 0.09, 1.0)

# Badge colours
const C_SPREADING    := Color(0.10, 0.68, 0.22, 1.0)
const C_CONTRADICTED := Color(0.80, 0.10, 0.10, 1.0)

# ── Section enum ──────────────────────────────────────────────────────────────

enum Section { RUMORS, INTELLIGENCE, FACTIONS, TIMELINE, OBJECTIVES, MILESTONES }
const SECTION_LABELS: Array = ["Rumors", "Intelligence", "Factions", "Timeline", "Objectives", "Milestones"]

# ── References ────────────────────────────────────────────────────────────────

var _world_ref:        Node2D           = null
var _intel_store_ref:  PlayerIntelStore = null
var _day_night_ref:    Node             = null

# ── Section modules ───────────────────────────────────────────────────────────

var _rumors_section:     JournalRumorsSection     = null
var _intel_section:      JournalIntelSection      = null
var _factions_section:   JournalFactionsSection   = null
var _timeline_section:   JournalTimelineSection   = null
var _objectives_section: JournalObjectivesSection = null

# ── UI state ──────────────────────────────────────────────────────────────────

var _is_open:           bool      = false
var _current_section:   Section   = Section.RUMORS
var _scroll_positions:  Dictionary = {}
var _last_opened_tick:  int       = -1
var _notification_pending: bool   = false
var _panel_tween:          Tween  = null
var _dot_pulse_tween:      Tween  = null

## Hard cap on milestone log entries.
const MAX_MILESTONE_ENTRIES := 100

## Milestone log: Array of {text: String, color_packed: int, reward_text: String}.
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

	_rumors_section     = JournalRumorsSection.new()
	_intel_section      = JournalIntelSection.new()
	_factions_section   = JournalFactionsSection.new()
	_timeline_section   = JournalTimelineSection.new()
	_objectives_section = JournalObjectivesSection.new()

	_build_sidebar()
	_close_btn.pressed.connect(toggle)


func setup(world: Node2D, intel_store: PlayerIntelStore, day_night: Node) -> void:
	_world_ref       = world
	_intel_store_ref = intel_store
	_day_night_ref   = day_night

	_rumors_section.setup(world, day_night)
	_intel_section.setup(world, intel_store, day_night)
	_factions_section.setup(world)
	_timeline_section.setup(world, intel_store, day_night)
	_objectives_section.setup(world, day_night)

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
	_rumors_section.on_journal_open()
	_pause_game(true)
	_rebuild_section(_current_section)
	call_deferred("_restore_scroll")
	# Animate open: fade bg + slide parchment from right.
	_overlay_bg.modulate.a = 0.0
	_parchment.modulate.a = 0.0
	_parchment.position.x += 40.0
	var open_pos_x: float = _parchment.position.x - 40.0
	if _panel_tween != null and _panel_tween.is_valid():
		_panel_tween.kill()
	_panel_tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_panel_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_panel_tween.tween_property(_overlay_bg, "modulate:a", 1.0, 0.18)
	_panel_tween.tween_property(_parchment, "modulate:a", 1.0, 0.20)
	_panel_tween.tween_property(_parchment, "position:x", open_pos_x, 0.25)
	if _sidebar.get_child_count() > 0:
		_sidebar.get_child(0).call_deferred("grab_focus")


func _close() -> void:
	AudioManager.play_sfx("journal_close")
	_save_scroll()
	_is_open = false
	_rumors_section.on_journal_close()
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
	var tab_tooltips: Array = [
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
		if i < tab_tooltips.size():
			btn.tooltip_text = tab_tooltips[i]
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
	focus_ring.border_color = Color(1.00, 0.90, 0.40, 1.0)
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
		Section.RUMORS:
			_rumors_section.build(_content_vbox, func(): _rebuild_section(Section.RUMORS))
		Section.INTELLIGENCE:
			_intel_section.build(_content_vbox, func(): _rebuild_section(Section.INTELLIGENCE))
		Section.FACTIONS:
			_factions_section.build(_content_vbox)
		Section.TIMELINE:
			_timeline_section.build(_content_vbox, func(): _rebuild_section(Section.TIMELINE))
		Section.OBJECTIVES:
			_objectives_section.build(_content_vbox)
		Section.MILESTONES:
			_build_milestones_section()


# ── Section 6: Milestones ─────────────────────────────────────────────────────

func _build_milestones_section() -> void:
	_add_section_header("Milestones")

	if _milestone_log.is_empty():
		_add_body_label("No milestones reached yet — keep spreading those rumors.")
		return

	var entries: Array = _milestone_log.duplicate()
	entries.reverse()

	for entry: Dictionary in entries:
		var text:        String = str(entry.get("text",        ""))
		var color_html:  String = str(entry.get("color_packed", ""))
		var reward_text: String = str(entry.get("reward_text", ""))

		var text_color := Color(0.85, 0.78, 0.55, 1.0)
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


# ── Notification dot ──────────────────────────────────────────────────────────

func _on_game_tick(_tick: int) -> void:
	_timeline_section.flush_pending_events()

	if _is_open or _notification_pending:
		return
	if _timeline_section.has_new_entries_since(_last_opened_tick) or _rumors_section.has_status_transitions():
		_notification_pending = true
		_show_notification_dot()


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
## Optional diagnostic is rendered as italic subtext below the main event line (SPA-848).
func push_timeline_event(tick: int, message: String, diagnostic: String = "") -> void:
	_timeline_section.push_event(tick, message, diagnostic)
	if not _is_open and tick > _last_opened_tick:
		_notification_pending = true
		_show_notification_dot()


## Open the journal directly to the Timeline tab with optional pre-set filters.
## If filter_text is non-empty, the keyword filter is pre-filled.
## If today is true, the Today quick-filter is auto-activated and sort set to newest-first.
func open_to_timeline(filter_text: String = "", today: bool = false) -> void:
	_timeline_section.set_open_filters(filter_text, today)
	_current_section = Section.TIMELINE
	if not _is_open:
		_open()
	else:
		_refresh_sidebar_highlights()
		_rebuild_section(Section.TIMELINE)


## Called by SaveManager after a load to restore the persisted timeline log.
func restore_timeline(entries: Array) -> void:
	_timeline_section.restore(entries)


## Record a narrative milestone in the Milestones journal tab.
## Called by MilestoneNotifier when a milestone popup is shown.
## reward_text is the human-readable reward string (e.g. "+1 bribe charge"), or "".
func push_milestone_event(text: String, color: Color, reward_text: String = "") -> void:
	_milestone_log.append({
		"text":         text,
		"color_packed": color.to_html(false),
		"reward_text":  reward_text,
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


func _get_current_tick() -> int:
	if _day_night_ref != null and "current_tick" in _day_night_ref:
		return _day_night_ref.current_tick
	return 0


func _pause_game(paused: bool) -> void:
	if _day_night_ref != null and _day_night_ref.has_method("set_paused"):
		_day_night_ref.set_paused(paused)
