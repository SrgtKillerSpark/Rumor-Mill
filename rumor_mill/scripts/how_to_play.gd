extends CanvasLayer

## how_to_play.gd — Three-tab reference overlay (layer 51, above pause menu and main menu).
## Accessible from pause menu and main menu.
## Esc closes it; does NOT unpause the game tree.
## All nodes use PROCESS_MODE_ALWAYS so input is received while paused.

# ── Palette ───────────────────────────────────────────────────────────────────
const C_OVERLAY      := Color(0.0,  0.0,  0.0,  0.55)
const C_PANEL_BG     := Color(0.12, 0.08, 0.05, 1.0)
const C_BORDER       := Color(0.65, 0.55, 0.35, 1.0)
const C_TITLE        := Color(0.92, 0.78, 0.12, 1.0)   # gold
const C_HEADING      := Color(0.92, 0.78, 0.12, 1.0)   # gold
const C_BODY         := Color(0.82, 0.74, 0.58, 1.0)   # parchment
const C_TAB_ACTIVE   := Color(0.55, 0.38, 0.18, 1.0)   # amber-brown
const C_TAB_INACTIVE := Color(0.20, 0.14, 0.09, 1.0)   # very dark
const C_TAB_TEXT     := Color(0.95, 0.91, 0.80, 1.0)
const C_ROW_ALT      := Color(0.18, 0.12, 0.07, 0.5)
const C_ROW_HEADER   := Color(0.30, 0.20, 0.10, 0.8)

enum Tab { CONTROLS, MECHANICS, SYSTEMS }

var _current_tab:   Tab              = Tab.CONTROLS
var _tab_buttons:   Array            = []   # Array[Button]
var _content_boxes: Array            = []   # Array[VBoxContainer]
var _scroll:        ScrollContainer  = null


func _ready() -> void:
	layer        = 51
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_RIGHT:
			var next_tab := Tab(((_current_tab as int) + 1) % 3)
			_switch_tab(next_tab)
			_tab_buttons[next_tab as int].grab_focus()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_LEFT:
			var prev_tab := Tab(((_current_tab as int) + 2) % 3)
			_switch_tab(prev_tab)
			_tab_buttons[prev_tab as int].grab_focus()
			get_viewport().set_input_as_handled()


## Show the overlay and reset to the Controls tab.
func open() -> void:
	visible = true
	_switch_tab(Tab.CONTROLS)
	# Grab focus on the first tab button so keyboard navigation works immediately.
	if _tab_buttons.size() > 0:
		_tab_buttons[0].call_deferred("grab_focus")


func _close() -> void:
	visible = false


