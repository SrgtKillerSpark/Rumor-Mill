extends CanvasLayer

## recon_hud.gd — Reconnaissance HUD overlay.
##
## Displays:
##   • Daily recon action pips (top-right corner) — filled/empty circles
##   • Whisper token pips
##   • Optional Favors count (visible when heat or bribes are active)
##   • Toast notifications for action results (centre-bottom)
##
## Press R to toggle the Rumor Crafting Panel.
## Call setup(intel_store, rumor_panel) after the scene tree is ready.

@onready var action_pips_row:  HBoxContainer = $CounterPanel/VBox/ActionsRow/ActionPips
@onready var whisper_pips_row: HBoxContainer = $CounterPanel/VBox/WhispersRow/WhisperPips
@onready var favors_row:       HBoxContainer = $CounterPanel/VBox/FavorsRow
@onready var favors_label:     Label         = $CounterPanel/VBox/FavorsRow/FavorsLabel
@onready var toast_panel:      Panel         = $ToastPanel
@onready var toast_label:      Label         = $ToastPanel/ToastLabel

# Programmatic count labels added beside pip rows for clearer readability.
var _action_count_label:  Label = null
var _whisper_count_label: Label = null

const TOAST_DURATION := 3.5
const FLASH_DURATION := 0.3

# Pip colours
const PIP_FULL_ACTION   := Color(0.92, 0.65, 0.12, 1.0)  # amber
const PIP_EMPTY_ACTION  := Color(0.30, 0.22, 0.12, 1.0)  # dark
const PIP_FULL_WHISPER  := Color(0.345, 0.580, 0.769, 1.0) # WATER_L (#5894C4)
const PIP_EMPTY_WHISPER := Color(0.15, 0.20, 0.28, 1.0)  # dark blue

const PIP_SIZE := Vector2(20, 20)

# Heat meter colours
const C_HEAT_LOW    := Color(0.30, 0.75, 0.35, 1.0)  # green — safe
const C_HEAT_MED    := Color(0.95, 0.75, 0.15, 1.0)  # yellow — caution
const C_HEAT_HIGH   := Color(0.95, 0.40, 0.10, 1.0)  # orange — danger
const C_HEAT_CRIT   := Color(0.95, 0.15, 0.10, 1.0)  # red — critical
const C_HEAT_BG     := Color(0.18, 0.12, 0.06, 1.0)

var _intel_store_ref:  PlayerIntelStore = null
var _rumor_panel_ref:  CanvasLayer      = null
var _world_ref:        Node2D           = null
var _journal_ref:      CanvasLayer      = null
var _day_night_ref:    Node             = null
var _hint_btn:         Button           = null
var _hint_label:       Label            = null
var _hint_tween:       Tween            = null
var _dawn_label:       Label            = null

# Heat meter UI nodes.
var _heat_row:       HBoxContainer = null
var _heat_bar_fill:  ColorRect     = null
var _heat_count_lbl: Label         = null

# ── SPA-870: Section headers for visual grouping ────────────────────────────
var _resources_header: Label = null
var _threat_header: Label    = null
# Key hint label references for availability styling.
var _key_hint_rumor: Label   = null
var _key_hint_journal: Label = null
var _key_hint_graph: Label   = null
var _key_hint_help: Label    = null
# First-time resource callout tracking.
var _first_action_spent: bool  = false
var _first_whisper_spent: bool = false

# Toast animation tweens.
var _toast_tween:       Tween = null
var _toast_slide_tween: Tween = null
var _flash_rect:        ColorRect = null
var _flash_tween:       Tween = null

# ── SPA-724: Goal reminder strip ────────────────────────────────────────────
var _goal_strip: Panel = null
var _goal_label: Label = null
var _goal_auto_hidden: bool = false  # true after player has taken enough actions

# ── SPA-724: Auto-show hint state ───────────────────────────────────────────
var _auto_hint_shown: bool = false

# ── Milestone queue (SPA-713) ───────────────────────────────────────────────
var _milestone_queue: Array = []  # [{text: String, color: Color}]
var _milestone_showing: bool = false
var _milestone_current_lbl: Label = null
var _milestone_dismiss_tween: Tween = null
const MILESTONE_DISPLAY_SEC := 3.5
const MILESTONE_QUEUE_GAP_SEC := 1.0

# Toast panel resting offsets — saved in _ready() for slide animation reference.
var _toast_normal_offset_top:    float = 0.0
var _toast_normal_offset_bottom: float = 0.0

# Track last pip counts to avoid rebuilding every frame.
var _last_action_max:   int   = -1
var _last_whisper_max:  int   = -1
var _last_action_rem:   int   = -1
var _last_whisper_rem:  int   = -1
## SPA-869: Track previous heat value for floating delta labels.
var _last_heat_val:     float = -1.0

# ── Recent Actions feed ──────────────────────────────────────────────────────
const FEED_MAX_ENTRIES := 5

## Each entry: {message: String, success: bool, tick: int}
var _feed_entries: Array = []
var _feed_panel:       Panel         = null
var _feed_vbox:        VBoxContainer = null
var _feed_toggle_btn:  Button        = null
var _feed_collapsed:   bool          = false
## Current day-night phase at last clear — feed clears on phase transition.
var _feed_last_phase:  String        = ""


func _ready() -> void:
	layer = 5
	toast_panel.visible = false
	_toast_normal_offset_top    = toast_panel.offset_top
	_toast_normal_offset_bottom = toast_panel.offset_bottom
	_build_section_headers()
	_build_pips(action_pips_row, 3, 3, PIP_FULL_ACTION, PIP_EMPTY_ACTION)
	_build_pips(whisper_pips_row, 2, 2, PIP_FULL_WHISPER, PIP_EMPTY_WHISPER)
	_build_count_labels()
	_build_heat_meter()
	_build_dawn_label()
	_build_extra_key_hints()
	_build_hint_button()
	_build_flash_overlay()
	_build_feed_panel()
	_setup_recon_tooltips()


