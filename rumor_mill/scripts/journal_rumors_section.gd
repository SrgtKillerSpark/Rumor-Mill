class_name JournalRumorsSection
extends RefCounted

## journal_rumors_section.gd — Rumors tab content builder for Journal.
##
## Extracted from journal.gd (SPA-1003). Owns all rumor filter/sort/expand
## state and change-tracking for the Rumors tab.
##
## Call setup() once refs are known. Call on_journal_open() / on_journal_close()
## at the matching journal lifecycle events. Call build(content_vbox, rebuild_cb)
## to populate the content area for the current tab.

# ── Palette ───────────────────────────────────────────────────────────────────

const C_HEADING      := Color(0.92, 0.78, 0.12, 1.0)
const C_BODY         := Color(0.80, 0.72, 0.56, 1.0)
const C_KEY          := Color(0.90, 0.84, 0.68, 1.0)
const C_SUBKEY       := Color(0.65, 0.58, 0.45, 1.0)
const C_TAB_ACTIVE   := Color(0.55, 0.38, 0.18, 1.0)
const C_TAB_INACTIVE := Color(0.20, 0.14, 0.09, 1.0)
const C_EVALUATING   := Color(0.25, 0.45, 0.90, 1.0)
const C_SPREADING    := Color(0.10, 0.68, 0.22, 1.0)
const C_STALLING     := Color(0.82, 0.50, 0.10, 1.0)
const C_CONTRADICTED := Color(0.80, 0.10, 0.10, 1.0)
const C_EXPIRED      := Color(0.455, 0.431, 0.376, 1.0)

# ── State ─────────────────────────────────────────────────────────────────────

## Per-rumor expand state: rumor_id → bool.
var _expanded_rumors: Dictionary = {}

## State-change tracking: rumor_id → last-seen journal status string.
## Snapshotted on journal close so we can diff on next open.
var _rumor_last_status: Dictionary = {}

## Rumor IDs whose status changed since last journal visit.
var _changed_rumor_ids: Dictionary = {}

## Summary of transitions since last visit: {status_string → count}.
var _transition_summary: Dictionary = {}

## Filter text (persists across tab switches).
var _filter_text: String = ""

## Status filter: "" = all, or one of the status strings.
var _status_filter: String = ""

## Sort order: true = newest first (default), false = oldest first.
var _sort_newest: bool = true

# ── Refs ──────────────────────────────────────────────────────────────────────

var _world_ref:     Node2D = null
var _day_night_ref: Node   = null


func setup(world: Node2D, day_night: Node) -> void:
	_world_ref     = world
	_day_night_ref = day_night


## Called when the journal opens; computes status diff for change highlighting.
func on_journal_open() -> void:
	_compute_status_diff()


## Called when the journal closes; snapshots current statuses for next open.
func on_journal_close() -> void:
	_rumor_last_status = _snapshot_rumor_statuses()
	_changed_rumor_ids.clear()
	_transition_summary.clear()


## Returns true if any rumor's status differs from the last-seen snapshot.
## Used by the notification dot logic in journal.gd.
func has_status_transitions() -> bool:
	if _rumor_last_status.is_empty() or _world_ref == null:
		return false
	var current: Dictionary = _snapshot_rumor_statuses()
	for rid in current:
		if _rumor_last_status.has(rid) and _rumor_last_status[rid] != current[rid]:
			return true
	return false


