class_name MainMenuStatsPanel
extends Node

## main_menu_stats_panel.gd — Statistics phase panel for MainMenu (SPA-1004).
##
## Extracted from main_menu.gd.  Call build() then add the returned `panel`
## Control to the parent CanvasLayer.

signal back_requested

# ── Palette ───────────────────────────────────────────────────────────────────
const C_PANEL_BG     := Color(0.13, 0.09, 0.07, 1.0)
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_TITLE        := Color(0.92, 0.78, 0.12, 1.0)
const C_HEADING      := Color(0.91, 0.85, 0.70, 1.0)
const C_SUBHEADING   := Color(0.75, 0.65, 0.50, 1.0)
const C_BODY         := Color(0.70, 0.65, 0.55, 1.0)
const C_MUTED        := Color(0.60, 0.53, 0.42, 1.0)
const C_STAT_LABEL   := Color(0.75, 0.65, 0.50, 1.0)
const C_STAT_VALUE   := Color(0.91, 0.85, 0.70, 1.0)
const C_SCORE_WIN    := Color(0.92, 0.78, 0.12, 1.0)
const C_SCORE_FAIL   := Color(0.85, 0.18, 0.12, 1.0)

# ── Public panel ref ──────────────────────────────────────────────────────────
var panel: Control = null

# ── Callables injected by main_menu.gd ───────────────────────────────────────
var _make_button: Callable
var _separator:   Callable


## Build the statistics panel.
func build(make_button: Callable, separator: Callable) -> Control:
	_make_button = make_button
	_separator   = separator

	panel = _make_panel(680, 520)

	var vbox := VBoxContainer.new()
	vbox.name = "StatsVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	return panel


