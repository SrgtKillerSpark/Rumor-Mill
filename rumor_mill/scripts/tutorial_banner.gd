extends CanvasLayer

## tutorial_banner.gd — Scenario 1 non-blocking contextual hint banner.
##
## Procedurally-built CanvasLayer (layer 19) that displays one hint at a time
## from a queue.  Unlike TutorialHUD this banner does NOT block input — the game
## continues uninterrupted while it is visible.
##
## Display spec:
##   • Bottom-left corner, 24 px margin from screen edge.
##   • 380 px wide × auto-height panel.
##   • Dark semi-transparent background (alpha 0.82), rounded corners 8 px.
##   • Left-side amber accent stripe (#F4A63A).
##   • Entrance: slide in from left over 0.25 s (ease-out).
##   • Exit:     fade out over 0.4 s on auto-dismiss; slide out left on X dismiss.
##   • Auto-dismiss: 7 or 9 s (per-hint).  Timer pauses while cursor hovers banner.
##   • One hint visible at a time; others queue behind it.
##   • Queue pauses while suppressed (Journal / Rumour Panel / Pause Menu open).
##
## Usage from main.gd:
##   var tutorial_banner := preload("res://scripts/tutorial_banner.gd").new()
##   tutorial_banner.name = "TutorialBanner"
##   add_child(tutorial_banner)
##   tutorial_banner.setup(tutorial_system_instance)
##   tutorial_banner.queue_hint("hint_camera")

# ── Palette ───────────────────────────────────────────────────────────────────

const C_PANEL_BG     := Color(0.06, 0.04, 0.02, 0.82)   # dark semi-transparent
const C_ACCENT       := Color(0.957, 0.651, 0.227, 1.0)  # amber #F4A63A
const C_HEADING      := Color(0.96, 0.84, 0.40, 1.0)    # warm gold
const C_BODY         := Color(0.80, 0.72, 0.55, 1.0)    # parchment
const C_BTN_NORMAL   := Color(0.30, 0.18, 0.05, 0.90)
const C_BTN_HOVER    := Color(0.50, 0.30, 0.08, 1.0)
const C_BTN_TEXT     := Color(0.92, 0.82, 0.60, 1.0)

const BANNER_WIDTH   := 380
const MARGIN         := 24       # px from screen edges
const ACCENT_WIDTH   := 5        # px wide left stripe

# ── Node refs (built in _ready) ───────────────────────────────────────────────

var _container:   Control        = null  # anchored root control
var _panel_bg:    ColorRect      = null  # dark background
var _accent:      ColorRect      = null  # amber left stripe
var _title_label: Label          = null
var _body_label:  RichTextLabel  = null
var _dismiss_btn: Button         = null
var _dismiss_tween: Tween        = null

# ── State ─────────────────────────────────────────────────────────────────────

var _tutorial_sys:  TutorialSystem = null
var _queue:         Array          = []   ## Array[Dictionary] — {id, body_override}
var _active_id:     String         = ""
var _active_body:   String         = ""   ## body_override of the currently-showing hint
var _auto_secs:     float          = 7.0
var _timer:         float          = 0.0
var _suppressed:    bool           = false
var _hovered:       bool           = false  # cursor is over the banner


func _ready() -> void:
	layer = 19
	_build_ui()
	visible = false


## Wire the TutorialSystem instance.  Must be called before queue_hint().
func setup(tutorial_sys: TutorialSystem) -> void:
	_tutorial_sys = tutorial_sys


## Add a hint to the display queue.
## body_override replaces the data body when provided (used for dynamic text
## such as substituting the actual evidence item name in hint_evidence).
func queue_hint(hint_id: String, body_override: String = "") -> void:
	if _tutorial_sys == null:
		return
	if _tutorial_sys.has_seen(hint_id):
		return
	# Avoid duplicates.
	for entry in _queue:
		if entry["id"] == hint_id:
			return
	if _active_id == hint_id:
		return
	_queue.append({"id": hint_id, "body_override": body_override})
	if _active_id == "" and not _suppressed:
		_show_next()


