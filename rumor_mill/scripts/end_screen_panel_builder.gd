class_name EndScreenPanelBuilder
extends RefCounted

## end_screen_panel_builder.gd — Full UI tree construction and tab management
## for EndScreen.
##
## Extracted from end_screen.gd (SPA-1016). Owns the backdrop, panel, and all
## child widgets. Provides tab-switching and the defeat "what went wrong" insert.
##
## Call build(owner_layer) to construct everything and add nodes to owner_layer.
## All public node-ref vars are populated after build() returns.
## Call show_tab_results() / show_tab_replay() to switch tabs.
## Call show_what_went_wrong(text) to insert the defeat one-liner.

# ── Palette ───────────────────────────────────────────────────────────────────
const C_BACKDROP     := Color(0.04, 0.02, 0.02, 0.90)
const C_PANEL_BG     := Color(0.13, 0.09, 0.07, 1.0)
const C_CARD_BG      := Color(0.10, 0.07, 0.05, 1.0)
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_WIN          := Color(0.92, 0.78, 0.12, 1.0)
const C_FAIL         := Color(0.85, 0.18, 0.12, 1.0)
const C_HEADING      := Color(0.91, 0.85, 0.70, 1.0)
const C_SUBHEADING   := Color(0.75, 0.65, 0.50, 1.0)
const C_BODY         := Color(0.70, 0.65, 0.55, 1.0)
const C_BTN_NORMAL   := Color(0.40, 0.22, 0.08, 1.0)
const C_BTN_HOVER    := Color(0.60, 0.34, 0.12, 1.0)
const C_BTN_TEXT     := Color(0.95, 0.91, 0.80, 1.0)
const C_TAB_ACTIVE   := Color(0.55, 0.38, 0.18, 1.0)
const C_TAB_INACTIVE := Color(0.20, 0.14, 0.10, 1.0)

const PANEL_W := 760
const PANEL_H := 640

# ── Public node refs (populated by build()) ───────────────────────────────────
var backdrop:           ColorRect      = null
var panel:              PanelContainer = null
var result_banner:      Label          = null
var scenario_title:     Label          = null
var narrative_lbl:      RichTextLabel  = null
var strategic_hint_lbl: RichTextLabel  = null
var stats_container:    VBoxContainer  = null
var npc_container:      VBoxContainer  = null
var btn_again:          Button         = null
var btn_next:           Button         = null
var btn_main_menu:      Button         = null
var tease_lbl:          RichTextLabel  = null
var tab_results:        Button         = null
var tab_replay:         Button         = null
var results_container:  Control        = null
var replay_container:   VBoxContainer  = null

# ── Private state ─────────────────────────────────────────────────────────────
var _what_went_wrong_lbl: Label = null