func setup(intel_store: PlayerIntelStore, rumor_panel: CanvasLayer) -> void:
	_intel_store_ref = intel_store
	_rumor_panel_ref = rumor_panel
	_refresh_pips()


## Called by main.gd to provide world reference for contextual hint generation.
func setup_hints(world: Node2D) -> void:
	_world_ref = world


## Called by main.gd to provide journal + day_night refs for feed→journal navigation.
func setup_feed(journal: CanvasLayer, day_night: Node) -> void:
	_journal_ref  = journal
	_day_night_ref = day_night


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			if _rumor_panel_ref != null and _rumor_panel_ref.has_method("toggle"):
				_rumor_panel_ref.toggle()
			get_viewport().set_input_as_handled()


# ── Per-frame ─────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	_refresh_pips()


# ── Public API ────────────────────────────────────────────────────────────────

func show_toast(message: String, success: bool) -> void:
	var icon := "✓ " if success else "✗ "
	toast_label.text = icon + message
	var color := Color(0.894, 0.820, 0.659, 1.0) if success else Color(0.941, 0.510, 0.173, 1.0)  # PARCH_L / FORGE
	toast_label.add_theme_color_override("font_color", color)
	toast_label.add_theme_constant_override("outline_size", 2)
	toast_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	# Tint the toast border to match success/fail for stronger visual cue.
	var border_node: ColorRect = toast_panel.get_node_or_null("ToastBorder")
	if border_node != null:
		border_node.color = Color(0.30, 0.65, 0.25, 1.0) if success else Color(0.75, 0.30, 0.12, 1.0)
	show_action_flash(success)

	# Slide in from below, then fade out after TOAST_DURATION seconds.
	if _toast_tween != null:
		_toast_tween.kill()
	if _toast_slide_tween != null:
		_toast_slide_tween.kill()

	toast_panel.modulate.a = 1.0
	toast_panel.offset_top    = _toast_normal_offset_top    + 20.0
	toast_panel.offset_bottom = _toast_normal_offset_bottom + 20.0
	toast_panel.visible = true

	_toast_slide_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_toast_slide_tween.tween_property(toast_panel, "offset_top",    _toast_normal_offset_top,    0.18)
	_toast_slide_tween.parallel().tween_property(toast_panel, "offset_bottom", _toast_normal_offset_bottom, 0.18)

	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_DURATION)
	_toast_tween.tween_property(toast_panel, "modulate:a", 0.0, 0.35)
	_toast_tween.tween_callback(func() -> void: toast_panel.visible = false)


## Show a prominent milestone notification with queueing support (SPA-713).
## Notifications slide in from the right to upper-right, auto-dismiss after
## ~3.5 seconds, and can be clicked to dismiss early.  When multiple milestones
## fire in rapid succession they are queued with a 1-second gap.
func show_milestone(text: String, color: Color) -> void:
	_milestone_queue.append({"text": text, "color": color})
	if not _milestone_showing:
		_show_next_milestone()


func _show_next_milestone() -> void:
	if _milestone_queue.is_empty():
		_milestone_showing = false
		return
	_milestone_showing = true
	var entry: Dictionary = _milestone_queue.pop_front()
	var text: String = entry["text"]
	var color: Color = entry["color"]

	# Screen flash (subtle vignette).
	if _flash_rect != null:
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash_rect.color = Color(color.r, color.g, color.b, 0.18)
		_flash_tween = create_tween()
		_flash_tween.tween_property(_flash_rect, "color:a", 0.0, 0.6) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	# Build floating label — positioned upper-right so gameplay is not blocked.
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	# Upper-right positioning.
	lbl.anchor_left = 0.55
	lbl.anchor_right = 1.0
	lbl.anchor_top = 0.0
	lbl.anchor_bottom = 0.0
	lbl.offset_top = 60.0
	lbl.offset_right = -20.0
	lbl.offset_left = 0.0
	lbl.mouse_filter = Control.MOUSE_FILTER_STOP  # clickable to dismiss
	lbl.pivot_offset = Vector2(200, 14)
	lbl.modulate.a = 0.0
	add_child(lbl)
	_milestone_current_lbl = lbl

	# Click-to-dismiss.
	lbl.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			_dismiss_milestone(lbl)
	)

	# Slide in from right with scale bounce.
	lbl.offset_right = 200.0  # start off-screen right
	lbl.scale = Vector2(0.8, 0.8)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "offset_right", -20.0, 0.35)
	tw.tween_property(lbl, "scale", Vector2(1.05, 1.05), 0.3)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.15)

	# Settle scale.
	var tw_settle := create_tween()
	tw_settle.tween_interval(0.3)
	tw_settle.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.15)

	# Auto-dismiss after display duration.
	if _milestone_dismiss_tween != null and _milestone_dismiss_tween.is_valid():
		_milestone_dismiss_tween.kill()
	_milestone_dismiss_tween = create_tween()
	_milestone_dismiss_tween.tween_interval(MILESTONE_DISPLAY_SEC)
	_milestone_dismiss_tween.tween_callback(func() -> void:
		_dismiss_milestone(lbl)
	)


func _dismiss_milestone(lbl: Label) -> void:
	if lbl == null or not is_instance_valid(lbl):
		_advance_milestone_queue()
		return
	if _milestone_dismiss_tween != null and _milestone_dismiss_tween.is_valid():
		_milestone_dismiss_tween.kill()
	# Fade out and drift upward.
	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tw.tween_property(lbl, "offset_top", lbl.offset_top - 20.0, 0.4).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		lbl.queue_free()
		_advance_milestone_queue()
	)


func _advance_milestone_queue() -> void:
	_milestone_current_lbl = null
	if _milestone_queue.is_empty():
		_milestone_showing = false
		return
	# Gap between queued milestones.
	var gap_tw := create_tween()
	gap_tw.tween_interval(MILESTONE_QUEUE_GAP_SEC)
	gap_tw.tween_callback(_show_next_milestone)


