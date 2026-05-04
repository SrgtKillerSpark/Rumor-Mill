extends CanvasLayer

## main_menu.gd — Sprint 8 pre-game UI (SPA-589 redesign).
##
## Lamplighter Square dusk aesthetic with animated whispering figures,
## parchment scroll overlay, and redesigned scenario selection.
##
## Phases:
##   MAIN     — atmospheric title with whispering-figures silhouette effect.
##   SELECT   — scenario cards with difficulty indicator, hook, preview color.
##   BRIEFING — full startingText for the chosen scenario + Begin / Back.
##   INTRO    — atmospheric intro text.
##   SETTINGS / CREDITS / STATS — unchanged.
##
## Emits begin_game(scenario_id) when the player commits to a scenario.
## Wire via setup() from main.gd.

# ── Signals ───────────────────────────────────────────────────────────────────
signal begin_game(scenario_id: String)

# ── Palette (matches end_screen.gd) ──────────────────────────────────────────
const C_BACKDROP     := Color(0.04, 0.02, 0.02, 0.95)
const C_PANEL_BG     := Color(0.13, 0.09, 0.07, 1.0)
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 1.0)
const C_TITLE        := Color(0.92, 0.78, 0.12, 1.0)   # gold
const C_HEADING      := Color(0.91, 0.85, 0.70, 1.0)   # parchment
const C_SUBHEADING   := Color(0.75, 0.65, 0.50, 1.0)
const C_BODY         := Color(0.70, 0.65, 0.55, 1.0)
const C_MUTED        := Color(0.60, 0.53, 0.42, 1.0)
const C_BTN_NORMAL   := Color(0.40, 0.22, 0.08, 1.0)
const C_BTN_HOVER    := Color(0.60, 0.34, 0.12, 1.0)
const C_BTN_TEXT     := Color(0.95, 0.91, 0.80, 1.0)
const C_CARD_BG      := Color(0.10, 0.07, 0.05, 1.0)
const C_CARD_HOVER   := Color(0.18, 0.13, 0.09, 1.0)
const C_CARD_BORDER  := Color(0.45, 0.30, 0.12, 1.0)
const C_CARD_SEL     := Color(0.70, 0.50, 0.15, 1.0)
const C_STAT_LABEL   := Color(0.75, 0.65, 0.50, 1.0)
const C_STAT_VALUE   := Color(0.91, 0.85, 0.70, 1.0)
const C_SCORE_WIN    := Color(0.92, 0.78, 0.12, 1.0)   # gold
const C_SCORE_FAIL   := Color(0.85, 0.18, 0.12, 1.0)   # crimson

# SPA-589: Scenario difficulty band colours (select-phase difficulty badges).
const C_DIFF_EASY    := Color(0.40, 0.75, 0.35, 1.0)   # mossy green
const C_DIFF_MEDIUM  := Color(0.85, 0.70, 0.20, 1.0)   # amber
const C_DIFF_HARD    := Color(0.85, 0.40, 0.15, 1.0)   # burnt orange
const C_DIFF_EXPERT  := Color(0.85, 0.18, 0.12, 1.0)   # crimson

# SPA-589: Atmospheric dusk sky gradient colours.
const C_SKY_TOP      := Color(0.12, 0.06, 0.18, 1.0)   # deep twilight purple
const C_SKY_MID      := Color(0.22, 0.10, 0.08, 1.0)   # dusky red-brown
const C_SKY_BOTTOM   := Color(0.08, 0.05, 0.03, 1.0)   # near-black

# SPA-589: Scenario preview accent colours (left-edge stripe on scenario cards).
const SCENARIO_ACCENT := {
	"scenario_1": Color(0.40, 0.75, 0.35, 1.0),   # mossy green — introductory
	"scenario_2": Color(0.85, 0.70, 0.20, 1.0),   # amber — moderate
	"scenario_3": Color(0.85, 0.40, 0.15, 1.0),   # burnt orange — challenging
	"scenario_4": Color(0.85, 0.18, 0.12, 1.0),   # crimson — expert
	"scenario_5": Color(0.70, 0.20, 0.50, 1.0),   # deep purple — advanced
	"scenario_6": Color(0.55, 0.12, 0.55, 1.0),   # dark magenta — master
}

# SPA-589: Human-readable difficulty labels per scenario.
const SCENARIO_DIFFICULTY := {
	"scenario_1": "Introductory",
	"scenario_2": "Moderate",
	"scenario_3": "Challenging",
	"scenario_4": "Expert",
	"scenario_5": "Advanced",
	"scenario_6": "Master",
}

# SPA-806: One-line difficulty descriptors shown below the difficulty badge.
const SCENARIO_DESCRIPTOR := {
	"scenario_1": "Single target, generous timeline. Learn the basics.",
	"scenario_2": "New mechanic: epidemic spread. One NPC can end your run.",
	"scenario_3": "Two targets + a rival agent working against you.",
	"scenario_4": "Pure defense — protect three allies from escalating attacks.",
	"scenario_5": "Three-way race with a timed endorsement event.",
	"scenario_6": "Stealth mode — guards are on the enemy payroll.",
}

# SPA-1669 #11: Responsive panel sizing — min/max pixel bounds and viewport
# fractions.  Each call site computes actual w/h via
# UILayoutConstants.clamp_to_viewport() before passing to _make_*_panel().
const MAIN_PANEL_MIN_W    := 340;  const MAIN_PANEL_MAX_W    := 440
const MAIN_PANEL_MIN_H    := 480;  const MAIN_PANEL_MAX_H    := 600
const MAIN_PANEL_VP_W     := 0.35; const MAIN_PANEL_VP_H     := 0.83

const WIDE_PANEL_MIN_W    := 500;  const WIDE_PANEL_MAX_W    := 700
const WIDE_PANEL_MIN_H    := 400;  const WIDE_PANEL_MAX_H    := 520
const WIDE_PANEL_VP_W     := 0.55; const WIDE_PANEL_VP_H     := 0.72

const MED_PANEL_MIN_W     := 380;  const MED_PANEL_MAX_W     := 600
const MED_PANEL_MIN_H     := 400;  const MED_PANEL_MAX_H     := 580
const MED_PANEL_VP_W      := 0.47; const MED_PANEL_VP_H      := 0.81

const NARROW_PANEL_MIN_W  := 360;  const NARROW_PANEL_MAX_W  := 480
const NARROW_PANEL_MIN_H  := 380;  const NARROW_PANEL_MAX_H  := 580
const NARROW_PANEL_VP_W   := 0.38; const NARROW_PANEL_VP_H   := 0.81

const STATS_PANEL_MIN_W   := 480;  const STATS_PANEL_MAX_W   := 680
const STATS_PANEL_MIN_H   := 400;  const STATS_PANEL_MAX_H   := 520
const STATS_PANEL_VP_W    := 0.53; const STATS_PANEL_VP_H    := 0.72

enum Phase { MAIN, SELECT, BRIEFING, INTRO, SETTINGS, CREDITS, STATS }

# ── State ─────────────────────────────────────────────────────────────────────
var _phase:              Phase     = Phase.MAIN
var _scenarios:          Array     = []   # parsed from scenarios.json
var _selected_scenario:  Dictionary = {}  # currently highlighted scenario data

# ── Node refs ─────────────────────────────────────────────────────────────────
var _backdrop:           ColorRect  = null
var _panel_main:         Control    = null
var _panel_select:       Control    = null
var _panel_briefing:     Control    = null

# Select-phase refs
var _scenario_cards:     Array      = []  # Array[PanelContainer]
var _selected_card_idx:  int        = -1

# HowToPlay overlay ref
var _how_to_play:        CanvasLayer = null

# Continue button (disabled when no saves exist)
var _btn_continue:       Button      = null

# SPA-589: Atmospheric dusk background elements
var _dusk_sky:           ColorRect   = null  # gradient sky background
var _silhouettes:        Array       = []    # whispering figure silhouettes (Array[ColorRect])
var _silhouette_anchors: Array       = []    # original [left, right] anchors per silhouette
var _silhouette_phase:   float       = 0.0   # animation timer for figure sway
var _fog_overlay:        ColorRect   = null  # subtle ground fog
var _lantern_glow:       ColorRect   = null  # warm lantern point-light effect

# Settings-phase refs
var _panel_settings:     Control    = null

# Credits-phase refs
var _panel_credits:      Control    = null
var _version_label:      Label      = null

# Stats-phase refs
var _panel_stats:        Control    = null
var _lbl_music_val:      Label      = null
var _lbl_ambient_val:    Label      = null
var _lbl_sfx_val:        Label      = null
var _lbl_speed_val:      Label      = null
var _btn_resolution:     Button     = null
var _btn_window_mode:    Button     = null
var _btn_ui_scale:       Button     = null