## Build the Rumors tab content into content_vbox.
## rebuild_cb is called (deferred) whenever the user changes a filter or sort.
func build(content_vbox: VBoxContainer, rebuild_cb: Callable) -> void:
	_add_section_header(content_vbox, "Rumors")

	if _world_ref == null:
		_add_body_label(content_vbox, "(World not connected)")
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
		content_vbox.add_child(banner_panel)

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

		# Auto-dismiss after 5 seconds. banner_panel is in the scene tree so
		# get_tree() and create_tween() work on it directly.
		var banner_timer := banner_panel.get_tree().create_timer(5.0, true)
		banner_timer.timeout.connect(func() -> void:
			if is_instance_valid(banner_panel):
				var tw := banner_panel.create_tween()
				tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
				tw.tween_property(banner_panel, "modulate:a", 0.0, 0.3)
				tw.tween_callback(banner_panel.queue_free)
		)

	# Collect unique rumors from all NPC slots.
	var all_rumors: Dictionary = {}
	for npc in _world_ref.npcs:
		for rid in npc.rumor_slots:
			if not all_rumors.has(rid):
				all_rumors[rid] = (npc.rumor_slots[rid] as Rumor.NpcRumorSlot).rumor

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
	filter_edit.placeholder_text      = "subject or claim type…"
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

	# ── Status filter buttons ────────────────────────────────────────────────
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 3)
	content_vbox.add_child(status_row)

	var status_lbl := Label.new()
	status_lbl.text = "Status:"
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", C_SUBKEY)
	status_row.add_child(status_lbl)

	# Pre-compute per-status counts for badge display.
	var status_counts: Dictionary = {}
	var total_rumor_count: int = all_rumors.size()
	for cnt_rid in all_rumors:
		var cr: Rumor = all_rumors[cnt_rid]
		var cspr: int = 0
		var cbel: int = 0
		for npc in _world_ref.npcs:
			if npc.rumor_slots.has(cnt_rid):
				var cslot: Rumor.NpcRumorSlot = npc.rumor_slots[cnt_rid]
				if cslot.state == Rumor.RumorState.SPREAD:
					cspr += 1; cbel += 1
				elif cslot.state == Rumor.RumorState.BELIEVE or cslot.state == Rumor.RumorState.ACT:
					cbel += 1
		var cis_cont: bool = _is_contradicted(cr, cspr)
		var cst: String = _rumor_journal_status(cr, cspr, cbel, cis_cont)
		status_counts[cst] = status_counts.get(cst, 0) + 1

	var status_options: Array = ["", "EVALUATING", "SPREADING", "STALLING", "CONTRADICTED", "EXPIRED"]
	var status_labels: Array  = ["All", "Evaluating", "Spreading", "Stalling", "Contradicted", "Expired"]
	for si in range(status_options.size()):
		var sbtn := Button.new()
		var btn_count: int = total_rumor_count if status_options[si] == "" else status_counts.get(status_options[si], 0)
		sbtn.text = "%s (%d)" % [status_labels[si], btn_count]
		sbtn.add_theme_font_size_override("font_size", 12)
		var is_active: bool = _status_filter == status_options[si]
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
			_status_filter = captured_status
			rebuild_cb.call_deferred()
		)
		sbtn.focus_mode = Control.FOCUS_ALL
		status_row.add_child(sbtn)

	# ── Sort toggle ──────────────────────────────────────────────────────────
	var sort_btn := Button.new()
	sort_btn.text = "↓ Newest" if _sort_newest else "↑ Oldest"
	sort_btn.add_theme_font_size_override("font_size", 12)
	sort_btn.add_theme_color_override("font_color", C_KEY)
	sort_btn.focus_mode = Control.FOCUS_ALL
	sort_btn.pressed.connect(func() -> void:
		_sort_newest = not _sort_newest
		rebuild_cb.call_deferred()
	)
	status_row.add_child(sort_btn)

	# ─────────────────────────────────────────────────────────────────────────

	if all_rumors.is_empty():
		_add_body_label(content_vbox, "No rumors recorded yet.\nUse the debug console to inject a rumor, or seed one via the Rumor Crafting panel.")
		return

	var npc_names: Dictionary = _build_npc_name_lookup()

	# Sort by creation tick (newest or oldest first).
	var sorted_rumors: Array = all_rumors.values()
	if _sort_newest:
		sorted_rumors.sort_custom(func(a, b): return a.created_tick > b.created_tick)
	else:
		sorted_rumors.sort_custom(func(a, b): return a.created_tick < b.created_tick)

	# Apply text filter (subject name or claim type).
	var filter_lower := _filter_text.to_lower().strip_edges()
	if not filter_lower.is_empty():
		sorted_rumors = sorted_rumors.filter(func(r: Rumor) -> bool:
			var subj_name: String = npc_names.get(r.subject_npc_id, r.subject_npc_id).to_lower()
			var claim_str: String = Rumor.ClaimType.keys()[r.claim_type].to_lower()
			return subj_name.contains(filter_lower) or claim_str.contains(filter_lower)
		)

	# Apply status filter — compute status for each rumor to match.
	if not _status_filter.is_empty():
		sorted_rumors = sorted_rumors.filter(func(r: Rumor) -> bool:
			var spr: int = 0
			var bel: int = 0
			for npc in _world_ref.npcs:
				if npc.rumor_slots.has(r.id):
					var slot: Rumor.NpcRumorSlot = npc.rumor_slots[r.id]
					if slot.state == Rumor.RumorState.SPREAD:
						spr += 1; bel += 1
					elif slot.state == Rumor.RumorState.BELIEVE or slot.state == Rumor.RumorState.ACT:
						bel += 1
			var is_cont: bool = _is_contradicted(r, spr)
			var st: String = _rumor_journal_status(r, spr, bel, is_cont)
			return st == _status_filter
		)

	if sorted_rumors.is_empty():
		var hint := _filter_text if not _filter_text.is_empty() else _status_filter
		_add_body_label(content_vbox, "No rumors match \"%s\"." % hint)
		return

	for rumor in sorted_rumors:
		_add_rumor_card(content_vbox, rumor, npc_names)


