## achievement_toast.gd — In-game achievement unlock notification (SPA-1093).
##
## CanvasLayer-based toast that appears at the top-centre of the screen when
## AchievementManager emits achievement_unlocked.  Design mirrors SuggestionToast:
##   - "Achievement Unlocked" golden header label
##   - Achievement display name below, near-white
##   - Fade-in enter animation (0.4s EASE_OUT / TRANS_BACK)
##   - Auto-dismiss after AUTO_DISMISS_SEC with 0.3s fade-out
##   - Queue: simultaneous calls are shown sequentially (SPA-1143)
##
## UILayerManager creates this node and wires AchievementManager's signal to
## show_achievement().

class_name AchievementToast
extends CanvasLayer

const C_HEADER         := Color(0.95, 0.85, 0.40, 1.0)
const C_NAME           := Color(0.92, 0.92, 0.92, 1.0)
const AUTO_DISMISS_SEC := 5.0

var _panel:        PanelContainer = null
var _name_label:   Label          = null
var _anim_tween:   Tween          = null
## Queue of display_name strings waiting to be shown (SPA-1143).
var _queue:        Array[String]  = []
## True while a toast is animating/visible (guards queue drain).
var _is_showing:   bool           = false


func _init() -> void:
	layer = 120
	_build_ui()


func _build_ui() -> void:
	# Full-rect transparent root so the panel can anchor to viewport centre-top.
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.anchor_left   = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left   = -150
	_panel.offset_right  = 150
	_panel.offset_top    = 16
	_panel.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_panel.visible       = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.02, 0.92)
	style.set_corner_radius_all(4)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.70, 0.55, 0.15, 1.0)
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",     8)
	margin.add_theme_constant_override("margin_bottom",  8)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "Achievement Unlocked"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size",      11)
	header.add_theme_color_override("font_color",         C_HEADER)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size",     13)
	_name_label.add_theme_color_override("font_color",        C_NAME)
	_name_label.add_theme_constant_override("outline_size",   2)
	_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_name_label)


## Queue an achievement toast.  If none is currently showing the toast appears
## immediately; otherwise the name is added to the back of the queue and shown
## after the current one dismisses.  Prevents overlapping toasts (SPA-1143).
func show_achievement(display_name: String) -> void:
	if _is_showing:
		_queue.append(display_name)
		return
	_play(display_name)


# ── Internal helpers ──────────────────────────────────────────────────────────

func _play(display_name: String) -> void:
	_is_showing      = true
	_name_label.text = display_name
	_panel.visible   = true
	_panel.modulate.a = 0.0

	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()

	_anim_tween = create_tween()
	_anim_tween.tween_property(_panel, "modulate:a", 1.0, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_anim_tween.tween_interval(AUTO_DISMISS_SEC)
	_anim_tween.tween_property(_panel, "modulate:a", 0.0, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_callback(func() -> void:
		_panel.visible = false
		_is_showing    = false
		_drain_queue()
	)


func _drain_queue() -> void:
	if _queue.is_empty():
		return
	_play(_queue.pop_front())
