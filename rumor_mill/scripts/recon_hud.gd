extends CanvasLayer

## recon_hud.gd — Sprint 3 Reconnaissance HUD overlay.
##
## Displays:
##   • Daily Recon action counter (top-right corner)
##   • Toast notifications for action results (centre-bottom)
##
## Press R to toggle the Rumor Crafting Panel 1 (RumorPanel).
## Call setup(intel_store, rumor_panel) after the scene tree is ready.

@onready var counter_label: Label = $CounterPanel/CounterLabel
@onready var toast_panel:   Panel = $ToastPanel
@onready var toast_label:   Label = $ToastPanel/ToastLabel

const TOAST_DURATION   := 3.5   ## seconds the toast is shown
const TOAST_SLIDE_IN   := 0.22  ## seconds for the slide-in tween
const TOAST_SLIDE_OUT  := 0.18  ## seconds for the slide-out tween
const TOAST_OFFSET_TOP := -56.0 ## resting offset_top (from .tscn)

var _intel_store_ref:  PlayerIntelStore = null
var _rumor_panel_ref:  CanvasLayer      = null
var _toast_timer:      float            = 0.0
var _toast_tween:      Tween            = null


func _ready() -> void:
	layer = 5
	toast_panel.visible = false
	_refresh_counter()


func setup(intel_store: PlayerIntelStore, rumor_panel: CanvasLayer) -> void:
	_intel_store_ref = intel_store
	_rumor_panel_ref = rumor_panel
	_refresh_counter()


# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			if _rumor_panel_ref != null and _rumor_panel_ref.has_method("toggle"):
				_rumor_panel_ref.toggle()
			get_viewport().set_input_as_handled()


# ── Per-frame ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	# Keep counter in sync every frame (cheap label update).
	_refresh_counter()

	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_slide_out_toast()


# ── Public API ────────────────────────────────────────────────────────────────

## Called by ReconController's action_performed signal.
func show_toast(message: String, success: bool) -> void:
	toast_label.text = message
	var color := Color(0.3, 1.0, 0.4, 1.0) if success else Color(1.0, 0.65, 0.2, 1.0)
	toast_label.add_theme_color_override("font_color", color)
	_toast_timer = TOAST_DURATION
	_slide_in_toast()


func _slide_in_toast() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_panel.visible       = true
	toast_panel.offset_top    = 10.0
	toast_panel.offset_bottom = TOAST_OFFSET_TOP + 10.0 + 52.0  # maintain panel height
	_toast_tween = create_tween()
	_toast_tween.set_ease(Tween.EASE_OUT)
	_toast_tween.set_trans(Tween.TRANS_CUBIC)
	_toast_tween.tween_property(toast_panel, "offset_top",    TOAST_OFFSET_TOP, TOAST_SLIDE_IN)
	_toast_tween.parallel().tween_property(toast_panel, "offset_bottom", -4.0, TOAST_SLIDE_IN)


func _slide_out_toast() -> void:
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.set_ease(Tween.EASE_IN)
	_toast_tween.set_trans(Tween.TRANS_CUBIC)
	_toast_tween.tween_property(toast_panel, "offset_top",    10.0, TOAST_SLIDE_OUT)
	_toast_tween.parallel().tween_property(toast_panel, "offset_bottom",
		TOAST_OFFSET_TOP + 10.0 + 52.0, TOAST_SLIDE_OUT)
	_toast_tween.tween_callback(func() -> void: toast_panel.visible = false)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _refresh_counter() -> void:
	if _intel_store_ref == null:
		counter_label.text = "Recon: ---"
		return
	var remaining: int  = _intel_store_ref.recon_actions_remaining
	var max_val:   int  = PlayerIntelStore.MAX_DAILY_ACTIONS
	var filled := "*".repeat(remaining)
	var empty  := "-".repeat(max_val - remaining)

	var whispers: int     = _intel_store_ref.whisper_tokens_remaining
	var max_w:    int     = PlayerIntelStore.MAX_DAILY_WHISPERS
	var w_filled := "W".repeat(whispers)
	var w_empty  := "_".repeat(max_w - whispers)

	counter_label.text = "Recon [%s%s]  %d/%d   Whisper [%s%s]  %d/%d" % [
		filled, empty, remaining, max_val,
		w_filled, w_empty, whispers, max_w
	]
