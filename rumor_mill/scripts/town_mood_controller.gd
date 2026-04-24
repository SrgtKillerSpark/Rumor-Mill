## town_mood_controller.gd — SPA-695 Channel C: Environmental mood feedback.
## A plain class (no Node inheritance) owned and ticked by World.
## Listens to game state each tick and applies subtle environmental effects:
##
##   1. Building dims when associated NPC reputation drops below 40.
##   2. Ambient audio layer when >=5 NPCs are in SPREAD state.
##   3. Guard patrol speed increase when max player heat > 50.
##   4. Tense music crossfade when win progress exceeds 75%.
##   5. Camera shake + bell sfx at 25/50/75% win milestones.
##
## Initialised in World._init_town_mood_controller(); wired to on_game_tick().
## main.gd should call set_camera() after world setup to enable shake effects.
class_name TownMoodController


# ── External references ──────────────────────────────────────────────────────
var _world: Node2D           = null
var _rep:   ReputationSystem = null
var _sm:    ScenarioManager  = null
var _store: PlayerIntelStore = null
var _camera: Node            = null   # Camera2D — set by main.gd via set_camera()

# ── Building dim overlays ────────────────────────────────────────────────────
## location_id → Polygon2D overlay node added as a World child.
var _building_overlays: Dictionary = {}
## Tracks which buildings are currently dimmed to avoid re-tweening each tick.
var _dimmed_buildings: Dictionary = {}

const _DIM_ALPHA     := 0.35   # overlay alpha when dimmed
const _DIM_FADE_SEC  := 1.0    # fade duration
## SPA-909: Ambient flicker on dimmed buildings (simulates torch/lamp variation).
const _FLICKER_RANGE    := 0.07   # ± alpha around _DIM_ALPHA
const _FLICKER_MIN_SEC  := 0.45
const _FLICKER_MAX_SEC  := 1.25

# ── State tracking ───────────────────────────────────────────────────────────
var _spread_audio_active: bool  = false   # ambient chatter layer playing
var _tension_audio_active: bool = false   # evening_tension crossfade done
var _guards_alerted: bool       = false   # guard speed modifier applied
## Win-progress milestones already fired this session (0.25, 0.50, 0.75).
var _fired_milestones: Array[float] = []
## SPA-909: location_id → active flicker Tween for dimmed buildings.
var _flickering_buildings: Dictionary = {}

const _SPREAD_THRESHOLD  := 5      # NPCs in SPREAD to trigger ambient chatter
const _HEAT_THRESHOLD    := 50.0   # max player heat to alert guards
const _TENSION_THRESHOLD := 0.75   # win progress to crossfade tense music
const _GUARD_SPEED_SCALE := 1.5    # speed multiplier for alerted guards
const _MILESTONES: Array[float]    = [0.25, 0.50, 0.75]


# ── Initialisation ───────────────────────────────────────────────────────────

## Call from World after all systems are ready.
func setup(world: Node2D) -> void:
	_world = world
	_rep   = world.reputation_system
	_sm    = world.scenario_manager
	_store = world.intel_store
	_create_building_overlays()


## Set by main.gd after world initialisation so camera shake works.
func set_camera(cam: Node) -> void:
	_camera = cam


