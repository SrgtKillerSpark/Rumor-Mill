## rumor_event_wiring.gd — SPA-1002: Rumor event relay, VFX, reward moments, and planning counters.
##
## Extracted from main.gd (_wire_rumor_events, _on_rumor_event, _on_rumor_seeded,
## reward moments, gossip VFX, parchment toasts, daily planning counters).
## Add as a child of main then call setup().

class_name RumorEventWiring
extends Node

var _world: Node2D = null
var _day_night: Node = null
var _camera: Camera2D = null
var _journal: CanvasLayer = null
var _recon_hud: CanvasLayer = null
var _rumor_panel: CanvasLayer = null
var _social_graph_overlay: CanvasLayer = null
var _objective_hud: CanvasLayer = null
var _milestone_notifier: CanvasLayer = null
var _daily_planning: CanvasLayer = null

# ── SPA-788: First-time reward moment guards ──────────────────────────────────
var _reward_first_spread_fired: bool = false
var _reward_first_belief_fired: bool = false


## Wire all rumor event signals and store references.
func setup(
		world: Node2D,
		day_night: Node,
		camera: Camera2D,
		journal: CanvasLayer,
		recon_hud: CanvasLayer,
		rumor_panel: CanvasLayer,
		social_graph_overlay: CanvasLayer,
		objective_hud: CanvasLayer,
		milestone_notifier: CanvasLayer,
		daily_planning: CanvasLayer,
		recon_ctrl: Node,
) -> void:
	_world = world
	_day_night = day_night
	_camera = camera
	_journal = journal
	_recon_hud = recon_hud
	_rumor_panel = rumor_panel
	_social_graph_overlay = social_graph_overlay
	_objective_hud = objective_hud
	_milestone_notifier = milestone_notifier
	_daily_planning = daily_planning

	# ── Wire world rumor event signals ────────────────────────────────────────
	if _world != null:
		_world.rumor_event.connect(_on_rumor_event)
		_world.socially_dead_triggered.connect(_on_socially_dead_triggered)
		if _world.has_signal("cascade_triggered"):
			_world.cascade_triggered.connect(_on_cascade_triggered)
		if _world.has_signal("rumor_target_shifted"):
			_world.rumor_target_shifted.connect(_on_rumor_target_shifted)
		if "npcs" in _world:
			for npc in _world.npcs:
				if npc.has_signal("rumor_transmitted"):
					npc.rumor_transmitted.connect(_on_first_rumor_transmitted)
				if npc.has_signal("rumor_state_changed"):
					npc.rumor_state_changed.connect(_on_first_belief_flip)

	# ── Wire rumor panel signals ──────────────────────────────────────────────
	if _rumor_panel != null and _journal != null:
		_rumor_panel.rumor_seeded.connect(_on_rumor_seeded)
	if _rumor_panel != null:
		_rumor_panel.rumor_seeded.connect(_on_rumor_seeded_for_planning)

	# ── Wire recon controller signals for planning counters ───────────────────
	if recon_ctrl != null:
		recon_ctrl.action_performed.connect(_on_recon_action_for_planning)
		recon_ctrl.bribe_executed.connect(_on_bribe_for_planning)
		recon_ctrl.bribe_executed.connect(_on_bribe_executed)


# ── Rumor seeded handlers ────────────────────────────────────────────────────

