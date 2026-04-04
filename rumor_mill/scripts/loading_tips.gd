extends CanvasLayer

## loading_tips.gd — Sprint 9 (SPA-124)
## Shows a random gameplay tip during scene transitions longer than MIN_DURATION_SEC.
##
## Usage in main.gd:
##   _loading_tips.start_transition()
##   await get_tree().create_timer(LOAD_DELAY).timeout
##   # ... run init code ...
##   _loading_tips.end_transition()

const MIN_DURATION_SEC := 2.0

const TIPS: Array = [
	"[b]Rumors travel through relationships.[/b]  Seed your story where the crowd gathers — the Tavern and Market Square carry whispers farthest and fastest.",
	"[b]High Credulity means easy believers — but watch for high Loyalty.[/b]  A loyal NPC may defend your target instead of doubting them.",
	"[b]Eavesdropping is risky.[/b]  Getting caught ends your run instantly. Save it for targets you've already softened through rumor.",
	"[b]Watch the clock.[/b]  Each scenario has a hard deadline. A reputation just barely above the threshold on the final day is the same as failure.",
	"[b]The right mouth matters more than many.[/b]  A highly Sociable NPC will carry your story further with fewer Whisper Tokens spent than a crowd of quiet listeners.",
	"[b]Bribery silences skeptics — for a price.[/b]  In scenarios where it's available, use it on influential NPCs on the verge of rejecting your rumor.",
	"[b]The Noble faction closes ranks quickly.[/b]  If your target has powerful allies, work to weaken those ties before striking at the main target.",
	"[b]Not every NPC needs to believe.[/b]  You only need enough voices spreading the story — three loud gossips can outweigh a dozen skeptical silences.",
	"[b]In The Succession, Calder's reputation is as fragile as Tomas's.[/b]  If he falls below 40, the scenario ends immediately — and your rival knows exactly which thread to pull.",
	"[b]Rumor intensity is not always better.[/b]  High-intensity claims spread fast but are also easier to reject. Match your claim strength to your target's credulity.",
]

const C_BACKDROP := Color(0.04, 0.02, 0.02, 0.97)
const C_LABEL    := Color(0.55, 0.48, 0.38, 1.0)
const C_TIP      := Color(0.91, 0.85, 0.70, 1.0)

var _tip_label:     RichTextLabel = null
var _loading_label: Label         = null
var _start_time:    float         = 0.0
var _active:        bool          = false
var _fade_tween:    Tween         = null
var _wrapper:       Control       = null


func _ready() -> void:
	layer = 60
	_build_ui()
	visible = false


func _build_ui() -> void:
	_wrapper = Control.new()
	_wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_wrapper)

	var backdrop := ColorRect.new()
	backdrop.color = C_BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrapper.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wrapper.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(640, 0)
	vbox.add_theme_constant_override("separation", 20)
	center.add_child(vbox)

	_loading_label = Label.new()
	_loading_label.text = "Loading…"
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 13)
	_loading_label.add_theme_color_override("font_color", C_LABEL)
	vbox.add_child(_loading_label)

	_tip_label = RichTextLabel.new()
	_tip_label.custom_minimum_size = Vector2(640, 60)
	_tip_label.fit_content = true
	_tip_label.scroll_active = false
	_tip_label.bbcode_enabled = true
	_tip_label.add_theme_font_size_override("normal_font_size", 15)
	_tip_label.add_theme_color_override("default_color", C_TIP)
	vbox.add_child(_tip_label)


## Call when a scene transition begins. Fades in a random tip.
func start_transition() -> void:
	_start_time = Time.get_ticks_msec() / 1000.0
	_active = true
	_tip_label.text = "[center]" + TIPS[randi() % TIPS.size()] + "[/center]"
	_wrapper.modulate = Color(1.0, 1.0, 1.0, 0.0)
	visible = true
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(_wrapper, "modulate:a", 1.0, 0.25)


## Call when the transition finishes. Hides immediately if it was faster than
## MIN_DURATION_SEC (tip was never meaningfully visible); otherwise stays until
## force_hide() is called by the caller.
func end_transition() -> void:
	if not _active:
		return
	var elapsed := Time.get_ticks_msec() / 1000.0 - _start_time
	if elapsed < MIN_DURATION_SEC:
		force_hide()


## Always hide, regardless of elapsed time.
func force_hide() -> void:
	_active = false
	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null
	_wrapper.modulate = Color(1.0, 1.0, 1.0, 1.0)
	visible = false
