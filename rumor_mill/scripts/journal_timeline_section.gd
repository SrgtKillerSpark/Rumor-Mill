class_name JournalTimelineSection
extends RefCounted

## journal_timeline_section.gd — Timeline tab content builder for Journal.
##
## Extracted from journal.gd (SPA-1003). Owns the timeline log, pending event
## buffer, and all filter/sort state for the Timeline tab.
##
## Call setup() once refs are known. Call flush_pending_events() each game tick
## (from journal's _on_game_tick). Call build(content_vbox, rebuild_cb) to
## populate the content area for the current tab.
##
## Public API mirroring journal.gd's original surface:
##   push_event(tick, message, diagnostic)  — buffer a new timeline event
##   set_open_filters(filter_text, today)   — pre-set filters (for open_to_timeline)
##   restore(entries)                        — re-hydrate after a save-load
##   has_new_entries_since(since_tick)       — used by notification dot logic

# ── Palette ───────────────────────────────────────────────────────────────────

const C_HEADING := Color(0.92, 0.78, 0.12, 1.0)
const C_BODY    := Color(0.80, 0.72, 0.56, 1.0)
const C_KEY     := Color(0.90, 0.84, 0.68, 1.0)
const C_SUBKEY  := Color(0.65, 0.58, 0.45, 1.0)

# ── Limits ────────────────────────────────────────────────────────────────────

const MAX_TIMELINE_ENTRIES := 200

# ── State ─────────────────────────────────────────────────────────────────────

## Timeline event log: Array of {tick: int, message: String, diagnostic: String}.
var _timeline_log: Array = []

## Events buffered during the current tick; flushed into _timeline_log at tick-end.
var _pending_events: Array = []

## Filter text (persists across tab switches).
var _filter_text: String = ""

## Sort order: true = newest first, false = oldest first (default).
var _sort_newest: bool = false

## "Today only" filter: when true, only show events from the current in-game day.
var _today_filter: bool = false

# ── Refs ──────────────────────────────────────────────────────────────────────

var _world_ref:       Node2D           = null
var _intel_store_ref: PlayerIntelStore = null
var _day_night_ref:   Node             = null


func setup(world: Node2D, intel_store: PlayerIntelStore, day_night: Node) -> void:
	_world_ref       = world
	_intel_store_ref = intel_store
	_day_night_ref   = day_night


# ── Public API ────────────────────────────────────────────────────────────────

## Buffer a new timeline event. Flushed to _timeline_log at the next tick-end.
func push_event(tick: int, message: String, diagnostic: String = "") -> void:
	_pending_events.append({"tick": tick, "message": message, "diagnostic": diagnostic})


## Move buffered events into the log and trim to cap. Call once per game tick.
func flush_pending_events() -> void:
	if not _pending_events.is_empty():
		_timeline_log.append_array(_pending_events)
		_pending_events.clear()
		if _timeline_log.size() > MAX_TIMELINE_ENTRIES:
			_timeline_log = _timeline_log.slice(_timeline_log.size() - MAX_TIMELINE_ENTRIES)


## Pre-set filters before opening the journal directly to the Timeline tab.
func set_open_filters(filter_text: String, today: bool) -> void:
	_filter_text  = filter_text
	_today_filter = today
	if today:
		_sort_newest = true


## Replace _timeline_log in-place after a save-load. Clears pending buffer.
func restore(entries: Array) -> void:
	_timeline_log   = entries.duplicate(true)
	_pending_events.clear()


## Returns true if any new entry or rumor/intel appeared after since_tick.
## Used by the notification dot logic in journal.gd.
func has_new_entries_since(since_tick: int) -> bool:
	if since_tick < 0:
		return false
	for ev in _timeline_log:
		if ev["tick"] > since_tick:
			return true
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


# ── Tab builder ───────────────────────────────────────────────────────────────

