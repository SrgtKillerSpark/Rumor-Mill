extends CanvasLayer

## debug_overlay.gd — Sprint 2 debug visualisation.
##
## F2 — toggle NPC state badges
## F3 — toggle social graph connection lines

# State badge colours
const STATE_COLORS := {
	Rumor.RumorState.UNAWARE:    Color(0.5, 0.5, 0.5, 0.9),
	Rumor.RumorState.EVALUATING: Color(1.0, 1.0, 0.0, 0.9),
	Rumor.RumorState.BELIEVE:    Color(0.0, 0.9, 0.2, 0.9),
	Rumor.RumorState.REJECT:     Color(0.9, 0.1, 0.1, 0.9),
	Rumor.RumorState.SPREAD:     Color(1.0, 0.55, 0.0, 0.9),
	Rumor.RumorState.ACT:        Color(0.7, 0.0, 1.0, 0.9),
}

var show_states:  bool = true
var show_social:  bool = false

var _world_ref: Node2D = null
var _draw_node: Node2D = null  # child used for draw calls


func _ready() -> void:
	layer = 10
	# Create a Node2D child that actually issues draw calls (CanvasLayer cannot draw directly).
	_draw_node = Node2D.new()
	_draw_node.name = "DebugDraw"
	add_child(_draw_node)
	_draw_node.draw.connect(_on_draw)


func set_world(world: Node2D) -> void:
	_world_ref = world


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F2:
				show_states = not show_states
				_draw_node.queue_redraw()
				print("[DebugOverlay] State badges: %s" % ("ON" if show_states else "OFF"))
			KEY_F3:
				show_social = not show_social
				_draw_node.queue_redraw()
				print("[DebugOverlay] Social graph: %s" % ("ON" if show_social else "OFF"))


## Called each frame to refresh the overlay.
func _process(_delta: float) -> void:
	if show_states or show_social:
		_draw_node.queue_redraw()


func _on_draw() -> void:
	if _world_ref == null:
		return

	var npcs: Array = _world_ref.npcs
	if npcs.is_empty():
		return

	if show_social and _world_ref.social_graph != null:
		_draw_social_edges(npcs)

	if show_states:
		_draw_state_badges(npcs)


func _draw_state_badges(npcs: Array) -> void:
	for npc in npcs:
		var state := npc.get_worst_rumor_state()
		var color := STATE_COLORS.get(state, Color.GRAY)
		# Convert NPC world position to local space of _draw_node (which is on the CanvasLayer).
		# Since the CanvasLayer ignores the camera, we need to translate through the viewport.
		var world_pos: Vector2 = npc.global_position + Vector2(0, -22)
		var vp_pos: Vector2 = _world_to_screen(world_pos)
		_draw_node.draw_rect(Rect2(vp_pos - Vector2(5, 5), Vector2(10, 10)), color)


func _draw_social_edges(npcs: Array) -> void:
	if _world_ref.social_graph == null:
		return
	var sg: SocialGraph = _world_ref.social_graph
	for npc in npcs:
		var nid: String = npc.npc_data.get("id", "")
		var top := sg.get_top_neighbours(nid, 3)
		for pair in top:
			var target_id: String = pair[0]
			var weight: float     = pair[1]
			# Find target NPC node.
			var target_npc := _find_npc_by_id(npcs, target_id)
			if target_npc == null:
				continue
			var from_pos := _world_to_screen(npc.global_position)
			var to_pos   := _world_to_screen(target_npc.global_position)
			var alpha    := clamp(weight, 0.1, 1.0)
			_draw_node.draw_line(from_pos, to_pos, Color(0.2, 0.8, 1.0, alpha * 0.6), 1.0)


func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world_pos
	var cam := viewport.get_camera_2d()
	if cam == null:
		return world_pos
	# Apply camera transform manually.
	var canvas_transform := viewport.get_canvas_transform()
	return canvas_transform * world_pos


func _find_npc_by_id(npcs: Array, npc_id: String) -> Node2D:
	for npc in npcs:
		if npc.npc_data.get("id", "") == npc_id:
			return npc
	return null