## Called when the player successfully seeds a rumor via the crafting panel.
func _on_rumor_seeded(
		rumor_id: String,
		subject_name: String,
		claim_id: String,
		seed_target_name: String
) -> void:
	AudioManager.on_rumor_seeded(rumor_id, subject_name, claim_id, seed_target_name)
	_camera_shake(5.0, 0.3)
	# SPA-861: Screen-space whisper-glyph burst from the HUD area.
	_spawn_rumor_seed_burst()
	# SPA-805: Ripple VFX on the seed target NPC.
	_spawn_seed_ripple(seed_target_name)
	# SPA-805: Pulse the Believers counter on the objective HUD.
	if _objective_hud != null and _objective_hud.has_method("pulse_believers_counter"):
		_objective_hud.pulse_believers_counter()
	if _journal != null and _journal.has_method("push_timeline_event"):
		var _seed_tick: int = _day_night.current_tick if _day_night != null else 0
		_journal.push_timeline_event(
			_seed_tick,
			"Seeded rumor [%s] about %s — whispered to %s" % [
				claim_id, subject_name, seed_target_name
			]
		)
	# Toast + feed entry confirming the plant-rumor action to the player.
	var toast_msg := "Whispered to %s — [%s] about %s" % [seed_target_name, claim_id, subject_name]
	if _recon_hud != null and _recon_hud.has_method("show_toast"):
		_recon_hud.show_toast(toast_msg, true)
	# Build spread-path preview from seed target's social graph.
	var spread_line := _build_spread_preview(seed_target_name)
	var feed_msg := toast_msg if spread_line.is_empty() else toast_msg + "\n" + spread_line
	if _recon_hud != null and _recon_hud.has_method("push_feed_entry"):
		_recon_hud.push_feed_entry(feed_msg, true)


## SPA-885: Builds a short "likely spread path" hint string for the feed entry
## after the player seeds a rumor. Looks up the seed target NPC and calls
## get_spread_preview() to rank top-3 transmission targets.
func _build_spread_preview(seed_target_name: String) -> String:
	if _world == null:
		return ""
	var seed_npc: Node2D = null
	for npc in _world.npcs:
		var nid: String = npc.npc_data.get("id", "")
		if nid.replace("_", " ").capitalize() == seed_target_name:
			seed_npc = npc
			break
	if seed_npc == null or not seed_npc.has_method("get_spread_preview"):
		return ""
	var preview: Array = seed_npc.get_spread_preview(3)
	if preview.is_empty():
		return ""
	var names: Array[String] = []
	for entry in preview:
		names.append(entry.get("name", "?"))
	return "  → May reach: %s" % ", ".join(names)


# ── Seed VFX ─────────────────────────────────────────────────────────────────

## SPA-805: Spawn expanding ring VFX at the seed target NPC's world position.
## Looks up the NPC by display name among world.npcs.
func _spawn_seed_ripple(seed_target_name: String) -> void:
	if _world == null:
		return
	var npc_pos := Vector2.ZERO
	var found := false
	for npc in _world.npcs:
		var nid: String = npc.npc_data.get("id", "")
		if nid.replace("_", " ").capitalize() == seed_target_name:
			npc_pos = npc.global_position
			# SPA-903: Immediate amber sprite flash before the ripple VFX lands.
			if npc.has_method("flash_seed_confirmation"):
				npc.flash_seed_confirmation()
			found = true
			break
	if not found:
		return
	var fx := preload("res://scripts/rumor_ripple_vfx.gd").new()
	_world.add_child(fx)
	fx.global_position = npc_pos


## SPA-861: Brief screen-space whisper-glyph burst confirming rumor seeding.
## 12 small glyphs fan outward from the bottom-left counter area and fade.
func _spawn_rumor_seed_burst() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	# Origin near the whisper pip counter (top-left HUD panel area).
	var origin := Vector2(140.0, 80.0)
	const GLYPHS: Array = ["✦", "~", "✧", "…", "✦", "~", "✧", "…", "✦", "~", "✧", "…"]
	const C_WHISPER := Color(0.55, 0.75, 1.0, 1.0)
	const C_GOLD    := Color(0.92, 0.78, 0.22, 1.0)
	for i in GLYPHS.size():
		var lbl := Label.new()
		lbl.text = GLYPHS[i]
		lbl.add_theme_font_size_override("font_size", randi_range(11, 18))
		var col: Color = C_WHISPER if i % 2 == 0 else C_GOLD
		col.a = randf_range(0.75, 1.0)
		lbl.add_theme_color_override("font_color", col)
		lbl.add_theme_constant_override("outline_size", 1)
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		lbl.position = origin + Vector2(randf_range(-18.0, 18.0), randf_range(-10.0, 10.0))
		layer.add_child(lbl)
		var angle := randf_range(-TAU * 0.4, 0.0)   # fan upward and sideways
		var dist  := randf_range(55.0, 120.0)
		var travel := Vector2(cos(angle), sin(angle)) * dist
		var delay  := randf_range(0.0, 0.15)
		var dur    := randf_range(0.55, 0.90)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(lbl, "position", lbl.position + travel, dur) \
			.set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(lbl, "modulate:a", 0.0, dur * 0.8) \
			.set_delay(delay + dur * 0.25)
	get_tree().create_timer(1.5).timeout.connect(func() -> void:
		if is_instance_valid(layer):
			layer.queue_free()
	)


