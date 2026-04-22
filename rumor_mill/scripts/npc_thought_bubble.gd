## npc_thought_bubble.gd — SPA-695 Channel A: NPC visual state indicator.
## A Node2D child of each NPC that shows a small symbol above the sprite
## reflecting the NPC's worst rumor state.
##
## Performance constraints:
##   - Only shows for on-screen NPCs (viewport rect check).
##   - Global cap of MAX_VISIBLE simultaneous bubbles.
##   - Prioritizes closest NPCs by natural first-come-first-served ordering.
class_name NpcThoughtBubble
extends Node2D

const MAX_VISIBLE: int = 5

## Symbols displayed per RumorState. Empty string = no bubble.
const SYMBOL: Dictionary = {
	Rumor.RumorState.UNAWARE:      "",
	Rumor.RumorState.EVALUATING:   "?",
	Rumor.RumorState.BELIEVE:      "!",
	Rumor.RumorState.SPREAD:       "...",
	Rumor.RumorState.ACT:          "!!",
	Rumor.RumorState.REJECT:       "x",
	Rumor.RumorState.CONTRADICTED: "~",
	Rumor.RumorState.EXPIRED:      "",
	Rumor.RumorState.DEFENDING:    "[>",
}

## Label colours per state.
const STATE_COLOR: Dictionary = {
	Rumor.RumorState.UNAWARE:      Color.WHITE,
	Rumor.RumorState.EVALUATING:   Color(1.00, 1.00, 0.50, 1.0),
	Rumor.RumorState.BELIEVE:      Color(0.40, 1.00, 0.50, 1.0),
	Rumor.RumorState.SPREAD:       Color(1.00, 0.75, 0.30, 1.0),
	Rumor.RumorState.ACT:          Color(1.00, 0.40, 0.90, 1.0),
	Rumor.RumorState.REJECT:       Color(0.70, 0.70, 0.90, 1.0),
	Rumor.RumorState.CONTRADICTED: Color(0.80, 0.50, 1.00, 1.0),
	Rumor.RumorState.EXPIRED:      Color.WHITE,
	Rumor.RumorState.DEFENDING:    Color(0.40, 0.80, 1.00, 1.0),
}

## State name hints shown briefly on state change (SPA-894).
const STATE_HINT: Dictionary = {
	Rumor.RumorState.EVALUATING:   "Thinking",
	Rumor.RumorState.BELIEVE:      "Believes",
	Rumor.RumorState.SPREAD:       "Spreading",
	Rumor.RumorState.ACT:          "Acting!",
	Rumor.RumorState.REJECT:       "Rejected",
	Rumor.RumorState.CONTRADICTED: "Conflicted",
	Rumor.RumorState.DEFENDING:    "Defending",
}

## Global count of currently visible thought bubbles across all NPC instances.
static var _visible_count: int = 0

var _label: Label = null
var _badge_bg: Panel = null  # SPA-894: background badge for contrast
var _hint_label: Label = null  # SPA-894: brief state-name hint
var _hint_tween: Tween = null
var _tween: Tween = null
## SPA-909: Looping tween for the gentle idle float animation when bubble is visible.
var _float_tween: Tween = null
## True while this bubble holds one of the MAX_VISIBLE slots.
var _is_showing: bool = false
var _current_state: Rumor.RumorState = Rumor.RumorState.UNAWARE


func _ready() -> void:
	# SPA-894: Background badge for contrast against any world background.
	_badge_bg = Panel.new()
	_badge_bg.custom_minimum_size = Vector2(24, 24)
	_badge_bg.position = Vector2(-12.0, -120.0)
	_badge_bg.size = Vector2(24.0, 24.0)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.05, 0.03, 0.02, 0.75)
	badge_style.set_corner_radius_all(12)
	badge_style.set_border_width_all(1)
	badge_style.border_color = Color(0.55, 0.38, 0.18, 0.50)
	_badge_bg.add_theme_stylebox_override("panel", badge_style)
	_badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge_bg.modulate.a = 0.0
	add_child(_badge_bg)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_constant_override("outline_size", 3)
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	# Position above the NPC sprite (sprite is 96 px tall; add 16 px clearance).
	_label.position = Vector2(-10.0, -118.0)
	_label.size = Vector2(20.0, 22.0)
	_label.modulate.a = 0.0
	add_child(_label)

	# SPA-894: Brief state-name hint that fades in/out on state change.
	_hint_label = Label.new()
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.add_theme_font_size_override("font_size", 10)
	_hint_label.add_theme_constant_override("outline_size", 2)
	_hint_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_hint_label.position = Vector2(-30.0, -98.0)
	_hint_label.size = Vector2(60.0, 14.0)
	_hint_label.modulate.a = 0.0
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)


func _exit_tree() -> void:
	if _is_showing:
		_visible_count = maxi(_visible_count - 1, 0)
		_is_showing = false


## Called from npc.gd whenever the NPC's worst rumor state changes.
## Also called each tick so visibility can adapt to on-screen status.
func refresh(state: Rumor.RumorState) -> void:
	var state_changed := (state != _current_state)
	_current_state = state

	var sym: String = SYMBOL.get(state, "")
	if sym.is_empty():
		_hide()
		return

	# Update label text and colour whenever state changes.
	if state_changed:
		_label.text = sym
		var state_col: Color = STATE_COLOR.get(state, Color.WHITE)
		_label.add_theme_color_override("font_color", state_col)
		# SPA-894: Tint badge border to match state colour.
		if _badge_bg != null:
			var bs: StyleBoxFlat = _badge_bg.get_theme_stylebox("panel") as StyleBoxFlat
			if bs != null:
				bs.border_color = Color(state_col.r, state_col.g, state_col.b, 0.55)
		# SPA-894: Flash brief state-name hint.
		_show_state_hint(state)

	# Decide whether to show based on on-screen status and global cap.
	if _is_on_screen():
		if not _is_showing:
			_show()
		elif state_changed:
			_pulse()
	else:
		_hide()