## Build the full end-screen UI and add all nodes to owner_layer.
## After this call, all public vars above are populated.
func build(owner_layer: CanvasLayer) -> void:
	backdrop = ColorRect.new()
	backdrop.color = C_BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	owner_layer.add_child(backdrop)

	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	panel.set_anchor(SIDE_LEFT,   0.5)
	panel.set_anchor(SIDE_RIGHT,  0.5)
	panel.set_anchor(SIDE_TOP,    0.5)
	panel.set_anchor(SIDE_BOTTOM, 0.5)
	panel.set_offset(SIDE_LEFT,   -PANEL_W / 2.0)
	panel.set_offset(SIDE_RIGHT,   PANEL_W / 2.0)
	panel.set_offset(SIDE_TOP,    -PANEL_H / 2.0)
	panel.set_offset(SIDE_BOTTOM,  PANEL_H / 2.0)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color           = C_PANEL_BG
	panel_style.border_color       = C_PANEL_BORDER
	panel_style.set_border_width_all(2)
	panel_style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", panel_style)
	owner_layer.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)

	# ── Victory / Defeat banner ───────────────────────────────────────────────
	result_banner = Label.new()
	result_banner.text = "VICTORY"
	result_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_banner.add_theme_font_size_override("font_size", 36)
	result_banner.add_theme_color_override("font_color", C_WIN)
	vbox.add_child(result_banner)

	# ── Scenario title ────────────────────────────────────────────────────────
	scenario_title = Label.new()
	scenario_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scenario_title.add_theme_font_size_override("font_size", 16)
	scenario_title.add_theme_color_override("font_color", C_SUBHEADING)
	vbox.add_child(scenario_title)

	vbox.add_child(_make_separator())

	# ── Summary narrative ─────────────────────────────────────────────────────
	narrative_lbl = RichTextLabel.new()
	narrative_lbl.fit_content          = true
	narrative_lbl.custom_maximum_size  = Vector2(0, 120)
	narrative_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	narrative_lbl.bbcode_enabled       = true
	narrative_lbl.add_theme_color_override("default_color", C_BODY)
	narrative_lbl.add_theme_font_size_override("normal_font_size", 15)
	vbox.add_child(narrative_lbl)

	# ── SPA-948: Strategic defeat hint ───────────────────────────────────────
	strategic_hint_lbl = RichTextLabel.new()
	strategic_hint_lbl.fit_content          = true
	strategic_hint_lbl.custom_maximum_size  = Vector2(0, 60)
	strategic_hint_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	strategic_hint_lbl.bbcode_enabled       = true
	strategic_hint_lbl.add_theme_color_override("default_color", Color(0.95, 0.75, 0.30, 1.0))
	strategic_hint_lbl.add_theme_font_size_override("normal_font_size", 13)
	strategic_hint_lbl.add_theme_font_size_override("bold_font_size", 13)
	strategic_hint_lbl.visible = false
	vbox.add_child(strategic_hint_lbl)

	vbox.add_child(_make_separator())

	# ── SPA-840: Next-scenario tease ─────────────────────────────────────────
	tease_lbl = RichTextLabel.new()
	tease_lbl.custom_minimum_size = Vector2(0, 32)
	tease_lbl.fit_content = true
	tease_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tease_lbl.bbcode_enabled = true
	tease_lbl.add_theme_color_override("default_color", C_SUBHEADING)
	tease_lbl.add_theme_font_size_override("normal_font_size", 14)
	tease_lbl.visible = false
	vbox.add_child(tease_lbl)

	# ── SPA-212: Tab bar ─────────────────────────────────────────────────────
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_row)

	tab_results = _make_tab_button("RESULTS", true)
	tab_results.pressed.connect(show_tab_results)
	tab_row.add_child(tab_results)

	tab_replay = _make_tab_button("REPLAY", false)
	tab_replay.pressed.connect(show_tab_replay)
	tab_row.add_child(tab_replay)

	tab_results.focus_neighbor_right = tab_replay.get_path()
	tab_results.focus_next           = tab_replay.get_path()
	tab_replay.focus_neighbor_left   = tab_results.get_path()
	tab_replay.focus_previous        = tab_results.get_path()

	# ── Results tab content ───────────────────────────────────────────────────
	results_container = HBoxContainer.new()
	results_container.add_theme_constant_override("separation", 12)
	results_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(results_container)

	var left_card := _make_card()
	left_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_container.add_child(left_card)

	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 6)
	left_card.add_child(left_vbox)

	var stats_heading := Label.new()
	stats_heading.text = "STATS"
	stats_heading.add_theme_font_size_override("font_size", 13)
	stats_heading.add_theme_color_override("font_color", C_HEADING)
	left_vbox.add_child(stats_heading)

	left_vbox.add_child(_make_separator())

	stats_container = VBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 5)
	left_vbox.add_child(stats_container)

	var right_card := _make_card()
	right_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_container.add_child(right_card)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 6)
	right_card.add_child(right_vbox)

	var npc_heading := Label.new()
	npc_heading.text = "KEY OUTCOMES"
	npc_heading.add_theme_font_size_override("font_size", 13)
	npc_heading.add_theme_color_override("font_color", C_HEADING)
	right_vbox.add_child(npc_heading)

	right_vbox.add_child(_make_separator())

	npc_container = VBoxContainer.new()
	npc_container.add_theme_constant_override("separation", 7)
	right_vbox.add_child(npc_container)

	# ── Replay tab content ────────────────────────────────────────────────────
	replay_container = VBoxContainer.new()
	replay_container.add_theme_constant_override("separation", 8)
	replay_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	replay_container.visible = false
	vbox.add_child(replay_container)

	vbox.add_child(_make_separator())

	# ── Button row ────────────────────────────────────────────────────────────
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_row)

	btn_again = _make_button("Play Again", 150)
	btn_row.add_child(btn_again)

	btn_next = _make_button("Next Scenario", 160)
	btn_next.modulate = Color(1.0, 1.0, 1.0, 0.35)
	btn_next.disabled = true
	btn_row.add_child(btn_next)

	btn_main_menu = _make_button("Main Menu", 150)
	btn_row.add_child(btn_main_menu)

	btn_again.focus_neighbor_right      = btn_next.get_path()
	btn_again.focus_next                = btn_next.get_path()
	btn_again.focus_neighbor_left       = btn_main_menu.get_path()
	btn_again.focus_previous            = btn_main_menu.get_path()
	btn_next.focus_neighbor_left        = btn_again.get_path()
	btn_next.focus_previous             = btn_again.get_path()
	btn_next.focus_neighbor_right       = btn_main_menu.get_path()
	btn_next.focus_next                 = btn_main_menu.get_path()
	btn_main_menu.focus_neighbor_left   = btn_next.get_path()
	btn_main_menu.focus_previous        = btn_next.get_path()
	btn_main_menu.focus_neighbor_right  = btn_again.get_path()
	btn_main_menu.focus_next            = btn_again.get_path()