# ── SPA-870: Section headers for visual grouping ────────────────────────────

## Build tiny section headers ("RESOURCES" / "THREAT") to visually separate
## player resource pips from threat/suspicion meters in the counter panel.
func _build_section_headers() -> void:
	var vbox: VBoxContainer = $CounterPanel/VBox

	# "RESOURCES" header — inserted before ActionsRow (index 0).
	_resources_header = _make_section_header("RESOURCES")
	vbox.add_child(_resources_header)
	vbox.move_child(_resources_header, 0)

	# "THREAT" header — inserted dynamically once heat meter is built
	# (see _build_heat_meter); create it here and keep it hidden until then.
	_threat_header = _make_section_header("THREAT")
	_threat_header.visible = false
	vbox.add_child(_threat_header)

	# Expand counter panel slightly to accommodate the new headers.
	var counter_panel: Panel = $CounterPanel
	counter_panel.offset_bottom += 22


func _make_section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.48, 0.35, 0.70))
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.4))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


# ── Count labels & extra key hints ───────────────────────────────────────────

func _build_count_labels() -> void:
	_action_count_label = Label.new()
	_action_count_label.add_theme_font_size_override("font_size", 16)
	_action_count_label.add_theme_color_override("font_color", PIP_FULL_ACTION)
	_action_count_label.add_theme_constant_override("outline_size", 3)
	_action_count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	action_pips_row.get_parent().add_child(_action_count_label)

	_whisper_count_label = Label.new()
	_whisper_count_label.add_theme_font_size_override("font_size", 16)
	_whisper_count_label.add_theme_color_override("font_color", PIP_FULL_WHISPER)
	_whisper_count_label.add_theme_constant_override("outline_size", 3)
	_whisper_count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	whisper_pips_row.get_parent().add_child(_whisper_count_label)


## Build a small label under the counter panel showing when actions refresh.
## Only visible when all actions have been spent.
func _build_dawn_label() -> void:
	_dawn_label = Label.new()
	_dawn_label.add_theme_font_size_override("font_size", 12)
	_dawn_label.add_theme_color_override("font_color", Color(0.75, 0.65, 0.40, 0.90))
	_dawn_label.add_theme_constant_override("outline_size", 2)
	_dawn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_dawn_label.text = ""
	_dawn_label.visible = false
	var vbox: VBoxContainer = $CounterPanel/VBox
	vbox.add_child(_dawn_label)
	# Move it just before the KeyHintRow.
	for i in vbox.get_child_count():
		if vbox.get_child(i).name == "KeyHintRow":
			vbox.move_child(_dawn_label, i)
			break


func _build_flash_overlay() -> void:
	_flash_rect = ColorRect.new()
	_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash_rect)


## Brief screen-edge flash to confirm an action visually.
func show_action_flash(success: bool) -> void:
	if _flash_rect == null:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	var color := Color(0.30, 0.85, 0.40, 0.18) if success else Color(0.95, 0.35, 0.15, 0.18)
	_flash_rect.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, FLASH_DURATION * 1.2) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


## Build a horizontal heat meter row: icon + "Heat" label + bar + numeric value.
## Inserted into the CounterPanel VBox between whispers and key hints.
func _build_heat_meter() -> void:
	var vbox: VBoxContainer = $CounterPanel/VBox
	_heat_row = HBoxContainer.new()
	_heat_row.add_theme_constant_override("separation", 4)
	_heat_row.visible = false  # hidden until heat_enabled

	# Flame icon
	var icon := Label.new()
	icon.text = "🔥"
	icon.add_theme_font_size_override("font_size", 12)
	icon.add_theme_color_override("font_color", Color(0.85, 0.45, 0.15, 1.0))
	_heat_row.add_child(icon)

	# "Heat" title
	var title := Label.new()
	title.text = "Heat"
	title.custom_minimum_size = Vector2(54, 0)
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.80, 0.72, 0.55, 1.0))
	_heat_row.add_child(title)

	# Bar background
	var bar_bg := Panel.new()
	bar_bg.custom_minimum_size = Vector2(96, 14)
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = C_HEAT_BG
	bar_style.set_corner_radius_all(3)
	bar_style.set_border_width_all(1)
	bar_style.border_color = Color(0.40, 0.28, 0.14, 0.6)
	bar_bg.add_theme_stylebox_override("panel", bar_style)
	_heat_row.add_child(bar_bg)

	# Bar fill
	_heat_bar_fill = ColorRect.new()
	_heat_bar_fill.anchor_bottom = 1.0
	_heat_bar_fill.anchor_right = 0.0
	_heat_bar_fill.color = C_HEAT_LOW
	bar_bg.add_child(_heat_bar_fill)

	# Numeric label
	_heat_count_lbl = Label.new()
	_heat_count_lbl.text = "0"
	_heat_count_lbl.add_theme_font_size_override("font_size", 12)
	_heat_count_lbl.add_theme_color_override("font_color", C_HEAT_LOW)
	_heat_row.add_child(_heat_count_lbl)

	_heat_row.tooltip_text = "Suspicion: highest NPC heat level (0-100). High heat makes NPCs reject your rumors."

	# Insert before KeyHintRow (index 2 = after ActionsRow, WhispersRow)
	var key_hint_idx: int = -1
	for i in vbox.get_child_count():
		if vbox.get_child(i).name == "KeyHintRow":
			key_hint_idx = i
			break
	if key_hint_idx >= 0:
		if _threat_header != null:
			vbox.move_child(_threat_header, key_hint_idx)
			_threat_header.visible = true
		vbox.add_child(_heat_row)
		vbox.move_child(_heat_row, key_hint_idx + 1)
	else:
		vbox.add_child(_heat_row)

	# Expand counter panel to fit the heat row when visible.
	var counter_panel: Panel = $CounterPanel
	counter_panel.offset_bottom += 18