# ── UI Construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Full-screen dim overlay.
	var overlay := ColorRect.new()
	overlay.color = C_OVERLAY
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	# Centred panel 700 × 500.
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(700, 500)
	panel.set_anchor(SIDE_LEFT,   0.5)
	panel.set_anchor(SIDE_RIGHT,  0.5)
	panel.set_anchor(SIDE_TOP,    0.5)
	panel.set_anchor(SIDE_BOTTOM, 0.5)
	panel.set_offset(SIDE_LEFT,   -350)
	panel.set_offset(SIDE_RIGHT,   350)
	panel.set_offset(SIDE_TOP,    -250)
	panel.set_offset(SIDE_BOTTOM,  250)
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_BG
	style.set_border_width_all(2)
	style.border_color = C_BORDER
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	# Margin inside panel.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_child(margin)

	# Outer VBox: title → tabs → content → close row.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.process_mode = Node.PROCESS_MODE_ALWAYS
	margin.add_child(vbox)

	# Title.
	var title := Label.new()
	title.text                 = "— HOW TO PLAY —"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", C_TITLE)
	title.custom_minimum_size = Vector2(0, 32)
	vbox.add_child(title)

	# Tab row.
	var tab_row := HBoxContainer.new()
	tab_row.custom_minimum_size = Vector2(0, 32)
	tab_row.add_theme_constant_override("separation", 4)
	tab_row.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(tab_row)

	var tab_labels := ["Controls", "Mechanics", "Systems"]
	for i in tab_labels.size():
		var btn := Button.new()
		btn.text                    = tab_labels[i]
		btn.custom_minimum_size     = Vector2(0, 32)
		btn.size_flags_horizontal   = Control.SIZE_EXPAND_FILL
		btn.process_mode            = Node.PROCESS_MODE_ALWAYS
		btn.pressed.connect(_switch_tab.bind(i as Tab))
		_apply_tab_style(btn, false)
		tab_row.add_child(btn)
		_tab_buttons.append(btn)

	# Scroll container for content.
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(_scroll)

	var scroll_inner := VBoxContainer.new()
	scroll_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_inner.process_mode = Node.PROCESS_MODE_ALWAYS
	_scroll.add_child(scroll_inner)

	# Pre-build all three content VBoxes; only one is visible at a time.
	for builder in [_build_tab_controls, _build_tab_mechanics, _build_tab_systems]:
		var content: VBoxContainer = builder.call()
		content.process_mode = Node.PROCESS_MODE_ALWAYS
		scroll_inner.add_child(content)
		_content_boxes.append(content)

	# Close button row (bottom-right).
	var close_row := HBoxContainer.new()
	close_row.custom_minimum_size = Vector2(0, 28)
	close_row.process_mode = Node.PROCESS_MODE_ALWAYS
	vbox.add_child(close_row)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_row.add_child(spacer)

	var btn_close := Button.new()
	btn_close.text = "Close  (Esc)"
	btn_close.custom_minimum_size = Vector2(130, 24)
	btn_close.add_theme_font_size_override("font_size", 12)
	btn_close.process_mode = Node.PROCESS_MODE_ALWAYS
	btn_close.pressed.connect(_close)
	# Focus ring matches the tab button gold-border style.
	var close_focus := StyleBoxFlat.new()
	close_focus.bg_color = Color(0, 0, 0, 0)
	close_focus.draw_center = false
	close_focus.set_border_width_all(2)
	close_focus.border_color = Color(1.00, 0.90, 0.40, 1.0)
	btn_close.add_theme_stylebox_override("focus", close_focus)
	close_row.add_child(btn_close)

	# ── Tab button focus neighbors (Left/Right to cycle; Down goes to Close) ──
	for i in _tab_buttons.size():
		var prev_idx: int = (i - 1 + _tab_buttons.size()) % _tab_buttons.size()
		var next_idx: int = (i + 1) % _tab_buttons.size()
		_tab_buttons[i].focus_neighbor_left   = _tab_buttons[prev_idx].get_path()
		_tab_buttons[i].focus_neighbor_right  = _tab_buttons[next_idx].get_path()
		_tab_buttons[i].focus_neighbor_bottom = btn_close.get_path()
		_tab_buttons[i].focus_next            = _tab_buttons[next_idx].get_path()
		_tab_buttons[i].focus_previous        = _tab_buttons[prev_idx].get_path()
	# Close button Tab-back goes to the last tab button.
	btn_close.focus_neighbor_top = _tab_buttons[_tab_buttons.size() - 1].get_path()
	btn_close.focus_previous     = _tab_buttons[_tab_buttons.size() - 1].get_path()

	# Activate first tab.
	_switch_tab(Tab.CONTROLS)


# ── Tab Switching ─────────────────────────────────────────────────────────────

func _switch_tab(tab: Tab) -> void:
	_current_tab = tab
	for i in _content_boxes.size():
		_content_boxes[i].visible = (i == tab as int)
	for i in _tab_buttons.size():
		_apply_tab_style(_tab_buttons[i], i == tab as int)
	_scroll.scroll_vertical = 0


func _apply_tab_style(btn: Button, active: bool) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = C_TAB_ACTIVE if active else C_TAB_INACTIVE
	s.set_border_width_all(1)
	s.border_color = C_BORDER
	s.set_content_margin_all(6)
	var focus_ring := StyleBoxFlat.new()
	focus_ring.bg_color = Color(0, 0, 0, 0)
	focus_ring.draw_center = false
	focus_ring.set_border_width_all(2)
	focus_ring.border_color = Color(1.00, 0.90, 0.40, 1.0)  # gold focus ring
	btn.add_theme_stylebox_override("normal",  s)
	btn.add_theme_stylebox_override("hover",   s)
	btn.add_theme_stylebox_override("pressed", s)
	btn.add_theme_stylebox_override("focus",   focus_ring)
	btn.add_theme_color_override("font_color", C_TAB_TEXT)
	btn.add_theme_font_size_override("font_size", 13)


# ── Shared UI Helpers ─────────────────────────────────────────────────────────