## Build the Timeline tab content into content_vbox.
## rebuild_cb is called (deferred) whenever the user changes a filter or sort.
func build(content_vbox: VBoxContainer, rebuild_cb: Callable) -> void:
	_add_section_header(content_vbox, "Timeline")

	var events: Array = []

	# Always include game start.
	events.append({"tick": 0, "message": "Game started."})

	# External push-log events.
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

	# Sort by tick.
	if _sort_newest:
		events.sort_custom(func(a, b) -> bool: return a["tick"] > b["tick"])
	else:
		events.sort_custom(func(a, b) -> bool: return a["tick"] < b["tick"])

	# ── Timeline filter bar ───────────────────────────────────────────────────
	var tl_filter_row := HBoxContainer.new()
	tl_filter_row.add_theme_constant_override("separation", 4)
	content_vbox.add_child(tl_filter_row)

	var tl_filter_lbl := Label.new()
	tl_filter_lbl.text = "Filter:"
	tl_filter_lbl.add_theme_font_size_override("font_size", 12)
	tl_filter_lbl.add_theme_color_override("font_color", C_SUBKEY)
	tl_filter_row.add_child(tl_filter_lbl)

	var tl_filter_edit := LineEdit.new()
	tl_filter_edit.placeholder_text      = "keyword…"
	tl_filter_edit.text                  = _filter_text
	tl_filter_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl_filter_edit.add_theme_font_size_override("font_size", 12)
	tl_filter_row.add_child(tl_filter_edit)

	var tl_clear_btn := Button.new()
	tl_clear_btn.text    = "×"
	tl_clear_btn.visible = not _filter_text.is_empty()
	tl_clear_btn.add_theme_font_size_override("font_size", 12)
	tl_filter_row.add_child(tl_clear_btn)

	tl_filter_edit.text_changed.connect(func(txt: String) -> void:
		_filter_text = txt
		tl_clear_btn.visible = not txt.is_empty()
		rebuild_cb.call_deferred()
	)
	tl_clear_btn.pressed.connect(func() -> void:
		_filter_text = ""
		rebuild_cb.call_deferred()
	)

	# ── Sort toggle + Today filter ───────────────────────────────────────────
	var tl_controls_row := HBoxContainer.new()
	tl_controls_row.add_theme_constant_override("separation", 6)
	content_vbox.add_child(tl_controls_row)

	var tl_sort_btn := Button.new()
	tl_sort_btn.text = "↓ Newest" if _sort_newest else "↑ Oldest"
	tl_sort_btn.add_theme_font_size_override("font_size", 12)
	tl_sort_btn.add_theme_color_override("font_color", C_KEY)
	tl_sort_btn.focus_mode = Control.FOCUS_ALL
	tl_sort_btn.pressed.connect(func() -> void:
		_sort_newest = not _sort_newest
		rebuild_cb.call_deferred()
	)
	tl_controls_row.add_child(tl_sort_btn)

	var tl_today_btn := Button.new()
	tl_today_btn.text = "☀ Today" if not _today_filter else "☀ Today ✓"
	tl_today_btn.add_theme_font_size_override("font_size", 12)
	tl_today_btn.add_theme_color_override("font_color", Color(0.92, 0.78, 0.12, 1.0) if _today_filter else C_SUBKEY)
	tl_today_btn.focus_mode = Control.FOCUS_ALL
	tl_today_btn.pressed.connect(func() -> void:
		_today_filter = not _today_filter
		rebuild_cb.call_deferred()
	)
	tl_controls_row.add_child(tl_today_btn)
	# ─────────────────────────────────────────────────────────────────────────

	if events.size() <= 1:
		_add_body_label(content_vbox, "No events recorded yet.")
		return

	# Apply keyword filter.
	var tl_filter_lower := _filter_text.to_lower().strip_edges()
	var filtered_events: Array = events
	if not tl_filter_lower.is_empty():
		filtered_events = events.filter(func(ev: Dictionary) -> bool:
			return ev["message"].to_lower().contains(tl_filter_lower)
		)

	# Apply "Today" filter — keep only events from the current in-game day.
	if _today_filter:
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
		if _today_filter and tl_filter_lower.is_empty():
			_add_body_label(content_vbox, "No events today yet.")
		elif not tl_filter_lower.is_empty():
			_add_body_label(content_vbox, "No events match \"%s\"." % _filter_text)
		else:
			_add_body_label(content_vbox, "No events recorded yet.")
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
			content_vbox.add_child(day_hdr)
		var lbl := Label.new()
		lbl.text          = "  %s  %s" % [_tick_to_day_str(ev["tick"]), ev["message"]]
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", C_BODY)
		content_vbox.add_child(lbl)
		var diag: String = ev.get("diagnostic", "")
		if not diag.is_empty():
			var diag_lbl := RichTextLabel.new()
			diag_lbl.bbcode_enabled = true
			diag_lbl.fit_content    = true
			diag_lbl.scroll_active  = false
			diag_lbl.text = "    [i]%s[/i]" % diag
			diag_lbl.add_theme_font_size_override("normal_font_size", 11)
			diag_lbl.add_theme_color_override("default_color", C_SUBKEY)
			content_vbox.add_child(diag_lbl)


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
