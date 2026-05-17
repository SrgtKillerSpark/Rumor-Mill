extends CanvasLayer

## foreshadow_hud.gd — SPA-2699: Spec-aligned event foreshadow banner.
##
## Shows a slim parchment-tan banner at the top of the screen 1–2 ticks before
## a qualifying mid-game event fires.  Auto-dismisses after 6 s; no manual
## dismiss (per spec: ambient awareness, not a prompt).
##
## Supports two hint sources:
##   - FactionEventSystem.get_foreshadow_for_day(day)  (returns Array[String])
##   - MidGameEventAgent.get_upcoming_event(day)        (returns Dictionary)
##     The event dictionary's "foreshadowText" field is preferred; if absent
##     the banner falls back to "Whispers of [event name]...".
##
## Usage from UILayerManager:
##   var foreshadow_hud := preload("res://scripts/foreshadow_hud.gd").new()
##   foreshadow_hud.name = "ForeshadowHUD"
##   add_child(foreshadow_hud)
##   foreshadow_hud.setup(world, day_night)

# ── Palette (parchment-tan per spec) ─────────────────────────────────────────

# Spec: #F5E6C8 parchment-tan background, 1px dark-sepia border
const C_BG          := Color(0.961, 0.902, 0.784, 1.0)  # #F5E6C8
const C_BORDER      := Color(0.239, 0.157, 0.047, 1.0)  # dark sepia
const C_ICON        := Color(0.239, 0.157, 0.047, 0.85) # dark-sepia icon dot
const C_TEXT        := Color(0.231, 0.153, 0.071, 1.0)  # #3B2712 dark-brown
const C_SUBTEXT     := Color(0.478, 0.420, 0.365, 1.0)  # #7A6B5D muted

# Spec: 48px height banner
const BANNER_H      := 48.0
const BANNER_PAD_X  := 20.0
const REVEAL_TIME   := 0.4
const HOLD_TIME     := 6.0   # seconds before auto-hide (spec: 6 s)
const HIDE_TIME     := 0.3

# ── Node refs ─────────────────────────────────────────────────────────────────

var _container:    PanelContainer = null
var _icon_rect:    ColorRect      = null
var _text_label:   Label          = null
var _subtext_label: Label         = null

# ── State ─────────────────────────────────────────────────────────────────────

var _world:     Node  = null
var _day_night: Node  = null
var _tween:     Tween = null
var _hide_timer: SceneTreeTimer = null

# Track which events have already shown a foreshadow this playthrough so we
# don't re-show the same banner if the player fast-forwards.
var _shown_event_ids: Dictionary = {}


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
	var hints: Array[Dictionary] = []   # each: { text, subtext }

	# Faction event foreshadow.
	if _world != null and _world.get("faction_event_system") != null:
		var fes: Node = _world.faction_event_system
		if fes.has_method("get_foreshadow_for_day"):
			for t in fes.get_foreshadow_for_day(day):
				hints.append({ "text": str(t), "subtext": "" })

	# Mid-game event foreshadow — use authored foreshadowText when present.
	if _world != null and _world.get("mid_game_event_agent") != null:
		var agent: Node = _world.mid_game_event_agent
		if agent.has_method("get_upcoming_event"):
			var upcoming: Dictionary = agent.get_upcoming_event(day)
			if not upcoming.is_empty():
				var ev_id: String    = str(upcoming.get("id", ""))
				var win_start: int   = int(upcoming.get("dayWindowStart", 0))
				var days_away: int   = win_start - day

				# First slice: show 1-tick ("tomorrow") and 2-tick foreshadow.
				if days_away >= 1 and days_away <= 2 and not _shown_event_ids.has(ev_id):
					var ev_name: String = str(upcoming.get("name", "an event"))
					# Prefer authored foreshadowText; fall back to generic copy.
					var body_text: String = str(upcoming.get("foreshadowText", ""))
					if body_text.is_empty():
						body_text = "Whispers of %s reach your ears..." % ev_name
					var sub: String = "in %d day%s" % [days_away, "s" if days_away != 1 else ""]
					hints.append({ "text": body_text, "subtext": sub, "ev_id": ev_id })

	if hints.is_empty():
		return

	# Show only the first (most urgent) hint.  Mark event as shown.
	var hint: Dictionary = hints[0]
	if hint.has("ev_id"):
		_shown_event_ids[str(hint["ev_id"])] = true
	_show_hint(str(hint.get("text", "")), str(hint.get("subtext", "")))


# ── UI ─────────────────────────────────────────────────────────────────────────

