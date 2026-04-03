extends CanvasLayer

## debug_console.gd — Sprint 2 in-game debug console.
##
## F1           — toggle console visibility
## Commands:
##   inject_rumor <npc_id> <claim_type> <intensity>
##   show_states
##   show_social
##   list_npcs

@onready var panel:     Panel    = $Panel
@onready var log_label: RichTextLabel = $Panel/VBox/LogLabel
@onready var input_box: LineEdit = $Panel/VBox/InputBox

var _world_ref: Node2D = null
var _overlay_ref: CanvasLayer = null


func _ready() -> void:
	layer = 20
	panel.visible = false
	input_box.text_submitted.connect(_on_command_submitted)
	_log("[color=cyan]Rumor Mill Debug Console — F1 to toggle[/color]")
	_log("[color=yellow]Commands: inject_rumor, show_states, show_social, list_npcs, lineage_tree[/color]")


func set_world(world: Node2D) -> void:
	_world_ref = world


func set_overlay(overlay: CanvasLayer) -> void:
	_overlay_ref = overlay


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			panel.visible = not panel.visible
			if panel.visible:
				input_box.grab_focus()
				get_viewport().set_input_as_handled()


func _on_command_submitted(text: String) -> void:
	input_box.clear()
	if text.strip_edges().is_empty():
		return

	_log("> " + text)
	var parts := text.strip_edges().split(" ", false)
	var cmd := parts[0].to_lower()

	match cmd:
		"inject_rumor":
			_cmd_inject_rumor(parts)
		"show_states":
			_cmd_show_states()
		"show_social":
			_cmd_show_social()
		"list_npcs":
			_cmd_list_npcs()
		"lineage_tree":
			_cmd_lineage_tree()
		"help":
			_log("[color=yellow]inject_rumor <npc_id> <claim_type> <intensity 1-5>[/color]")
			_log("[color=yellow]show_states | show_social | list_npcs | lineage_tree[/color]")
		_:
			_log("[color=red]Unknown command: %s[/color]" % cmd)


# ── Command handlers ─────────────────────────────────────────────────────────

func _cmd_inject_rumor(parts: Array) -> void:
	if parts.size() < 4:
		_log("[color=red]Usage: inject_rumor <npc_id> <claim_type> <intensity>[/color]")
		return

	var npc_id:     String = parts[1]
	var claim_str:  String = parts[2]
	var intensity:  int    = int(parts[3])

	if intensity < 1 or intensity > 5:
		_log("[color=red]Intensity must be 1–5[/color]")
		return

	if _world_ref == null:
		_log("[color=red]World not connected[/color]")
		return

	var result: String = _world_ref.inject_rumor(npc_id, claim_str, intensity)
	if result.is_empty():
		_log("[color=red]inject_rumor failed — check npc_id and claim_type[/color]")
	else:
		_log("[color=green]Injected rumor '%s' → %s[/color]" % [result, npc_id])


func _cmd_show_states() -> void:
	if _overlay_ref == null:
		_log("[color=red]Overlay not connected[/color]")
		return
	_overlay_ref.show_states = not _overlay_ref.show_states
	_log("State badges: %s" % ("ON" if _overlay_ref.show_states else "OFF"))


func _cmd_show_social() -> void:
	if _overlay_ref == null:
		_log("[color=red]Overlay not connected[/color]")
		return
	_overlay_ref.show_social = not _overlay_ref.show_social
	_log("Social graph: %s" % ("ON" if _overlay_ref.show_social else "OFF"))


func _cmd_list_npcs() -> void:
	if _world_ref == null:
		_log("[color=red]World not connected[/color]")
		return
	for npc in _world_ref.npcs:
		var id:      String = npc.npc_data.get("id", "?")
		var name_s:  String = npc.npc_data.get("name", "?")
		var faction: String = npc.npc_data.get("faction", "?")
		var state: String = Rumor.state_name(npc.get_worst_rumor_state())
		_log("  %s (%s) [%s] — %s" % [name_s, id, faction, state])


func _cmd_lineage_tree() -> void:
	if _world_ref == null:
		_log("[color=red]World not connected[/color]")
		return
	var engine: PropagationEngine = _world_ref.propagation_engine
	if engine == null:
		_log("[color=red]PropagationEngine not initialised[/color]")
		return
	_log("[color=cyan]── Rumor Lineage Tree ──[/color]")
	_log("[color=yellow]Live: %d  |  Total tracked: %d[/color]" % [
		engine.live_rumors.size(), engine.lineage.size()])
	var summary := engine.get_lineage_summary()
	for line in summary.split("\n"):
		_log(line)


# ── Internal ─────────────────────────────────────────────────────────────────

func _log(msg: String) -> void:
	log_label.append_text(msg + "\n")
	# Auto-scroll to bottom.
	await get_tree().process_frame
	log_label.scroll_to_line(log_label.get_line_count() - 1)
