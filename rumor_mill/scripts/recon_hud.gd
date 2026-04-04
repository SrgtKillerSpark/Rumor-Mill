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

const TOAST_DURATION := 3.5

# Pip colours
const PIP_FULL_ACTION   := Color(0.92, 0.65, 0.12, 1.0)  # amber
const PIP_EMPTY_ACTION  := Color(0.30, 0.22, 0.12, 1.0)  # dark
const PIP_FULL_WHISPER  := Color(0.45, 0.75, 1.00, 1.0)  # pale blue
const PIP_EMPTY_WHISPER := Color(0.15, 0.20, 0.28, 1.0)  # dark blue

const PIP_SIZE := Vector2(14, 14)

var _intel_store_ref:  PlayerIntelStore = null
var _rumor_panel_ref:  CanvasLayer      = null

# Toast animation tweens.
var _toast_tween:       Tween = null
var _toast_slide_tween: Tween = null

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
	_build_pips(whisper_pips_row, 1, 1, PIP_FULL_WHISPER, PIP_EMPTY_WHISPER)


func setup(intel_store: PlayerIntelStore, rumor_panel: CanvasLayer) -> void:
	_intel_store_ref = intel_store
	_rumor_panel_ref = rumor_panel
	_refresh_pips()


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
	var color := Color(0.45, 1.00, 0.55, 1.0) if success else Color(1.00, 0.60, 0.20, 1.0)
	toast_label.add_theme_color_override("font_color", color)

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

	# Favors row.
	var show_favors: bool = _intel_store_ref.heat_enabled or favors > 0
	if favors_row != null:
		favors_row.visible = show_favors
		if show_favors:
			favors_label.text = str(favors)


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
func _update_pips(
		container: HBoxContainer, remaining: int,
		full_color: Color, empty_color: Color
) -> void:
	var pips := container.get_children()
	for i in pips.size():
		var style := (pips[i] as Panel).get_theme_stylebox("panel") as StyleBoxFlat
		if style != null:
			style.bg_color = full_color if i < remaining else empty_color
