extends CanvasLayer

## building_interior.gd — Sprint 5 (Art Pass 1, SPA-41)
## Base controller for flat 2D interior panels: Tavern, Manor, Chapel.
##
## Usage: call show_interior() to open; panel closes on E key or × button.
## The scene tree expects:
##   $Overlay   (ColorRect)    — dim background
##   $Panel     (Panel)        — parchment panel
##   $Panel/Layout/.../CloseBtn (Button)
##
## Intended to be instanced into Main.tscn and toggled by world.gd or the
## recon controller when the player interacts with a building.

signal interior_closed

@onready var _overlay:    ColorRect = $Overlay
@onready var _panel:      Panel     = $Panel
@onready var _close_btn:  Button    = _find_close_btn()

var _open: bool = false


func _ready() -> void:
	_overlay.visible = false
	_panel.visible   = false
	if _close_btn != null:
		_close_btn.pressed.connect(close_interior)


func _find_close_btn() -> Button:
	# Walk the panel tree looking for a Button named "CloseBtn".
	return _panel.find_child("CloseBtn", true, false) as Button


# ── Public API ────────────────────────────────────────────────────────────────

func show_interior() -> void:
	_overlay.visible = true
	_panel.visible   = true
	_open = true


func close_interior() -> void:
	_overlay.visible = false
	_panel.visible   = false
	_open = false
	emit_signal("interior_closed")


func is_open() -> bool:
	return _open


# ── Input ─────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E or event.keycode == KEY_ESCAPE:
			close_interior()
			get_viewport().set_input_as_handled()
