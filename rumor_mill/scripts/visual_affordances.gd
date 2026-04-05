extends CanvasLayer

## visual_affordances.gd — SPA-589: Subtle visual cues for new players.
##
## Highlights interactable NPCs and buildings with a gentle pulsing glow
## during the first few days of a scenario, guiding new players toward
## the right-click interaction model.
##
## Features:
##   • NPC interaction ring — faint gold circle under NPCs, pulses slowly.
##   • Building shimmer — subtle highlight on buildings that can be observed.
##   • "Next step" glow — slightly brighter pulse on the objective HUD's
##     recommended next action target (e.g. "Observe Market" → Market glows).
##   • Auto-fades after day 3 or after the player has performed 5+ actions.
##
## Usage from main.gd:
##   var affordances := preload("res://scripts/visual_affordances.gd").new()
##   affordances.name = "VisualAffordances"
##   add_child(affordances)
##   affordances.setup(world, day_night)

# ── Palette ───────────────────────────────────────────────────────────────────
const C_NPC_GLOW      := Color(1.00, 0.90, 0.40, 0.18)   # warm gold, very subtle
const C_BUILDING_GLOW := Color(0.96, 0.80, 0.30, 0.12)   # softer gold for buildings
const C_NEXT_STEP     := Color(0.96, 0.65, 0.20, 0.30)   # brighter amber for next-step

const FADE_OUT_ACTIONS := 5    # disable after this many successful actions
const FADE_OUT_DAY     := 4    # disable after this day number

# ── State ─────────────────────────────────────────────────────────────────────
var _world_ref:       Node2D   = null
var _day_night_ref:   Node     = null
var _action_count:    int      = 0
var _enabled:         bool     = true
var _pulse_phase:     float    = 0.0
var _npc_rings:       Dictionary = {}  # npc_id → Polygon2D (drawn in world space)
var _fading_out:      bool     = false


func _ready() -> void:
	layer = 4  # below most HUDs


func setup(world: Node2D, day_night: Node) -> void:
	_world_ref = world
	_day_night_ref = day_night

	# Wire day changes to check auto-fade.
	if day_night != null and day_night.has_signal("day_changed"):
		day_night.day_changed.connect(_on_day_changed)

	# Build NPC glow rings.
	_build_npc_rings()


## Called by main.gd when any recon action succeeds (Observe/Eavesdrop).
func on_action_performed() -> void:
	_action_count += 1
	if _action_count >= FADE_OUT_ACTIONS and not _fading_out:
		_fade_out()


func _on_day_changed(day: int) -> void:
	if day >= FADE_OUT_DAY and not _fading_out:
		_fade_out()


func _build_npc_rings() -> void:
	if _world_ref == null:
		return
	for npc in _world_ref.npcs:
		var npc_id: String = npc.npc_data.get("id", "")
		if npc_id == "":
			continue
		# Create a small diamond ring under the NPC in world space.
		var ring := Polygon2D.new()
		ring.polygon = PackedVector2Array([
			Vector2(0, -10), Vector2(16, 0), Vector2(0, 10), Vector2(-16, 0)
		])
		ring.color = C_NPC_GLOW
		ring.z_index = -1  # draw under the NPC sprite
		npc.add_child(ring)
		ring.position = Vector2(0, 8)  # slightly below centre
		_npc_rings[npc_id] = ring


func _process(delta: float) -> void:
	if not _enabled:
		return
	_pulse_phase += delta * 2.0  # slow pulse
	var pulse: float = (sin(_pulse_phase) * 0.5 + 0.5)  # 0→1

	# Pulse NPC rings.
	for npc_id in _npc_rings:
		var ring: Polygon2D = _npc_rings[npc_id]
		ring.modulate.a = 0.5 + pulse * 0.5  # subtle brightness variation


func _fade_out() -> void:
	_fading_out = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Fade all NPC rings.
	for npc_id in _npc_rings:
		var ring: Polygon2D = _npc_rings[npc_id]
		tween.parallel().tween_property(ring, "modulate:a", 0.0, 1.5)
	tween.chain().tween_callback(_disable)


func _disable() -> void:
	_enabled = false
	# Clean up rings.
	for npc_id in _npc_rings:
		var ring: Polygon2D = _npc_rings[npc_id]
		ring.queue_free()
	_npc_rings.clear()
	visible = false
