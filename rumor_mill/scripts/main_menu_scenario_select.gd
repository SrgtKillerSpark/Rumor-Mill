class_name MainMenuScenarioSelect
extends Node

## main_menu_scenario_select.gd — Scenario selection phase panel for MainMenu (SPA-1004).
##
## Extracted from main_menu.gd.  Call build(scenarios, ...) then add the returned
## `panel` Control to the parent CanvasLayer.

signal back_requested
signal next_requested

# ── Palette ───────────────────────────────────────────────────────────────────
const C_HEADING      := Color(0.91, 0.85, 0.70, 1.0)
const C_MUTED        := Color(0.60, 0.53, 0.42, 1.0)
const C_BODY         := Color(0.70, 0.65, 0.55, 1.0)
const C_CARD_BG      := Color(0.10, 0.07, 0.05, 1.0)
const C_CARD_HOVER   := Color(0.18, 0.13, 0.09, 1.0)
const C_CARD_BORDER  := Color(0.45, 0.30, 0.12, 1.0)
const C_CARD_SEL     := Color(0.70, 0.50, 0.15, 1.0)
const C_PANEL_BG     := Color(0.11, 0.08, 0.05, 0.92)
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 0.85)

const SCENARIO_ACCENT := {
	"scenario_1": Color(0.40, 0.75, 0.35, 1.0),
	"scenario_2": Color(0.85, 0.70, 0.20, 1.0),
	"scenario_3": Color(0.85, 0.40, 0.15, 1.0),
	"scenario_4": Color(0.85, 0.18, 0.12, 1.0),
	"scenario_5": Color(0.70, 0.20, 0.50, 1.0),
	"scenario_6": Color(0.55, 0.12, 0.55, 1.0),
}
const SCENARIO_DIFFICULTY := {
	"scenario_1": "Introductory",
	"scenario_2": "Moderate",
	"scenario_3": "Challenging",
	"scenario_4": "Expert",
	"scenario_5": "Advanced",
	"scenario_6": "Master",
}
const SCENARIO_DESCRIPTOR := {
	"scenario_1": "Single target, generous timeline. Learn the basics.",
	"scenario_2": "New mechanic: epidemic spread. One NPC can end your run.",
	"scenario_3": "Two targets + a rival agent working against you.",
	"scenario_4": "Pure defense — protect three allies from escalating attacks.",
	"scenario_5": "Three-way race with a timed endorsement event.",
	"scenario_6": "Stealth mode — guards are on the enemy payroll.",
}

# SPA-1669 #11: Responsive panel sizing (mirrors main_menu.gd WIDE_PANEL).
const SELECT_PANEL_MIN_W := 500;  const SELECT_PANEL_MAX_W := 700
const SELECT_PANEL_MIN_H := 400;  const SELECT_PANEL_MAX_H := 520
const SELECT_PANEL_VP_W  := 0.55; const SELECT_PANEL_VP_H  := 0.72

# ── Public refs ───────────────────────────────────────────────────────────────
var panel: Control = null
var selected_scenario: Dictionary = {}
var selected_idx: int = -1

# ── Internal state ────────────────────────────────────────────────────────────
var _scenario_cards: Array = []
var _scenarios:      Array = []

# ── Callables ─────────────────────────────────────────────────────────────────
var _make_button:          Callable
var _separator:            Callable
var _is_scenario_locked:   Callable  # (idx: int) -> bool
var _unlock_requires_title: Callable # (idx: int) -> String


