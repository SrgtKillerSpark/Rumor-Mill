class_name ObjectiveHudBanner
extends Node

## objective_hud_banner.gd — Banner + failure proximity subsystems (SPA-1004).
##
## Extracted from objective_hud.gd.  Manages:
##   • Banner label (dawn bulletin, deadline warnings, show_banner public API)
##   • Dawn overnight reputation summary (SPA-648)
##   • Deadline warning relay from ScenarioManager signal (SPA-797)
##   • Failure proximity warnings (SPA-797) — scenario-specific instant-fail alerts

# ── Urgency colours (duplicated from coordinator for banner color logic) ──────
const C_DAY_CRITICAL := Color(0.95, 0.20, 0.10, 1.0)
const C_DAY_URGENT   := Color(0.95, 0.55, 0.10, 1.0)

# ── Banner state ──────────────────────────────────────────────────────────────
var _banner_label: Label = null
var _banner_tween: Tween = null

# ── Dawn snapshot ─────────────────────────────────────────────────────────────
## NPC id → score from previous dawn for overnight delta comparison.
var _prev_dawn_scores: Dictionary = {}

# ── Failure proximity throttle ────────────────────────────────────────────────
## Tracks which fail-warning keys have already fired this day to avoid spam.
var _fail_warn_fired:    Dictionary = {}
var _fail_warn_last_day: int        = -1

# ── Dependencies ──────────────────────────────────────────────────────────────
var _reputation_system: ReputationSystem  = null
var _scenario_manager:  ScenarioManager   = null
var _day_night:         Node              = null
var _intel_store:       PlayerIntelStore  = null
var _world_ref:         Node2D            = null
var _hud_root:          Node              = null


## Inject dependencies and build the banner label.
## `hud_root` is the parent CanvasLayer — the banner is added as its child so
## it can anchor relative to the viewport.
func setup(
		hud_root: Node,
		rep_system: ReputationSystem,
		scenario_manager: ScenarioManager,
		day_night: Node,
		intel_store: PlayerIntelStore) -> void:
	_hud_root          = hud_root
	_reputation_system = rep_system
	_scenario_manager  = scenario_manager
	_day_night         = day_night
	_intel_store       = intel_store
	_build_banner()


## Called by coordinator once the world node is available.
func setup_world(world: Node2D) -> void:
	_world_ref = world


## Show a banner with text, color, and optional duration (default 6 s).
## Public — also called by ObjectiveHudNudgeManager via Callable from coordinator.
func show_banner(text: String, color: Color, duration: float = 6.0) -> void:
	if _banner_label == null:
		return
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner_label.text = text
	_banner_label.add_theme_color_override("font_color", color)
	_banner_label.modulate.a = 0.0
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner_label, "modulate:a", 1.0, 0.4) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_banner_tween.tween_interval(duration)
	_banner_tween.tween_property(_banner_label, "modulate:a", 0.0, 1.2) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)


## Capture reputation scores at dawn for overnight comparison.
## Call from coordinator._on_day_changed().
func snapshot_dawn_scores() -> void:
	if _reputation_system == null:
		return
	_prev_dawn_scores.clear()
	var snaps: Dictionary = _reputation_system.get_all_snapshots()
	for npc_id in snaps:
		var snap: ReputationSystem.ReputationSnapshot = snaps[npc_id]
		_prev_dawn_scores[npc_id] = snap.score


