extends Node

## CursorManager — Autoload singleton for priority-based cursor control.
##
## Callers request a cursor shape with an owner key and priority integer.
## The highest-priority active request wins; when released, the next
## highest-priority request (if any) takes over automatically.
##
## This eliminates the race between DisplayServer.cursor_set_shape() (used by
## recon_controller.gd) and the deprecated Input.set_default_cursor_shape()
## (used by npc.gd / building_tooltip.gd).  All callers now go through a
## single authority that uses only DisplayServer.
##
## Priority constants (higher value = wins):
##   PRIORITY_WORLD  = 0  — building_tooltip world-layer hover
##   PRIORITY_NPC    = 1  — per-NPC hover area signals
##   PRIORITY_RECON  = 2  — recon_controller per-frame hit detection
##   PRIORITY_HUD    = 3  — reserved for S2-S6 HUD button POINTING_HAND work

const PRIORITY_WORLD := 0
const PRIORITY_NPC   := 1
const PRIORITY_RECON := 2
const PRIORITY_HUD   := 3

## owner (String/StringName) → { "shape": int, "priority": int }
var _requests: Dictionary = {}
var _current_shape: int = DisplayServer.CURSOR_ARROW


## Register or update a cursor request from `owner`.
## If this request has the highest priority it takes effect immediately.
func request_cursor(owner: String, shape: int, priority: int) -> void:
	_requests[owner] = { "shape": shape, "priority": priority }
	_apply()


## Remove a cursor request from `owner`.
## The next highest-priority active request (if any) takes over.
func release_cursor(owner: String) -> void:
	if _requests.erase(owner):
		_apply()


func _apply() -> void:
	var best_shape: int = DisplayServer.CURSOR_ARROW
	var best_priority: int = -1
	for entry: Dictionary in _requests.values():
		if entry["priority"] > best_priority:
			best_priority = entry["priority"]
			best_shape    = entry["shape"]
	if best_shape != _current_shape:
		_current_shape = best_shape
		DisplayServer.cursor_set_shape(best_shape as DisplayServer.CursorShape)
