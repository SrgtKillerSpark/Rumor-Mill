## npc_dialogue.gd — Speech bubble and reaction-icon subsystem for NPC (SPA-1009).
## Extracted from npc.gd.  Manages the dialogue DB, idle/gossip/chatter bubbles,
## and all floating reaction icons (hear, believe, reject, spread, act, defending).
## Call setup() from npc.init_from_data().

class_name NpcDialogue
extends Node

## Dialogue lines loaded once from data/npc_dialogue.json (shared across all NPCs).
static var _dialogue_data:   Dictionary = {}
static var _dialogue_loaded: bool       = false
## Global count of bubbles currently visible; capped at _MAX_BUBBLES.
static var _active_bubbles:  int        = 0
const  _MAX_BUBBLES:         int        = 2

var _npc:                  Node2D = null
var _npc_dialogue_key:     String = ""
var _idle_bubble_cooldown: int    = 0
var _has_bubble:           bool   = false
var _gossip_cooldown:      int    = 0
var _chatter_cooldown:     int    = 0
## Persistent shield icon shown while this NPC is DEFENDING.
var _defending_icon: Label = null


## Inject dependencies and stagger initial bubble cooldowns.
func setup(npc: Node2D, npc_id: String) -> void:
	_npc              = npc
	_npc_dialogue_key = npc_id
	_load_dialogue_db()
	_idle_bubble_cooldown = randi_range(1, 50)
	_gossip_cooldown      = randi_range(60, 120)
	_chatter_cooldown     = randi_range(20, 50)


## Release global bubble slot when NPC leaves the scene tree.
func on_exit_tree() -> void:
	if _has_bubble:
		_active_bubbles = maxi(_active_bubbles - 1, 0)
		_has_bubble = false


# ── Per-tick bubble logic ─────────────────────────────────────────────────────

## Tick ambient/gossip/chatter bubble cooldowns.  Called from npc.on_tick().
func tick_bubbles(tick: int, current_hour: int) -> void:
	_idle_bubble_cooldown -= 1
	if _idle_bubble_cooldown <= 0:
		_idle_bubble_cooldown = randi_range(30, 60)
		var phase_cat := "ambient_" + _get_time_phase(current_hour)
		var npc_lines: Dictionary = _dialogue_data.get(_npc_dialogue_key, {})
		if npc_lines.has(phase_cat) and not (npc_lines[phase_cat] as Array).is_empty():
			show_bubble(phase_cat)
		else:
			show_bubble("ambient")
	_gossip_cooldown -= 1
	if _gossip_cooldown <= 0:
		_gossip_cooldown = randi_range(60, 120)
		var sid: String   = GameState.selected_scenario_id
		var short: String = sid.replace("scenario_", "s")
		show_bubble("gossip_" + short)
	_chatter_cooldown -= 1
	if _chatter_cooldown <= 0:
		_chatter_cooldown = randi_range(40, 80)
		_try_chatter_bubble()


# ── Dialogue DB ───────────────────────────────────────────────────────────────

## Load npc_dialogue.json (and npc_dialogue_extended.json) once; no-op thereafter.
static func _load_dialogue_db() -> void:
	if _dialogue_loaded:
		return
	var f := FileAccess.open("res://data/npc_dialogue.json", FileAccess.READ)
	if f == null:
		_dialogue_loaded = true
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary and parsed.has("npc_dialogue"):
		_dialogue_data = parsed["npc_dialogue"]
	# Merge extended dialogue (time-of-day, scenario gossip, chatter).
	var ef := FileAccess.open("res://data/npc_dialogue_extended.json", FileAccess.READ)
	if ef != null:
		var ext: Variant = JSON.parse_string(ef.get_as_text())
		ef.close()
		if ext is Dictionary:
			for npc_id in ext:
				if _dialogue_data.has(npc_id):
					var base: Dictionary      = _dialogue_data[npc_id]
					var additions: Dictionary = ext[npc_id]
					for cat in additions:
						base[cat] = additions[cat]
	_dialogue_loaded = true


