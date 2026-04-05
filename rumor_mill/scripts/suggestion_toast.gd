## suggestion_toast.gd — Tier 3 hint toast widget.
##
## PanelContainer-based toast that displays one contextual hint at a time with:
##   - Arrow-prefixed hint text (12px, C_SUGGESTION colour)
##   - Dismiss button [×] in the top-right corner
##   - Fade-in enter animation (0.4s EASE_OUT / TRANS_BACK)
##   - Fade-out exit (auto 0.3s after 8 s; dismiss 0.15s on button click)
##   - Fast-dismiss detection: emits was_fast=true if dismissed < 1 second
##     after appearing (signals the engine to double the next cooldown)

class_name SuggestionToast
extends PanelContainer

## Emitted when the toast disappears — either via button, auto-timer, or
## a call to dismiss().  was_fast is true when the player clicked [×] within
## FAST_DISMISS_THRESHOLD_SEC of the hint appearing.
signal hint_dismissed(was_fast: bool)

const C_SUGGESTION             := Color(0.80, 0.90, 0.65, 1.0)
const AUTO_DISMISS_SEC         := 8.0
const FAST_DISMISS_THRESHOLD_SEC := 1.0

var _hint_label:  Label  = null
var _dismiss_btn: Button = null
var _anim_tween:  Tween  = null
## Seconds (real time) when the current hint became visible.
var _shown_at_sec: float = 0.0


func _init() -> void:
	_build_style()
	_build_children()


func _build_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.10, 0.75)
	style.set_corner_radius_all(4)
	add_theme_stylebox_override("panel", style)
	mouse_filter = MOUSE_FILTER_STOP


func _build_children() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   6)
	margin.add_theme_constant_override("margin_right",  4)
	margin.add_theme_constant_override("margin_top",    4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	margin.add_child(hbox)

	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint_label.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.add_theme_font_size_override("font_size",           12)
	_hint_label.add_theme_color_override("font_color",              C_SUGGESTION)
	_hint_label.add_theme_constant_override("outline_size",         2)
	_hint_label.add_theme_color_override("font_outline_color",      Color(0, 0, 0, 0.7))
	_hint_label.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_hint_label)

	_dismiss_btn = Button.new()
	_dismiss_btn.text = "×"
	_dismiss_btn.flat = true
	_dismiss_btn.custom_minimum_size = Vector2(16, 0)
	_dismiss_btn.add_theme_font_size_override("font_size",  12)
	_dismiss_btn.add_theme_color_override("font_color",     Color(0.7, 0.7, 0.7, 0.8))
	_dismiss_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_dismiss_btn.pressed.connect(_on_dismiss_pressed)
	hbox.add_child(_dismiss_btn)


## Display hint text with enter animation.  Replaces any active hint.
func show_hint(text: String) -> void:
	_stop_anim()
	_hint_label.text = "→  " + text
	visible          = true
	modulate.a       = 0.0
	_shown_at_sec    = Time.get_ticks_msec() / 1000.0

	_anim_tween = create_tween()
	# Fade in.
	_anim_tween.tween_property(self, "modulate:a", 1.0, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	# Hold for AUTO_DISMISS_SEC seconds.
	_anim_tween.tween_interval(AUTO_DISMISS_SEC)
	# Auto-dismiss fade out.
	_anim_tween.tween_property(self, "modulate:a", 0.0, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_callback(func() -> void:
		visible = false
		hint_dismissed.emit(false)
	)


## Immediately dismiss the toast (no fast-dismiss penalty).
func dismiss() -> void:
	_fade_out(0.15, false)


# ── Internal helpers ──────────────────────────────────────────────────────────

func _stop_anim() -> void:
	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
		_anim_tween = null


func _on_dismiss_pressed() -> void:
	var now_sec: float = Time.get_ticks_msec() / 1000.0
	var fast: bool     = (now_sec - _shown_at_sec) < FAST_DISMISS_THRESHOLD_SEC
	_fade_out(0.15, fast)


func _fade_out(duration: float, was_fast: bool) -> void:
	_stop_anim()
	_anim_tween = create_tween()
	_anim_tween.tween_property(self, "modulate:a", 0.0, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_callback(func() -> void:
		visible = false
		hint_dismissed.emit(was_fast)
	)