# ── Milestone / scenario-specific handlers ───────────────────────────────────

## SPA-805: Called when scenario_manager emits s1_first_blood (Edric rep < 48).
func on_s1_first_blood() -> void:
	if _milestone_notifier != null and _milestone_notifier.has_method("show_milestone"):
		_milestone_notifier.show_milestone(
			"First Blood — Edric's reputation cracks!",
			Color(0.92, 0.45, 0.12, 1.0)
		)


## Called when the player bribes an NPC; logs the event to the journal timeline.
func _on_bribe_executed(npc_name: String, tick: int) -> void:
	if _journal != null and _journal.has_method("push_timeline_event"):
		_journal.push_timeline_event(tick, "Bribed %s — forced to believe a rumor" % npc_name)


# ── SPA-708: Daily planning priority counter handlers ─────────────────────────

func _on_recon_action_for_planning(message: String, success: bool) -> void:
	if _daily_planning == null or not success:
		return
	var lower := message.to_lower()
	if lower.find("observe") >= 0:
		_daily_planning.increment_counter("observe_count")
	elif lower.find("eavesdrop") >= 0:
		_daily_planning.increment_counter("eavesdrop_count")


func _on_bribe_for_planning(_npc_name: String, _tick: int) -> void:
	if _daily_planning != null:
		_daily_planning.increment_counter("bribe_count")


func _on_rumor_seeded_for_planning(
		_rumor_id: String, _subject_name: String,
		_claim_id: String, seed_target_name: String
) -> void:
	if _daily_planning == null:
		return
	_daily_planning.increment_counter("whisper_count")
	# Check if target is clergy for the specific priority.
	if seed_target_name.to_lower().find("clergy") >= 0 or seed_target_name.to_lower().find("priest") >= 0 or seed_target_name.to_lower().find("friar") >= 0:
		_daily_planning.increment_counter("whisper_clergy")


# ── Rumor event relay ────────────────────────────────────────────────────────