## Returns the broad time-of-day phase for ambient dialogue selection.
## morning: 05-11, day: 12-16, evening: 17-21, night: 22-04.
func _get_time_phase(current_hour: int) -> String:
	if current_hour >= 5 and current_hour <= 11:
		return "morning"
	elif current_hour >= 12 and current_hour <= 16:
		return "day"
	elif current_hour >= 17 and current_hour <= 21:
		return "evening"
	else:
		return "night"


func _try_chatter_bubble() -> void:
	for other in _npc.all_npcs_ref:
		if other == _npc:
			continue
		var dist: int = abs(other.current_cell.x - _npc.current_cell.x) + \
						abs(other.current_cell.y - _npc.current_cell.y)
		if dist <= 3:
			show_bubble("chatter")
			return


# ── Parchment speech bubble ───────────────────────────────────────────────────

## Spawns a parchment-style speech bubble above this NPC with a random line
## from the given dialogue category.  Respects the global 2-bubble cap.
## prominent=true uses larger text and a longer hold (for eavesdrop readability).
func show_bubble(category: String, prominent: bool = false) -> void:
	if _has_bubble:
		return
	if _active_bubbles >= _MAX_BUBBLES:
		return
	if _npc_dialogue_key == "":
		return
	var npc_lines: Dictionary = _dialogue_data.get(_npc_dialogue_key, {})
	var lines: Array          = npc_lines.get(category, [])
	if lines.is_empty():
		return
	var text: String = lines[randi() % lines.size()]

	# ── Build parchment panel ─────────────────────────────────────────────────
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.88, 0.78, 0.58, 0.93)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.border_width_left          = 1
	style.border_width_right         = 1
	style.border_width_top           = 1
	style.border_width_bottom        = 1
	style.border_color               = Color(0.55, 0.42, 0.25, 0.85)
	style.content_margin_left        = 6.0
	style.content_margin_right       = 6.0
	style.content_margin_top         = 4.0
	style.content_margin_bottom      = 4.0
	panel.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text                = text
	lbl.autowrap_mode       = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(100.0 if prominent else 80.0, 0.0)
	lbl.add_theme_font_size_override("font_size", 11 if prominent else 9)
	lbl.add_theme_color_override("font_color", Color(0.25, 0.18, 0.08, 1.0))
	panel.add_child(lbl)

	panel.modulate.a = 0.0
	panel.position   = Vector2(-50.0 if prominent else -44.0, -160.0 if prominent else -152.0)
	_npc.add_child(panel)

	_active_bubbles += 1
	_has_bubble      = true

	var hold_time := randf_range(5.0, 6.5) if prominent else randf_range(3.0, 4.0)
	var tw        := _npc.create_tween()
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw.tween_interval(hold_time)
	tw.tween_property(panel, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_on_bubble_finished.bind(panel))


func _on_bubble_finished(panel: PanelContainer) -> void:
	_active_bubbles = maxi(_active_bubbles - 1, 0)
	_has_bubble     = false
	if is_instance_valid(panel):
		panel.queue_free()


# ── Observe / eavesdrop ───────────────────────────────────────────────────────

func show_observed(heat: float) -> void:
	if heat >= 50.0:
		var npc_lines: Dictionary = _dialogue_data.get(_npc_dialogue_key, {})
		if not (npc_lines.get("observe_wary", []) as Array).is_empty():
			show_bubble("observe_wary")
			return
	var base_lines: Dictionary = _dialogue_data.get(_npc_dialogue_key, {})
	if (base_lines.get("observe", []) as Array).is_empty():
		push_warning("NPC '%s': missing 'observe' dialogue category — skipping bubble" % _npc_dialogue_key)
		return
	show_bubble("observe")