## Build the scenario select panel.
func build(
		scenarios: Array,
		make_button: Callable,
		separator: Callable,
		is_locked_fn: Callable,
		unlock_title_fn: Callable) -> Control:
	_scenarios            = scenarios
	_make_button          = make_button
	_separator            = separator
	_is_scenario_locked   = is_locked_fn
	_unlock_requires_title = unlock_title_fn

	# SPA-1669 #11: Responsive sizing — viewport-clamped panel dimensions.
	var vp_size := DisplayServer.window_get_size()
	var pw := UILayoutConstants.clamp_to_viewport(float(vp_size.x), SELECT_PANEL_VP_W, SELECT_PANEL_MIN_W, SELECT_PANEL_MAX_W)
	var ph := UILayoutConstants.clamp_to_viewport(float(vp_size.y), SELECT_PANEL_VP_H, SELECT_PANEL_MIN_H, SELECT_PANEL_MAX_H)
	panel = _make_parchment_panel(pw, ph)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	var heading := Label.new()
	heading.text = "Choose Your Assignment"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", C_HEADING)
	vbox.add_child(heading)

	var sub := Label.new()
	sub.text = "Each assignment tests a different facet of the whispersmith's art."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(sub)

	vbox.add_child(_separator.call())

	# Wrap the scenario card list in a ScrollContainer so the panel stays usable
	# when the card stack is taller than the panel (e.g. on smaller windows or
	# when all 6 scenarios are listed).
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vbox.add_child(scroll)

	var card_list := VBoxContainer.new()
	card_list.add_theme_constant_override("separation", 12)
	card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(card_list)

	_scenario_cards.clear()
	for i in _scenarios.size():
		var sc: Dictionary = _scenarios[i]
		var card := _build_scenario_card(sc, i)
		card_list.add_child(card)
		_scenario_cards.append(card)

	# Wire Up/Down focus between overlay buttons.
	var card_btns: Array = []
	for card in _scenario_cards:
		var overlay: Button = card.get_child(card.get_child_count() - 1) as Button
		if overlay != null:
			card_btns.append(overlay)
	for i in card_btns.size():
		var prev: Button = card_btns[(i - 1 + card_btns.size()) % card_btns.size()]
		var next: Button = card_btns[(i + 1) % card_btns.size()]
		card_btns[i].focus_neighbor_top    = prev.get_path()
		card_btns[i].focus_neighbor_bottom = next.get_path()
		card_btns[i].focus_next            = next.get_path()
		card_btns[i].focus_previous        = prev.get_path()

	vbox.add_child(_separator.call())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var btn_back := _make_button.call("Back", 140)
	btn_back.pressed.connect(func() -> void: back_requested.emit())
	btn_row.add_child(btn_back)

	var btn_next := _make_button.call("Next", 140)
	btn_next.pressed.connect(_on_select_next)
	btn_row.add_child(btn_next)

	return panel


func _build_scenario_card(sc: Dictionary, idx: int) -> PanelContainer:
	var locked: bool = _is_scenario_locked.call(idx)
	var sc_id: String = sc.get("scenarioId", "")

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 90)

	var accent_color: Color = SCENARIO_ACCENT.get(sc_id, C_CARD_BORDER)
	var style_normal := _scenario_card_style(C_CARD_BG, C_CARD_BORDER, accent_color)
	var style_hover  := _scenario_card_style(C_CARD_HOVER, C_CARD_BORDER, accent_color)
	card.add_theme_stylebox_override("panel", style_normal)
	card.set_meta("style_normal",  style_normal)
	card.set_meta("style_hover",   style_hover)
	card.set_meta("scenario_idx",  idx)
	card.set_meta("locked",        locked)

	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_theme_stylebox_override("normal",  StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover",   StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var focus_ring := StyleBoxFlat.new()
	focus_ring.bg_color = Color(0, 0, 0, 0)
	focus_ring.draw_center = false
	focus_ring.set_border_width_all(2)
	focus_ring.border_color = Color(1.00, 0.90, 0.40, 1.0)
	btn.add_theme_stylebox_override("focus", focus_ring)
	btn.pressed.connect(_on_card_pressed.bind(idx))
	btn.mouse_entered.connect(_on_card_hover.bind(card, true))
	btn.mouse_exited.connect(_on_card_hover.bind(card, false))

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)

	var number_lbl := Label.new()
	number_lbl.text = "  %d." % (idx + 1)
	number_lbl.add_theme_font_size_override("font_size", 15)
	number_lbl.add_theme_color_override("font_color", C_MUTED)
	title_row.add_child(number_lbl)

	var title_lbl := Label.new()
	title_lbl.text = sc.get("title", "Unknown Scenario")
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.add_theme_color_override("font_color", C_MUTED if locked else C_HEADING)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)

	var diff_text: String = SCENARIO_DIFFICULTY.get(sc_id, "")
	if diff_text != "":
		var diff_badge := Label.new()
		diff_badge.text = diff_text
		diff_badge.add_theme_font_size_override("font_size", 12)
		diff_badge.add_theme_color_override("font_color", accent_color if not locked else C_MUTED)
		title_row.add_child(diff_badge)

	var days_lbl := Label.new()
	if locked:
		days_lbl.text = "Locked"
	else:
		var days_val: int = int(sc.get("daysAllowed", 30))
		var est_mins: int = maxi(days_val * 2, 5)
		days_lbl.text = "%d days  (~%d min)" % [days_val, est_mins]
	days_lbl.add_theme_font_size_override("font_size", 12)
	days_lbl.add_theme_color_override("font_color", C_MUTED)
	title_row.add_child(days_lbl)

	inner.add_child(title_row)

	var teaser: String = sc.get("hookText", "")
	if teaser == "":
		var full_text: String = sc.get("startingText", "")
		teaser = full_text.split("\n")[0] if "\n" in full_text else full_text

	var desc_rtl := RichTextLabel.new()
	desc_rtl.bbcode_enabled = true
	desc_rtl.text = "[i]%s[/i]" % teaser if not locked else teaser
	desc_rtl.fit_content = false
	desc_rtl.scroll_active = true
	desc_rtl.custom_minimum_size = Vector2(0, 60)
	desc_rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_rtl.add_theme_font_size_override("normal_font_size", 12)
	desc_rtl.add_theme_color_override("default_color", C_MUTED if locked else C_BODY)
	inner.add_child(desc_rtl)

	var descriptor: String = SCENARIO_DESCRIPTOR.get(sc_id, "")
	if descriptor != "" and not locked:
		var desc_lbl := Label.new()
		desc_lbl.text = descriptor
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", accent_color.lerp(C_MUTED, 0.35))
		inner.add_child(desc_lbl)

	if locked:
		var lock_row := HBoxContainer.new()
		lock_row.visible = false
		lock_row.name = "LockMessageRow"
		lock_row.add_theme_constant_override("separation", 8)

		var lock_msg := Label.new()
		lock_msg.text = "Complete \"%s\" to unlock." % _unlock_requires_title.call(idx)
		lock_msg.add_theme_font_size_override("font_size", 12)
		lock_msg.add_theme_color_override("font_color", C_MUTED)
		lock_row.add_child(lock_msg)

		var play_anyway := Button.new()
		play_anyway.text = "Play anyway \u2192"
		play_anyway.flat = true
		play_anyway.add_theme_font_size_override("font_size", 12)
		play_anyway.add_theme_color_override("font_color", C_MUTED)
		play_anyway.add_theme_stylebox_override("normal",  StyleBoxEmpty.new())
		play_anyway.add_theme_stylebox_override("hover",   StyleBoxEmpty.new())
		play_anyway.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		play_anyway.pressed.connect(_on_play_anyway_pressed.bind(idx))
		lock_row.add_child(play_anyway)

		inner.add_child(lock_row)

	card.add_child(inner)
	card.add_child(btn)
	return card