## Suppress the banner queue (call when Journal / Rumour Panel / Pause Menu opens).
## Any active hint is hidden immediately; queued hints are held until unsuppressed.
func suppress() -> void:
	if _suppressed:
		return
	_suppressed = true
	if _active_id != "":
		_instant_hide()


## Resume the banner queue after suppression ends.
func unsuppress() -> void:
	if not _suppressed:
		return
	_suppressed = false
	# If there was an active hint when suppressed, re-queue it at front.
	if _active_id != "":
		_queue.push_front({"id": _active_id, "body_override": _active_body})
		_active_id   = ""
		_active_body = ""
	if not _queue.is_empty():
		_show_next()


# ── Per-frame auto-dismiss timer ──────────────────────────────────────────────

func _process(delta: float) -> void:
	if _active_id == "" or _suppressed:
		return
	if _hovered:
		return  # pause timer while cursor is over the banner
	_timer -= delta
	if _timer <= 0.0:
		_auto_dismiss()


# ── Internal display ──────────────────────────────────────────────────────────

func _show_next() -> void:
	if _queue.is_empty() or _suppressed:
		_active_id = ""
		visible    = false
		return

	var entry: Dictionary = _queue.pop_front()
	var hint_id: String   = str(entry["id"])

	if _tutorial_sys.has_seen(hint_id):
		_show_next()
		return

	var data: Dictionary = _tutorial_sys.get_hint(hint_id)
	if data.is_empty():
		_show_next()
		return

	_active_id  = hint_id
	_auto_secs  = float(data.get("auto_dismiss_secs", 7))
	_timer      = _auto_secs

	var body_override: String = str(entry["body_override"])
	_active_body = body_override
	var body: String = body_override if body_override != "" \
		else str(data.get("body", ""))
	_title_label.text = data.get("title", "")
	_body_label.text  = body

	# Position banner off-screen to the left for slide-in.
	_container.offset_left  = -(BANNER_WIDTH + MARGIN + 20)
	_container.offset_right = -(MARGIN + 20)
	visible = true
	_hovered = false

	# Slide in from left.
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_container, "offset_left",  MARGIN, 0.25)
	tween.parallel().tween_property(_container, "offset_right", MARGIN + BANNER_WIDTH, 0.25)


func _auto_dismiss() -> void:
	# Fade out over 0.4 s.
	if _dismiss_tween != null:
		_dismiss_tween.kill()
	_dismiss_tween = create_tween()
	_dismiss_tween.tween_property(_container, "modulate:a", 0.0, 0.4)
	_dismiss_tween.tween_callback(_finish_dismiss)


func _slide_out_dismiss() -> void:
	# Slide out to the left on X press.
	if _dismiss_tween != null:
		_dismiss_tween.kill()
	_dismiss_tween = create_tween()
	_dismiss_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_dismiss_tween.tween_property(_container, "offset_left",  -(BANNER_WIDTH + MARGIN + 20), 0.22)
	_dismiss_tween.parallel().tween_property(_container, "offset_right", -(MARGIN + 20), 0.22)
	_dismiss_tween.tween_callback(_finish_dismiss)


func _finish_dismiss() -> void:
	if _tutorial_sys != null and _active_id != "":
		_tutorial_sys.mark_seen(_active_id)
	_active_id       = ""
	_container.modulate.a = 1.0
	visible          = false
	_hovered         = false
	if not _suppressed:
		_show_next()


func _instant_hide() -> void:
	if _dismiss_tween != null:
		_dismiss_tween.kill()
	_container.modulate.a = 1.0
	visible    = false


func _on_dismiss_pressed() -> void:
	if _tutorial_sys != null and _active_id != "":
		_tutorial_sys.mark_seen(_active_id)
	_active_id   = ""
	_active_body = ""
	_slide_out_dismiss()


func _on_banner_mouse_entered() -> void:
	_hovered = true
	_timer   = _auto_secs  # reset timer on hover


func _on_banner_mouse_exited() -> void:
	_hovered = false


# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	# Root control anchored to bottom-left.
	_container = Control.new()
	_container.anchor_left   = 0.0
	_container.anchor_top    = 1.0
	_container.anchor_right  = 0.0
	_container.anchor_bottom = 1.0
	# Initial resting position (bottom-left, 24 px margins).
	# offset_bottom is negative because anchor is at bottom edge.
	_container.offset_left   = MARGIN
	_container.offset_right  = MARGIN + BANNER_WIDTH
	_container.offset_bottom = -MARGIN
	_container.offset_top    = -MARGIN  # will be adjusted after content measures
	_container.mouse_filter  = Control.MOUSE_FILTER_STOP
	_container.mouse_entered.connect(_on_banner_mouse_entered)
	_container.mouse_exited.connect(_on_banner_mouse_exited)
	add_child(_container)

	# Accent stripe (left edge, full height).
	_accent = ColorRect.new()
	_accent.color                 = C_ACCENT
	_accent.anchor_left           = 0.0
	_accent.anchor_top            = 0.0
	_accent.anchor_right          = 0.0
	_accent.anchor_bottom         = 1.0
	_accent.offset_right          = ACCENT_WIDTH
	_accent.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	_container.add_child(_accent)

	# Dark background panel (full container, sits behind content).
	_panel_bg = ColorRect.new()
	_panel_bg.color               = C_PANEL_BG
	_panel_bg.anchor_right        = 1.0
	_panel_bg.anchor_bottom       = 1.0
	_panel_bg.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	_container.add_child(_panel_bg)

	# Rounded border via a StyleBoxFlat on a Panel overlay.
	var border_panel := Panel.new()
	border_panel.anchor_right  = 1.0
	border_panel.anchor_bottom = 1.0
	border_panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color(0, 0, 0, 0)
	border_style.border_color = C_ACCENT
	border_style.set_border_width_all(1)
	border_style.set_corner_radius_all(8)
	border_panel.add_theme_stylebox_override("panel", border_style)
	_container.add_child(border_panel)

	# Content VBox (inset from accent stripe).
	var vbox := VBoxContainer.new()
	vbox.anchor_right   = 1.0
	vbox.anchor_bottom  = 1.0
	vbox.offset_left    = ACCENT_WIDTH + 10
	vbox.offset_right   = -8
	vbox.offset_top     = 8
	vbox.offset_bottom  = -8
	vbox.add_theme_constant_override("separation", 5)
	_container.add_child(vbox)

	# Title row: title label + X dismiss button.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 4)
	vbox.add_child(title_row)

	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", C_HEADING)
	_title_label.add_theme_font_size_override("font_size", 13)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(_title_label)

	_dismiss_btn = Button.new()
	_dismiss_btn.text                = "✕"
	_dismiss_btn.flat                = true
	_dismiss_btn.custom_minimum_size = Vector2(22, 22)
	_dismiss_btn.add_theme_font_size_override("font_size", 11)
	_dismiss_btn.add_theme_color_override("font_color",         C_BTN_TEXT)
	_dismiss_btn.add_theme_color_override("font_hover_color",   C_HEADING)
	_dismiss_btn.add_theme_color_override("font_pressed_color", C_HEADING)
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0, 0, 0, 0)
	_dismiss_btn.add_theme_stylebox_override("normal",  btn_normal)
	_dismiss_btn.add_theme_stylebox_override("hover",   btn_normal)
	_dismiss_btn.add_theme_stylebox_override("pressed", btn_normal)
	_dismiss_btn.pressed.connect(_on_dismiss_pressed)
	title_row.add_child(_dismiss_btn)

	# Body text (BBCode for [b] tags).
	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content    = true
	_body_label.scroll_active  = false
	_body_label.autowrap_mode  = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(BANNER_WIDTH - ACCENT_WIDTH - 30, 0)
	_body_label.add_theme_color_override("default_color",   C_BODY)
	_body_label.add_theme_color_override("font_bold_color", C_HEADING)
	_body_label.add_theme_font_size_override("normal_font_size", 12)
	_body_label.add_theme_font_size_override("bold_font_size",   12)
	vbox.add_child(_body_label)
