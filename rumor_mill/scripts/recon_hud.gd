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

const PIP_SIZE := Vector2(14, 14)

var _intel_store_ref:  PlayerIntelStore = null
var _rumor_panel_ref:  CanvasLayer      = null
var _world_ref:        Node2D           = null
var _hint_btn:         Button           = null
var _hint_label:       Label            = null
var _hint_tween:       Tween            = null

# Toast animation tweens.
var _toast_tween:       Tween = null
var _toast_slide_tween: Tween = null
var _flash_rect:        ColorRect = null
var _flash_tween:       Tween = null

# Toast panel resting offsets — saved in _ready() for slide animation reference.
var _toast_normal_offset_top:    float = 0.0
var _toast_normal_offset_bottom: float = 0.0

# Track last pip counts to avoid rebuilding every frame.
var _last_action_max:   int = -1
var _last_whisper_max:  int = -1
var _last_action_rem:   int = -1
var _last_whisper_rem:  int = -1


func _ready() -> void:
	layer = 5
	toast_panel.visible = false
	_toast_normal_offset_top    = toast_panel.offset_top
	_toast_normal_offset_bottom = toast_panel.offset_bottom
	_build_pips(action_pips_row, 3, 3, PIP_FULL_ACTION, PIP_EMPTY_ACTION)
	_build_pips(whisper_pips_row, 2, 2, PIP_FULL_WHISPER, PIP_EMPTY_WHISPER)
	_build_count_labels()
	_build_extra_key_hints()
	_build_hint_button()
	_build_flash_overlay()


func setup(intel_store: PlayerIntelStore, rumor_panel: CanvasLayer) -> void:
	_intel_store_ref = intel_store
	_rumor_panel_ref = rumor_panel
	_refresh_pips()


## Called by main.gd to provide world reference for contextual hint generation.
func setup_hints(world: Node2D) -> void:
	_world_ref = world


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
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


## Show a prominent floating milestone label for major game events.
## The label appears centred, scales up, and fades out over ~2 seconds.
func show_milestone(text: String, color: Color) -> void:
	# Strong screen flash.
	if _flash_rect != null:
		if _flash_tween != null and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash_rect.color = Color(color.r, color.g, color.b, 0.18)
		_flash_tween = create_tween()
		_flash_tween.tween_property(_flash_rect, "color:a", 0.0, 0.6) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

	# Floating label.
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.pivot_offset = Vector2(150, 12)  # approximate centre
	lbl.scale = Vector2(0.7, 0.7)
	add_child(lbl)

	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.3)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.15)
	var tw2 := create_tween()
	tw2.tween_interval(1.5)
	tw2.tween_property(lbl, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN)
	tw2.tween_property(lbl, "position:y", lbl.position.y - 30.0, 0.8).set_ease(Tween.EASE_IN)
	tw2.tween_callback(lbl.queue_free)


# ── Count labels & extra key hints ───────────────────────────────────────────

func _build_count_labels() -> void:
	_action_count_label = Label.new()
	_action_count_label.add_theme_font_size_override("font_size", 11)
	_action_count_label.add_theme_color_override("font_color", PIP_FULL_ACTION)
	action_pips_row.get_parent().add_child(_action_count_label)

	_whisper_count_label = Label.new()
	_whisper_count_label.add_theme_font_size_override("font_size", 11)
	_whisper_count_label.add_theme_color_override("font_color", PIP_FULL_WHISPER)
	whisper_pips_row.get_parent().add_child(_whisper_count_label)


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
	var color := Color(0.30, 0.85, 0.40, 0.12) if success else Color(0.95, 0.35, 0.15, 0.12)
	_flash_rect.color = color
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash_rect, "color:a", 0.0, FLASH_DURATION) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)


func _build_extra_key_hints() -> void:
	var key_hint_row: HBoxContainer = $CounterPanel/VBox/KeyHintRow
	key_hint_row.add_theme_constant_override("separation", 6)
	_add_key_hint(key_hint_row, "R", "Rumor", Color(0.92, 0.65, 0.12, 1.0))
	_add_key_hint(key_hint_row, "J", "Journal", Color(0.894, 0.820, 0.659, 1.0))  # PARCH_L
	_add_key_hint(key_hint_row, "G", "Graph", Color(0.55, 0.75, 1.00, 1.0))


## Create a styled key hint badge with a subtle pulse animation.
func _add_key_hint(parent: HBoxContainer, key: String, label: String, accent: Color) -> void:
	var hint := Label.new()
	hint.text = " %s: %s " % [key, label]
	hint.add_theme_font_size_override("font_size", 11)
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
		_update_pips(action_pips_row, remaining, PIP_FULL_ACTION, PIP_EMPTY_ACTION)
		_last_action_rem = remaining

	if max_w != _last_whisper_max:
		_build_pips(whisper_pips_row, whispers, max_w, PIP_FULL_WHISPER, PIP_EMPTY_WHISPER)
		_last_whisper_max = max_w
		_last_whisper_rem = whispers
	elif whispers != _last_whisper_rem:
		_update_pips(whisper_pips_row, whispers, PIP_FULL_WHISPER, PIP_EMPTY_WHISPER)
		_last_whisper_rem = whispers

	# Update row tooltips so hovering the pip area explains the resource.
	action_pips_row.get_parent().tooltip_text = "Recon Actions: %d / %d remaining (refresh at dawn)" % [remaining, max_val]
	whisper_pips_row.get_parent().tooltip_text = "Whisper Tokens: %d / %d remaining (press R to craft a rumor)" % [whispers, max_w]

	# Update numeric count labels beside pips.
	if _action_count_label != null:
		_action_count_label.text = "%d/%d" % [remaining, max_val]
	if _whisper_count_label != null:
		_whisper_count_label.text = "%d/%d" % [whispers, max_w]

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
	_hint_btn.add_theme_font_size_override("font_size", 10)
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
		style.set_corner_radius_all(7)
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