## Show a morning popup summarizing overnight reputation changes.
## Call from coordinator._on_day_changed().
func show_dawn_bulletin() -> void:
	if _reputation_system == null or _prev_dawn_scores.is_empty():
		return
	var snaps: Dictionary = _reputation_system.get_all_snapshots()
	var lines: Array[String] = []
	for npc_id in snaps:
		if not _prev_dawn_scores.has(npc_id):
			continue
		var snap:       ReputationSystem.ReputationSnapshot = snaps[npc_id]
		var prev_score: int  = _prev_dawn_scores[npc_id]
		var delta:      int  = snap.score - prev_score
		if abs(delta) < 3:
			continue
		var arrow:    String = "+" if delta > 0 else ""
		var npc_name: String = npc_id.replace("_", " ").capitalize()
		lines.append("%s %s%d (%d)" % [npc_name, arrow, delta, snap.score])
	var summary_line: String = _build_dawn_summary_text()
	if lines.is_empty() and summary_line.is_empty():
		return
	var bulletin: String = "Dawn Report"
	if not summary_line.is_empty():
		bulletin += "\n" + summary_line
	if not lines.is_empty():
		bulletin += "\n" + "\n".join(lines)
	show_banner(bulletin, Color(0.85, 0.78, 0.55, 1.0), 8.0)


## Connected to ScenarioManager.deadline_warning signal.
## Call from coordinator.setup() as: scenario_manager.deadline_warning.connect(_banner.on_deadline_warning)
func on_deadline_warning(threshold: float, days_remaining: int) -> void:
	var urgency: String
	var color:   Color
	if threshold >= 0.90:
		urgency = "CRITICAL"
		color   = C_DAY_CRITICAL
	else:
		urgency = "WARNING"
		color   = C_DAY_URGENT
	var text: String = "%s - %d day%s remaining!" % [
		urgency, days_remaining, "" if days_remaining == 1 else "s"]
	show_banner(text, color, 5.0)


## SPA-797: Check scenario-specific instant-fail thresholds and show alerts.
## Call from coordinator._on_tick().
func check_failure_proximity() -> void:
	if _scenario_manager == null or _reputation_system == null or _world_ref == null:
		return
	var current_day: int = _day_night.current_day if _day_night != null else 1
	if current_day != _fail_warn_last_day:
		_fail_warn_fired.clear()
		_fail_warn_last_day = current_day

	var sid: String = _world_ref.active_scenario_id if "active_scenario_id" in _world_ref else ""
	match sid:
		"scenario_1":
			# S1: NPC heat >= 80 is instant fail. Warn at 65+.
			if _intel_store != null:
				for npc_id in _intel_store.heat:
					var heat: float = _intel_store.heat[npc_id]
					if heat >= 65.0 and not _fail_warn_fired.has("s1_heat_%s" % npc_id):
						var npc_name: String = npc_id.replace("_", " ").capitalize()
						show_banner(
							"DANGER: %s's suspicion is rising! (Heat: %d/80)" % [npc_name, int(heat)],
							C_DAY_CRITICAL, 5.0)
						_fail_warn_fired["s1_heat_%s" % npc_id] = true
		"scenario_3":
			# S3: Calder < 35 is instant fail. Warn at 42.
			var calder_snap: ReputationSystem.ReputationSnapshot = _reputation_system.get_snapshot("calder_fenn")
			if calder_snap != null and calder_snap.score <= 42 and not _fail_warn_fired.has("s3_calder"):
				show_banner(
					"DANGER: Calder Fenn's reputation is collapsing! (%d — fails below %d)" % [
						calder_snap.score, _scenario_manager.S3_FAIL_CALDER_BELOW],
					C_DAY_CRITICAL, 5.0)
				_fail_warn_fired["s3_calder"] = true
		"scenario_4":
			# S4: Any protected NPC < 42 is instant fail. Warn at 47.
			for npc_id in ScenarioManager.S4_PROTECTED_NPC_IDS:
				var snap: ReputationSystem.ReputationSnapshot = _reputation_system.get_snapshot(npc_id)
				if snap != null and snap.score <= 47 and not _fail_warn_fired.has("s4_%s" % npc_id):
					var display_name: String = npc_id.split("_")[0].capitalize()
					show_banner(
						"DANGER: %s is in the danger zone! (%d — fails below %d)" % [
							display_name, snap.score, _scenario_manager.S4_FAIL_REP_BELOW],
						C_DAY_CRITICAL, 5.0)
					_fail_warn_fired["s4_%s" % npc_id] = true
		"scenario_5":
			# S5: Aldric < 30 is instant fail. Warn at 38.
			var aldric_snap: ReputationSystem.ReputationSnapshot = _reputation_system.get_snapshot("aldric_vane")
			if aldric_snap != null and aldric_snap.score <= 38 and not _fail_warn_fired.has("s5_aldric"):
				show_banner(
					"DANGER: Aldric Vane is losing support! (%d — fails below %d)" % [
						aldric_snap.score, _scenario_manager.S5_FAIL_ALDRIC_BELOW],
					C_DAY_CRITICAL, 5.0)
				_fail_warn_fired["s5_aldric"] = true
		"scenario_6":
			# S6: Marta < 30 instant fail. Warn at 38. Heat >= 55 instant fail. Warn at 45.
			var marta_snap: ReputationSystem.ReputationSnapshot = _reputation_system.get_snapshot("marta_coin")
			if marta_snap != null and marta_snap.score <= 38 and not _fail_warn_fired.has("s6_marta"):
				show_banner(
					"DANGER: Marta Coin's reputation is dropping! (%d — fails below %d)" % [
						marta_snap.score, _scenario_manager.S6_FAIL_MARTA_BELOW],
					C_DAY_CRITICAL, 5.0)
				_fail_warn_fired["s6_marta"] = true
			if _intel_store != null:
				var player_heat: float = _intel_store.get_heat("player") \
					if _intel_store.has_method("get_heat") else 0.0
				if player_heat >= 45.0 and not _fail_warn_fired.has("s6_heat"):
					show_banner(
						"DANGER: Your exposure is dangerously high! (Heat: %d/%d)" % [
							int(player_heat), int(_scenario_manager.S6_EXPOSED_HEAT)],
						C_DAY_CRITICAL, 5.0)
					_fail_warn_fired["s6_heat"] = true


