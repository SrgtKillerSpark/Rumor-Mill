extends BaseScenarioHud

## scenario4_hud.gd — Persistent triple-track reputation defence display.
##
## Shows a thin header tracking the three protected NPCs' reputation scores
## against the Scenario 4 fail threshold (< 50) and 20-day survival win.
##
## Layout:
##   Scenario 4: The Holy Inquisition
##   [Aldous Prior]   Rep: 60 / 100   Floor: 50  [bar]
##   [Vera Midwife]   Rep: 55 / 100   Floor: 50  [bar]
##   [Finn Monk]      Rep: 50 / 100   Floor: 50  [bar]
##   Days remaining: 20       Inquisitor: no activity yet
##
## Wire via setup(world, day_night) from main.gd.

# ── S4-specific palette ──────────────────────────────────────────────────────
const C_DEFEND := Color(0.50, 0.80, 1.00, 1.0)  # sky blue for defending

const BAR_WIDTH  := 100
const BAR_HEIGHT := 8

const NPC_DISPLAY_NAMES := {
	"aldous_prior": "Aldous Prior",
	"vera_midwife": "Vera Midwife",
	"finn_monk":    "Finn Monk",
}

# ── Node refs ────────────────────────────────────────────────────────────────
var _score_labels:   Dictionary = {}  # npc_id -> Label
var _bars:           Dictionary = {}  # npc_id -> ColorRect (fill)
var _bar_bgs:        Dictionary = {}  # npc_id -> ColorRect (background)
var _inquisitor_lbl: Label      = null


func _scenario_number() -> int:
	return 4


func _on_setup_extra(world: Node2D) -> void:
	var inquisitor = world.get("inquisitor_agent") if world != null else null
	if inquisitor != null:
		inquisitor.inquisitor_acted.connect(notify_inquisitor_acted)


# ── UI construction ──────────────────────────────────────────────────────────

func _build_ui() -> void:
	var hbox := _make_panel("Scenario4Panel", 78, 14)

	# Title.
	var title_lbl := Label.new()
	title_lbl.text = "Scenario 4:"
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", C_HEADING)
	title_lbl.tooltip_text = "The Holy Inquisition — keep all three accused above 50 reputation for 20 days."
	title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(title_lbl)

	# NPC tracks.
	const NPC_TOOLTIPS := {
		"aldous_prior": "Aldous Prior's reputation. Keep above 50 or the scenario fails immediately.",
		"vera_midwife": "Vera Midwife's reputation. Keep above 50 or the scenario fails immediately.",
		"finn_monk":    "Finn Monk's reputation. Keep above 50 or the scenario fails immediately.",
	}
	for npc_id in ScenarioManager.S4_PROTECTED_NPC_IDS:
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 2)
		hbox.add_child(vbox)

		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", C_BODY)
		lbl.text = "%s  Rep: 50 / 100  Floor: 50" % NPC_DISPLAY_NAMES.get(npc_id, npc_id)
		lbl.tooltip_text = NPC_TOOLTIPS.get(npc_id, "Keep this NPC's reputation above 50.")
		lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		vbox.add_child(lbl)
		_score_labels[npc_id] = lbl

		var bar_pair := _make_progress_bar(BAR_WIDTH, BAR_HEIGHT,
			"Reputation bar — green means safe (>=50), red means failing (<50).")
		var bar_bg: ColorRect = bar_pair[0]
		var bar:    ColorRect = bar_pair[1]
		vbox.add_child(bar_bg)
		_bar_bgs[npc_id] = bar_bg
		_bars[npc_id]    = bar

	# Right column: days + result + inquisitor.
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 2)
	hbox.add_child(right_vbox)

	_days_lbl = Label.new()
	_days_lbl.add_theme_font_size_override("font_size", 12)
	_days_lbl.add_theme_color_override("font_color", C_BODY)
	_days_lbl.text = "Days remaining: 20"
	_days_lbl.tooltip_text = "Days before the Inquisitor presents his findings to the Bishop. Survive all 20 days with all three above 50 to win."
	_days_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	right_vbox.add_child(_days_lbl)

	_result_lbl = Label.new()
	_result_lbl.add_theme_font_size_override("font_size", 14)
	_result_lbl.add_theme_color_override("font_color", C_WIN)
	_result_lbl.text = ""
	right_vbox.add_child(_result_lbl)

	var legend_lbl := Label.new()
	legend_lbl.add_theme_font_size_override("font_size", 11)
	legend_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.50, 0.85))
	legend_lbl.text = "[safe] >= 50  [danger] < 50"
	right_vbox.add_child(legend_lbl)

	_inquisitor_lbl = Label.new()
	_inquisitor_lbl.add_theme_font_size_override("font_size", 12)
	_inquisitor_lbl.add_theme_color_override("font_color", Color(0.65, 0.55, 0.45, 0.80))
	_inquisitor_lbl.text = "Inquisitor: no activity yet"
	_inquisitor_lbl.tooltip_text = "The inquisitor seeds accusation and heresy rumors against the three protected NPCs. Counter with praise and defend rumors."
	_inquisitor_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	right_vbox.add_child(_inquisitor_lbl)


# ── Refresh ──────────────────────────────────────────────────────────────────

func _refresh() -> void:
	if not _has_world_deps():
		return

	var rep: ReputationSystem = _world_ref.reputation_system
	var sm:  ScenarioManager  = _world_ref.scenario_manager
	var progress: Dictionary  = sm.get_scenario_4_progress(rep)
	var scores: Dictionary    = progress["protected_scores"]
	var win_thr: int          = progress["win_threshold"]
	var state                 = progress["state"]

	for npc_id in ScenarioManager.S4_PROTECTED_NPC_IDS:
		var score: int = scores.get(npc_id, 50)
		if _score_labels.has(npc_id):
			_score_labels[npc_id].text = "%s  Rep: %d / 100  Floor: %d" % [
				NPC_DISPLAY_NAMES.get(npc_id, npc_id), score, win_thr]
		if _bars.has(npc_id):
			_bars[npc_id].custom_minimum_size.x = BAR_WIDTH * clamp(float(score) / 100.0, 0.0, 1.0)
			_bars[npc_id].color = C_WIN if score >= win_thr else C_FAIL

	_update_days_remaining(sm)
	_update_result_label(state,
		"VICTORY — The accused are safe",
		"FAILED — The inquisitor prevails")


# ── Inquisitor activity ──────────────────────────────────────────────────────

## Called by inquisitor_agent.inquisitor_acted signal.
func notify_inquisitor_acted(day: int, claim_type: String, subject_id: String) -> void:
	if _inquisitor_lbl == null:
		return
	var subject_display := NPC_DISPLAY_NAMES.get(subject_id, _display_name(subject_id))
	_inquisitor_lbl.text = "Inquisitor: Day %d — %s on %s" % [day, claim_type.capitalize(), subject_display]
	_inquisitor_lbl.add_theme_color_override("font_color", Color(1.0, 0.30, 0.15, 1.0))
	var tween := create_tween()
	tween.tween_property(_inquisitor_lbl, "modulate:a", 0.25, 0.12)
	tween.tween_property(_inquisitor_lbl, "modulate:a", 1.0, 0.30)
