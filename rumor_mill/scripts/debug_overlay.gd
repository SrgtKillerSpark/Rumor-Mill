extends CanvasLayer

## debug_overlay.gd — Sprint 4 update.
##
## F2 — toggle NPC state badges
## F3 — toggle social graph connection lines
## F4 — toggle lineage tree panel

# State badge colours
const STATE_COLORS := {
	Rumor.RumorState.UNAWARE:    Color(0.5, 0.5, 0.5, 0.9),
	Rumor.RumorState.EVALUATING: Color(1.0, 1.0, 0.0, 0.9),
	Rumor.RumorState.BELIEVE:    Color(0.0, 0.9, 0.2, 0.9),
	Rumor.RumorState.REJECT:     Color(0.9, 0.1, 0.1, 0.9),
	Rumor.RumorState.SPREAD:     Color(1.0, 0.55, 0.0, 0.9),
	Rumor.RumorState.ACT:        Color(0.7, 0.0, 1.0, 0.9),
	Rumor.RumorState.EXPIRED:    Color(0.25, 0.25, 0.25, 0.9),
	Rumor.RumorState.DEFENDING:  Color(0.2, 0.7, 1.0, 0.9),  # sky blue
}

var show_states:  bool = true
var show_social:  bool = false
var show_lineage: bool = false

var _world_ref: Node2D = null
var _draw_node: Node2D = null

# Lineage panel — created on demand.
var _lineage_panel: PanelContainer = null
var _lineage_label: RichTextLabel  = null


func _ready() -> void:
	layer = 10
	_draw_node = Node2D.new()
	_draw_node.name = "DebugDraw"
	add_child(_draw_node)
	_draw_node.draw.connect(_on_draw)

	# Build the lineage panel (hidden by default).
	_build_lineage_panel()


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
			KEY_F4:
				show_lineage = not show_lineage
				_lineage_panel.visible = show_lineage
				print("[DebugOverlay] Lineage panel: %s" % ("ON" if show_lineage else "OFF"))


func _process(_delta: float) -> void:
	if show_states or show_social:
		_draw_node.queue_redraw()
	if show_lineage:
		_refresh_lineage_panel()


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
			var target_npc := _find_npc_by_id(npcs, target_id)
			if target_npc == null:
				continue
			var from_pos := _world_to_screen(npc.global_position)
			var to_pos   := _world_to_screen(target_npc.global_position)
			var alpha    := clamp(weight, 0.1, 1.0)
			_draw_node.draw_line(from_pos, to_pos, Color(0.2, 0.8, 1.0, alpha * 0.6), 1.0)


# ── Lineage panel ─────────────────────────────────────────────────────────────

func _build_lineage_panel() -> void:
	_lineage_panel = PanelContainer.new()
	_lineage_panel.name = "LineagePanel"

	# Anchor to top-right corner.
	_lineage_panel.set_anchor_and_offset(SIDE_RIGHT, 1.0, -420.0)
	_lineage_panel.set_anchor_and_offset(SIDE_LEFT,  1.0, -420.0)
	_lineage_panel.set_anchor_and_offset(SIDE_TOP,   0.0,   10.0)
	_lineage_panel.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 410.0)
	_lineage_panel.custom_minimum_size = Vector2(400, 400)

	_lineage_label = RichTextLabel.new()
	_lineage_label.bbcode_enabled  = true
	_lineage_label.scroll_active   = true
	_lineage_label.custom_minimum_size = Vector2(380, 380)

	_lineage_panel.add_child(_lineage_label)
	add_child(_lineage_panel)
	_lineage_panel.visible = false


func _refresh_lineage_panel() -> void:
	if _world_ref == null or _world_ref.propagation_engine == null:
		_lineage_label.text = "[color=gray](no engine)[/color]"
		return

	var engine: PropagationEngine = _world_ref.propagation_engine
	var summary := engine.get_lineage_summary()

	_lineage_label.clear()
	_lineage_label.append_text("[color=cyan][b]Rumor Lineage Tree[/b][/color]\n")
	_lineage_label.append_text("[color=yellow]Live: %d  |  Total tracked: %d[/color]\n\n" % [
		engine.live_rumors.size(), engine.lineage.size()])
	_lineage_label.append_text("[color=white]%s[/color]" % summary)


# ── Utilities ─────────────────────────────────────────────────────────────────

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world_pos
	var canvas_transform := viewport.get_canvas_transform()
	return canvas_transform * world_pos


func _find_npc_by_id(npcs: Array, npc_id: String) -> Node2D:
	for npc in npcs:
		if npc.npc_data.get("id", "") == npc_id:
			return npc
	return null
