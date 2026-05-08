class_name EndScreenReplayTab
extends RefCounted

## end_screen_replay_tab.gd — Analytics / Replay tab content builder for EndScreen.
##
## Extracted from end_screen.gd (SPA-1010). Owns all replay-tab UI construction
## and analytics data rendering (timeline, top influencers, key moments).
##
## Call setup(replay_container, analytics_ref) once refs are known.
## Call populate() to (re-)build the tab content.

# ── Palette ───────────────────────────────────────────────────────────────────
const C_HEADING    := Color(0.91, 0.85, 0.70, 1.0)
const C_BODY       := Color(0.70, 0.65, 0.55, 1.0)
const C_SUBHEADING := Color(0.75, 0.65, 0.50, 1.0)
const C_MUTED      := Color(0.60, 0.53, 0.42, 1.0)
const C_STAT_LABEL := Color(0.75, 0.65, 0.50, 1.0)
const C_PANEL_BORDER := Color(0.55, 0.38, 0.18, 1.0)

const C_BAR_HIGH    := Color(0.92, 0.78, 0.12, 1.0)
const C_BAR_MED     := Color(0.85, 0.65, 0.15, 1.0)
const C_BAR_LOW     := Color(0.50, 0.45, 0.38, 1.0)
const C_MOMENT_SEED := Color(0.40, 0.75, 0.40, 1.0)
const C_MOMENT_PEAK := Color(0.92, 0.78, 0.12, 1.0)
const C_MOMENT_BAD  := Color(0.85, 0.18, 0.12, 1.0)

# ── Runtime refs ──────────────────────────────────────────────────────────────
var _replay_container: VBoxContainer    = null
var _analytics_ref:    ScenarioAnalytics = null


func setup(replay_container: VBoxContainer, analytics_ref: ScenarioAnalytics) -> void:
	_replay_container = replay_container
	_analytics_ref    = analytics_ref


## (Re-)populate the Replay tab with analytics data from ScenarioAnalytics.
func populate() -> void:
	for child in _replay_container.get_children():
		child.queue_free()

	if _analytics_ref == null:
		return

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_replay_container.add_child(scroll)

	var replay_content := VBoxContainer.new()
	replay_content.add_theme_constant_override("separation", 10)
	replay_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(replay_content)

	_build_timeline_section(replay_content)
	replay_content.add_child(_make_separator())
	_build_influence_section(replay_content)
	replay_content.add_child(_make_separator())
	_build_moments_section(replay_content)


# ── Private builders ──────────────────────────────────────────────────────────

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = C_PANEL_BORDER
	sep_style.set_content_margin_all(0)
	sep.add_theme_stylebox_override("separator", sep_style)
	return sep


func _build_timeline_section(parent: VBoxContainer) -> void:
	var heading := Label.new()
	heading.text = "RUMOR TIMELINE"
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", C_HEADING)
	parent.add_child(heading)

	var data: Array = _analytics_ref.get_timeline_data()
	if data.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No rumor activity recorded."
		empty_lbl.add_theme_color_override("font_color", C_MUTED)
		parent.add_child(empty_lbl)
		return

	var max_count := 1
	for entry in data:
		var count: int = entry.get("believer_count", 0)
		if count > max_count:
			max_count = count
		var live: int = entry.get("live_count", 0)
		if live > max_count:
			max_count = live

	for entry in data:
		var day: int      = entry.get("day", 0)
		var live: int     = entry.get("live_count", 0)
		var believers: int = entry.get("believer_count", 0)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)

		var day_lbl := Label.new()
		day_lbl.text = "Day %d" % day
		day_lbl.custom_minimum_size = Vector2(50, 0)
		day_lbl.add_theme_font_size_override("font_size", 12)
		day_lbl.add_theme_color_override("font_color", C_STAT_LABEL)
		row.add_child(day_lbl)

		var bar_width: float = (float(believers) / float(max_count)) * 300.0
		var bar := ColorRect.new()
		bar.custom_minimum_size = Vector2(maxf(bar_width, 2.0), 12)
		bar.color = _bar_color(believers, max_count)
		row.add_child(bar)

		var count_lbl := Label.new()
		count_lbl.text = "%d believers / %d active" % [believers, live]
		count_lbl.add_theme_font_size_override("font_size", 12)
		count_lbl.add_theme_color_override("font_color", C_MUTED)
		row.add_child(count_lbl)

		parent.add_child(row)


func _bar_color(value: int, max_val: int) -> Color:
	var ratio := float(value) / float(max_val) if max_val > 0 else 0.0
	if ratio > 0.6:
		return C_BAR_HIGH
	elif ratio > 0.3:
		return C_BAR_MED
	return C_BAR_LOW


func _build_influence_section(parent: VBoxContainer) -> void:
	var heading := Label.new()
	heading.text = "TOP INFLUENCERS"
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", C_HEADING)
	parent.add_child(heading)

	var ranking: Array = _analytics_ref.get_influence_ranking(5)
	if ranking.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No rumor transmissions recorded."
		empty_lbl.add_theme_color_override("font_color", C_MUTED)
		parent.add_child(empty_lbl)
		return

	for i in range(ranking.size()):
		var entry: Dictionary = ranking[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var rank_lbl := Label.new()
		rank_lbl.text = "#%d" % (i + 1)
		rank_lbl.custom_minimum_size = Vector2(28, 0)
		rank_lbl.add_theme_font_size_override("font_size", 12)
		rank_lbl.add_theme_color_override("font_color", C_SUBHEADING)
		row.add_child(rank_lbl)

		var name_lbl := Label.new()
		name_lbl.text = str(entry.get("name", "?"))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", C_HEADING)
		row.add_child(name_lbl)

		var stats_lbl := Label.new()
		stats_lbl.text = "%d spread, %d received" % [
			entry.get("spread_count", 0),
			entry.get("received_count", 0),
		]
		stats_lbl.add_theme_font_size_override("font_size", 12)
		stats_lbl.add_theme_color_override("font_color", C_BODY)
		row.add_child(stats_lbl)

		parent.add_child(row)


func _build_moments_section(parent: VBoxContainer) -> void:
	var heading := Label.new()
	heading.text = "KEY MOMENTS"
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", C_HEADING)
	parent.add_child(heading)

	var moments: Array = _analytics_ref.get_key_moments()
	if moments.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No notable moments detected."
		empty_lbl.add_theme_color_override("font_color", C_MUTED)
		parent.add_child(empty_lbl)
		return

	var shown := 0
	for moment in moments:
		if shown >= 8:
			break

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var day_lbl := Label.new()
		day_lbl.text = "Day %d" % moment.get("day", 0)
		day_lbl.custom_minimum_size = Vector2(50, 0)
		day_lbl.add_theme_font_size_override("font_size", 12)
		day_lbl.add_theme_color_override("font_color", C_SUBHEADING)
		row.add_child(day_lbl)

		var text_lbl := Label.new()
		text_lbl.text = str(moment.get("text", ""))
		text_lbl.add_theme_font_size_override("font_size", 12)
		text_lbl.add_theme_color_override("font_color", _moment_color(str(moment.get("type", ""))))
		text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_lbl)

		parent.add_child(row)
		shown += 1


func _moment_color(moment_type: String) -> Color:
	match moment_type:
		"seed":          return C_MOMENT_SEED
		"peak":          return C_MOMENT_PEAK
		"social_death":  return C_MOMENT_BAD
		"contradiction": return C_MOMENT_BAD
		"state_change":  return C_BAR_MED
		_:               return C_BODY
