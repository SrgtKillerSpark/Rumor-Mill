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

const TOAST_DURATION := 3.5  ## seconds the toast is shown

var _intel_store_ref:  PlayerIntelStore = null
var _rumor_panel_ref:  CanvasLayer      = null
var _toast_timer:      float            = 0.0


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
			toast_panel.visible = false


# ── Public API ────────────────────────────────────────────────────────────────

## Called by ReconController's action_performed signal.
func show_toast(message: String, success: bool) -> void:
	toast_label.text = message
	var color := Color(0.3, 1.0, 0.4, 1.0) if success else Color(1.0, 0.65, 0.2, 1.0)
	toast_label.add_theme_color_override("font_color", color)
	toast_panel.visible = true
	_toast_timer = TOAST_DURATION


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
