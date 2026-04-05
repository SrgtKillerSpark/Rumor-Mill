extends CanvasLayer

## transition_manager.gd — SPA-561: Centralized screen transition overlay.
##
## Provides full-screen fade-to-black (or custom colour) transitions.
## Registered as an autoload on layer 99 so it draws above everything.
##
## Usage:
##   await TransitionManager.fade_out(0.35)   # screen goes black
##   # ... swap scene / toggle panels ...
##   await TransitionManager.fade_in(0.35)    # screen fades back in

var _overlay: ColorRect = null
var _tween: Tween = null

func _ready() -> void:
	layer = 99
	_overlay = ColorRect.new()
	_overlay.color = Color(0.0, 0.0, 0.0, 1.0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.modulate.a = 0.0
	_overlay.visible = false
	add_child(_overlay)


## Fade screen to opaque colour over `duration` seconds. Awaitable.
func fade_out(duration: float = 0.35, colour: Color = Color.BLACK) -> void:
	_kill_tween()
	_overlay.color = colour
	_overlay.visible = true
	_overlay.modulate.a = 0.0
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_overlay, "modulate:a", 1.0, duration)
	await _tween.finished


## Fade screen back from opaque to transparent over `duration` seconds. Awaitable.
func fade_in(duration: float = 0.35) -> void:
	_kill_tween()
	_overlay.visible = true
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(_overlay, "modulate:a", 0.0, duration)
	await _tween.finished
	_overlay.visible = false


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