## SPA-925: Apply a scenario-specific environment tint to the world node via a
## smooth canvas modulate transition.  The tint is a subtle multiplicative color
## that shifts the overall atmosphere without obscuring the art.
## Call from main.gd after set_camera(), passing the active scenario id string.
func apply_scenario_mood(scenario_id: String) -> void:
	if _world == null:
		return
	var target: Color = ScenarioEnvironmentPalette.scenario_canvas_tint(scenario_id)
	if target == Color(1.0, 1.0, 1.0, 1.0):
		return  # S1 tutorial: no tint needed
	var tw := _world.create_tween()
	tw.tween_property(_world, "modulate", target, 2.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ── Per-tick entry point ─────────────────────────────────────────────────────

func on_game_tick(tick: int) -> void:
	if _world == null or _rep == null or _sm == null:
		return
	_update_building_dims()
	_update_spread_audio()
	_update_guard_alert()
	_update_tension_audio(tick)
	_check_milestones(tick)


# ── Effect 1: Building dims ──────────────────────────────────────────────────

func _update_building_dims() -> void:
	# For every NPC that has a work_location and a reputation below 40,
	# dim their associated building.
	var npcs: Array = _world.npcs
	var wanted_dim: Dictionary = {}   # location_id → true

	for npc in npcs:
		var work_loc: String = npc.work_location
		if work_loc.is_empty():
			continue
		if not _building_overlays.has(work_loc):
			continue
		var npc_id: String = npc.npc_data.get("id", "")
		if npc_id.is_empty():
			continue
		var snap: ReputationSystem.ReputationSnapshot = _rep.get_snapshot(npc_id)
		if snap == null:
			continue
		if snap.score < 40:
			wanted_dim[work_loc] = true

	# Apply / remove dim for each building overlay.
	for loc in _building_overlays:
		var should_dim: bool = wanted_dim.has(loc)
		var is_dim: bool     = _dimmed_buildings.get(loc, false)
		if should_dim == is_dim:
			continue
		_dimmed_buildings[loc] = should_dim
		var overlay: Polygon2D = _building_overlays[loc]
		if overlay == null:
			continue
		var target_a: float = _DIM_ALPHA if should_dim else 0.0
		var tw := overlay.create_tween()
		tw.tween_property(overlay, "modulate:a", target_a, _DIM_FADE_SEC)
		# SPA-909: Start/stop ambient flicker alongside the dim transition.
		if should_dim:
			tw.tween_callback(_flicker_building.bind(loc, overlay))
		else:
			_stop_flicker(loc)


# ── Effect 2: Ambient chatter audio ─────────────────────────────────────────

func _update_spread_audio() -> void:
	var spread_count := 0
	for npc in _world.npcs:
		if npc.get_worst_rumor_state() == Rumor.RumorState.SPREAD:
			spread_count += 1

	var want_active: bool = (spread_count >= _SPREAD_THRESHOLD)
	if want_active == _spread_audio_active:
		return
	_spread_audio_active = want_active
	# Reflect via SFX — a "rumor_spread" chime signals rising chatter.
	# (A dedicated ambient chatter track is not yet in the asset set.)
	if want_active:
		if AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("rumor_spread")


# ── Effect 3: Guard patrol speed ─────────────────────────────────────────────

func _update_guard_alert() -> void:
	if _store == null or not _store.heat_enabled:
		return

	# Compute max heat across all tracked NPCs.
	var max_heat: float = 0.0
	for npc_id in _store.heat:
		var h: float = _store.heat[npc_id]
		if h > max_heat:
			max_heat = h

	var want_alerted: bool = (max_heat > _HEAT_THRESHOLD)
	if want_alerted == _guards_alerted:
		return
	_guards_alerted = want_alerted

	var scale: float = _GUARD_SPEED_SCALE if want_alerted else 1.0
	for npc in _world.npcs:
		if npc.archetype == NpcSchedule.ScheduleArchetype.GUARD_CIVIC:
			npc.mood_speed_scale = scale


# ── Effect 4: Tense music crossfade ─────────────────────────────────────────

func _update_tension_audio(tick: int) -> void:
	if _tension_audio_active:
		return
	var progress: float = _sm.get_win_progress(_rep, tick)
	if progress >= _TENSION_THRESHOLD:
		_tension_audio_active = true
		if AudioManager.has_method("play_music"):
			AudioManager.play_music("evening_tension", true)


# ── Effect 5: Milestone camera shake + bell ──────────────────────────────────

func _check_milestones(tick: int) -> void:
	var progress: float = _sm.get_win_progress(_rep, tick)
	for threshold in _MILESTONES:
		if _fired_milestones.has(threshold):
			continue
		if progress >= threshold:
			_fired_milestones.append(threshold)
			_play_milestone_effect()
			break  # fire at most one milestone per tick


func _play_milestone_effect() -> void:
	# Bell-like audio cue.
	if AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx("new_day")
	# Camera shake (moderate — noticeable but not jarring).
	if _camera != null and _camera.has_method("shake_screen"):
		_camera.shake_screen(6.0, 0.4)


# ── SPA-909: Ambient building flicker ───────────────────────────────────────

## Entry point: start flicker on a newly dimmed building overlay.
## Chains self-referentially so the effect continues until _stop_flicker() is called.
func _flicker_building(loc: String, overlay: Polygon2D) -> void:
	if overlay == null or not is_instance_valid(overlay):
		_flickering_buildings.erase(loc)
		return
	if _flickering_buildings.has(loc):
		var ft: Tween = _flickering_buildings[loc]
		if ft != null and ft.is_valid():
			return  # already flickering
	_do_flicker_step(loc, overlay)


func _do_flicker_step(loc: String, overlay: Polygon2D) -> void:
	if overlay == null or not is_instance_valid(overlay):
		_flickering_buildings.erase(loc)
		return
	var target_a := clampf(
		_DIM_ALPHA + randf_range(-_FLICKER_RANGE, _FLICKER_RANGE),
		_DIM_ALPHA - _FLICKER_RANGE,
		_DIM_ALPHA + _FLICKER_RANGE
	)
	var duration := randf_range(_FLICKER_MIN_SEC, _FLICKER_MAX_SEC)
	var ft := overlay.create_tween()
	_flickering_buildings[loc] = ft
	ft.tween_property(overlay, "modulate:a", target_a, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ft.tween_callback(_do_flicker_step.bind(loc, overlay))


func _stop_flicker(loc: String) -> void:
	if _flickering_buildings.has(loc):
		var ft: Tween = _flickering_buildings[loc]
		if ft != null and ft.is_valid():
			ft.kill()
		_flickering_buildings.erase(loc)


# ── Building overlay creation ────────────────────────────────────────────────

## Creates a semi-transparent dark Polygon2D for each building footprint.
## Overlays start invisible (modulate.a = 0) and are faded in when needed.
func _create_building_overlays() -> void:
	if _world == null:
		return
	var buildings: Array = _world.buildings
	if buildings.is_empty():
		return

	const HALF_TW := 32.0   # half of tile width (64 / 2)
	const HALF_TH := 16.0   # half of tile height (32 / 2)

	for b in buildings:
		var bname: String = b.get("name", "")
		if bname.is_empty():
			continue
		var bx: int = b.get("x", 0)
		var by: int = b.get("y", 0)
		var bw: int = b.get("width",  2)
		var bh: int = b.get("height", 2)

		# Isometric world position for a tile (cx, cy):
		#   wx = (cx - cy) * HALF_TW
		#   wy = (cx + cy) * HALF_TH
		# Build a polygon covering the full footprint as an isometric diamond.
		var top_x    := float(bx)
		var top_y    := float(by)
		var right_x  := float(bx + bw)
		var right_y  := float(by)
		var bottom_x := float(bx + bw)
		var bottom_y := float(by + bh)
		var left_x   := float(bx)
		var left_y   := float(by + bh)

		var to_world := func(cx: float, cy: float) -> Vector2:
			return Vector2((cx - cy) * HALF_TW, (cx + cy) * HALF_TH)

		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			to_world.call(top_x,    top_y),
			to_world.call(right_x,  right_y),
			to_world.call(bottom_x, bottom_y),
			to_world.call(left_x,   left_y),
		])
		poly.color   = Color(0.0, 0.0, 0.0, 1.0)   # black; alpha controlled via modulate
		poly.modulate.a = 0.0
		poly.z_index = 2   # above terrain, below NPCs
		_world.add_child(poly)
		_building_overlays[bname] = poly