## Force-hide without waiting for the next refresh() call.
## Called from npc.gd when the NPC exits the tree.
func force_hide() -> void:
	_hide()


## SPA-788: Temporarily display a custom symbol and colour for duration seconds,
## then snap back to the NPC's actual current state via refresh().
## Used for one-shot reward feedback (e.g. belief-flip conviction flash).
func show_override(symbol: String, color: Color, duration: float) -> void:
	if _label == null:
		return
	_label.text = symbol
	_label.add_theme_color_override("font_color", color)
	if not _is_showing:
		if _visible_count >= MAX_VISIBLE:
			return  # cap full — skip tween so no ghost bubble forms
		_visible_count += 1
		_is_showing = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(duration)
	_tween.tween_callback(func() -> void: refresh(_current_state))


# ── Private helpers ──────────────────────────────────────────────────────────

func _show() -> void:
	if _visible_count >= MAX_VISIBLE:
		return
	_is_showing = true
	_visible_count += 1
	if _float_tween:
		_float_tween.kill()
		_float_tween = null
	if _tween:
		_tween.kill()
	# SPA-909: Scale spring pop-in so the bubble feels alive rather than a plain fade.
	_label.scale = Vector2(0.35, 0.35)
	if _badge_bg != null:
		_badge_bg.scale = Vector2(0.35, 0.35)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_label, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_label, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _badge_bg != null:
		_tween.tween_property(_badge_bg, "modulate:a", 1.0, 0.22).set_ease(Tween.EASE_OUT)
		_tween.tween_property(_badge_bg, "scale", Vector2.ONE, 0.28) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Start idle float loop once the entrance animation completes.
	_float_tween = create_tween()
	_float_tween.tween_interval(0.30)
	_float_tween.tween_callback(_start_float_loop)


func _hide() -> void:
	if not _is_showing:
		return
	_is_showing = false
	_visible_count = maxi(_visible_count - 1, 0)
	# SPA-909: Stop float loop and reset positions before fading out.
	if _float_tween:
		_float_tween.kill()
		_float_tween = null
	_label.position.y = -118.0
	if _badge_bg != null:
		_badge_bg.position.y = -120.0
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_label, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)
	if _badge_bg != null:
		_tween.tween_property(_badge_bg, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)


func _pulse() -> void:
	# SPA-909: Stop float so the position pop below has a clean baseline.
	if _float_tween:
		_float_tween.kill()
		_float_tween = null
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 0.3, 0.08)
	_tween.tween_property(_label, "modulate:a", 1.0, 0.18)
	# Brief upward position pop to signal the state change visually.
	var _pt := create_tween()
	_pt.tween_property(_label, "position:y", _label.position.y - 5.0, 0.08) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pt.tween_property(_label, "position:y", -118.0, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_pt.tween_callback(_start_float_loop)


## SPA-894: Show a brief state-name label below the symbol for immediate readability.
func _show_state_hint(state: Rumor.RumorState) -> void:
	if _hint_label == null:
		return
	var hint_text: String = STATE_HINT.get(state, "")
	if hint_text.is_empty():
		return
	_hint_label.text = hint_text
	_hint_label.add_theme_color_override("font_color", STATE_COLOR.get(state, Color.WHITE))
	if _hint_tween != null and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_label.modulate.a = 0.0
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint_label, "modulate:a", 1.0, 0.15).set_ease(Tween.EASE_OUT)
	_hint_tween.tween_interval(1.5)
	_hint_tween.tween_property(_hint_label, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN)


## SPA-909: Idle float loop — gently oscillates label+badge up and back (±2.5 px, 1.3 s period).
## Starts after the pop-in spring completes; restarts after each _pulse().
func _start_float_loop() -> void:
	if not _is_showing:
		return
	if _float_tween != null and _float_tween.is_valid():
		_float_tween.kill()
	const FLOAT_AMP  := 2.5
	const FLOAT_HALF := 0.65  # half-period in seconds
	_float_tween = create_tween()
	_float_tween.tween_method(
		func(v: float) -> void:
			if _label != null:
				_label.position.y = -118.0 - v
			if _badge_bg != null:
				_badge_bg.position.y = -120.0 - v,
		0.0, FLOAT_AMP, FLOAT_HALF
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_method(
		func(v: float) -> void:
			if _label != null:
				_label.position.y = -118.0 - v
			if _badge_bg != null:
				_badge_bg.position.y = -120.0 - v,
		FLOAT_AMP, 0.0, FLOAT_HALF
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_float_tween.tween_callback(_start_float_loop)


## Returns true when this node's world position is within the visible viewport.
## Uses the active Camera2D to compute the visible world rectangle.
func _is_on_screen() -> bool:
	if not is_inside_tree():
		return false
	var vp := get_viewport()
	if vp == null:
		return true
	var cam := vp.get_camera_2d()
	if cam == null:
		return true
	var vp_size := vp.get_visible_rect().size
	# World-space half-extents of the visible area.
	var half_w := (vp_size.x * 0.5) / cam.zoom.x + 80.0   # small margin
	var half_h := (vp_size.y * 0.5) / cam.zoom.y + 120.0
	var cam_pos := cam.get_screen_center_position()
	var diff := global_position - cam_pos
	return abs(diff.x) < half_w and abs(diff.y) < half_h