## Rebuild stats panel content from PlayerStats.
## Called each time the stats phase is shown so it reflects the latest data.
func rebuild_content() -> void:
	var vbox: VBoxContainer = panel.get_node_or_null("StatsVBox")
	if vbox == null:
		return
	for child in vbox.get_children():
		child.queue_free()

	# Heading
	var heading := Label.new()
	heading.text = "Statistics"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(heading)

	vbox.add_child(_separator.call())

	# Scrollable body
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	if not PlayerStats.has_any_data():
		var empty_lbl := Label.new()
		empty_lbl.text = "No games recorded yet.\nPlay a scenario to start tracking your stats."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_color_override("font_color", C_MUTED)
		empty_lbl.add_theme_font_size_override("font_size", 14)
		body.add_child(empty_lbl)
	else:
		# Global totals
		var totals := PlayerStats.get_totals()
		var totals_hdr := Label.new()
		totals_hdr.text = "Lifetime Totals"
		totals_hdr.add_theme_font_size_override("font_size", 16)
		totals_hdr.add_theme_color_override("font_color", C_HEADING)
		body.add_child(totals_hdr)

		var play_sec: int = totals.get("total_play_time_sec", 0)
		var play_str: String
		if play_sec >= 3600:
			play_str = "%dh %dm" % [play_sec / 3600, (play_sec % 3600) / 60]
		else:
			play_str = "%dm %ds" % [play_sec / 60, play_sec % 60]

		var totals_grid := GridContainer.new()
		totals_grid.columns = 2
		totals_grid.add_theme_constant_override("h_separation", 24)
		totals_grid.add_theme_constant_override("v_separation", 4)
		body.add_child(totals_grid)
		_add_grid_stat(totals_grid, "Play Time",      play_str)
		_add_grid_stat(totals_grid, "Rumors Spread",  str(totals.get("total_rumors_spread",  0)))
		_add_grid_stat(totals_grid, "NPCs Convinced", str(totals.get("total_npcs_convinced", 0)))
		_add_grid_stat(totals_grid, "Bribes Paid",    str(totals.get("total_bribes_paid",    0)))

		body.add_child(_separator.call())

		# Per-scenario table
		var sc_hdr := Label.new()
		sc_hdr.text = "Scenario Records"
		sc_hdr.add_theme_font_size_override("font_size", 16)
		sc_hdr.add_theme_color_override("font_color", C_HEADING)
		body.add_child(sc_hdr)

		var scenario_names := {
			"scenario_1": "1 — A Whisper in Autumn",
			"scenario_2": "2 — The Herb-Wife's Ruin",
			"scenario_3": "3 — The Fenn Succession",
			"scenario_4": "4 — The Holy Inquisition",
			"scenario_5": "5 — The Election",
			"scenario_6": "6 — The Merchant's Debt",
		}
		var diff_labels := { "apprentice": "Appr.", "master": "Master", "spymaster": "Spym." }

		for sid in PlayerStats.SCENARIO_IDS:
			var has_sc_data := false
			for diff in PlayerStats.DIFFICULTIES:
				if PlayerStats.get_scenario_stats(sid, diff).get("games_played", 0) > 0:
					has_sc_data = true
					break
			if not has_sc_data:
				continue

			var sc_title := Label.new()
			sc_title.text = scenario_names.get(sid, sid)
			sc_title.add_theme_font_size_override("font_size", 13)
			sc_title.add_theme_color_override("font_color", C_SUBHEADING)
			body.add_child(sc_title)

			var header_row := HBoxContainer.new()
			header_row.add_theme_constant_override("separation", 0)
			body.add_child(header_row)
			_add_table_cell(header_row, "Difficulty",  100, C_MUTED,       true)
			_add_table_cell(header_row, "Played",       60, C_MUTED,       true)
			_add_table_cell(header_row, "Wins",         50, C_MUTED,       true)
			_add_table_cell(header_row, "Losses",       55, C_MUTED,       true)
			_add_table_cell(header_row, "Best Score",   80, C_MUTED,       true)
			_add_table_cell(header_row, "Fastest Win",  90, C_MUTED,       true)

			for diff in PlayerStats.DIFFICULTIES:
				var rec := PlayerStats.get_scenario_stats(sid, diff)
				if rec.get("games_played", 0) == 0:
					continue
				var fastest: int = rec.get("fastest_win_days", -1)
				var fastest_str: String = ("%d days" % fastest) if fastest >= 0 else "—"
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 0)
				body.add_child(row)
				_add_table_cell(row, diff_labels.get(diff, diff),        100, C_BODY,       false)
				_add_table_cell(row, str(rec.get("games_played", 0)),     60, C_STAT_VALUE, false)
				_add_table_cell(row, str(rec.get("wins",         0)),     50, C_SCORE_WIN,  false)
				_add_table_cell(row, str(rec.get("losses",       0)),     55, C_SCORE_FAIL, false)
				_add_table_cell(row, str(rec.get("best_score",   0)),     80, C_STAT_VALUE, false)
				_add_table_cell(row, fastest_str,                         90, C_STAT_VALUE, false)

	# Bottom buttons
	vbox.add_child(_separator.call())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var btn_back := _make_button.call("Back", 160)
	btn_back.pressed.connect(func() -> void: back_requested.emit())
	btn_row.add_child(btn_back)

	if PlayerStats.has_any_data():
		var btn_reset := _make_button.call("Reset Stats", 160)
		btn_reset.pressed.connect(_on_stats_reset)
		btn_row.add_child(btn_reset)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _add_grid_stat(grid: GridContainer, label_text: String, value_text: String) -> void:
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", C_STAT_LABEL)
	lbl.add_theme_font_size_override("font_size", 13)
	grid.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_color_override("font_color", C_STAT_VALUE)
	val.add_theme_font_size_override("font_size", 13)
	grid.add_child(val)


func _add_table_cell(row: HBoxContainer, text: String, w: int, color: Color, bold: bool) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(w, 0)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 12)
	if bold:
		lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)


func _make_panel(w: int, h: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(w, h)
	p.set_anchor(SIDE_LEFT,   0.5)
	p.set_anchor(SIDE_RIGHT,  0.5)
	p.set_anchor(SIDE_TOP,    0.5)
	p.set_anchor(SIDE_BOTTOM, 0.5)
	p.set_offset(SIDE_LEFT,   -w / 2.0)
	p.set_offset(SIDE_RIGHT,   w / 2.0)
	p.set_offset(SIDE_TOP,    -h / 2.0)
	p.set_offset(SIDE_BOTTOM,  h / 2.0)
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_BG
	style.border_color = C_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(28)
	p.add_theme_stylebox_override("panel", style)
	return p


# ── Event handlers ────────────────────────────────────────────────────────────

func _on_stats_reset() -> void:
	PlayerStats.reset_all()
	rebuild_content()