# Briefing-phase refs
var _briefing_title:     Label      = null
var _briefing_days:      Label      = null
var _briefing_body:      RichTextLabel = null
var _btn_begin:          Button     = null
var _briefing_objective: RichTextLabel = null
var _briefing_portrait_frame: Panel = null  # SPA-806: target portrait in objective card
var _difficulty_buttons: Dictionary = {}   # preset_id → Button

# Intro-phase refs
var _panel_intro:        Control    = null
var _intro_title:        Label      = null
var _intro_body:         RichTextLabel = null


func _ready() -> void:
	layer = 50
	_load_scenarios()
	_build_backdrop()
	_build_main_panel()
	_build_select_panel()
	_build_briefing_panel()
	_build_intro_panel()
	_build_settings_panel()
	_build_credits_panel()
	_build_stats_panel()
	_build_version_label()
	_how_to_play = preload("res://scripts/how_to_play.gd").new()
	_how_to_play.name = "HowToPlay"
	add_child(_how_to_play)
	_show_phase(Phase.MAIN)


## Load scenario metadata from scenarios.json.
func _load_scenarios() -> void:
	var file := FileAccess.open("res://data/scenarios.json", FileAccess.READ)
	if file == null:
		push_error("MainMenu: cannot open scenarios.json")
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		_scenarios = parsed
	else:
		push_error("MainMenu: failed to parse scenarios.json")


## Returns true if the scenario at index idx is locked.
## Lock rule: each scenario requires the previous one to be completed.
## scenario_1 (idx 0) is always unlocked.
func _is_scenario_locked(idx: int) -> bool:
	if idx <= 0 or idx >= _scenarios.size():
		return false
	var prev_sc: Dictionary = _scenarios[idx - 1]
	var prev_id: String = prev_sc.get("scenarioId", "")
	return not ProgressData.is_completed(prev_id)


## Returns the title of the scenario that must be completed to unlock idx.
func _unlock_requires_title(idx: int) -> String:
	if idx <= 0 or idx >= _scenarios.size():
		return ""
	return _scenarios[idx - 1].get("title", "the previous scenario")


# ── Phase switching ───────────────────────────────────────────────────────────

## SPA-561: Active crossfade tween for phase transitions.
var _phase_tween: Tween = null

func _show_phase(p: Phase) -> void:
	var old_phase := _phase
	_phase = p

	# Map phases to their panel nodes.
	var panels: Dictionary = {
		Phase.MAIN:     _panel_main,
		Phase.SELECT:   _panel_select,
		Phase.BRIEFING: _panel_briefing,
		Phase.INTRO:    _panel_intro,
		Phase.SETTINGS: _panel_settings,
		Phase.CREDITS:  _panel_credits,
		Phase.STATS:    _panel_stats,
	}

	# Determine outgoing and incoming panels.
	var outgoing: Control = panels.get(old_phase)
	var incoming: Control = panels.get(p)

	# Kill any in-progress phase tween.
	if _phase_tween != null and _phase_tween.is_valid():
		_phase_tween.kill()

	# Hide all panels except outgoing (which we'll fade out) and incoming.
	for phase_key in panels:
		var panel: Control = panels[phase_key]
		if panel == null:
			continue
		if phase_key != old_phase and phase_key != p:
			panel.visible = false

	# SPA-561: Crossfade between panels (0.2s total).
	if outgoing != null and incoming != null and outgoing != incoming:
		incoming.visible = true
		incoming.modulate.a = 0.0
		_phase_tween = create_tween().set_parallel(true) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_phase_tween.tween_property(outgoing, "modulate:a", 0.0, 0.15)
		_phase_tween.tween_property(incoming, "modulate:a", 1.0, 0.2)
		_phase_tween.chain().tween_callback(func() -> void:
			outgoing.visible = false
			outgoing.modulate.a = 1.0
		)
	else:
		# First show or same panel — just make visible instantly.
		for phase_key in panels:
			var panel: Control = panels[phase_key]
			if panel == null:
				continue
			panel.visible = (phase_key == p)
			panel.modulate.a = 1.0

	# Rebuild stats panel content each time it's shown so it reflects latest data.
	if p == Phase.STATS:
		_rebuild_stats_content()
	# Set initial keyboard focus for the active phase.
	call_deferred("_set_phase_focus", p)


## Assigns keyboard focus to the first interactive element in the active phase.
func _set_phase_focus(p: Phase) -> void:
	match p:
		Phase.MAIN:
			_grab_first_button(_panel_main)
		Phase.SELECT:
			_grab_first_button(_panel_select)
		Phase.BRIEFING:
			if _btn_begin != null:
				_btn_begin.grab_focus()
		Phase.INTRO:
			_grab_first_button(_panel_intro)
		Phase.SETTINGS:
			_grab_first_button(_panel_settings)
		Phase.CREDITS:
			_grab_first_button(_panel_credits)
		Phase.STATS:
			_grab_first_button(_panel_stats)