func _refresh_heat() -> void:
	if _intel_store_ref == null or _heat_row == null:
		return
	if not _intel_store_ref.heat_enabled:
		_heat_row.visible = false
		if _threat_header != null:
			_threat_header.visible = false
		return
	_heat_row.visible = true
	if _threat_header != null:
		_threat_header.visible = true

	# Find the maximum heat across all NPCs as the player's "heat level."
	var max_heat: float = 0.0
	for npc_id in _intel_store_ref.heat:
		var h: float = _intel_store_ref.heat[npc_id]
		if h > max_heat:
			max_heat = h

	# SPA-869: Floating delta label when heat changes by at least 1 point.
	if _last_heat_val >= 0.0:
		var heat_delta: int = int(max_heat) - int(_last_heat_val)
		if heat_delta != 0:
			_spawn_heat_delta(heat_delta)
	_last_heat_val = max_heat

	# Resolve failure ceiling from the active scenario (if any).
	var ceiling: float = -1.0
	var sm = _world_ref.get("scenario_manager") if _world_ref != null else null
	if sm != null and sm.has_method("get_heat_ceiling"):
		ceiling = sm.get_heat_ceiling()

	var fraction: float = clampf(max_heat / 100.0, 0.0, 1.0)
	if _heat_bar_fill != null:
		_heat_bar_fill.anchor_right = fraction
		# Colour gradient: green → yellow → orange → red
		var heat_color: Color
		if fraction < 0.25:
			heat_color = C_HEAT_LOW
		elif fraction < 0.50:
			heat_color = C_HEAT_LOW.lerp(C_HEAT_MED, (fraction - 0.25) / 0.25)
		elif fraction < 0.75:
			heat_color = C_HEAT_MED.lerp(C_HEAT_HIGH, (fraction - 0.50) / 0.25)
		else:
			heat_color = C_HEAT_HIGH.lerp(C_HEAT_CRIT, (fraction - 0.75) / 0.25)
		_heat_bar_fill.color = heat_color
		if _heat_count_lbl != null:
			_heat_count_lbl.text = "%d" % int(max_heat)
			_heat_count_lbl.add_theme_color_override("font_color", heat_color)

	# Update tooltip to reflect the current failure ceiling.
	if _heat_row != null:
		if ceiling > 0.0:
			_heat_row.tooltip_text = (
				"Suspicion: highest NPC heat (0-100). Reaches %d → exposed, scenario fails!\n"
				+ "High heat also makes NPCs reject your rumors (−15%% at 50, −30%% at 75)."
			) % int(ceiling)
		else:
			_heat_row.tooltip_text = (
				"Suspicion: highest NPC heat (0-100). "
				+ "High heat makes NPCs reject your rumors (−15%% at 50, −30%% at 75)."
			)


func _build_extra_key_hints() -> void:
	var key_hint_row: HBoxContainer = $CounterPanel/VBox/KeyHintRow
	key_hint_row.add_theme_constant_override("separation", 6)
	_key_hint_rumor   = _add_key_hint(key_hint_row, "R", "Rumor", Color(0.92, 0.65, 0.12, 1.0))
	_key_hint_journal = _add_key_hint(key_hint_row, "J", "Journal", Color(0.894, 0.820, 0.659, 1.0))  # PARCH_L
	_key_hint_graph   = _add_key_hint(key_hint_row, "G", "Graph", Color(0.55, 0.75, 1.00, 1.0))
	_key_hint_help    = _add_key_hint(key_hint_row, "F1", "Help", Color(0.70, 0.65, 0.50, 1.0))