func show_eavesdropped(heat: float) -> void:
	if heat >= 50.0:
		var npc_lines: Dictionary = _dialogue_data.get(_npc_dialogue_key, {})
		if not (npc_lines.get("eavesdrop_wary", []) as Array).is_empty():
			show_bubble("eavesdrop_wary", true)
			return
	var base_lines: Dictionary = _dialogue_data.get(_npc_dialogue_key, {})
	if (base_lines.get("eavesdrop", []) as Array).is_empty():
		push_warning("NPC '%s': missing 'eavesdrop' dialogue category — skipping bubble" % _npc_dialogue_key)
		return
	show_bubble("eavesdrop", true)


# ── Floating reaction icons ───────────────────────────────────────────────────

## Small floating speech bubble drifting up from this NPC toward a spread target.
func show_spread_bubble(_target_npc: Node2D) -> void:
	var lbl := Label.new()
	lbl.text = "💬"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.position = Vector2(-8.0, -60.0)
	lbl.modulate = Color(1.0, 0.85, 0.3, 1.0)
	_npc.add_child(lbl)
	var tw := _npc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -24.0), 1.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.5)
	tw.chain().tween_callback(lbl.queue_free)


## Persistent shield icon — shown for the duration of DEFENDING state.
func show_defending_icon() -> void:
	if is_instance_valid(_defending_icon):
		return  # already showing
	var lbl := Label.new()
	lbl.text = "🛡"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.position = Vector2(-6.0, -88.0)
	lbl.modulate = Color(0.55, 0.85, 1.0, 1.0)
	_npc.add_child(lbl)
	_defending_icon = lbl


func hide_defending_icon() -> void:
	if is_instance_valid(_defending_icon):
		_defending_icon.queue_free()
	_defending_icon = null


## "?" icon when this NPC first hears a new rumor (UNAWARE → EVALUATING).
func show_hear_reaction() -> void:
	var lbl := Label.new()
	lbl.text = "?"
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.position = Vector2(-4.0, -72.0)
	lbl.modulate = Color(1.0, 1.0, 0.5, 1.0)
	_npc.add_child(lbl)
	var tw := _npc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -16.0), 1.0)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tw.chain().tween_callback(lbl.queue_free)


## "!" pop when EVALUATING → BELIEVE.
func show_believe_reaction() -> void:
	var lbl := Label.new()
	lbl.text = "!"
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.position = Vector2(-6.0, -84.0)
	lbl.modulate = Color(0.30, 1.00, 0.42, 1.0)
	_npc.add_child(lbl)
	var tw := _npc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "scale", Vector2(1.6, 1.6), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.18).set_delay(0.18)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -22.0), 1.6).set_delay(0.1)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.0).set_delay(0.55)
	tw.chain().tween_callback(lbl.queue_free)


## "✗" when EVALUATING → REJECT.
func show_reject_reaction() -> void:
	var lbl := Label.new()
	lbl.text = "✗"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.position = Vector2(-6.0, -76.0)
	lbl.modulate = Color(0.80, 0.80, 0.85, 1.0)
	_npc.add_child(lbl)
	var tw := _npc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -14.0), 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_delay(0.25)
	tw.chain().tween_callback(lbl.queue_free)


## "👂" ear icon when this NPC receives a whispered rumor.
func show_whisper_received() -> void:
	var lbl := Label.new()
	lbl.text = "👂"
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.position = Vector2(4.0, -68.0)
	lbl.modulate = Color(1.0, 0.90, 0.55, 1.0)
	_npc.add_child(lbl)
	var tw := _npc.create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position", lbl.position + Vector2(0.0, -14.0), 1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tw.chain().tween_callback(lbl.queue_free)


## Pulsing "⚡" for ~2 seconds when this NPC enters ACT state.
func show_act_icon() -> void:
	var lbl := Label.new()
	lbl.text = "⚡"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.position = Vector2(-8.0, -76.0)
	lbl.modulate = Color(1.0, 0.85, 0.1, 1.0)
	_npc.add_child(lbl)
	var tw := _npc.create_tween()
	tw.set_loops(3)
	tw.tween_property(lbl, "modulate:a", 0.2, 0.35)
	tw.tween_property(lbl, "modulate:a", 1.0, 0.35)
	tw.chain().tween_callback(lbl.queue_free)