## Finds and focuses the first Button descendant of the given node.
func _grab_first_button(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			child.grab_focus()
			return
		_grab_first_button(child)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			match _phase:
				Phase.SELECT:
					_on_select_back()
					get_viewport().set_input_as_handled()
				Phase.BRIEFING:
					_on_briefing_back()
					get_viewport().set_input_as_handled()
				Phase.INTRO:
					_on_intro_back()
					get_viewport().set_input_as_handled()
				Phase.SETTINGS:
					_on_settings_back()
					get_viewport().set_input_as_handled()
				Phase.CREDITS:
					_on_credits_back()
					get_viewport().set_input_as_handled()
				Phase.STATS:
					_on_stats_back()
					get_viewport().set_input_as_handled()


# ── Backdrop ──────────────────────────────────────────────────────────────────

func _build_backdrop() -> void:
	# SPA-589: Lamplighter Square dusk atmosphere — dark sky with warm accents.
	_backdrop = ColorRect.new()
	_backdrop.color = C_SKY_TOP
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	# Lower-half gradient strip — simulates dusk horizon glow.
	_dusk_sky = ColorRect.new()
	_dusk_sky.color = C_SKY_MID
	_dusk_sky.set_anchor(SIDE_LEFT,   0.0)
	_dusk_sky.set_anchor(SIDE_RIGHT,  1.0)
	_dusk_sky.set_anchor(SIDE_TOP,    0.55)
	_dusk_sky.set_anchor(SIDE_BOTTOM, 1.0)
	_dusk_sky.modulate.a = 0.6
	add_child(_dusk_sky)

	# Ground fog — subtle warm haze at the bottom.
	_fog_overlay = ColorRect.new()
	_fog_overlay.color = Color(0.15, 0.10, 0.06, 0.35)
	_fog_overlay.set_anchor(SIDE_LEFT,   0.0)
	_fog_overlay.set_anchor(SIDE_RIGHT,  1.0)
	_fog_overlay.set_anchor(SIDE_TOP,    0.78)
	_fog_overlay.set_anchor(SIDE_BOTTOM, 1.0)
	add_child(_fog_overlay)

	# Warm lantern glow — a soft radial highlight at centre-bottom.
	_lantern_glow = ColorRect.new()
	_lantern_glow.color = Color(0.95, 0.65, 0.20, 0.08)
	_lantern_glow.set_anchor(SIDE_LEFT,   0.25)
	_lantern_glow.set_anchor(SIDE_RIGHT,  0.75)
	_lantern_glow.set_anchor(SIDE_TOP,    0.40)
	_lantern_glow.set_anchor(SIDE_BOTTOM, 0.90)
	add_child(_lantern_glow)

	# SPA-589: Whispering figure silhouettes — dark shapes at the bottom edges.
	_build_silhouettes()


# ── SPA-589: Whispering figure silhouettes ────────────────────────────────────

## Build 4-6 abstract figure silhouettes along the bottom of the screen.
## Each is a narrow dark rectangle with varying height — representing
## hooded/cloaked figures standing in the dusk.
func _build_silhouettes() -> void:
	_silhouettes.clear()
	_silhouette_anchors.clear()
	# Positions and heights for silhouettes (normalised anchor coords).
	# Each: [left_anchor, right_anchor, height_frac, alpha]
	var figures: Array = [
		[0.04, 0.07, 0.28, 0.45],   # far left, tall
		[0.10, 0.12, 0.22, 0.30],   # left, medium
		[0.14, 0.17, 0.25, 0.38],   # left-centre, tall
		[0.83, 0.86, 0.26, 0.40],   # right-centre, tall
		[0.88, 0.90, 0.20, 0.28],   # right, short
		[0.93, 0.96, 0.24, 0.35],   # far right, medium
	]
	for f in figures:
		var fig := ColorRect.new()
		fig.color = Color(0.02, 0.01, 0.01, f[3])
		fig.set_anchor(SIDE_LEFT,   f[0])
		fig.set_anchor(SIDE_RIGHT,  f[1])
		fig.set_anchor(SIDE_TOP,    1.0 - f[2])
		fig.set_anchor(SIDE_BOTTOM, 1.0)
		add_child(fig)
		_silhouettes.append(fig)
		_silhouette_anchors.append([f[0], f[1]])


## Animate whispering figures with subtle sway and opacity pulsing.
func _process(delta: float) -> void:
	if not visible:
		return
	_silhouette_phase += delta * 0.4
	for i in _silhouettes.size():
		var fig: ColorRect = _silhouettes[i]
		# Each figure sways at a slightly different phase.
		var phase_offset: float = float(i) * 1.3
		var sway: float = sin(_silhouette_phase + phase_offset) * 0.003
		var orig: Array = _silhouette_anchors[i]
		fig.set_anchor(SIDE_LEFT,  orig[0] + sway)
		fig.set_anchor(SIDE_RIGHT, orig[1] + sway)
		# Subtle opacity pulse (breathing effect).
		var alpha_base: float = fig.color.a
		var pulse: float = sin(_silhouette_phase * 0.8 + phase_offset) * 0.04
		fig.modulate.a = clampf(1.0 + pulse, 0.7, 1.3)


# ── Phase 1: Main Menu panel ──────────────────────────────────────────────────

func _build_main_panel() -> void:
	# SPA-685 / SPA-1669 #11: Responsive parchment scroll.
	var vp := get_viewport().get_visible_rect().size
	var pw := UILayoutConstants.clamp_to_viewport(vp.x, MAIN_PANEL_VP_W, MAIN_PANEL_MIN_W, MAIN_PANEL_MAX_W)
	var ph := UILayoutConstants.clamp_to_viewport(vp.y, MAIN_PANEL_VP_H, MAIN_PANEL_MIN_H, MAIN_PANEL_MAX_H)
	_panel_main = _make_parchment_panel(pw, ph)
	add_child(_panel_main)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_main.add_child(vbox)

	# SPA-1099: Top expand-fill spacer — absorbs vertical space symmetrically
	# with spacer_bottom so content is centered inside the full-rect VBox.
	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_top)

	# SPA-685: Top decorative flourish — ornamental manuscript border.
	var top_flourish := _make_manuscript_flourish()
	vbox.add_child(top_flourish)

	# SPA-685: Medieval manuscript title — larger, with decorative framing.
	var title := Label.new()
	title.text = "RUMOR MILL"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(title)

	# SPA-685: Decorative dash separator below title (manuscript style).
	var title_sep := Label.new()
	title_sep.text = "\u2014  \u273D  \u2014"
	title_sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_sep.add_theme_font_size_override("font_size", 14)
	title_sep.add_theme_color_override("font_color", Color(0.75, 0.55, 0.20, 0.70))
	vbox.add_child(title_sep)

	# SPA-685: Atmospheric subtitle referencing Lamplighter Square.
	var tagline := Label.new()
	tagline.text = "Whispers in the Lamplighter\u2019s Square"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 14)
	tagline.add_theme_color_override("font_color", C_SUBHEADING)
	vbox.add_child(tagline)

	var subtitle := Label.new()
	subtitle.text = "A medieval rumor-spreading social simulation"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(subtitle)

	# SPA-685: Bottom decorative flourish.
	var bot_flourish := _make_manuscript_flourish()
	vbox.add_child(bot_flourish)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	vbox.add_child(spacer)

	# SPA-685: Buttons — New Game / Continue / How to Play / Settings / Credits / Statistics / Quit
	var btn_row := VBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 10)
	vbox.add_child(btn_row)

	var btn_new_game := _make_button("New Game", 200)
	btn_new_game.pressed.connect(_on_play_pressed)
	btn_row.add_child(btn_new_game)

	# SPA-685: Continue — loads the most recent save across all scenarios.
	_btn_continue = _make_button("Continue", 200)
	_btn_continue.pressed.connect(_on_continue_pressed)
	btn_row.add_child(_btn_continue)
	_refresh_continue_button()

	var btn_howto := _make_button("How to Play", 200)
	btn_howto.pressed.connect(_on_how_to_play_pressed)
	btn_row.add_child(btn_howto)

	var btn_settings := _make_button("Settings", 200)
	btn_settings.pressed.connect(_on_settings_pressed)
	btn_row.add_child(btn_settings)

	var btn_credits := _make_button("Credits", 200)
	btn_credits.pressed.connect(_on_credits_pressed)
	btn_row.add_child(btn_credits)

	var btn_stats := _make_button("Statistics", 200)
	btn_stats.pressed.connect(_on_stats_pressed)
	btn_row.add_child(btn_stats)

	if not OS.has_feature("web"):
		var btn_quit := _make_button("Quit", 200)
		btn_quit.pressed.connect(get_tree().quit)
		btn_row.add_child(btn_quit)

	# SPA-1099: Bottom expand-fill spacer — mirrors spacer_top to center
	# all content vertically within the full-rect VBox.
	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bottom)


# ── Phase 2: Scenario Select panel ───────────────────────────────────────────

func _build_select_panel() -> void:
	var vps := get_viewport().get_visible_rect().size
	var sw := UILayoutConstants.clamp_to_viewport(vps.x, WIDE_PANEL_VP_W, WIDE_PANEL_MIN_W, WIDE_PANEL_MAX_W)
	var sh := UILayoutConstants.clamp_to_viewport(vps.y, WIDE_PANEL_VP_H, WIDE_PANEL_MIN_H, WIDE_PANEL_MAX_H)
	_panel_select = _make_parchment_panel(sw, sh)
	add_child(_panel_select)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_select.add_child(vbox)

	# Heading
	var heading := Label.new()
	heading.text = "Choose Your Assignment"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", C_HEADING)
	vbox.add_child(heading)

	# SPA-589: Subheading with flavour text.
	var sub := Label.new()
	sub.text = "Each assignment tests a different facet of the whispersmith's art."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(sub)

	vbox.add_child(_separator())

	# Scenario cards — wrapped in a ScrollContainer so they don't overflow at 1280×720 (SPA-1109).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	var cards_vbox := VBoxContainer.new()
	cards_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(cards_vbox)

	_scenario_cards.clear()
	for i in _scenarios.size():
		var sc: Dictionary = _scenarios[i]
		var card := _build_scenario_card(sc, i)
		cards_vbox.add_child(card)
		_scenario_cards.append(card)

	# SPA-1636: Wire focus_neighbor between card overlay buttons for keyboard nav.
	# Cards are already in the tree (panel added at line 513), so get_path() is safe.
	_wire_scenario_card_focus()

	vbox.add_child(_separator())

	# Bottom row: Back + Next
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var btn_back := _make_button("Back", 140)
	btn_back.pressed.connect(_on_select_back)
	btn_row.add_child(btn_back)

	var btn_next := _make_button("Next", 140)
	btn_next.pressed.connect(_on_select_next)
	btn_row.add_child(btn_next)