func _make_heading(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", C_HEADING)
	lbl.custom_minimum_size = Vector2(0, 28)
	return lbl


func _make_body(text: String) -> Label:
	var lbl := Label.new()
	lbl.text                  = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", C_BODY)
	lbl.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return lbl


func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	var s := StyleBoxFlat.new()
	s.bg_color = C_BORDER
	s.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", s)
	return sep


func _make_spacer(h: int = 6) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _make_table_header(col1: String, col2: String) -> PanelContainer:
	return _make_row_impl(col1, col2, C_ROW_HEADER, C_TITLE, C_TITLE)


func _make_table_row(col1: String, col2: String, alt: bool) -> PanelContainer:
	var bg := C_ROW_ALT if alt else Color(0.0, 0.0, 0.0, 0.0)
	return _make_row_impl(col1, col2, bg, C_HEADING, C_BODY)


func _make_row_impl(col1: String, col2: String, bg: Color, c1: Color, c2: Color) -> PanelContainer:
	var row := PanelContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_content_margin_all(4)
	row.add_theme_stylebox_override("panel", s)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)

	var lbl1 := Label.new()
	lbl1.text                  = col1
	lbl1.custom_minimum_size   = Vector2(200, 0)
	lbl1.add_theme_font_size_override("font_size", 12)
	lbl1.add_theme_color_override("font_color", c1)
	hbox.add_child(lbl1)

	var lbl2 := Label.new()
	lbl2.text                  = col2
	lbl2.add_theme_font_size_override("font_size", 12)
	lbl2.add_theme_color_override("font_color", c2)
	lbl2.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	lbl2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(lbl2)

	return row


# ── Tab 1: Controls ───────────────────────────────────────────────────────────

func _build_tab_controls() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	vbox.add_child(_make_heading("Controls & Hotkeys"))
	vbox.add_child(_make_separator())
	vbox.add_child(_make_spacer(4))

	# Camera
	vbox.add_child(_make_table_header("Input", "Camera Action"))
	var cam_rows := [
		["W / Up Arrow",          "Pan camera up"],
		["S / Down Arrow",        "Pan camera down"],
		["A / Left Arrow",        "Pan camera left"],
		["D / Right Arrow",       "Pan camera right"],
		["+ / =",                 "Zoom in"],
		["-",                     "Zoom out"],
		["Middle-mouse drag",     "Pan camera"],
		["Scroll wheel",          "Zoom in / out"],
	]
	for i in cam_rows.size():
		vbox.add_child(_make_table_row(cam_rows[i][0], cam_rows[i][1], i % 2 == 1))

	vbox.add_child(_make_spacer(8))

	# Gameplay
	vbox.add_child(_make_table_header("Input", "Gameplay Action"))
	var gp_rows := [
		["R",                           "Open / close Rumor Crafting panel"],
		["J",                           "Open / close Player Journal"],
		["G",                           "Open / close Social Graph overlay"],
		["Esc",                         "Pause menu (or exit building interior)"],
		["E",                           "Exit building interior"],
		["Left-click NPC",              "View NPC tooltip"],
		["Right-click building",        "Observe — costs 1 Recon Action"],
		["Right-click NPC (in convo)", "Eavesdrop — costs 1 Recon Action"],
		["F11 / Alt+Enter",             "Toggle fullscreen"],
	]
	for i in gp_rows.size():
		vbox.add_child(_make_table_row(gp_rows[i][0], gp_rows[i][1], i % 2 == 1))

	vbox.add_child(_make_spacer(8))

	# Game Speed
	vbox.add_child(_make_table_header("Input", "Game Speed Action"))
	var spd_rows := [
		["Space",  "Toggle pause / resume"],
		["1",      "Set speed to 1× (normal)"],
		["3",      "Set speed to 3× (fast-forward)"],
	]
	for i in spd_rows.size():
		vbox.add_child(_make_table_row(spd_rows[i][0], spd_rows[i][1], i % 2 == 1))

	return vbox


# ── Tab 2: Mechanics ──────────────────────────────────────────────────────────