# ── Build ─────────────────────────────────────────────────────────────────────

func _build_banner() -> void:
	_banner_label = Label.new()
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.anchor_left   = 0.15
	_banner_label.anchor_right  = 0.85
	_banner_label.anchor_top    = 0.0
	_banner_label.anchor_bottom = 0.0
	_banner_label.offset_top    = 165.0
	_banner_label.offset_bottom = 235.0
	_banner_label.offset_left   = 0.0
	_banner_label.offset_right  = 0.0
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_label.add_theme_font_size_override("font_size", 13)
	_banner_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55, 1.0))
	_banner_label.add_theme_constant_override("outline_size", 2)
	_banner_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_banner_label.modulate.a = 0.0
	_banner_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.add_child(_banner_label)


# ── Dawn summary helper ────────────────────────────────────────────────────────

func _build_dawn_summary_text() -> String:
	if _reputation_system == null or _world_ref == null or not "npcs" in _world_ref:
		return ""
	var active_rumors: int  = 0
	var expired_count: int  = 0
	var seen_rids:     Dictionary = {}
	for npc in _world_ref.npcs:
		for rid in npc.rumor_slots:
			if seen_rids.has(rid):
				continue
			seen_rids[rid] = true
			var slot: Rumor.NpcRumorSlot = npc.rumor_slots[rid]
			if slot.state in [Rumor.RumorState.BELIEVE, Rumor.RumorState.SPREAD,
							   Rumor.RumorState.EVALUATING, Rumor.RumorState.ACT]:
				active_rumors += 1
			elif slot.state == Rumor.RumorState.EXPIRED:
				expired_count += 1
	var believers: int = _reputation_system.get_global_believer_count()
	var parts: Array[String] = []
	if active_rumors > 0:
		parts.append("%d active rumour%s" % [active_rumors, "" if active_rumors == 1 else "s"])
	if believers > 0:
		parts.append("%d believer%s" % [believers, "" if believers == 1 else "s"])
	if expired_count > 0:
		parts.append("%d expired" % expired_count)
	if parts.is_empty():
		return ""
	return "Dawn — " + ", ".join(parts)
