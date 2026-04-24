## game_input_handler.gd — SPA-1002: Input dispatch, NPC cycling, and context-controls mode.
##
## Extracted from main.gd (_process mode tracking, _unhandled_input keyboard
## shortcuts, _cycle_npc Tab cycling).  Add as a child of main then call setup().

class_name GameInputHandler
extends Node

## Emitted when the player presses O — main.gd handles the recall overlay.
signal objective_recall_requested

var _game_started: bool = false
var _tab_npc_index: int = -1
var _tab_npc_list: Array = []

var _world: Node2D = null
var _camera: Camera2D = null
var _day_night: Node = null
var _rumor_panel: CanvasLayer = null
var _journal: CanvasLayer = null
var _social_graph_overlay: CanvasLayer = null
var _npc_info_panel: CanvasLayer = null
var _tutorial_banner: CanvasLayer = null
var _context_controls: CanvasLayer = null


func setup(
		world: Node2D,
		camera: Camera2D,
		day_night: Node,
		rumor_panel: CanvasLayer,
		journal: CanvasLayer,
		social_graph_overlay: CanvasLayer,
		npc_info_panel: CanvasLayer,
		tutorial_banner: CanvasLayer,
		context_controls: CanvasLayer,
) -> void:
	_world = world
	_camera = camera
	_day_night = day_night
	_rumor_panel = rumor_panel
	_journal = journal
	_social_graph_overlay = social_graph_overlay
	_npc_info_panel = npc_info_panel
	_tutorial_banner = tutorial_banner
	_context_controls = context_controls
	_game_started = true


## SPA-767: Update context controls panel mode based on which panels are open.
func _process(_delta: float) -> void:
	if _context_controls == null or not _game_started:
		return
	var mode: int = 0  # EXPLORE
	if _rumor_panel != null and _rumor_panel.visible:
		mode = 1  # RUMOR_PANEL
	elif _journal != null and _journal.visible:
		mode = 2  # JOURNAL
	elif _social_graph_overlay != null and _social_graph_overlay.visible:
		mode = 3  # SOCIAL_GRAPH
	elif _day_night != null and _day_night.has_method("is_paused") and _day_night.is_paused():
		mode = 4  # PAUSED
	_context_controls.set_mode(mode)


## SPA-518/SPA-872: Keyboard shortcuts for panels and NPC cycling.
func _unhandled_input(event: InputEvent) -> void:
	if not _game_started:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_H:
				if _tutorial_banner != null and _tutorial_banner.has_method("replay_hint"):
					_tutorial_banner.replay_hint()
					get_viewport().set_input_as_handled()
			KEY_O:
				objective_recall_requested.emit()
				get_viewport().set_input_as_handled()
			KEY_M:
				# M mirrors G: toggle the Social Graph / Map overview.
				if _social_graph_overlay != null and _social_graph_overlay.has_method("_toggle_overlay"):
					_social_graph_overlay._toggle_overlay()
					get_viewport().set_input_as_handled()
			KEY_TAB:
				# Tab cycles through NPCs in the current world and shows the info panel.
				_cycle_npc(1)
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				# Centralised Esc: close whichever panel is topmost.
				if _npc_info_panel != null and _npc_info_panel.visible:
					_npc_info_panel.hide_panel()
					get_viewport().set_input_as_handled()
				elif _rumor_panel != null and _rumor_panel.visible and _rumor_panel.has_method("toggle"):
					_rumor_panel.toggle()
					get_viewport().set_input_as_handled()


## SPA-872: Cycle through NPCs in the world using Tab.
## direction: +1 = forward, -1 = backward.
func _cycle_npc(direction: int) -> void:
	if _world == null:
		return
	var npc_container: Node = _world.get_node_or_null("NPCContainer")
	if npc_container == null:
		return
	# Rebuild NPC list each cycle so it stays current.
	_tab_npc_list = npc_container.get_children().filter(
		func(n: Node) -> bool: return n is Node2D and n.has_method("get_worst_rumor_state")
	)
	if _tab_npc_list.is_empty():
		return
	_tab_npc_index = (_tab_npc_index + direction) % _tab_npc_list.size()
	if _tab_npc_index < 0:
		_tab_npc_index = _tab_npc_list.size() - 1
	var npc: Node2D = _tab_npc_list[_tab_npc_index]
	# Pan camera toward the selected NPC.
	if _camera != null:
		var tw := _camera.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tw.tween_property(_camera, "position", npc.global_position, 0.4)
	# Show the NPC info panel.
	if _npc_info_panel != null:
		_npc_info_panel.show_npc(npc)