## Relay world rumor events into the Journal timeline and overlay.
## Also fire milestone HUD effects for the most impactful events.
func _on_rumor_event(message: String, tick: int) -> void:
	# SPA-848: diagnostic lines are embedded after "\n" — split to keep journal entry clean.
	var parts := message.split("\n", false, 1)
	var main_msg := parts[0]
	var diagnostic := parts[1] if parts.size() > 1 else ""
	if _journal != null and _journal.has_method("push_timeline_event"):
		_journal.push_timeline_event(tick, main_msg, diagnostic)
	if _social_graph_overlay != null and _social_graph_overlay.has_method("on_rumor_event"):
		_social_graph_overlay.on_rumor_event(main_msg)
	# SPA-827: Cause-and-effect toast + feed entry + ripple VFX on each NPC-to-NPC spread.
	# Format: "FromName whispered to ToName [id]"
	if main_msg.contains("whispered to"):
		var wt_parts := main_msg.split(" whispered to ", false)
		if wt_parts.size() >= 2:
			var from_name := wt_parts[0].strip_edges()
			var to_part := wt_parts[1].split(" [", false)
			var to_name := to_part[0].strip_edges()
			var to_role := ""
			var to_npc_pos := Vector2.ZERO
			if _world != null:
				for npc in _world.npcs:
					if npc.npc_data.get("name", "") == to_name:
						to_role = npc.npc_data.get("role", "")
						to_npc_pos = npc.global_position
						break
			# Toast: show FROM → TO so the chain of cause-and-effect is explicit.
			var from_first := from_name.split(" ")[0]
			var to_first   := to_name.split(" ")[0]
			var toast_msg: String
			if to_role != "":
				toast_msg = "%s → %s the %s — rumor spreads!" % [from_first, to_first, to_role]
			else:
				toast_msg = "%s → %s — rumor spreads!" % [from_first, to_first]
			if _recon_hud != null:
				if _recon_hud.has_method("show_toast"):
					_recon_hud.show_toast(toast_msg, true)
				# Feed entry so the spread chain is visible in Recent Actions.
				if _recon_hud.has_method("push_feed_entry"):
					_recon_hud.push_feed_entry("%s told %s" % [from_first, to_first], true)
			# Ripple VFX at the receiving NPC's world position.
			# Blue-tinted (vs. gold at seed) so the player can distinguish origin from spread.
			if to_npc_pos != Vector2.ZERO and _world != null:
				var fx := preload("res://scripts/rumor_ripple_vfx.gd").new()
				fx.accent_color = Color(0.45, 0.80, 1.0, 0.75)
				_world.add_child(fx)
				fx.global_position = to_npc_pos

	# Milestone visual feedback for key state-change events.
	if _recon_hud != null and _recon_hud.has_method("show_milestone"):
		if main_msg.contains("→ Believe"):
			var npc_name := main_msg.split(" →")[0].strip_edges() if " →" in main_msg else "NPC"
			_recon_hud.show_milestone("%s is convinced!" % npc_name, Color(0.50, 1.00, 0.55, 1.0))
			# SPA-827: Golden flash to reinforce the belief moment — clear cause-and-effect signal.
			if _recon_hud.has_method("show_action_flash"):
				_recon_hud.show_action_flash(true)
		elif main_msg.contains("→ Spread"):
			var npc_name := main_msg.split(" →")[0].strip_edges() if " →" in main_msg else "NPC"
			_recon_hud.show_milestone("%s is spreading the word!" % npc_name, Color(0.40, 0.85, 1.00, 1.0))
			# SPA-922: Flash to reinforce spread — makes NPC-to-NPC propagation more noticeable.
			if _recon_hud.has_method("show_action_flash"):
				_recon_hud.show_action_flash(true)
		elif main_msg.contains("→ Act"):
			var npc_name := main_msg.split(" →")[0].strip_edges() if " →" in main_msg else "NPC"
			_recon_hud.show_milestone("%s takes action!" % npc_name, Color(1.00, 0.85, 0.20, 1.0))
		elif main_msg.contains("→ Reject"):
			var npc_name := main_msg.split(" →")[0].strip_edges() if " →" in main_msg else "NPC"
			_recon_hud.show_milestone("%s rejected the rumor" % npc_name, Color(0.85, 0.40, 0.30, 1.0))

	# SPA-860 / SPA-917: SFX for each NPC belief-state transition.
	if main_msg.contains("→ Believe"):
		AudioManager.on_rumor_success()
	elif main_msg.contains("→ Spread"):
		AudioManager.play_event("rumor_seeded")
	elif main_msg.contains("→ Act"):
		AudioManager.play_sfx("victory_chime")
	elif main_msg.contains("→ Reject"):
		AudioManager.play_sfx("failure_bell")


# ── SPA-788: Reward moments ──────────────────────────────────────────────────

## SPA-788 Moment 1: fires once the first time any NPC-to-NPC rumor transmission occurs.
## Layered audio motif + gossip-line particles + parchment toast + brief camera nudge.
func _on_first_rumor_transmitted(from_name: String, to_name: String, _rumor_id: String, _outcome: String) -> void:
	if _reward_first_spread_fired:
		return
	_reward_first_spread_fired = true

	# Audio: 2-note descending minor-third whisper motif (semitone ratio 2^(-3/12) ≈ 0.841).
	AudioManager.play_sfx_pitched("whisper", 1.0)
	get_tree().create_timer(0.28).timeout.connect(
		func() -> void: AudioManager.play_sfx_pitched("whisper", 0.841), CONNECT_ONE_SHOT
	)

	# Visual: gossip-line particle trail from spreader to receiver.
	var from_pos := Vector2.ZERO
	var to_pos   := Vector2.ZERO
	if _world != null and "npcs" in _world:
		for npc in _world.npcs:
			var nm: String = npc.npc_data.get("name", "")
			if nm == from_name:
				from_pos = npc.global_position
			if nm == to_name:
				to_pos = npc.global_position
	if from_pos != Vector2.ZERO and to_pos != Vector2.ZERO:
		_spawn_gossip_line_particles(from_pos, to_pos)

	# UI: parchment-styled toast.
	_show_parchment_toast("Your words have found new lips.", 3.0)

	# Feel: brief camera nudge (120 ms).
	_camera_shake(3.5, 0.12)