## Create a styled key hint badge with a subtle pulse animation.
func _add_key_hint(parent: HBoxContainer, key: String, label: String, accent: Color) -> Label:
	var hint := Label.new()
	hint.text = " %s: %s " % [key, label]
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", accent)
	hint.add_theme_constant_override("outline_size", 1)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	parent.add_child(hint)
	# Gentle pulse — loops 4 times then stops (draws attention without being annoying).
	var tw := create_tween().set_loops(4)
	var dim := Color(accent.r, accent.g, accent.b, 0.4)
	tw.tween_property(hint, "modulate", Color.WHITE, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(hint, "modulate", Color(dim.r, dim.g, dim.b, 0.6), 0.8).set_trans(Tween.TRANS_SINE)
	tw.finished.connect(func() -> void:
		hint.modulate = Color.WHITE
	)
	return hint


# ── SPA-870: Key hint availability styling ──────────────────────────────────

## Update key hint labels to show greyed-out state when the related resource
## is exhausted, with a tooltip explaining why.
func _refresh_key_hint_availability() -> void:
	if _intel_store_ref == null:
		return
	var whispers: int = _intel_store_ref.whisper_tokens_remaining

	# R: Rumor — requires whisper tokens.
	if _key_hint_rumor != null:
		if whispers <= 0:
			_key_hint_rumor.modulate = Color(1.0, 1.0, 1.0, 0.30)
			_key_hint_rumor.tooltip_text = "Craft Rumor (R)\nUnavailable — no Whisper Tokens remaining.\nTokens refresh at dawn."
		else:
			_key_hint_rumor.modulate = Color.WHITE
			_key_hint_rumor.tooltip_text = "Craft Rumor (R)\nOpen the Rumor Crafting panel to create and seed a new rumor.\nCosts 1 Whisper Token."
		_key_hint_rumor.mouse_filter = Control.MOUSE_FILTER_PASS

	# J: Journal — always available.
	if _key_hint_journal != null:
		_key_hint_journal.tooltip_text = "Journal (J)\nReview your rumors, intel, faction standings, and objectives."
		_key_hint_journal.mouse_filter = Control.MOUSE_FILTER_PASS

	# G: Graph — always available.
	if _key_hint_graph != null:
		_key_hint_graph.tooltip_text = "Social Graph (G)\nVisualize NPC relationships and find the best paths to spread rumors."
		_key_hint_graph.mouse_filter = Control.MOUSE_FILTER_PASS

	# F1: Help — always available.
	if _key_hint_help != null:
		_key_hint_help.tooltip_text = "Help (F1)\nOpen the tutorial and help overlay."
		_key_hint_help.mouse_filter = Control.MOUSE_FILTER_PASS


# ── SPA-870: First-time resource change callouts ────────────────────────────

## Show a brief toast explaining what happened when a resource changes for the
## first time, helping new players understand the resource economy.
func _check_first_time_callouts(old_actions: int, new_actions: int,
		old_whispers: int, new_whispers: int) -> void:
	if not _first_action_spent and old_actions > 0 and new_actions < old_actions:
		_first_action_spent = true
		show_toast("Action spent! You used a Recon Action. Right-click NPCs or buildings for more intel.", true)
	if not _first_whisper_spent and old_whispers > 0 and new_whispers < old_whispers:
		_first_whisper_spent = true
		show_toast("Whisper spent! Your rumor is now seeded. Watch it spread through the town.", true)


# ── Recent Actions feed ──────────────────────────────────────────────────────

func _build_feed_panel() -> void:
	_feed_panel = Panel.new()
	_feed_panel.anchor_left   = 1.0
	_feed_panel.anchor_right  = 1.0
	_feed_panel.anchor_top    = 1.0
	_feed_panel.anchor_bottom = 1.0
	_feed_panel.offset_left   = -320.0
	_feed_panel.offset_top    = -160.0
	_feed_panel.offset_right  = -6.0
	_feed_panel.offset_bottom = -6.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.05, 0.03, 0.92)
	panel_style.set_border_width_all(1)
	panel_style.border_color = Color(0.55, 0.38, 0.18, 0.7)
	panel_style.set_corner_radius_all(4)
	panel_style.set_content_margin_all(6)
	_feed_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_feed_panel)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_vbox.offset_left   = 6.0
	outer_vbox.offset_top    = 4.0
	outer_vbox.offset_right  = -6.0
	outer_vbox.offset_bottom = -4.0
	outer_vbox.add_theme_constant_override("separation", 2)
	_feed_panel.add_child(outer_vbox)

	# Header row with toggle button.
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 4)
	outer_vbox.add_child(header_row)

	var title_lbl := Label.new()
	title_lbl.text = "Recent Actions"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.12, 1.0))
	title_lbl.add_theme_constant_override("outline_size", 1)
	title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title_lbl)

	_feed_toggle_btn = Button.new()
	_feed_toggle_btn.text = "▼"
	_feed_toggle_btn.add_theme_font_size_override("font_size", 10)
	_feed_toggle_btn.custom_minimum_size = Vector2(22, 18)
	var toggle_style := StyleBoxFlat.new()
	toggle_style.bg_color = Color(0.20, 0.14, 0.08, 0.8)
	toggle_style.set_corner_radius_all(3)
	toggle_style.set_content_margin_all(1)
	_feed_toggle_btn.add_theme_stylebox_override("normal", toggle_style)
	_feed_toggle_btn.pressed.connect(_on_feed_toggle)
	header_row.add_child(_feed_toggle_btn)

	_feed_vbox = VBoxContainer.new()
	_feed_vbox.add_theme_constant_override("separation", 1)
	outer_vbox.add_child(_feed_vbox)

	_feed_panel.visible = false  # hidden until first action


func _on_feed_toggle() -> void:
	_feed_collapsed = not _feed_collapsed
	_feed_toggle_btn.text = "▲" if _feed_collapsed else "▼"
	_feed_vbox.visible = not _feed_collapsed


# ── SPA-724: Goal reminder strip ────────────────────────────────────────────

## Build a compact goal strip below the counter panel showing the current objective.
## Fades out after a few actions so it doesn't permanently clutter the HUD.
func build_goal_strip(goal_text: String) -> void:
	if _goal_strip != null:
		return  # already built
	_goal_strip = Panel.new()
	_goal_strip.anchor_left  = 1.0
	_goal_strip.anchor_right = 1.0
	_goal_strip.anchor_top   = 0.0
	_goal_strip.anchor_bottom = 0.0
	# Position just below the counter panel.
	var counter_bottom: float = $CounterPanel.offset_bottom + 4.0
	_goal_strip.offset_left   = $CounterPanel.offset_left
	_goal_strip.offset_right  = $CounterPanel.offset_right
	_goal_strip.offset_top    = counter_bottom
	_goal_strip.offset_bottom = counter_bottom + 28.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.02, 0.88)
	style.set_border_width_all(1)
	style.border_color = Color(0.55, 0.38, 0.18, 0.5)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	_goal_strip.add_theme_stylebox_override("panel", style)
	_goal_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_goal_strip)

	_goal_label = Label.new()
	_goal_label.text = goal_text
	_goal_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_goal_label.offset_left = 6
	_goal_label.offset_right = -6
	_goal_label.add_theme_font_size_override("font_size", 11)
	_goal_label.add_theme_color_override("font_color", Color(0.90, 0.78, 0.45, 0.9))
	_goal_label.add_theme_constant_override("outline_size", 1)
	_goal_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal_strip.add_child(_goal_label)


## Fade out the goal strip once the player has enough context (called after N actions).
func fade_goal_strip() -> void:
	if _goal_strip == null or _goal_auto_hidden:
		return
	_goal_auto_hidden = true
	var tw := create_tween()
	tw.tween_property(_goal_strip, "modulate:a", 0.0, 1.5) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func() -> void: _goal_strip.visible = false)


# ── SPA-724: Auto-show contextual hint on game start ────────────────────────

## Called by main.gd after ReadyOverlay is dismissed to show the first guidance
## automatically without requiring the player to find and click "? What next".
func auto_show_initial_hint() -> void:
	if _auto_hint_shown:
		return
	_auto_hint_shown = true
	# Delay slightly so the game world is visible first.
	var timer := get_tree().create_timer(1.5)
	timer.timeout.connect(func() -> void:
		_on_hint_pressed()
	)


