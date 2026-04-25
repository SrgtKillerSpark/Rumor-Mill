class_name EndScreenAnimations
extends RefCounted

## end_screen_animations.gd — Count-up tween, arrow bounce, and button pulse
## animations for EndScreen.
##
## Extracted from end_screen.gd (SPA-1010). Needs a Node owner reference for
## create_tween() and get_tree().create_timer() calls.
##
## Call setup(owner_node) once. Then:
##   start_count_up(tween_targets, bonus_lbl, rating_row, arrow_labels)
##   start_arrow_animations(arrow_labels)
##   start_btn_pulse(btn_next)

var _owner: Node = null
var _btn_pulse_tween: Tween = null


func setup(owner_node: Node) -> void:
	_owner = owner_node


## Start count-up tween for all numeric stat value labels.
## Triggers arrow animations automatically after stats complete.
func start_count_up(tween_targets: Array, bonus_lbl: Control,
		rating_row: HBoxContainer, arrow_labels: Array) -> void:
	if tween_targets.is_empty() or _owner == null:
		return

	var tw: Tween = _owner.create_tween()
	tw.set_parallel(true)

	var idx := 0
	for entry in tween_targets:
		var val_lbl: Label   = entry["label"] as Label
		var target: int      = int(entry["target"])
		var suffix: String   = str(entry["suffix"])
		var row_node: Node   = val_lbl.get_parent() if is_instance_valid(val_lbl) else null
		var stagger: float   = idx * 0.3
		if row_node != null:
			tw.tween_property(row_node, "modulate:a", 1.0, 0.25) \
				.set_delay(stagger) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_method(
			func(v: float) -> void:
				if is_instance_valid(val_lbl):
					val_lbl.text = str(int(v)) + suffix,
			0.0, float(target), 1.0
		).set_delay(stagger + 0.2) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		idx += 1

	# Reveal the bonus row (scenario 2: contradiction events) after tween.
	if bonus_lbl != null:
		var bonus_ref: Node = bonus_lbl
		var bonus_delay: float = idx * 0.3 + 0.3
		_owner.get_tree().create_timer(bonus_delay).timeout.connect(func() -> void:
			if is_instance_valid(bonus_ref):
				bonus_ref.modulate = Color.WHITE
		)

	# SPA-907: Reveal the performance rating row after all stats.
	if rating_row != null:
		var rating_ref: HBoxContainer = rating_row
		var rating_delay: float = idx * 0.3 + 0.6
		_owner.get_tree().create_timer(rating_delay).timeout.connect(func() -> void:
			if is_instance_valid(rating_ref):
				var rtw := rating_ref.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				rtw.tween_property(rating_ref, "modulate:a", 1.0, 0.35)
		)

	# SPA-784: Start arrow pulse animations after stats are revealed.
	var arrow_delay: float = idx * 0.3 + 0.5
	var arrow_labels_ref := arrow_labels
	_owner.get_tree().create_timer(arrow_delay).timeout.connect(func() -> void:
		start_arrow_animations(arrow_labels_ref)
	)


## Bounce-pulse each arrow label to draw attention to reputation changes.
func start_arrow_animations(arrow_labels: Array) -> void:
	for i in range(arrow_labels.size()):
		var arrow: Label = arrow_labels[i]
		if not is_instance_valid(arrow):
			continue
		var delay := i * 0.15
		arrow.pivot_offset = arrow.size * 0.5
		var tw := arrow.create_tween()
		tw.tween_property(arrow, "scale", Vector2(1.4, 1.4), 0.15) \
			.set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(arrow, "scale", Vector2.ONE, 0.2) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## SPA-784: Pulsing glow on the Next Scenario button for victory.
func start_btn_pulse(btn_next: Button) -> void:
	if btn_next == null or btn_next.disabled:
		return
	if _btn_pulse_tween != null:
		_btn_pulse_tween.kill()
	_btn_pulse_tween = btn_next.create_tween().set_loops()
	_btn_pulse_tween.tween_property(btn_next, "modulate",
		Color(1.2, 1.1, 0.8, 1.0), 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_btn_pulse_tween.tween_property(btn_next, "modulate",
		Color.WHITE, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