func _build_scenario_card(sc: Dictionary, idx: int) -> PanelContainer:
	var locked: bool = _is_scenario_locked(idx)
	var sc_id: String = sc.get("scenarioId", "")

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 90)

	# SPA-589: Card style with left accent stripe matching scenario difficulty.
	var accent_color: Color = SCENARIO_ACCENT.get(sc_id, C_CARD_BORDER)
	var style_normal := _scenario_card_style(C_CARD_BG, C_CARD_BORDER, accent_color)
	var style_hover  := _scenario_card_style(C_CARD_HOVER, C_CARD_BORDER, accent_color)
	card.add_theme_stylebox_override("panel", style_normal)
	card.set_meta("style_normal", style_normal)
	card.set_meta("style_hover",  style_hover)
	card.set_meta("scenario_idx", idx)
	card.set_meta("locked", locked)

	# Make it mouse-interactive via a Button overlay
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover",  StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var _card_focus_ring := StyleBoxFlat.new()
	_card_focus_ring.bg_color     = Color(0, 0, 0, 0)
	_card_focus_ring.draw_center  = false
	_card_focus_ring.set_border_width_all(2)
	_card_focus_ring.border_color = Color(1.00, 0.90, 0.40, 1.0)
	btn.add_theme_stylebox_override("focus", _card_focus_ring)
	btn.pressed.connect(_on_card_pressed.bind(idx))
	btn.mouse_entered.connect(_on_card_hover.bind(card, true))
	btn.mouse_exited.connect(_on_card_hover.bind(card, false))

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)

	# SPA-589: Title row with difficulty badge.
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

	# SPA-589: Difficulty badge — coloured label right-aligned.
	var diff_text: String = SCENARIO_DIFFICULTY.get(sc_id, "")
	if diff_text != "":
		var diff_badge := Label.new()
		diff_badge.text = diff_text
		diff_badge.add_theme_font_size_override("font_size", 12)
		diff_badge.add_theme_color_override("font_color", accent_color if not locked else C_MUTED)
		title_row.add_child(diff_badge)

	# Days label — replaced with lock message when locked.
	var days_lbl := Label.new()
	if locked:
		days_lbl.text = "Locked"
	else:
		days_lbl.text = "%d days" % int(sc.get("daysAllowed", 30))
	days_lbl.add_theme_font_size_override("font_size", 12)
	days_lbl.add_theme_color_override("font_color", C_MUTED)
	title_row.add_child(days_lbl)

	inner.add_child(title_row)

	# SPA-589: Hook text — italic 1-sentence pitch for the scenario.
	var teaser: String = sc.get("hookText", "")
	if teaser == "":
		var full_text: String = sc.get("startingText", "")
		teaser = full_text.split("\n")[0] if "\n" in full_text else full_text
	if teaser.length() > 180:
		teaser = teaser.substr(0, 177) + "..."

	var desc_rtl := RichTextLabel.new()
	desc_rtl.bbcode_enabled = true
	desc_rtl.text = "[i]%s[/i]" % teaser if not locked else teaser
	desc_rtl.fit_content = true
	desc_rtl.scroll_active = false
	desc_rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_rtl.add_theme_font_size_override("normal_font_size", 12)
	desc_rtl.add_theme_color_override("default_color", C_MUTED if locked else C_BODY)
	inner.add_child(desc_rtl)

	# SPA-806: Difficulty descriptor — one-line summary below the hook text.
	var descriptor: String = SCENARIO_DESCRIPTOR.get(sc_id, "")
	if descriptor != "" and not locked:
		var desc_lbl := Label.new()
		desc_lbl.text = descriptor
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", accent_color.lerp(C_MUTED, 0.35))
		inner.add_child(desc_lbl)

	# Locked message row — hidden until the card is pressed while locked.
	if locked:
		var lock_row := HBoxContainer.new()
		lock_row.visible = false
		lock_row.name = "LockMessageRow"
		lock_row.add_theme_constant_override("separation", 8)

		var lock_msg := Label.new()
		lock_msg.text = "Complete \"%s\" to unlock." % _unlock_requires_title(idx)
		lock_msg.add_theme_font_size_override("font_size", 12)
		lock_msg.add_theme_color_override("font_color", C_MUTED)
		lock_row.add_child(lock_msg)

		var play_anyway := Button.new()
		play_anyway.text = "Play anyway \u2192"
		play_anyway.flat = true
		play_anyway.add_theme_font_size_override("font_size", 12)
		play_anyway.add_theme_color_override("font_color", C_MUTED)
		play_anyway.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		play_anyway.add_theme_stylebox_override("hover",  StyleBoxEmpty.new())
		play_anyway.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		play_anyway.pressed.connect(_on_play_anyway_pressed.bind(idx))
		lock_row.add_child(play_anyway)

		inner.add_child(lock_row)

	card.add_child(inner)
	card.add_child(btn)  # overlay last so it captures mouse events
	return card


## SPA-1636: Wire focus_neighbor on scenario card overlay buttons so keyboard
## navigation (up/down arrows) cycles through all cards correctly.
func _wire_scenario_card_focus() -> void:
	if _scenario_cards.size() < 2:
		return
	for i in _scenario_cards.size():
		var card: PanelContainer = _scenario_cards[i]
		# The overlay Button is the last child of each card (added after inner VBox).
		var btn: Button = card.get_child(card.get_child_count() - 1) as Button
		if btn == null:
			continue
		var prev_idx: int = (i - 1) % _scenario_cards.size()
		var next_idx: int = (i + 1) % _scenario_cards.size()
		var prev_card: PanelContainer = _scenario_cards[prev_idx]
		var next_card: PanelContainer = _scenario_cards[next_idx]
		var prev_btn: Button = prev_card.get_child(prev_card.get_child_count() - 1) as Button
		var next_btn: Button = next_card.get_child(next_card.get_child_count() - 1) as Button
		if prev_btn:
			btn.focus_neighbor_top = prev_btn.get_path()
		if next_btn:
			btn.focus_neighbor_bottom = next_btn.get_path()


## SPA-589: Card style with a coloured left accent stripe for scenario difficulty.
func _scenario_card_style(bg: Color, border: Color, accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = border
	s.set_border_width_all(1)
	# Left border is the accent colour, wider for visual emphasis.
	s.border_width_left = 4
	s.set_content_margin_all(10)
	s.content_margin_left = 14  # extra padding after accent stripe
	# Use the accent colour on the left edge by blending it into the border.
	# StyleBoxFlat doesn't support per-side colours, so we use the main border
	# and rely on the wider left width to make it prominent. For true accent,
	# the accent colour is used when creating the selected variant.
	return s


func _on_card_hover(card: PanelContainer, entering: bool) -> void:
	var idx: int = card.get_meta("scenario_idx", -1)
	if idx == _selected_card_idx:
		return  # keep selected style
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
		# Show the lock message row; hide others.
		for i in _scenario_cards.size():
			var c: PanelContainer = _scenario_cards[i]
			var row = c.find_child("LockMessageRow", true, false)
			if row != null:
				row.visible = (i == idx)
		return

	# Deselect previous
	if _selected_card_idx >= 0 and _selected_card_idx < _scenario_cards.size():
		var prev: PanelContainer = _scenario_cards[_selected_card_idx]
		prev.add_theme_stylebox_override("panel", prev.get_meta("style_normal"))

	_selected_card_idx = idx
	card.add_theme_stylebox_override("panel", _card_style(C_CARD_HOVER, C_CARD_SEL))
	_selected_scenario = _scenarios[idx]
	AudioManager.play_sfx("ui_click")


## Called when the player clicks "Play anyway →" on a locked scenario card.
func _on_play_anyway_pressed(idx: int) -> void:
	if idx < 0 or idx >= _scenario_cards.size() or idx >= _scenarios.size():
		return
	# Bypass the lock and treat the card as selected.
	if _selected_card_idx >= 0 and _selected_card_idx < _scenario_cards.size():
		var prev: PanelContainer = _scenario_cards[_selected_card_idx]
		prev.add_theme_stylebox_override("panel", prev.get_meta("style_normal"))

	_selected_card_idx = idx
	var card: PanelContainer = _scenario_cards[idx]
	card.add_theme_stylebox_override("panel", _card_style(C_CARD_HOVER, C_CARD_SEL))
	_selected_scenario = _scenarios[idx]
	_populate_briefing()
	_show_phase(Phase.BRIEFING)


# ── Phase 3: Briefing panel ───────────────────────────────────────────────────

func _build_briefing_panel() -> void:
	var vpb := get_viewport().get_visible_rect().size
	var bw := UILayoutConstants.clamp_to_viewport(vpb.x, MED_PANEL_VP_W, MED_PANEL_MIN_W, MED_PANEL_MAX_W)
	var bh := UILayoutConstants.clamp_to_viewport(vpb.y, MED_PANEL_VP_H, MED_PANEL_MIN_H, MED_PANEL_MAX_H)
	_panel_briefing = _make_panel(bw, bh)
	add_child(_panel_briefing)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_briefing.add_child(vbox)

	# Title row
	_briefing_title = Label.new()
	_briefing_title.text = ""
	_briefing_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_briefing_title.add_theme_font_size_override("font_size", 20)
	_briefing_title.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(_briefing_title)

	_briefing_days = Label.new()
	_briefing_days.text = ""
	_briefing_days.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_briefing_days.add_theme_font_size_override("font_size", 12)
	_briefing_days.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(_briefing_days)

	vbox.add_child(_separator())

	# Briefing body
	_briefing_body = RichTextLabel.new()
	_briefing_body.custom_minimum_size = Vector2(0, 140)
	_briefing_body.fit_content = false
	_briefing_body.scroll_active = true
	_briefing_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_body.add_theme_font_size_override("normal_font_size", 13)
	_briefing_body.add_theme_color_override("default_color", C_BODY)
	vbox.add_child(_briefing_body)

	vbox.add_child(_separator())

	# SPA-806: Objective card with optional target portrait.
	var obj_row := HBoxContainer.new()
	obj_row.add_theme_constant_override("separation", 10)

	# Portrait frame (hidden by default; shown when target NPC exists).
	_briefing_portrait_frame = Panel.new()
	_briefing_portrait_frame.custom_minimum_size = Vector2(64, 96)
	var pf_style := StyleBoxFlat.new()
	pf_style.bg_color = Color(0.05, 0.04, 0.03, 1.0)
	pf_style.border_color = C_CARD_BORDER
	pf_style.set_border_width_all(1)
	pf_style.set_corner_radius_all(4)
	pf_style.set_content_margin_all(0)
	_briefing_portrait_frame.add_theme_stylebox_override("panel", pf_style)
	_briefing_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_briefing_portrait_frame.visible = false
	obj_row.add_child(_briefing_portrait_frame)

	_briefing_objective = RichTextLabel.new()
	_briefing_objective.custom_minimum_size = Vector2(0, 100)
	_briefing_objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_briefing_objective.fit_content = false
	_briefing_objective.scroll_active = true
	_briefing_objective.bbcode_enabled = true
	_briefing_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_objective.add_theme_font_size_override("normal_font_size", 12)
	_briefing_objective.add_theme_color_override("default_color", C_HEADING)
	obj_row.add_child(_briefing_objective)

	vbox.add_child(obj_row)

	vbox.add_child(_separator())

	# Difficulty selector row
	var diff_label := Label.new()
	diff_label.text = "Difficulty"
	diff_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_label.add_theme_font_size_override("font_size", 12)
	diff_label.add_theme_color_override("font_color", C_MUTED)
	vbox.add_child(diff_label)

	var diff_row := HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 8)
	vbox.add_child(diff_row)

	for preset in ["apprentice", "master", "spymaster"]:
		var lbl: String = preset.capitalize()
		var btn := _make_button(lbl, 120)
		btn.pressed.connect(_on_difficulty_pressed.bind(preset))
		diff_row.add_child(btn)
		_difficulty_buttons[preset] = btn

	_refresh_difficulty_buttons()

	vbox.add_child(_separator())

	# Button row
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var btn_back := _make_button("Back", 140)
	btn_back.pressed.connect(_on_briefing_back)
	btn_row.add_child(btn_back)

	_btn_begin = _make_button("Next", 140)
	_btn_begin.pressed.connect(_on_briefing_next_pressed)
	btn_row.add_child(_btn_begin)


