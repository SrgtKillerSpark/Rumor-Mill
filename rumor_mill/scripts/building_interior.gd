extends CanvasLayer

## building_interior.gd — Sprint 5 (Art Pass 1, SPA-41)
## SPA-910: NPC roster display added (who is currently inside the building).
##
## Base controller for flat 2D interior panels: Tavern, Manor, Chapel.
##
## Usage:
##   1. Call setup_world_ref(world, building_key) once from main.gd.
##   2. Call show_interior() to open; panel closes on E key or × button.
##
## The scene tree expects:
##   $Overlay   (ColorRect)    — dim background
##   $Panel     (Panel)        — parchment panel
##   $Panel/Layout/.../CloseBtn (Button)
##
## Intended to be instanced into Main.tscn and toggled by world.gd or the
## recon controller when the player interacts with a building.

signal interior_opened
signal interior_closed
## Emitted when the player clicks an NPC entry in the roster.
## npc_id: the NPC's data id string.
signal npc_selected(npc_id: String)

@onready var _overlay:    ColorRect = $Overlay
@onready var _panel:      Panel     = $Panel
@onready var _close_btn:  Button    = _find_close_btn()

var _open: bool = false
var _transitioning: bool = false
var _anim_tween: Tween = null

## SPA-910: world reference used to query which NPCs are nearby.
var _world_ref: Node = null
## Location key matching world._gathering_points (e.g. "tavern", "chapel").
var _building_key: String = ""
## Dynamically-created roster label inserted above the hint line.
var _npc_roster: RichTextLabel = null

## How close (grid cells) an NPC must be to appear in the roster.
const ROSTER_RADIUS := 4

## Faction display labels and badge colours for the roster.
const FACTION_LABEL: Dictionary = {
	"merchant": "[color=#3a5fa0]Merchant[/color]",
	"noble":    "[color=#8a1c1c]Noble[/color]",
	"clergy":   "[color=#8a7a10]Clergy[/color]",
}


func _ready() -> void:
	_overlay.visible = false
	_panel.visible   = false
	if _close_btn != null:
		_close_btn.pressed.connect(close_interior)
	_ensure_npc_roster()


## SPA-910: Wire the world reference so the roster can query nearby NPCs.
## Call once from main.gd after instantiating this interior.
func setup_world_ref(world: Node, building_key: String) -> void:
	_world_ref    = world
	_building_key = building_key


func _find_close_btn() -> Button:
	# Walk the panel tree looking for a Button named "CloseBtn".
	var btn := _panel.find_child("CloseBtn", true, false) as Button
	if btn == null:
		push_warning("BuildingInterior: CloseBtn not found in panel — Escape/E key fallback only.")
	return btn


# ── NPC roster (SPA-910) ──────────────────────────────────────────────────────

## Create the roster RichTextLabel if it does not yet exist.
## Inserted just above the HintLabel inside $Panel/Layout.
func _ensure_npc_roster() -> void:
	if _npc_roster != null:
		return
	var layout: Node = _panel.get_node_or_null("Layout")
	if layout == null:
		return
	var hint: Node = layout.get_node_or_null("HintLabel")

	_npc_roster = RichTextLabel.new()
	_npc_roster.name            = "NpcRoster"
	_npc_roster.bbcode_enabled  = true
	_npc_roster.fit_content     = true
	_npc_roster.mouse_filter    = Control.MOUSE_FILTER_PASS
	_npc_roster.add_theme_font_size_override("normal_font_size", 11)
	_npc_roster.add_theme_color_override("default_color", Color(0.32, 0.18, 0.06, 1.0))
	_npc_roster.meta_clicked.connect(_on_roster_meta_clicked)

	if hint != null:
		layout.add_child(_npc_roster)
		layout.move_child(_npc_roster, hint.get_index())
	else:
		layout.add_child(_npc_roster)


## Query the world for NPCs near this building and refresh the roster text.
func _refresh_npc_roster() -> void:
	if _npc_roster == null or _world_ref == null or _building_key.is_empty():
		return
	var nearby: Array = _world_ref.get_npcs_near_location(_building_key, ROSTER_RADIUS)
	if nearby.is_empty():
		_npc_roster.text = "[color=#8a7050][i]No patrons visible.[/i][/color]"
		return

	var lines: Array[String] = []
	lines.append("[color=#52381a][b]Inside:[/b][/color]")
	for npc in nearby:
		var nid: String     = npc.npc_data.get("id", "")
		var nname: String   = npc.npc_data.get("name", "?")
		var faction: String = npc.npc_data.get("faction", "merchant")
		var faction_tag: String = FACTION_LABEL.get(faction, faction.capitalize())
		# Clickable meta link so the player can select an NPC from the roster.
		lines.append("• [url=%s]%s[/url] — %s" % [nid, nname, faction_tag])
	_npc_roster.text = "\n".join(lines)


func _on_roster_meta_clicked(meta: Variant) -> void:
	emit_signal("npc_selected", str(meta))


# ── Public API ────────────────────────────────────────────────────────────────

func show_interior() -> void:
	if _open or _transitioning:
		return
	_refresh_npc_roster()
	_transitioning = true

	# Prepare initial states for the animation.
	_overlay.modulate.a = 0.0
	_overlay.visible    = true
	_panel.modulate.a   = 0.0
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale        = Vector2(0.95, 0.95)
	_panel.visible      = true

	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.set_parallel(true)
	_anim_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Overlay dims in over 0.3s.
	_anim_tween.tween_property(_overlay, "modulate:a", 1.0, 0.3) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	# Panel fades in and scales up over 0.25s.
	_anim_tween.tween_property(_panel, "modulate:a", 1.0, 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_anim_tween.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.25) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	# After all parallels finish, mark open and emit.
	_anim_tween.set_parallel(false)
	_anim_tween.tween_callback(func() -> void:
		_transitioning = false
		_open = true
		emit_signal("interior_opened")
		if _close_btn != null:
			_close_btn.call_deferred("grab_focus")
	)


func close_interior() -> void:
	if not _open or _transitioning:
		return
	_transitioning = true
	_open = false

	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = create_tween()
	_anim_tween.set_parallel(true)
	_anim_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	# Overlay and panel fade out together over 0.2s.
	_anim_tween.tween_property(_overlay, "modulate:a", 0.0, 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_anim_tween.tween_property(_panel, "modulate:a", 0.0, 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_anim_tween.tween_property(_panel, "scale", Vector2(0.95, 0.95), 0.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_anim_tween.set_parallel(false)
	_anim_tween.tween_callback(func() -> void:
		_overlay.visible    = false
		_panel.visible      = false
		# Reset modulate/scale so the next open starts clean.
		_overlay.modulate.a = 1.0
		_panel.modulate.a   = 1.0
		_panel.scale        = Vector2(1.0, 1.0)
		_transitioning = false
		emit_signal("interior_closed")
	)


func is_open() -> bool:
	return _open


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	# Block input while a transition is playing.
	if not _open or _transitioning:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E or event.keycode == KEY_ESCAPE:
			close_interior()
			get_viewport().set_input_as_handled()