func _build_tab_mechanics() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	vbox.add_child(_make_heading("Game Mechanics"))
	vbox.add_child(_make_separator())
	vbox.add_child(_make_spacer(4))

	# Core loop
	vbox.add_child(_make_body("Core Loop"))
	vbox.add_child(_make_body("  Observe  →  Gather Intel  →  Craft Rumor  →  Seed Rumor  →  Watch Propagation  →  Monitor Reputation & Heat"))
	vbox.add_child(_make_spacer())

	# Recon
	vbox.add_child(_make_body("Recon"))
	vbox.add_child(_make_body("  • 3 Recon Actions per day. Right-click buildings or conversations to spend them.\n  • 2 Whisper Tokens per day. Consumed when seeding a rumor.\n  • Evidence slots: carry up to 3 items at a time."))
	vbox.add_child(_make_spacer())

	# Rumor Crafting
	vbox.add_child(_make_body("Rumor Crafting"))
	vbox.add_child(_make_body("  Open the Rumor Crafting panel (R) and follow the 3-step flow:\n  1. Subject — who the rumor is about\n  2. Claim — what you are asserting\n  3. Seed Target — the first NPC to tell\n  Attaching Evidence during crafting boosts credibility."))
	vbox.add_child(_make_spacer())

	# Propagation table
	vbox.add_child(_make_body("Rumor Propagation"))
	vbox.add_child(_make_body("  Seeded rumors spread NPC-to-NPC through the social graph. Track via the Social Graph overlay (G)."))
	vbox.add_child(_make_table_header("State", "Meaning"))
	var prop_rows := [
		["○ Unaware",      "NPC has not heard this rumor yet"],
		["◇ Evaluating",   "NPC is deciding whether to believe it"],
		["✓ Believes",     "NPC believes the rumor but is not yet spreading it"],
		["▶ Spreading",    "NPC is actively passing it on"],
		["★ Acting",       "NPC is taking action based on the rumor"],
		["✕ Rejecting",    "NPC heard it but refused to believe it"],
		["⚡ Contradicted", "Conflicting information reached this NPC"],
		["— Expired",      "Rumor has run its natural course"],
		["◆ Defending",    "NPC is actively defending the rumor's target"],
	]
	for i in prop_rows.size():
		vbox.add_child(_make_table_row(prop_rows[i][0], prop_rows[i][1], i % 2 == 1))
	vbox.add_child(_make_spacer())

	# Heat table
	vbox.add_child(_make_body("Heat"))
	vbox.add_child(_make_body("  Each NPC maintains a personal suspicion meter toward you (0–100)."))
	vbox.add_child(_make_table_header("Threshold", "Effect"))
	var heat_rows := [
		["0 – 49",   "NPC behaves normally"],
		["50 – 74",  "NPC becomes guarded; lower receptivity"],
		["75 – 100", "NPC actively resists and may warn allies"],
	]
	for i in heat_rows.size():
		vbox.add_child(_make_table_row(heat_rows[i][0], heat_rows[i][1], i % 2 == 1))

	return vbox


# ── Tab 3: Systems ────────────────────────────────────────────────────────────

func _build_tab_systems() -> VBoxContainer:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	vbox.add_child(_make_heading("Advanced Systems"))
	vbox.add_child(_make_separator())
	vbox.add_child(_make_spacer(4))

	# Evidence
	vbox.add_child(_make_body("Evidence"))
	vbox.add_child(_make_body("  Collect up to 3 evidence items. Each raises rumor credibility when attached during crafting."))
	vbox.add_child(_make_table_header("Item", "Bonus"))
	var ev_rows := [
		["Forged Document",        "Enhances written / authority-based claims"],
		["Incriminating Artifact", "Tangible proof; high base credibility bonus"],
		["Witness Account",        "Third-party corroboration; social bonus"],
	]
	for i in ev_rows.size():
		vbox.add_child(_make_table_row(ev_rows[i][0], ev_rows[i][1], i % 2 == 1))
	vbox.add_child(_make_spacer())

	# Bribery
	vbox.add_child(_make_body("Bribery  (Scenarios 2 & 3 only)"))
	vbox.add_child(_make_body("  2 charges per scenario. Forces a skeptical NPC directly into the Believing state, bypassing evaluation. Charges do not replenish."))
	vbox.add_child(_make_spacer())

	# Counter-Intel
	vbox.add_child(_make_body("Counter-Intelligence"))
	vbox.add_child(_make_body("  High-loyalty NPCs actively defend their allies. Seeding against well-connected targets incurs a −0.15 credulity penalty from those defenders. Check NPC tooltips before seeding to identify potential defenders."))
	vbox.add_child(_make_spacer())

	# Reputation table
	vbox.add_child(_make_body("Reputation"))
	vbox.add_child(_make_body("  Your global reputation starts at 50 and shifts with faction sentiment. Four tiers affect available actions and NPC attitudes."))
	vbox.add_child(_make_table_header("Tier (Range)", "Effect"))
	var rep_rows := [
		["Distinguished (71–100)", "Maximum trust; NPCs highly receptive"],
		["Respected (51–70)",      "Favorable reception"],
		["Suspect (31–50)",        "NPCs are wary; some options closed"],
		["Disgraced (0–30)",       "Active distrust; most NPCs hostile"],
	]
	for i in rep_rows.size():
		vbox.add_child(_make_table_row(rep_rows[i][0], rep_rows[i][1], i % 2 == 1))
	vbox.add_child(_make_spacer())

	# Scenario Objectives
	vbox.add_child(_make_body("Scenario Objectives"))
	vbox.add_child(_make_body("  Each scenario has unique win and fail conditions tied to NPC reputation thresholds or believer counts. Check the Journal (J) → Objectives tab for live progress.\n  • S1: Destroy one reputation  •  S2: Spread a specific rumor widely\n  • S3: Raise one reputation AND ruin another  •  S4: Defend three people (purely defensive)\n  Fail conditions vary: running out of time, being exposed, a key NPC rejecting your rumor, or a protected reputation collapsing."))

	return vbox