func _scenario_card_style(bg: Color, border: Color, _accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.border_width_left = 4
	# SPA-1669 #21: Use shared TIGHT margin; left reduced by accent border width.
	s.set_content_margin_all(UILayoutConstants.MARGIN_TIGHT)
	s.content_margin_left = UILayoutConstants.MARGIN_TIGHT - 2
	return s


## Build the parchment-styled centred panel.  Accepts pre-computed w/h.
func _make_parchment_panel(w: int, h: int) -> PanelContainer:
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
	style.bg_color     = C_PANEL_BG
	style.border_color = C_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(UILayoutConstants.MARGIN_STANDARD)
	style.border_width_top = 3
	p.add_theme_stylebox_override("panel", style)
	return p


# ── Event handlers ────────────────────────────────────────────────────────────

func _on_card_hover(card: PanelContainer, entering: bool) -> void:
	var idx: int = card.get_meta("scenario_idx", -1)
	if idx == selected_idx:
		return
	if entering:
		AudioManager.play_sfx_pitched("ui_click", 2.0)
	var style = card.get_meta("style_hover") if entering else card.get_meta("style_normal")
	card.add_theme_stylebox_override("panel", style)


func _on_card_pressed(idx: int) -> void:
	if idx < 0 or idx >= _scenario_cards.size() or idx >= _scenarios.size():
		return
	var card: PanelContainer = _scenario_cards[idx]
	var locked: bool = card.get_meta("locked", false)

	if locked:
		for i in _scenario_cards.size():
			var c: PanelContainer = _scenario_cards[i]
			var row = c.find_child("LockMessageRow", true, false)
			if row != null:
				row.visible = (i == idx)
		return

	if selected_idx >= 0 and selected_idx < _scenario_cards.size():
		var prev: PanelContainer = _scenario_cards[selected_idx]
		prev.add_theme_stylebox_override("panel", prev.get_meta("style_normal"))

	selected_idx = idx
	card.add_theme_stylebox_override("panel", _card_style(C_CARD_HOVER, C_CARD_SEL))
	selected_scenario = _scenarios[idx]
	AudioManager.play_ui("click")


func _on_play_anyway_pressed(idx: int) -> void:
	if idx < 0 or idx >= _scenario_cards.size() or idx >= _scenarios.size():
		return
	if selected_idx >= 0 and selected_idx < _scenario_cards.size():
		var prev: PanelContainer = _scenario_cards[selected_idx]
		prev.add_theme_stylebox_override("panel", prev.get_meta("style_normal"))
	selected_idx = idx
	var card: PanelContainer = _scenario_cards[idx]
	card.add_theme_stylebox_override("panel", _card_style(C_CARD_HOVER, C_CARD_SEL))
	selected_scenario = _scenarios[idx]
	next_requested.emit()


func _on_select_next() -> void:
	if selected_scenario.is_empty():
		if not _scenarios.is_empty():
			_on_card_pressed(0)
		else:
			return
	next_requested.emit()


func _card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_content_margin_all(16)
	return s