func _add_rumor_card(content_vbox: VBoxContainer, rumor: Rumor, npc_names: Dictionary) -> void:
	var rid: String = rumor.id

	# Aggregate NPC states for this rumor.
	var believers: int  = 0
	var spreaders: int  = 0
	var rejectors: int  = 0
	var prop_path: Array = []
	var spreader_set: Dictionary = {}

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
	var card_has_change: bool = _changed_rumor_ids.has(rid)
	if card_has_change:
		var accent_bar := ColorRect.new()
		accent_bar.custom_minimum_size = Vector2(0, 2)
		accent_bar.color = C_HEADING if _is_positive_transition(journal_status) else C_CONTRADICTED
		content_vbox.add_child(accent_bar)

	# Collapsed header row — click to expand/collapse.
	var header_btn := Button.new()
	var change_marker: String = " *" if card_has_change else ""
	header_btn.text = "%s — %s   [%s]   %d believers  /  %d rejectors%s" % [
		claim_str, subject_name, journal_status, believers, rejectors, change_marker]
	header_btn.toggle_mode           = false
	header_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_btn.clip_text             = true
	header_btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_btn.add_theme_font_size_override("font_size", 12)
	header_btn.add_theme_color_override("font_color",         C_KEY)
	header_btn.add_theme_color_override("font_pressed_color", C_HEADING)
	header_btn.add_theme_color_override("font_hover_color",   C_HEADING)

	if card_has_change:
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
			card_style.bg_color = Color(0.22, 0.16, 0.08, 0.55)
		"EXPIRED", "CONTRADICTED":
			card_style.bg_color = Color(0.14, 0.14, 0.12, 0.55)
		_:
			card_style.bg_color = Color(0.18, 0.13, 0.07, 0.55)
	card_panel.add_theme_stylebox_override("panel", card_style)
	content_vbox.add_child(card_panel)
	var card_vbox := VBoxContainer.new()
	card_panel.add_child(card_vbox)

	card_vbox.add_child(header_btn)

	# Believability gauge — thin bar showing current_believability (0–1).
	var bel_bar := ProgressBar.new()
	bel_bar.min_value             = 0.0
	bel_bar.max_value             = 1.0
	bel_bar.value                 = rumor.current_believability
	bel_bar.show_percentage       = false
	bel_bar.custom_minimum_size   = Vector2(0, 8)
	bel_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bel_fill_color: Color
	if rumor.current_believability > 0.6:
		bel_fill_color = Color(0.10, 0.68, 0.22, 1.0)
	elif rumor.current_believability >= 0.3:
		bel_fill_color = Color(0.82, 0.50, 0.10, 1.0)
	else:
		bel_fill_color = Color(0.80, 0.10, 0.10, 1.0)
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
	badge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	badge_label.add_theme_font_size_override("font_size", 12)
	badge_label.add_theme_color_override("font_color", status_color)
	card_vbox.add_child(badge_label)

	# Chain badge — shown when this rumor is part of an active chain.
	if _world_ref != null and _world_ref.propagation_engine != null:
		var chain_ct: PropagationEngine.ChainType = _world_ref.propagation_engine.get_chain_type(rid)
		if chain_ct != PropagationEngine.ChainType.NONE:
			var chain_color: Color
			var chain_text:  String
			match chain_ct:
				PropagationEngine.ChainType.ESCALATION:
					chain_color = Color(0.92, 0.22, 0.18, 1.0)
					chain_text  = "Escalation"
				PropagationEngine.ChainType.CONTRADICTION:
					chain_color = Color(0.90, 0.50, 0.15, 1.0)
					chain_text  = "Contradiction"
				PropagationEngine.ChainType.SAME_TYPE:
					chain_color = Color(0.60, 0.60, 0.55, 1.0)
					chain_text  = "Echo"
			var chain_row := HBoxContainer.new()
			chain_row.add_theme_constant_override("separation", 4)
			var chain_panel := PanelContainer.new()
			var chain_style := StyleBoxFlat.new()
			chain_style.bg_color     = Color(chain_color.r * 0.25, chain_color.g * 0.25, chain_color.b * 0.25, 0.85)
			chain_style.border_color = chain_color
			chain_style.set_border_width_all(1)
			chain_style.set_corner_radius_all(3)
			chain_style.set_content_margin_all(3)
			chain_panel.add_theme_stylebox_override("panel", chain_style)
			var chain_lbl := Label.new()
			chain_lbl.text = chain_text
			chain_lbl.add_theme_font_size_override("font_size", 11)
			chain_lbl.add_theme_color_override("font_color", chain_color)
			chain_panel.add_child(chain_lbl)
			chain_row.add_child(chain_panel)
			card_vbox.add_child(chain_row)

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
		shelf_fill_style.bg_color = Color(0.55, 0.38, 0.18, 1.0)
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
		var path_parts: Array = []
		for pname in prop_path:
			if spreader_set.has(pname):
				path_parts.append("[b]● %s[/b]" % pname)
			else:
				path_parts.append(pname)
		path_lbl.text = "    " + "  →  ".join(path_parts)
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

	content_vbox.add_child(HSeparator.new())


# ── Rumor status helpers ──────────────────────────────────────────────────────

func _is_contradicted(rumor: Rumor, spreaders: int) -> bool:
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


func _is_positive_transition(status: String) -> bool:
	return status == "SPREADING" or status == "EVALUATING"


func _collect_mutations(parent_rid: String) -> Array:
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