func _populate_briefing() -> void:
	_briefing_title.text = _selected_scenario.get("title", "")
	_update_briefing_days()
	_briefing_body.text = _selected_scenario.get("startingText", "")
	_populate_objective_card()


func _populate_objective_card() -> void:
	if _briefing_objective == null:
		return
	var card: Dictionary = _selected_scenario.get("objectiveCard", {})
	if card.is_empty():
		_briefing_objective.text = ""
		if _briefing_portrait_frame != null:
			_briefing_portrait_frame.visible = false
		return
	var bbcode: String = "[b][color=#ebc80c]YOUR MISSION:[/color][/b] %s\n" % card.get("mission", "")
	bbcode += "[b]Goal:[/b] %s\n" % card.get("winCondition", "")
	bbcode += "[b]Time:[/b] %s\n" % card.get("timeLimit", "")
	bbcode += "[color=#d94030][b]DANGER:[/b] %s[/color]\n" % card.get("danger", "")
	bbcode += "[color=#b5a664][b]Hint:[/b] %s[/color]\n" % card.get("strategyHint", "")
	var first_action: String = card.get("firstAction", "")
	if first_action != "":
		bbcode += "\n[color=#f4a63a][b]YOUR FIRST MOVE:[/b] %s[/color]" % first_action
	_briefing_objective.text = bbcode

	# SPA-806: Show target portrait next to mission card.
	_populate_briefing_portrait()


# SPA-806: Sprite sheet constants (mirrors strategic_overview.gd / npc.gd).
const _PORTRAIT_SPRITE_W := 64
const _PORTRAIT_SPRITE_H := 96
const _PORTRAIT_IDLE_S_COL := 0
const _PORTRAIT_FACTION_ROW := {"merchant": 0, "noble": 1, "clergy": 2}
const _PORTRAIT_ARCHETYPE_ROW := {
	"guard_civic": 3, "tavern_staff": 5, "scholar": 6, "elder": 7, "spy": 8,
}
const _PORTRAIT_COMMONER_ROLES := [
	"Craftsman", "Mill Operator", "Storage Keeper", "Transport Worker",
	"Merchant's Wife", "Traveling Merchant",
]
const _PORTRAIT_BODY_ROW_OFFSET := 9
const _PORTRAIT_CLOTHING_BASE := {"merchant": 27, "noble": 30, "clergy": 33}


func _populate_briefing_portrait() -> void:
	if _briefing_portrait_frame == null:
		return
	# Clear previous portrait children.
	for child in _briefing_portrait_frame.get_children():
		child.queue_free()

	var brief: Dictionary = _selected_scenario.get("strategicBrief", {})
	var target_id: String = brief.get("targetNpcId", "")
	if target_id == "":
		_briefing_portrait_frame.visible = false
		return

	# Look up NPC data from npcs.json (already loaded by _load_scenarios).
	var npc: Dictionary = _find_npc_data(target_id)
	if npc.is_empty():
		_briefing_portrait_frame.visible = false
		return

	var npc_texture: Texture2D = load("res://assets/textures/npc_sprites.png")
	if npc_texture == null:
		_briefing_portrait_frame.visible = false
		return

	var faction:      String = npc.get("faction", "merchant")
	var archetype:    String = npc.get("archetype", "")
	var role:         String = npc.get("role", "")
	var body_type:    int    = clampi(int(npc.get("body_type", 0)), 0, 2)
	var clothing_var: int    = clampi(int(npc.get("clothing_var", 0)), 0, 3)
	var row: int = 0

	if _PORTRAIT_ARCHETYPE_ROW.has(archetype):
		row = _PORTRAIT_ARCHETYPE_ROW[archetype] + body_type * _PORTRAIT_BODY_ROW_OFFSET
	elif role in _PORTRAIT_COMMONER_ROLES:
		row = 4 + body_type * _PORTRAIT_BODY_ROW_OFFSET
	elif clothing_var > 0 and _PORTRAIT_CLOTHING_BASE.has(faction):
		row = _PORTRAIT_CLOTHING_BASE[faction] + (clothing_var - 1)
	else:
		row = _PORTRAIT_FACTION_ROW.get(faction, 0) + body_type * _PORTRAIT_BODY_ROW_OFFSET

	var region := Rect2(
		float(_PORTRAIT_IDLE_S_COL * _PORTRAIT_SPRITE_W),
		float(row * _PORTRAIT_SPRITE_H),
		float(_PORTRAIT_SPRITE_W),
		float(_PORTRAIT_SPRITE_H)
	)
	var atlas := AtlasTexture.new()
	atlas.atlas  = npc_texture
	atlas.region = region

	var portrait := TextureRect.new()
	portrait.texture      = atlas
	portrait.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_briefing_portrait_frame.add_child(portrait)
	_briefing_portrait_frame.visible = true


func _find_npc_data(npc_id: String) -> Dictionary:
	var file := FileAccess.open("res://data/npcs.json", FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var npcs: Array = json.data if json.data is Array else []
	for npc: Dictionary in npcs:
		if npc.get("id", "") == npc_id:
			return npc
	return {}


func _update_briefing_days() -> void:
	if _selected_scenario.is_empty() or _briefing_days == null:
		return
	var base_days: int = int(_selected_scenario.get("daysAllowed", 30))
	var mods: Dictionary = GameState.get_difficulty_modifiers(GameState.selected_difficulty)
	var total_days: int = base_days + int(mods.get("days_bonus", 0))
	_briefing_days.text = "You have %d days." % total_days


func _on_difficulty_pressed(preset: String) -> void:
	GameState.selected_difficulty = preset
	_refresh_difficulty_buttons()
	_update_briefing_days()


func _refresh_difficulty_buttons() -> void:
	var selected: String = GameState.selected_difficulty
	for preset in _difficulty_buttons:
		var btn: Button = _difficulty_buttons[preset]
		if preset == selected:
			btn.add_theme_color_override("font_color", C_TITLE)
			btn.add_theme_stylebox_override("normal", _make_selected_stylebox())
		else:
			btn.remove_theme_color_override("font_color")
			btn.remove_theme_stylebox_override("normal")


func _make_selected_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.35, 0.05, 1.0)
	sb.border_color = C_TITLE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	return sb


# ── Button / event handlers ───────────────────────────────────────────────────

## SPA-685: Builds a decorative manuscript-style flourish (amber line with centre ornament).
func _make_manuscript_flourish() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 0)

	var left_line := ColorRect.new()
	left_line.color = Color(0.75, 0.55, 0.20, 0.45)
	left_line.custom_minimum_size = Vector2(100, 1)
	row.add_child(left_line)

	var diamond := Label.new()
	diamond.text = " \u25C6 "
	diamond.add_theme_font_size_override("font_size", 10)
	diamond.add_theme_color_override("font_color", Color(0.75, 0.55, 0.20, 0.60))
	row.add_child(diamond)

	var right_line := ColorRect.new()
	right_line.color = Color(0.75, 0.55, 0.20, 0.45)
	right_line.custom_minimum_size = Vector2(100, 1)
	row.add_child(right_line)
	return row


## SPA-685: Refresh Continue button — enable only when saves exist.
func _refresh_continue_button() -> void:
	if _btn_continue == null:
		return
	var recent := SaveManager.get_most_recent_save(_scenarios)
	if recent.is_empty():
		_btn_continue.disabled = true
		_btn_continue.tooltip_text = "No saved games found."
	else:
		_btn_continue.disabled = false
		var title_str: String = recent.get("scenario_title", recent.get("scenario_id", ""))
		_btn_continue.tooltip_text = "%s — Day %d" % [title_str, recent.get("day", 1)]