## Push an action result into the feed. Called alongside show_toast.
func push_feed_entry(message: String, success: bool) -> void:
	var tick: int = 0
	if _day_night_ref != null and "current_tick" in _day_night_ref:
		tick = _day_night_ref.current_tick

	# Clear feed on phase transition.
	var current_phase: String = ""
	if _day_night_ref != null and "current_phase" in _day_night_ref:
		current_phase = str(_day_night_ref.current_phase)
	if not current_phase.is_empty() and current_phase != _feed_last_phase and not _feed_last_phase.is_empty():
		_feed_entries.clear()
	_feed_last_phase = current_phase

	_feed_entries.push_front({"message": message, "success": success, "tick": tick})
	if _feed_entries.size() > FEED_MAX_ENTRIES:
		_feed_entries.resize(FEED_MAX_ENTRIES)
	_rebuild_feed()
	_feed_panel.visible = true


func _rebuild_feed() -> void:
	for child in _feed_vbox.get_children():
		child.queue_free()

	for i in _feed_entries.size():
		var entry: Dictionary = _feed_entries[i]
		var btn := Button.new()
		var icon := "✓" if entry["success"] else "✗"
		btn.text = "%s %s" % [icon, entry["message"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 11)
		var text_color := Color(0.75, 0.85, 0.65, 1.0) if entry["success"] else Color(0.90, 0.55, 0.35, 1.0)
		btn.add_theme_color_override("font_color", text_color)
		btn.clip_text = true
		btn.custom_minimum_size = Vector2(0, 20)
		# Transparent flat style so it looks like a label but is clickable.
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		btn_style.set_content_margin_all(1)
		btn.add_theme_stylebox_override("normal", btn_style)
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color(0.30, 0.22, 0.10, 0.5)
		hover_style.set_corner_radius_all(2)
		hover_style.set_content_margin_all(1)
		btn.add_theme_stylebox_override("hover", hover_style)
		var focus_style := StyleBoxFlat.new()
		focus_style.bg_color = Color(0.30, 0.22, 0.10, 0.5)
		focus_style.set_border_width_all(1)
		focus_style.border_color = Color(1.0, 0.9, 0.4, 1.0)
		focus_style.set_corner_radius_all(2)
		focus_style.set_content_margin_all(1)
		btn.add_theme_stylebox_override("focus", focus_style)
		btn.tooltip_text = "Click to open Timeline filtered to this event"
		var filter_text: String = entry["message"]
		btn.pressed.connect(_on_feed_entry_clicked.bind(filter_text))
		_feed_vbox.add_child(btn)


func _on_feed_entry_clicked(filter_text: String) -> void:
	if _journal_ref == null:
		return
	if _journal_ref.has_method("open_to_timeline"):
		_journal_ref.open_to_timeline(filter_text, true)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _refresh_pips() -> void:
	if _intel_store_ref == null:
		return

	var remaining: int = _intel_store_ref.recon_actions_remaining
	var max_val:   int = _intel_store_ref.max_daily_actions
	var whispers:  int = _intel_store_ref.whisper_tokens_remaining
	var max_w:     int = _intel_store_ref.max_daily_whispers
	var favors:    int = _intel_store_ref.bribe_charges

	# Rebuild pips only when max changes; update colours when remaining changes.
	if max_val != _last_action_max:
		_build_pips(action_pips_row, remaining, max_val, PIP_FULL_ACTION, PIP_EMPTY_ACTION)
		_last_action_max = max_val
		_last_action_rem = remaining
	elif remaining != _last_action_rem:
		var _old_action := _last_action_rem
		_update_pips(action_pips_row, remaining, PIP_FULL_ACTION, PIP_EMPTY_ACTION)
		_last_action_rem = remaining
		# SPA-861: Floating delta label near the action counter.
		if _old_action >= 0:
			_spawn_pip_delta(remaining - _old_action, true)

	if max_w != _last_whisper_max:
		_build_pips(whisper_pips_row, whispers, max_w, PIP_FULL_WHISPER, PIP_EMPTY_WHISPER)
		_last_whisper_max = max_w
		_last_whisper_rem = whispers
	elif whispers != _last_whisper_rem:
		var _old_whisper := _last_whisper_rem
		_update_pips(whisper_pips_row, whispers, PIP_FULL_WHISPER, PIP_EMPTY_WHISPER)
		_last_whisper_rem = whispers
		# SPA-861: Floating delta label near the whisper counter.
		if _old_whisper >= 0:
			_spawn_pip_delta(whispers - _old_whisper, false)

	# Update row tooltips so hovering the pip area explains the resource.
	action_pips_row.get_parent().tooltip_text = "Recon Actions: %d / %d remaining\nRight-click buildings to Observe, NPCs to Eavesdrop.\nRefreshes at dawn each day." % [remaining, max_val]
	whisper_pips_row.get_parent().tooltip_text = "Whisper Tokens: %d / %d remaining\nPress R to craft and seed a rumor.\nRefreshes at dawn each day." % [whispers, max_w]
	action_pips_row.get_parent().mouse_filter = Control.MOUSE_FILTER_PASS
	whisper_pips_row.get_parent().mouse_filter = Control.MOUSE_FILTER_PASS

	# Show dawn refresh hint when all actions and whispers are spent.
	if _dawn_label != null:
		if remaining == 0 and whispers == 0:
			_dawn_label.text = "☀ Actions refresh at dawn"
			_dawn_label.visible = true
		else:
			_dawn_label.visible = false

	# Update numeric count labels beside pips.
	if _action_count_label != null:
		_action_count_label.text = "%d/%d" % [remaining, max_val]
	if _whisper_count_label != null:
		_whisper_count_label.text = "%d/%d" % [whispers, max_w]

	# Heat meter.
	_refresh_heat()

	# Favors row.
	var show_favors: bool = _intel_store_ref.heat_enabled or favors > 0
	if favors_row != null:
		favors_row.visible = show_favors
		if show_favors:
			favors_label.text = str(favors)
			favors_row.tooltip_text = "Favors: %d available (bribe NPCs to reduce suspicion)" % favors


# ── "What should I do?" hint button ──────────────────────────────────────────

func _build_hint_button() -> void:
	var key_hint_row: HBoxContainer = $CounterPanel/VBox/KeyHintRow
	_hint_btn = Button.new()
	_hint_btn.text = "? What next"
	_hint_btn.custom_minimum_size = Vector2(90, 22)
	_hint_btn.add_theme_font_size_override("font_size", 12)
	_hint_btn.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55, 1.0))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.15, 0.06, 0.85)
	style.set_border_width_all(1)
	style.border_color = Color(0.55, 0.38, 0.18, 0.7)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(2)
	_hint_btn.add_theme_stylebox_override("normal", style)
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.40, 0.25, 0.08, 0.95)
	hover_style.set_border_width_all(1)
	hover_style.border_color = Color(0.75, 0.55, 0.20, 1.0)
	hover_style.set_corner_radius_all(3)
	hover_style.set_content_margin_all(2)
	_hint_btn.add_theme_stylebox_override("hover", hover_style)
	_hint_btn.tooltip_text = "Get a context-aware hint about your next best action."
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(0.40, 0.25, 0.08, 0.95)
	focus_style.set_border_width_all(2)
	focus_style.border_color = Color(1.00, 0.90, 0.40, 1.0)
	focus_style.set_corner_radius_all(3)
	focus_style.set_content_margin_all(2)
	_hint_btn.add_theme_stylebox_override("focus", focus_style)
	_hint_btn.pressed.connect(_on_hint_pressed)
	key_hint_row.add_child(_hint_btn)

	# Hint display label (below counter panel, hidden by default).
	_hint_label = Label.new()
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.anchor_left = 0.55
	_hint_label.anchor_right = 0.98
	_hint_label.anchor_top = 0.0
	_hint_label.anchor_bottom = 0.0
	_hint_label.offset_top = 80.0
	_hint_label.offset_bottom = 160.0
	_hint_label.add_theme_font_size_override("font_size", 12)
	_hint_label.add_theme_color_override("font_color", Color(0.95, 0.88, 0.65, 1.0))
	_hint_label.add_theme_constant_override("outline_size", 2)
	_hint_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.02, 0.9))
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.modulate.a = 0.0
	_hint_label.visible = false
	add_child(_hint_label)


