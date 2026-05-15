extends CanvasLayer

## foreshadow_hud.gd — SPA-2691: Visual foreshadow indicator on HUD.
##
## Shows an ominous banner at the top of the screen when a faction event or
## mid-game event is approximately 2 days away.  Wired to the day_changed
## signal of DayNightCycle via setup().
##
## Supports two hint sources:
##   - FactionEventSystem.get_foreshadow_for_day(day)  (returns Array[String])
##   - MidGameEventAgent.get_upcoming_event(day)        (returns Dictionary)
##
## Usage from UILayerManager:
##   var foreshadow_hud := preload("res://scripts/foreshadow_hud.gd").new()
##   foreshadow_hud.name = "ForeshadowHUD"
##   add_child(foreshadow_hud)
##   foreshadow_hud.setup(world, day_night)

# ── Palette ───────────────────────────────────────────────────────────────────

const C_BG          := Color(0.04, 0.02, 0.01, 0.88)
const C_BORDER      := Color(0.55, 0.28, 0.06, 1.0)   # burnt amber
const C_ICON_GLOW   := Color(0.85, 0.40, 0.10, 1.0)   # ominous orange
const C_HEADING     := Color(0.90, 0.76, 0.36, 1.0)   # warm gold
const C_BODY        := Color(0.78, 0.68, 0.50, 1.0)   # parchment
const C_DISMISS     := Color(0.55, 0.48, 0.34, 0.70)

const BANNER_H        := 72.0
const BANNER_PAD_X    := 20.0
const REVEAL_TIME     := 0.4
const HOLD_TIME       := 5.0   # seconds before auto-hide
const HIDE_TIME       := 0.35

# ── Node refs ─────────────────────────────────────────────────────────────────

var _container:   PanelContainer = null
var _icon_rect:   ColorRect      = null
var _text_label:  RichTextLabel  = null
var _dismiss_btn: Button         = null

# ── State ─────────────────────────────────────────────────────────────────────

var _world:     Node  = null
var _day_night: Node  = null
var _tween:     Tween = null
var _hide_timer: SceneTreeTimer = null


func _ready() -> void:
	layer        = 19   # below event cards (20/21) but above base HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


## Wire to world subsystems and day_night clock.
func setup(world: Node, day_night: Node) -> void:
	_world     = world
	_day_night = day_night
	if day_night != null and day_night.has_signal("day_changed"):
		day_night.day_changed.connect(_on_day_changed)


# ── Day hook ──────────────────────────────────────────────────────────────────

func _on_day_changed(day: int) -> void:
	var hints: Array[String] = []

	# Faction event foreshadow (2 days ahead).
	if _world != null and _world.get("faction_event_system") != null:
		var fes: Node = _world.faction_event_system
		if fes.has_method("get_foreshadow_for_day"):
			for t in fes.get_foreshadow_for_day(day):
				hints.append(str(t))

	# Mid-game event: show foreshadow if the nearest event window starts soon.
	if _world != null and _world.get("mid_game_event_agent") != null:
		var agent: Node = _world.mid_game_event_agent
		if agent.has_method("get_upcoming_event"):
			var upcoming: Dictionary = agent.get_upcoming_event(day)
			if not upcoming.is_empty():
				var win_start: int = int(upcoming.get("dayWindowStart", 0))
				var days_away: int = win_start - day
				if days_away >= 1 and days_away <= 2:
					var ev_name: String = str(upcoming.get("name", "an event"))
					hints.append(
						"Something stirs on the horizon — the matter of [i]%s[/i] draws near." % ev_name
					)

	if hints.is_empty():
		return

	# Show only the first (most urgent) hint.
	_show_hint(hints[0])


# ── UI ─────────────────────────────────────────────────────────────────────────

func _show_hint(text: String) -> void:
	_text_label.text = text
	visible = true

	# Kill previous tween if still running.
	if _tween != null:
		_tween.kill()
	if _hide_timer != null:
		_hide_timer = null   # will be overwritten below

	# Slide in from top: container starts off-screen, slides to y = 0.
	_container.position.y = -BANNER_H - 10
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(
		_container, "position:y", 0.0, REVEAL_TIME
	).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_callback(_schedule_auto_hide)

	if AudioManager != null and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("event_sting")


func _schedule_auto_hide() -> void:
	_hide_timer = get_tree().create_timer(HOLD_TIME, false)
	_hide_timer.timeout.connect(_hide_banner, CONNECT_ONE_SHOT)


func _hide_banner() -> void:
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(
		_container, "position:y", -BANNER_H - 10, HIDE_TIME
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void: visible = false)


# ── Build UI ──────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Viewport-wide panel anchored to the top edge.
	_container = PanelContainer.new()
	_container.set_anchor(SIDE_LEFT,   0.0)
	_container.set_anchor(SIDE_RIGHT,  1.0)
	_container.set_anchor(SIDE_TOP,    0.0)
	_container.set_anchor(SIDE_BOTTOM, 0.0)
	_container.offset_top    = 0.0
	_container.offset_bottom = BANNER_H
	_container.offset_left   = 0.0
	_container.offset_right  = 0.0

	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.border_color = C_BORDER
	sb.set_border_width_all(0)
	sb.border_width_bottom = 2
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(0)
	_container.add_theme_stylebox_override("panel", sb)
	add_child(_container)

	# Horizontal layout: icon | text | dismiss.
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.add_child(hbox)

	# Left padding.
	var pad_l := Control.new()
	pad_l.custom_minimum_size = Vector2(BANNER_PAD_X, 0)
	hbox.add_child(pad_l)

	# Animated ominous eye/glow icon (simple pulsing ColorRect).
	_icon_rect = ColorRect.new()
	_icon_rect.custom_minimum_size = Vector2(14, 14)
	_icon_rect.color = C_ICON_GLOW
	_icon_rect.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	var icon_center := CenterContainer.new()
	icon_center.custom_minimum_size = Vector2(24, BANNER_H)
	icon_center.add_child(_icon_rect)
	hbox.add_child(icon_center)

	# Foreshadow text.
	_text_label = RichTextLabel.new()
	_text_label.bbcode_enabled   = true
	_text_label.fit_content      = false
	_text_label.scroll_active    = false
	_text_label.autowrap_mode    = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_color_override("default_color", C_BODY)
	_text_label.add_theme_font_size_override("normal_font_size", 13)
	hbox.add_child(_text_label)

	# Dismiss [×] button.
	_dismiss_btn = Button.new()
	_dismiss_btn.text = "×"
	_dismiss_btn.flat = true
	_dismiss_btn.custom_minimum_size = Vector2(36, BANNER_H)
	_dismiss_btn.add_theme_color_override("font_color", C_DISMISS)
	_dismiss_btn.add_theme_font_size_override("font_size", 20)
	_dismiss_btn.pressed.connect(_hide_banner)
	hbox.add_child(_dismiss_btn)

	# Pulse the glow icon to draw attention.
	var pulse := create_tween().set_loops()
	pulse.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pulse.tween_property(_icon_rect, "color:a", 0.3, 0.9) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_icon_rect, "color:a", 1.0, 0.9) \
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