## SPA-788 Moment 2: fires once when any NPC first transitions to BELIEVE / SPREAD / ACT.
## Conviction audio chime + dark vignette flash + thought-bubble override + milestone popup
## + belief-shaken walk penalty for the rest of the day.
func _on_first_belief_flip(npc_name: String, new_state_name: String, _rumor_id: String) -> void:
	if _reward_first_belief_fired:
		return
	if new_state_name != "BELIEVE" and new_state_name != "SPREAD" and new_state_name != "ACT":
		return
	_reward_first_belief_fired = true

	# Audio: reputation_down pitched down 2 semitones (2^(-2/12) ≈ 0.891) + conviction chime.
	AudioManager.play_sfx_pitched("reputation_down", 0.891)
	AudioManager.play_event("objective_progress")

	# Visual: NPC dark-vignette flash + thought-bubble conviction override.
	if _world != null and "npcs" in _world:
		for npc in _world.npcs:
			if npc.npc_data.get("name", "") == npc_name:
				if npc.has_method("flash_belief_vignette"):
					npc.flash_belief_vignette()
				if npc.has_method("set_belief_shaken"):
					npc.set_belief_shaken(true)
				var bubble: Node = npc.get("_thought_bubble")
				if bubble != null and bubble.has_method("show_override"):
					bubble.show_override("!", Color(0.40, 1.00, 0.50, 1.0), 2.0)
				break

	# UI: milestone popup, green-coded — fires exactly once per session.
	if _milestone_notifier != null and _milestone_notifier.has_method("show_milestone"):
		_milestone_notifier.show_milestone(
			"A townsfolk has become a true believer.",
			Color(0.50, 1.00, 0.55, 1.0),
			"first_belief_flip"
		)


## SPA-850: Cascade celebration — 3+ NPCs believed the same rumor in one day.
## Shows "RUMOR WILDFIRE" milestone popup with amber particles and audio burst.
func _on_cascade_triggered(rumor_id: String, believer_count: int) -> void:
	# Audio burst: milestone chime + pitched-up reputation_up for excitement.
	AudioManager.play_event("objective_progress")
	AudioManager.play_sfx_pitched("reputation_up", 1.12)

	# Milestone popup — amber/orange color, scaled particle count by believer count.
	var text := "RUMOR WILDFIRE — %d new believers!" % believer_count
	if _milestone_notifier != null and _milestone_notifier.has_method("show_milestone"):
		_milestone_notifier.show_milestone(
			text,
			Color(1.00, 0.75, 0.20, 1.0),
			""
		)

	# Toast in recon HUD for the activity feed.
	if _recon_hud != null and _recon_hud.has_method("show_toast"):
		_recon_hud.show_toast(text, true)

	# Journal log so the cascade is visible in the timeline.
	if _journal != null and _journal.has_method("push_timeline_event"):
		var tick: int = 0
		if _world != null and _world.day_night != null:
			tick = _world.day_night.current_tick
		_journal.push_timeline_event(tick, text)

	# Camera shake for visceral feedback.
	_camera_shake(5.0, 0.18)


# ── VFX helpers ────────────────────────────────────────────────────────────��─

## SPA-788: Spawns a world-space CPUParticles2D trail between two NPC positions.
## Uses a direction + velocity range so particles fly from spreader toward receiver.
func _spawn_gossip_line_particles(from_pos: Vector2, to_pos: Vector2) -> void:
	if _world == null:
		return
	var dir    := (to_pos - from_pos).normalized()
	var dist   := from_pos.distance_to(to_pos)
	var travel_time := 0.8  # seconds — matches lifetime

	var particles := CPUParticles2D.new()
	particles.name = "GossipLineParticles"
	particles.global_position          = from_pos
	particles.z_index                  = 10
	particles.emitting                 = true
	particles.one_shot                 = true
	particles.amount                   = 18
	particles.lifetime                 = travel_time
	particles.explosiveness            = 0.0
	particles.spread                   = 8.0
	particles.direction                = dir
	particles.initial_velocity_min     = dist / travel_time * 0.85
	particles.initial_velocity_max     = dist / travel_time * 1.10
	particles.color                    = Color(0.95, 0.78, 0.30, 0.72)  # thin gold thread
	particles.scale_amount_min         = 1.5
	particles.scale_amount_max         = 3.0
	_world.add_child(particles)
	get_tree().create_timer(travel_time + 0.25).timeout.connect(
		func() -> void:
			if is_instance_valid(particles):
				particles.queue_free(),
		CONNECT_ONE_SHOT
	)