## SPA-685: Continue — load the most recent save.
## Calls prepare_load() so has_pending_load() returns true, then emits
## begin_game.  main.gd's _on_begin_game will initialise the world
## and apply_pending_load() restores saved state.
func _on_continue_pressed() -> void:
	var recent := SaveManager.get_most_recent_save(_scenarios)
	if recent.is_empty():
		return
	var scenario_id: String = recent["scenario_id"]
	var slot: int = recent["slot"]
	var err: String = SaveManager.prepare_load(scenario_id, slot)
	if not err.is_empty():
		push_warning("MainMenu: continue failed — " + err)
		return
	begin_game.emit(scenario_id)


func _on_play_pressed() -> void:
	_selected_card_idx = -1
	_selected_scenario = {}
	_show_phase(Phase.SELECT)


func _on_how_to_play_pressed() -> void:
	_how_to_play.open()


func _on_select_back() -> void:
	_show_phase(Phase.MAIN)


func _on_select_next() -> void:
	if _selected_scenario.is_empty():
		# Auto-select first if none chosen
		if not _scenarios.is_empty():
			_on_card_pressed(0)
		else:
			return
	_populate_briefing()
	_show_phase(Phase.BRIEFING)


func _on_briefing_back() -> void:
	_show_phase(Phase.SELECT)


## Advance from BRIEFING to the atmospheric INTRO card.
func _on_briefing_next_pressed() -> void:
	_populate_intro()
	_show_phase(Phase.INTRO)


# ── Phase 4: Scenario Intro panel ─────────────────────────────────────────────

func _build_intro_panel() -> void:
	var vpi := get_viewport().get_visible_rect().size
	var iw := UILayoutConstants.clamp_to_viewport(vpi.x, WIDE_PANEL_VP_W, WIDE_PANEL_MIN_W, WIDE_PANEL_MAX_W)
	var ih := UILayoutConstants.clamp_to_viewport(vpi.y, WIDE_PANEL_VP_H, WIDE_PANEL_MIN_H, WIDE_PANEL_MAX_H)
	_panel_intro = _make_panel(iw, ih)
	add_child(_panel_intro)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_intro.add_child(vbox)

	_intro_title = Label.new()
	_intro_title.text = ""
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_title.add_theme_font_size_override("font_size", 22)
	_intro_title.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(_intro_title)

	vbox.add_child(_separator())

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	_intro_body = RichTextLabel.new()
	_intro_body.custom_minimum_size = Vector2(0, 240)
	_intro_body.fit_content = false
	_intro_body.scroll_active = false
	_intro_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro_body.bbcode_enabled = true
	_intro_body.add_theme_font_size_override("normal_font_size", 17)
	_intro_body.add_theme_color_override("default_color", C_HEADING)
	vbox.add_child(_intro_body)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer2)

	vbox.add_child(_separator())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var btn_back := _make_button("Back", 140)
	btn_back.pressed.connect(_on_intro_back)
	btn_row.add_child(btn_back)

	var btn_begin := _make_button("Begin", 140)
	btn_begin.pressed.connect(_on_intro_begin_pressed)
	btn_row.add_child(btn_begin)


func _populate_intro() -> void:
	_intro_title.text = _selected_scenario.get("title", "")
	var intro_text: String = _selected_scenario.get("introText", "")
	_intro_body.text = "[center][i]" + intro_text + "[/i][/center]"


func _on_intro_back() -> void:
	_show_phase(Phase.BRIEFING)


func _on_intro_begin_pressed() -> void:
	var scenario_id: String = _selected_scenario.get("scenarioId", "scenario_1")
	begin_game.emit(scenario_id)


# ── Phase 5: Settings panel ───────────────────────────────────────────────────

func _build_settings_panel() -> void:
	var vpc := get_viewport().get_visible_rect().size
	var cw := UILayoutConstants.clamp_to_viewport(vpc.x, NARROW_PANEL_VP_W, NARROW_PANEL_MIN_W, NARROW_PANEL_MAX_W)
	var ch := UILayoutConstants.clamp_to_viewport(vpc.y, NARROW_PANEL_VP_H, NARROW_PANEL_MIN_H, NARROW_PANEL_MAX_H)
	_panel_settings = _make_panel(cw, ch)
	add_child(_panel_settings)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_settings.add_child(vbox)

	var heading := Label.new()
	heading.text = "Settings"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", C_HEADING)
	vbox.add_child(heading)

	vbox.add_child(_separator())

	# Display section
	var display_lbl := Label.new()
	display_lbl.text = "Display"
	display_lbl.add_theme_font_size_override("font_size", 14)
	display_lbl.add_theme_color_override("font_color", C_SUBHEADING)
	vbox.add_child(display_lbl)

	# Resolution cycle button
	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 8)
	vbox.add_child(res_row)

	var res_name := Label.new()
	res_name.text = "Resolution:"
	res_name.custom_minimum_size = Vector2(80, 0)
	res_name.add_theme_font_size_override("font_size", 13)
	res_name.add_theme_color_override("font_color", C_BODY)
	res_row.add_child(res_name)

	_btn_resolution = Button.new()
	_btn_resolution.text = SettingsManager.get_resolution_label()
	_btn_resolution.custom_minimum_size = Vector2(120, 30)
	_btn_resolution.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_resolution.add_theme_font_size_override("font_size", 13)
	_btn_resolution.add_theme_color_override("font_color", C_BTN_TEXT)
	var res_normal := StyleBoxFlat.new()
	res_normal.bg_color = C_BTN_NORMAL
	res_normal.set_border_width_all(1)
	res_normal.border_color = C_PANEL_BORDER
	res_normal.set_content_margin_all(4)
	var res_hover := StyleBoxFlat.new()
	res_hover.bg_color = C_BTN_HOVER
	res_hover.set_border_width_all(1)
	res_hover.border_color = C_PANEL_BORDER
	res_hover.set_content_margin_all(4)
	var res_focus := StyleBoxFlat.new()
	res_focus.bg_color = C_BTN_HOVER
	res_focus.set_border_width_all(2)
	res_focus.border_color = Color(1.00, 0.90, 0.40, 1.0)
	res_focus.set_content_margin_all(4)
	_btn_resolution.add_theme_stylebox_override("normal", res_normal)
	_btn_resolution.add_theme_stylebox_override("hover", res_hover)
	_btn_resolution.add_theme_stylebox_override("focus", res_focus)
	_btn_resolution.pressed.connect(_on_resolution_cycle)
	res_row.add_child(_btn_resolution)

	# Window mode cycle button (Windowed / Borderless / Fullscreen)
	var fs_row := HBoxContainer.new()
	fs_row.add_theme_constant_override("separation", 8)
	vbox.add_child(fs_row)

	var fs_name := Label.new()
	fs_name.text = "Window (F11):"
	fs_name.custom_minimum_size = Vector2(80, 0)
	fs_name.add_theme_font_size_override("font_size", 13)
	fs_name.add_theme_color_override("font_color", C_BODY)
	fs_row.add_child(fs_name)

	_btn_window_mode = Button.new()
	_btn_window_mode.text = SettingsManager.get_window_mode_label()
	_btn_window_mode.custom_minimum_size = Vector2(120, 30)
	_btn_window_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_window_mode.add_theme_font_size_override("font_size", 13)
	_btn_window_mode.add_theme_color_override("font_color", C_BTN_TEXT)
	var wm_normal := StyleBoxFlat.new()
	wm_normal.bg_color = C_BTN_NORMAL
	wm_normal.set_border_width_all(1)
	wm_normal.border_color = C_PANEL_BORDER
	wm_normal.set_content_margin_all(4)
	var wm_hover := StyleBoxFlat.new()
	wm_hover.bg_color = C_BTN_HOVER
	wm_hover.set_border_width_all(1)
	wm_hover.border_color = C_PANEL_BORDER
	wm_hover.set_content_margin_all(4)
	var wm_focus := StyleBoxFlat.new()
	wm_focus.bg_color = C_BTN_HOVER
	wm_focus.set_border_width_all(2)
	wm_focus.border_color = Color(1.00, 0.90, 0.40, 1.0)
	wm_focus.set_content_margin_all(4)
	_btn_window_mode.add_theme_stylebox_override("normal", wm_normal)
	_btn_window_mode.add_theme_stylebox_override("hover", wm_hover)
	_btn_window_mode.add_theme_stylebox_override("focus", wm_focus)
	_btn_window_mode.pressed.connect(_on_window_mode_cycle)
	fs_row.add_child(_btn_window_mode)

	# UI scale cycle button
	var sc_row := HBoxContainer.new()
	sc_row.add_theme_constant_override("separation", 8)
	vbox.add_child(sc_row)

	var sc_name := Label.new()
	sc_name.text = "UI Scale:"
	sc_name.custom_minimum_size = Vector2(80, 0)
	sc_name.add_theme_font_size_override("font_size", 13)
	sc_name.add_theme_color_override("font_color", C_BODY)
	sc_row.add_child(sc_name)

	_btn_ui_scale = Button.new()
	_btn_ui_scale.text = SettingsManager.get_ui_scale_label()
	_btn_ui_scale.custom_minimum_size = Vector2(120, 30)
	_btn_ui_scale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_ui_scale.add_theme_font_size_override("font_size", 13)
	_btn_ui_scale.add_theme_color_override("font_color", C_BTN_TEXT)
	var sc_normal := StyleBoxFlat.new()
	sc_normal.bg_color = C_BTN_NORMAL
	sc_normal.set_border_width_all(1)
	sc_normal.border_color = C_PANEL_BORDER
	sc_normal.set_content_margin_all(4)
	var sc_hover := StyleBoxFlat.new()
	sc_hover.bg_color = C_BTN_HOVER
	sc_hover.set_border_width_all(1)
	sc_hover.border_color = C_PANEL_BORDER
	sc_hover.set_content_margin_all(4)
	var sc_focus := StyleBoxFlat.new()
	sc_focus.bg_color = C_BTN_HOVER
	sc_focus.set_border_width_all(2)
	sc_focus.border_color = Color(1.00, 0.90, 0.40, 1.0)
	sc_focus.set_content_margin_all(4)
	_btn_ui_scale.add_theme_stylebox_override("normal", sc_normal)
	_btn_ui_scale.add_theme_stylebox_override("hover", sc_hover)
	_btn_ui_scale.add_theme_stylebox_override("focus", sc_focus)
	_btn_ui_scale.pressed.connect(_on_ui_scale_cycle)
	sc_row.add_child(_btn_ui_scale)

	vbox.add_child(_separator())

	# Audio section
	var audio_lbl := Label.new()
	audio_lbl.text = "Audio"
	audio_lbl.add_theme_font_size_override("font_size", 14)
	audio_lbl.add_theme_color_override("font_color", C_SUBHEADING)
	vbox.add_child(audio_lbl)

	_lbl_music_val = _add_slider_row(vbox, "Music",
		SettingsManager.music_volume, 0.0, 100.0, 1.0,
		_on_music_volume_changed)

	_lbl_ambient_val = _add_slider_row(vbox, "Ambient",
		SettingsManager.ambient_volume, 0.0, 100.0, 1.0,
		_on_ambient_volume_changed)

	_lbl_sfx_val = _add_slider_row(vbox, "SFX",
		SettingsManager.sfx_volume, 0.0, 100.0, 1.0,
		_on_sfx_volume_changed)

	vbox.add_child(_separator())

	# Gameplay section
	var gameplay_lbl := Label.new()
	gameplay_lbl.text = "Gameplay"
	gameplay_lbl.add_theme_font_size_override("font_size", 14)
	gameplay_lbl.add_theme_color_override("font_color", C_SUBHEADING)
	vbox.add_child(gameplay_lbl)

	_lbl_speed_val = _add_slider_row(vbox, "Game Speed",
		SettingsManager.game_speed, 0.25, 4.0, 0.25,
		_on_game_speed_changed,
		"(lower = faster)")

	vbox.add_child(_separator())

	var btn_back := _make_button("Back", 160)
	btn_back.pressed.connect(_on_settings_back)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(btn_back)
	vbox.add_child(btn_row)


