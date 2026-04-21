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

## Global count of currently visible thought bubbles across all NPC instances.
static var _visible_count: int = 0

var _label: Label = null
var _tween: Tween = null
## True while this bubble holds one of the MAX_VISIBLE slots.
var _is_showing: bool = false
var _current_state: Rumor.RumorState = Rumor.RumorState.UNAWARE


func _ready() -> void:
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_constant_override("outline_size", 2)
	_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	# Position above the NPC sprite (sprite is 96 px tall; add 16 px clearance).
	_label.position = Vector2(-10.0, -116.0)
	_label.size = Vector2(20.0, 18.0)
	_label.modulate.a = 0.0
	add_child(_label)


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
		_label.add_theme_color_override("font_color", STATE_COLOR.get(state, Color.WHITE))

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
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT)


func _hide() -> void:
	if not _is_showing:
		return
	_is_showing = false
	_visible_count = maxi(_visible_count - 1, 0)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 0.0, 0.25).set_ease(Tween.EASE_IN)


func _pulse() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_label, "modulate:a", 0.3, 0.08)
	_tween.tween_property(_label, "modulate:a", 1.0, 0.18)


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