func _on_hint_pressed() -> void:
	AudioManager.play_sfx("ui_click")
	var hint := _generate_contextual_hint()
	_hint_label.text = hint
	_hint_label.visible = true
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_label.modulate.a = 0.0
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint_label, "modulate:a", 1.0, 0.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_hint_tween.tween_interval(8.0)
	_hint_tween.tween_property(_hint_label, "modulate:a", 0.0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_hint_tween.tween_callback(func() -> void: _hint_label.visible = false)


## Generate a context-aware hint based on current game state.
func _generate_contextual_hint() -> String:
	if _intel_store_ref == null:
		return "Explore the town. Right-click buildings to Observe, or right-click NPCs in conversation to Eavesdrop."

	var actions: int = _intel_store_ref.recon_actions_remaining
	var whispers: int = _intel_store_ref.whisper_tokens_remaining
	var observations: int = _intel_store_ref.get_observation_count() if _intel_store_ref.has_method("get_observation_count") else -1
	var relationships: int = _intel_store_ref.get_relationship_count() if _intel_store_ref.has_method("get_relationship_count") else -1

	# Priority 1: No actions or whispers left — wait for dawn.
	if actions == 0 and whispers == 0:
		return "You have used all actions and whispers for today. Speed up time and wait for dawn — resources refresh each morning."

	# Priority 2: Has whispers but no rumor seeded yet — encourage crafting.
	if whispers > 0 and _world_ref != null:
		var npcs := _world_ref.get_node_or_null("NPCContainer")
		var any_rumor_active := false
		if npcs != null:
			for npc in npcs.get_children():
				if "rumor_slots" in npc and npc.rumor_slots.size() > 0:
					any_rumor_active = true
					break
		if not any_rumor_active:
			return "No rumors are active yet! Press R to craft your first rumor. Pick a well-connected seed target to spread it fast."

	# Priority 3: Has actions — encourage gathering intel.
	if actions > 0 and (observations < 2 if observations >= 0 else true):
		return "You have %d actions remaining. Right-click a busy building to Observe who is present — this helps you find the best seed targets." % actions

	if actions > 0 and (relationships < 2 if relationships >= 0 else true):
		return "Try eavesdropping! Right-click two NPCs in conversation to learn their relationship. Allied NPCs spread rumors fastest."

	# Priority 4: Has whispers remaining.
	if whispers > 0:
		return "You have %d whisper token%s. Press R to craft a rumor. Choose a high-intensity claim and a well-connected seed target for maximum impact." % [whispers, "" if whispers == 1 else "s"]

	# Priority 5: Everything used — general guidance.
	if actions > 0:
		return "Use your remaining %d action%s to Observe buildings or Eavesdrop on conversations. More intel means better rumor targeting." % [actions, "" if actions == 1 else "s"]

	return "Check your Journal (J) for objectives and progress. Open the Social Graph (G) to find the strongest paths to your target."


## SPA-861: Spawn a floating "+N" or "−N" label near the pip row for the given resource.
## is_action=true → Recon Actions (amber), false → Whisper Tokens (blue).
## Positive delta (dawn refresh) shows green; negative delta (spent) shows the resource colour.
func _spawn_pip_delta(delta: int, is_action: bool) -> void:
	if delta == 0:
		return
	var lbl := Label.new()
	var sign := "+" if delta > 0 else ""
	lbl.text = "%s%d" % [sign, delta]
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	var color: Color
	if delta > 0:
		color = Color(0.45, 1.00, 0.55, 1.0)  # green for refreshed tokens
	elif is_action:
		color = Color(0.95, 0.60, 0.15, 1.0)  # amber for spent action
	else:
		color = Color(0.45, 0.65, 0.90, 1.0)  # steel blue for spent whisper
	lbl.add_theme_color_override("font_color", color)

	# Position near the relevant pip row using its screen position.
	var source_row: HBoxContainer = action_pips_row if is_action else whisper_pips_row
	var row_pos: Vector2 = source_row.global_position
	var spawn_x: float = row_pos.x + source_row.size.x * 0.5 - 8.0
	var spawn_y: float = row_pos.y - 2.0
	lbl.position = Vector2(spawn_x, spawn_y)
	add_child(lbl)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "position",
		Vector2(spawn_x + randf_range(-6.0, 6.0), spawn_y - 38.0), 0.85) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.85).set_delay(0.30)
	tw.chain().tween_callback(lbl.queue_free)