## Builds a labelled HSlider row. Returns the value Label for live updates.
func _add_slider_row(
		parent: VBoxContainer,
		label_text: String,
		initial_value: float,
		min_val: float, max_val: float, step: float,
		change_callback: Callable,
		hint: String = "") -> Label:

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = label_text + ":"
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", C_BODY)
	row.add_child(name_lbl)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step      = step
	slider.value     = initial_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(change_callback)
	row.add_child(slider)

	var val_lbl := Label.new()
	val_lbl.custom_minimum_size = Vector2(52, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.add_theme_font_size_override("font_size", 13)
	val_lbl.add_theme_color_override("font_color", C_MUTED)
	val_lbl.text = _format_slider_val(label_text, initial_value)
	row.add_child(val_lbl)

	if hint != "":
		var hint_lbl := Label.new()
		hint_lbl.text = hint
		hint_lbl.add_theme_font_size_override("font_size", 12)
		hint_lbl.add_theme_color_override("font_color", C_MUTED)
		parent.add_child(hint_lbl)

	return val_lbl


func _format_slider_val(label_text: String, value: float) -> String:
	if label_text == "Game Speed":
		return "%.2fs" % value
	return "%d%%" % int(value)


func _on_settings_pressed() -> void:
	_show_phase(Phase.SETTINGS)


func _on_settings_back() -> void:
	_show_phase(Phase.MAIN)


func _on_credits_pressed() -> void:
	_show_phase(Phase.CREDITS)


func _on_credits_back() -> void:
	_show_phase(Phase.MAIN)


func _on_music_volume_changed(value: float) -> void:
	SettingsManager.music_volume = value
	SettingsManager.apply_to_audio_manager()
	SettingsManager.save_settings()
	_lbl_music_val.text = _format_slider_val("Music", value)


func _on_ambient_volume_changed(value: float) -> void:
	SettingsManager.ambient_volume = value
	SettingsManager.apply_to_audio_manager()
	SettingsManager.save_settings()
	_lbl_ambient_val.text = _format_slider_val("Ambient", value)


func _on_sfx_volume_changed(value: float) -> void:
	SettingsManager.sfx_volume = value
	SettingsManager.apply_to_audio_manager()
	SettingsManager.save_settings()
	_lbl_sfx_val.text = _format_slider_val("SFX", value)


func _on_game_speed_changed(value: float) -> void:
	SettingsManager.game_speed = value
	SettingsManager.save_settings()
	_lbl_speed_val.text = _format_slider_val("Game Speed", value)


func _on_resolution_cycle() -> void:
	SettingsManager.resolution_index = (SettingsManager.resolution_index + 1) % SettingsManager.RESOLUTIONS.size()
	SettingsManager.apply_display_settings()
	SettingsManager.save_settings()
	_btn_resolution.text = SettingsManager.get_resolution_label()


func _on_window_mode_cycle() -> void:
	SettingsManager.window_mode = (SettingsManager.window_mode + 1) % 3
	SettingsManager.apply_display_settings()
	SettingsManager.save_settings()
	_btn_window_mode.text = SettingsManager.get_window_mode_label()


func _on_ui_scale_cycle() -> void:
	SettingsManager.ui_scale_index = (SettingsManager.ui_scale_index + 1) % SettingsManager.UI_SCALE_PRESETS.size()
	SettingsManager.ui_scale = SettingsManager.UI_SCALE_PRESETS[SettingsManager.ui_scale_index]
	SettingsManager.apply_ui_scale()
	SettingsManager.save_settings()
	_btn_ui_scale.text = SettingsManager.get_ui_scale_label()


# ── Phase 6: Credits panel ────────────────────────────────────────────────────

func _build_credits_panel() -> void:
	var vpcr := get_viewport().get_visible_rect().size
	var crw := UILayoutConstants.clamp_to_viewport(vpcr.x, NARROW_PANEL_VP_W, NARROW_PANEL_MIN_W, NARROW_PANEL_MAX_W)
	var crh := UILayoutConstants.clamp_to_viewport(vpcr.y, NARROW_PANEL_VP_H, NARROW_PANEL_MIN_H, NARROW_PANEL_MAX_H)
	_panel_credits = _make_panel(crw, crh)
	add_child(_panel_credits)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_credits.add_child(vbox)

	var heading := Label.new()
	heading.text = "Credits"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(heading)

	vbox.add_child(_separator())

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	var credits_body := RichTextLabel.new()
	credits_body.fit_content = true
	credits_body.scroll_active = false
	credits_body.bbcode_enabled = true
	credits_body.add_theme_font_size_override("normal_font_size", 14)
	credits_body.add_theme_color_override("default_color", C_BODY)
	var t := "[center]"
	t += "[color=#ebe8b2][b]Development Team[/b][/color]\n"
	t += "Lead Engineer\n"
	t += "UI/UX Designer\n"
	t += "Game Designer\n"
	t += "Narrative Writer\n\n"
	t += "[color=#ebe8b2][b]Studio[/b][/color]\n"
	t += "Paperclip Studio\n\n"
	t += "[color=#ebe8b2][b]Technology[/b][/color]\n"
	t += "Godot Engine 4  —  godotengine.org\n"
	t += "[color=#c8a84b]Built with AI agents powered by Paperclip[/color]\n\n"
	t += "[color=#ebe8b2][b]Music & Sound[/b][/color]\n"
	t += "Original Compositions\n\n"
	t += "[color=#ebe8b2][b]Playtesting[/b][/color]\n"
	t += "Early Access Community\n\n"
	t += "[color=#8c7a5a]v0.1.0-demo  —  All rights reserved.[/color]"
	t += "[/center]"
	credits_body.text = t
	vbox.add_child(credits_body)

	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer2)

	vbox.add_child(_separator())

	var btn_back := _make_button("Back", 160)
	btn_back.pressed.connect(_on_credits_back)
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_child(btn_back)
	vbox.add_child(btn_row)


# ── Phase 7: Statistics panel ─────────────────────────────────────────────────