func _show_hint(text: String, subtext: String) -> void:
	_text_label.text    = text
	_subtext_label.text = subtext
	_subtext_label.visible = not subtext.is_empty()
	visible = true

	# Kill previous tween/timer if still running.
	if _tween != null:
		_tween.kill()
	# Cancel any pending hide timer before clearing the reference.
	# SceneTreeTimer has no stop(); disconnecting the signal is the safe pattern.
	if _hide_timer != null and is_instance_valid(_hide_timer):
		if _hide_timer.timeout.is_connected(_hide_banner):
			_hide_timer.timeout.disconnect(_hide_banner)
	_hide_timer = null

	# Check reduced-motion preference (OS accessibility setting).
	var reduced := _reduced_motion_active()

	if reduced:
		# Fallback: instant appear with opacity fade.
		_container.modulate.a = 0.0
		_container.position.y = 0.0
		_tween = create_tween()
		_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tween.tween_property(_container, "modulate:a", 1.0, 0.2) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		_tween.tween_callback(_schedule_auto_hide)
	else:
		# Target: slide down from top over 400ms (ease-out).
		_container.modulate.a = 1.0
		_container.position.y = -BANNER_H - 10
		_tween = create_tween()
		_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_tween.tween_property(
			_container, "position:y", 0.0, REVEAL_TIME
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		_tween.tween_callback(_schedule_auto_hide)

		# Subtle paper-rustle SFX (fallback: silent if AudioManager absent).
		if AudioManager != null and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("paper_rustle")


func _schedule_auto_hide() -> void:
	_hide_timer = get_tree().create_timer(HOLD_TIME, false)
	_hide_timer.timeout.connect(_hide_banner, CONNECT_ONE_SHOT)


func _hide_banner() -> void:
	if _tween != null:
		_tween.kill()
	var reduced := _reduced_motion_active()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if reduced:
		_tween.tween_property(_container, "modulate:a", 0.0, 0.2) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	else:
		_tween.tween_property(
			_container, "position:y", -BANNER_H - 10, HIDE_TIME
		).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(func() -> void: visible = false)
	_hide_timer = null


func _reduced_motion_active() -> bool:
	# Godot exposes DisplayServer.is_touchscreen_available() but no direct
	# reduced-motion query yet.  We check a project setting or environment
	# variable as a lightweight substitute.
	if ProjectSettings.has_setting("accessibility/reduced_motion") \
			and bool(ProjectSettings.get_setting("accessibility/reduced_motion")):
		return true
	if OS.has_environment("REDUCE_MOTION"):
		return true
	return false


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

	# Spec: parchment-tan background, 1px dark-sepia bottom border.
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_BG
	sb.border_color = C_BORDER
	sb.set_border_width_all(0)
	sb.border_width_bottom = 1
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(0)
	_container.add_theme_stylebox_override("panel", sb)
	add_child(_container)

	# Horizontal layout: left-pad | icon | main-text/subtext | right-pad.
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_container.add_child(hbox)

	# Left padding.
	var pad_l := Control.new()
	pad_l.custom_minimum_size = Vector2(BANNER_PAD_X, 0)
	hbox.add_child(pad_l)

	# Spec: left-aligned 32×32 event-type icon area (simplified as a dark dot).
	_icon_rect = ColorRect.new()
	_icon_rect.custom_minimum_size = Vector2(10, 10)
	_icon_rect.color = C_ICON
	var icon_center := CenterContainer.new()
	icon_center.custom_minimum_size = Vector2(20, BANNER_H)
	icon_center.add_child(_icon_rect)
	hbox.add_child(icon_center)

	# Text column: main foreshadow text + "in N days" subtext side-by-side.
	var text_hbox := HBoxContainer.new()
	text_hbox.add_theme_constant_override("separation", 8)
	text_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_hbox.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	hbox.add_child(text_hbox)

	# Main italic serif text — spec: Crimson Text Italic 16px dark-brown.
	_text_label = Label.new()
	_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_label.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	_text_label.add_theme_color_override("font_color", C_TEXT)
	_text_label.add_theme_font_size_override("font_size", 14)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	text_hbox.add_child(_text_label)

	# "in N days" subtext — spec: 12px muted, right of main text.
	_subtext_label = Label.new()
	_subtext_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	_subtext_label.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	_subtext_label.add_theme_color_override("font_color", C_SUBTEXT)
	_subtext_label.add_theme_font_size_override("font_size", 12)
	_subtext_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtext_label.visible = false
	text_hbox.add_child(_subtext_label)

	# Right padding.
	var pad_r := Control.new()
	pad_r.custom_minimum_size = Vector2(BANNER_PAD_X, 0)
	hbox.add_child(pad_r)