## Insert or replace the defeat "what went wrong" label after results_container.
func show_what_went_wrong(text: String) -> void:
	if _what_went_wrong_lbl != null:
		_what_went_wrong_lbl.queue_free()
	_what_went_wrong_lbl = Label.new()
	_what_went_wrong_lbl.text = text
	_what_went_wrong_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_what_went_wrong_lbl.add_theme_font_size_override("font_size", 13)
	_what_went_wrong_lbl.add_theme_color_override("font_color", C_FAIL)
	_what_went_wrong_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if results_container != null and results_container.get_parent() != null:
		var vbox := results_container.get_parent()
		var idx_after: int = results_container.get_index() + 1
		vbox.add_child(_what_went_wrong_lbl)
		vbox.move_child(_what_went_wrong_lbl, idx_after)


func show_tab_results() -> void:
	_set_tab_active(tab_results, true)
	_set_tab_active(tab_replay, false)
	if results_container != null:
		results_container.visible = true
	if replay_container != null:
		replay_container.visible = false
	if tab_results != null:
		tab_results.call_deferred("grab_focus")


func show_tab_replay() -> void:
	_set_tab_active(tab_results, false)
	_set_tab_active(tab_replay, true)
	if results_container != null:
		results_container.visible = false
	if replay_container != null:
		replay_container.visible = true
	if tab_replay != null:
		tab_replay.call_deferred("grab_focus")


# ── Private helpers ───────────────────────────────────────────────────────────

func _make_card() -> PanelContainer:
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color     = C_CARD_BG
	card_style.border_color = C_PANEL_BORDER
	card_style.set_border_width_all(1)
	card_style.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", card_style)
	return card


func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_PANEL_BORDER
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	return sep


func _make_button(label: String, min_width: int) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(min_width, 40)

	var normal := StyleBoxFlat.new()
	normal.bg_color = C_BTN_NORMAL
	normal.set_border_width_all(1)
	normal.border_color = C_PANEL_BORDER
	normal.set_content_margin_all(8)

	var hover := StyleBoxFlat.new()
	hover.bg_color = C_BTN_HOVER
	hover.set_border_width_all(1)
	hover.border_color = C_PANEL_BORDER
	hover.set_content_margin_all(8)

	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = C_BTN_HOVER
	focus_style.set_border_width_all(2)
	focus_style.border_color = Color(1.00, 0.90, 0.40, 1.0)
	focus_style.set_content_margin_all(8)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover",  hover)
	btn.add_theme_stylebox_override("focus",  focus_style)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)
	return btn


func _make_tab_button(label_text: String, active: bool) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(100, 28)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)

	var style := StyleBoxFlat.new()
	style.bg_color = C_TAB_ACTIVE if active else C_TAB_INACTIVE
	style.set_border_width_all(1)
	style.border_color = C_PANEL_BORDER
	style.set_content_margin_all(4)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = C_TAB_ACTIVE if active else Color(0.30, 0.22, 0.14, 1.0)
	hover_style.set_border_width_all(1)
	hover_style.border_color = C_PANEL_BORDER
	hover_style.set_content_margin_all(4)

	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = C_TAB_ACTIVE if active else C_TAB_INACTIVE
	focus_style.set_border_width_all(2)
	focus_style.border_color = Color(1.00, 0.90, 0.40, 1.0)
	focus_style.set_content_margin_all(4)

	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", focus_style)
	return btn


func _set_tab_active(btn: Button, active: bool) -> void:
	var style := btn.get_theme_stylebox("normal") as StyleBoxFlat
	if style != null:
		style.bg_color = C_TAB_ACTIVE if active else C_TAB_INACTIVE