func _build_stats_panel() -> void:
	var vpst := get_viewport().get_visible_rect().size
	var stw := UILayoutConstants.clamp_to_viewport(vpst.x, STATS_PANEL_VP_W, STATS_PANEL_MIN_W, STATS_PANEL_MAX_W)
	var sth := UILayoutConstants.clamp_to_viewport(vpst.y, STATS_PANEL_VP_H, STATS_PANEL_MIN_H, STATS_PANEL_MAX_H)
	_panel_stats = _make_panel(stw, sth)
	add_child(_panel_stats)

	# Content is built dynamically in _rebuild_stats_content() to reflect live data.
	# Placeholder VBox so the panel isn't empty at startup.
	var vbox := VBoxContainer.new()
	vbox.name = "StatsVBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_stats.add_child(vbox)


## Rebuild stats panel content from PlayerStats.  Called each time the phase is shown.
func _rebuild_stats_content() -> void:
	var vbox: VBoxContainer = _panel_stats.get_node_or_null("StatsVBox")
	if vbox == null:
		return
	for child in vbox.get_children():
		child.queue_free()

	# ── Heading ───────────────────────────────────────────────────────────────
	var heading := Label.new()
	heading.text = "Statistics"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", C_TITLE)
	vbox.add_child(heading)

	vbox.add_child(_separator())

	# ── Scrollable body ───────────────────────────────────────────────────────
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
		# ── Global totals ─────────────────────────────────────────────────────
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
		_add_grid_stat(totals_grid, "Play Time",        play_str)
		_add_grid_stat(totals_grid, "Rumors Spread",    str(totals.get("total_rumors_spread",  0)))
		_add_grid_stat(totals_grid, "NPCs Convinced",   str(totals.get("total_npcs_convinced", 0)))
		_add_grid_stat(totals_grid, "Bribes Paid",      str(totals.get("total_bribes_paid",    0)))

		body.add_child(_separator())

		# ── Per-scenario table ────────────────────────────────────────────────
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

			var sc_name := scenario_names.get(sid, sid)
			var sc_title := Label.new()
			sc_title.text = sc_name
			sc_title.add_theme_font_size_override("font_size", 13)
			sc_title.add_theme_color_override("font_color", C_SUBHEADING)
			body.add_child(sc_title)

			# Column headers
			var header_row := HBoxContainer.new()
			header_row.add_theme_constant_override("separation", 0)
			body.add_child(header_row)
			_add_table_cell(header_row, "Difficulty", 100, C_MUTED, true)
			_add_table_cell(header_row, "Played",      60, C_MUTED, true)
			_add_table_cell(header_row, "Wins",        50, C_MUTED, true)
			_add_table_cell(header_row, "Losses",      55, C_MUTED, true)
			_add_table_cell(header_row, "Best Score",  80, C_MUTED, true)
			_add_table_cell(header_row, "Fastest Win", 90, C_MUTED, true)

			for diff in PlayerStats.DIFFICULTIES:
				var rec := PlayerStats.get_scenario_stats(sid, diff)
				if rec.get("games_played", 0) == 0:
					continue
				var fastest: int = rec.get("fastest_win_days", -1)
				var fastest_str: String = ("%d days" % fastest) if fastest >= 0 else "—"
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 0)
				body.add_child(row)
				_add_table_cell(row, diff_labels.get(diff, diff), 100, C_BODY, false)
				_add_table_cell(row, str(rec.get("games_played", 0)),   60, C_STAT_VALUE, false)
				_add_table_cell(row, str(rec.get("wins",         0)),   50, C_SCORE_WIN,  false)
				_add_table_cell(row, str(rec.get("losses",       0)),   55, C_SCORE_FAIL, false)
				_add_table_cell(row, str(rec.get("best_score",   0)),   80, C_STAT_VALUE, false)
				_add_table_cell(row, fastest_str,                       90, C_STAT_VALUE, false)

	# ── Bottom buttons ────────────────────────────────────────────────────────
	vbox.add_child(_separator())

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_row)

	var btn_back := _make_button("Back", 160)
	btn_back.pressed.connect(_on_stats_back)
	btn_row.add_child(btn_back)

	if PlayerStats.has_any_data():
		var btn_reset := _make_button("Reset Stats", 160)
		btn_reset.pressed.connect(_on_stats_reset)
		btn_row.add_child(btn_reset)


## Add a label+value pair to a 2-column GridContainer.
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


## Add a fixed-width cell to a row HBoxContainer for the scenario table.
func _add_table_cell(row: HBoxContainer, text: String, w: int, color: Color, bold: bool) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(w, 0)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 12)
	if bold:
		lbl.add_theme_font_size_override("font_size", 13)
	row.add_child(lbl)


func _on_stats_pressed() -> void:
	_show_phase(Phase.STATS)


func _on_stats_back() -> void:
	_show_phase(Phase.MAIN)


func _on_stats_reset() -> void:
	PlayerStats.reset_all()
	_rebuild_stats_content()


# ── Version corner label ──────────────────────────────────────────────────────

func _build_version_label() -> void:
	_version_label = Label.new()
	_version_label.text = "v0.1.0-demo"
	_version_label.add_theme_font_size_override("font_size", 12)
	_version_label.add_theme_color_override("font_color", C_MUTED)
	_version_label.set_anchor(SIDE_LEFT,   1.0)
	_version_label.set_anchor(SIDE_RIGHT,  1.0)
	_version_label.set_anchor(SIDE_TOP,    1.0)
	_version_label.set_anchor(SIDE_BOTTOM, 1.0)
	_version_label.set_offset(SIDE_LEFT,   -110)
	_version_label.set_offset(SIDE_RIGHT,  -8)
	_version_label.set_offset(SIDE_TOP,    -26)
	_version_label.set_offset(SIDE_BOTTOM, -6)
	add_child(_version_label)


# ── UI helpers ────────────────────────────────────────────────────────────────

## SPA-589 / SPA-1669: Creates a parchment-styled centred panel with warmer
## tones and a scroll-edge feel.  Accepts pre-computed (viewport-clamped) w/h.
func _make_parchment_panel(w: int, h: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(w, h)
	panel.set_anchor(SIDE_LEFT,   0.5)
	panel.set_anchor(SIDE_RIGHT,  0.5)
	panel.set_anchor(SIDE_TOP,    0.5)
	panel.set_anchor(SIDE_BOTTOM, 0.5)
	panel.set_offset(SIDE_LEFT,   -w / 2.0)
	panel.set_offset(SIDE_RIGHT,   w / 2.0)
	panel.set_offset(SIDE_TOP,    -h / 2.0)
	panel.set_offset(SIDE_BOTTOM,  h / 2.0)

	var style := StyleBoxFlat.new()
	style.bg_color           = Color(0.11, 0.08, 0.05, 0.92)   # darker parchment, slightly transparent
	style.border_color       = Color(0.55, 0.38, 0.18, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(UILayoutConstants.MARGIN_STANDARD)
	# Top border slightly thicker for scroll-top effect.
	style.border_width_top = 3
	panel.add_theme_stylebox_override("panel", style)
	return panel


## Creates a centred PanelContainer.  Accepts pre-computed (viewport-clamped) w/h.
func _make_panel(w: int, h: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(w, h)
	panel.set_anchor(SIDE_LEFT,   0.5)
	panel.set_anchor(SIDE_RIGHT,  0.5)
	panel.set_anchor(SIDE_TOP,    0.5)
	panel.set_anchor(SIDE_BOTTOM, 0.5)
	panel.set_offset(SIDE_LEFT,   -w / 2.0)
	panel.set_offset(SIDE_RIGHT,   w / 2.0)
	panel.set_offset(SIDE_TOP,    -h / 2.0)
	panel.set_offset(SIDE_BOTTOM,  h / 2.0)

	var style := StyleBoxFlat.new()
	style.bg_color           = C_PANEL_BG
	style.border_color       = C_PANEL_BORDER
	style.set_border_width_all(2)
	style.set_content_margin_all(UILayoutConstants.MARGIN_STANDARD)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _make_button(label_text: String, w: int) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(w, 42)

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

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.28, 0.14, 0.04, 1.0)
	pressed_style.set_border_width_all(1)
	pressed_style.border_color = C_PANEL_BORDER
	pressed_style.set_content_margin_all(8)

	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = C_BTN_HOVER
	focus_style.set_border_width_all(2)
	focus_style.border_color = Color(1.00, 0.90, 0.40, 1.0)  # gold — matches SPA-169 focus ring
	focus_style.set_content_margin_all(8)

	btn.add_theme_stylebox_override("normal",  normal)
	btn.add_theme_stylebox_override("hover",   hover)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_stylebox_override("focus",   focus_style)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)
	btn.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	btn.mouse_entered.connect(func() -> void: AudioManager.play_sfx_pitched("ui_click", 2.0))
	return btn


func _separator() -> HSeparator:
	var sep := HSeparator.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL_BORDER
	style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", style)
	return sep


func _card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color     = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_content_margin_all(10)
	return s