## SPA-788: Shows a warm parchment-coloured floating toast for duration seconds.
## Created as a transient CanvasLayer (layer 19) that removes itself when done.
func _show_parchment_toast(text: String, duration: float) -> void:
	var cl := CanvasLayer.new()
	cl.name  = "ParchmentToast"
	cl.layer = 19
	add_child(cl)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.70, 0.56, 0.28, 0.92)  # warm parchment
	style.set_corner_radius_all(5)
	style.content_margin_left   = 12.0
	style.content_margin_right  = 12.0
	style.content_margin_top    = 7.0
	style.content_margin_bottom = 7.0
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 76.0
	cl.add_child(panel)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.16, 0.09, 0.04, 1.0))  # dark ink
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.25))
	panel.add_child(lbl)

	panel.modulate.a = 0.0
	var tween := cl.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(duration)
	tween.tween_property(panel, "modulate:a", 0.0, 0.40).set_ease(Tween.EASE_IN)
	tween.tween_callback(cl.queue_free)


## Show a HUD toast + milestone when an NPC first becomes SOCIALLY_DEAD.
func _on_socially_dead_triggered(_npc_id: String, npc_name: String, _tick: int) -> void:
	if _recon_hud != null and _recon_hud.has_method("show_toast"):
		_recon_hud.show_toast("%s is SOCIALLY DEAD — reputation permanently frozen" % npc_name, false)
	if _recon_hud != null and _recon_hud.has_method("show_milestone"):
		_recon_hud.show_milestone("☠ %s — SOCIALLY DEAD" % npc_name, Color(0.85, 0.15, 0.15, 1.0))


## SPA-1664: Show a parchment toast + feed entry when propagation shifts a rumor's target.
## Uses a muted amber-purple style to distinguish it from gold spread toasts.
func _on_rumor_target_shifted(old_name: String, new_name: String, _rumor_id: String) -> void:
	var msg := "Rumor about %s has shifted to %s — NPCs reinterpret whispers as they spread." % [old_name, new_name]
	_show_target_shift_toast(msg, 4.5)
	if _recon_hud != null and _recon_hud.has_method("push_feed_entry"):
		_recon_hud.push_feed_entry("Target shift: %s → %s" % [old_name, new_name], false)


## SPA-1664: Amber-purple parchment toast for target-shift events.
## Distinct colour from gold spread toasts so the player can tell the mechanic apart.
func _show_target_shift_toast(text: String, duration: float) -> void:
	var cl := CanvasLayer.new()
	cl.name  = "TargetShiftToast"
	cl.layer = 19
	add_child(cl)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.42, 0.28, 0.62, 0.93)  # muted amber-purple
	style.set_corner_radius_all(5)
	style.content_margin_left   = 14.0
	style.content_margin_right  = 14.0
	style.content_margin_top    = 8.0
	style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 108.0  # below the spread toast row
	cl.add_child(panel)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.96, 0.90, 1.0, 1.0))  # pale lavender text
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.45))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size = Vector2(320.0, 0.0)
	panel.add_child(lbl)

	panel.modulate.a = 0.0
	var tween := cl.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.35) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(duration)
	tween.tween_property(panel, "modulate:a", 0.0, 0.40).set_ease(Tween.EASE_IN)
	tween.tween_callback(cl.queue_free)


# ── Internal helpers ─────────────────────────────────────────────────────────

func _camera_shake(intensity: float, duration: float) -> void:
	if _camera != null and _camera.has_method("shake_screen"):
		_camera.shake_screen(intensity, duration)