## SPA-869: Spawn a floating "+N" or "−N" label near the heat bar when heat changes.
## Red for heat increases, green for decreases.
func _spawn_heat_delta(delta: int) -> void:
	if delta == 0 or _heat_row == null:
		return
	var lbl := Label.new()
	var sign := "+" if delta > 0 else ""
	lbl.text = "%s%d" % [sign, delta]
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_constant_override("outline_size", 2)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	var hcolor: Color = Color(0.95, 0.25, 0.20, 1.0) if delta > 0 else Color(0.45, 1.00, 0.55, 1.0)
	lbl.add_theme_color_override("font_color", hcolor)

	var hrow_pos: Vector2 = _heat_row.global_position
	var hspawn_x: float = hrow_pos.x + _heat_row.size.x * 0.5 - 8.0
	var hspawn_y: float = hrow_pos.y - 2.0
	lbl.position = Vector2(hspawn_x, hspawn_y)
	add_child(lbl)

	var htw := create_tween().set_parallel(true)
	htw.tween_property(lbl, "position",
		Vector2(hspawn_x + randf_range(-6.0, 6.0), hspawn_y - 30.0), 0.80) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	htw.tween_property(lbl, "modulate:a", 0.0, 0.80).set_delay(0.25)
	htw.chain().tween_callback(lbl.queue_free)


## Rebuild pip children entirely (when max changes).
func _build_pips(
		container: HBoxContainer, remaining: int, total: int,
		full_color: Color, empty_color: Color
) -> void:
	for child in container.get_children():
		child.queue_free()
	for i in total:
		var pip := Panel.new()
		pip.custom_minimum_size = PIP_SIZE
		var style := StyleBoxFlat.new()
		style.bg_color = full_color if i < remaining else empty_color
		style.set_corner_radius_all(9)
		style.set_border_width_all(1)
		style.border_color = Color(full_color.r, full_color.g, full_color.b, 0.45) if i < remaining else Color(full_color.r, full_color.g, full_color.b, 0.20)
		pip.add_theme_stylebox_override("panel", style)
		container.add_child(pip)


## Update pip colours without rebuilding (when remaining changes, max stays same).
## Pips that just became empty get a bounce + fade animation for juicy feedback.
func _update_pips(
		container: HBoxContainer, remaining: int,
		full_color: Color, empty_color: Color
) -> void:
	var pips := container.get_children()
	for i in pips.size():
		var pip: Panel = pips[i] as Panel
		var style := pip.get_theme_stylebox("panel") as StyleBoxFlat
		if style == null:
			continue
		var was_full := (style.bg_color == full_color)
		var now_empty := (i >= remaining)
		style.bg_color = full_color if i < remaining else empty_color
		# Animate the pip that was just consumed.
		if was_full and now_empty:
			pip.pivot_offset = PIP_SIZE * 0.5
			var tw := pip.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(pip, "scale", Vector2(1.5, 1.5), 0.08)
			tw.tween_property(pip, "scale", Vector2.ONE, 0.18)


# ── SPA-767: Recon HUD tooltips & visual indicators ─────────────────────────

func _setup_recon_tooltips() -> void:
	# Counter panel overall tooltip.
	var counter_panel: Panel = $CounterPanel
	counter_panel.tooltip_text = "Recon Resources\nYour daily action and whisper token budget.\nResources refresh at the start of each new day."
	counter_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	# Heat meter tooltip (set dynamically, but provide a default).
	if _heat_row != null:
		_heat_row.tooltip_text = "Town Suspicion\nHow suspicious the townsfolk are of your activities.\nHigh heat reduces rumor believability and can trigger exposure."
		_heat_row.mouse_filter = Control.MOUSE_FILTER_PASS

	# Feed panel tooltip.
	if _feed_panel != null:
		_feed_panel.tooltip_text = "Recent Actions\nYour last few recon actions and their results.\nClick an entry to filter the Journal to that event."

	# Key hints row.
	var key_hint_row: HBoxContainer = $CounterPanel/VBox/KeyHintRow
	key_hint_row.tooltip_text = "Quick Actions\nKeyboard shortcuts to open game panels.\nR: Rumor crafting | J: Journal | G: Social Graph | F1: Help"
	key_hint_row.mouse_filter = Control.MOUSE_FILTER_PASS


## SPA-767: Update heat meter tooltip with live values for richer context.
func _update_heat_tooltip(heat_val: int) -> void:
	if _heat_row == null:
		return
	var severity := "Safe"
	var effect := "No effect on rumor believability."
	if heat_val > 75:
		severity = "CRITICAL"
		effect = "Severe penalty to believability. Risk of exposure!"
	elif heat_val > 50:
		severity = "Danger"
		effect = "-30% rumor believability."
	elif heat_val > 25:
		severity = "Caution"
		effect = "-15% rumor believability."
	_heat_row.tooltip_text = "Town Suspicion: %d/100 (%s)\n%s\nReduce heat by using Favors (bribes) or waiting." % [heat_val, severity, effect]
