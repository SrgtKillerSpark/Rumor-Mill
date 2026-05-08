extends Node

## guided_day2_manager.gd — SPA-2082
## Fires a 3-prompt guided Day 2 sequence for players who completed the S1 tutorial.
##
## Only activated via the step_completed("gtut_complete") signal path in
## tutorial_wiring.gd — never fires for players who skipped the tutorial
## (skip() marks steps seen without emitting step_completed).
##
## Prompt sequence (soft-gated: auto-dismiss after 10 s if no action taken):
##   1. gtut_day2_dawn           — at dawn of Day 2
##   2. gtut_day2_journal_checked — after player opens Journal on Day 2
##   3. gtut_day2_observe_done   — after first Observe action on Day 2
##
## Usage (tutorial_wiring.gd):
##   var mgr := GuidedDay2Manager.new()
##   mgr.name = "GuidedDay2Manager"
##   add_child(mgr)
##   mgr.activate(tutorial_sys, tutorial_banner, day_night, recon_ctrl, journal)

class_name GuidedDay2Manager

const HINT_DAWN    := "gtut_day2_dawn"
const HINT_JOURNAL := "gtut_day2_journal_checked"
const HINT_OBSERVE := "gtut_day2_observe_done"

var _tutorial_sys:    TutorialSystem = null
var _tutorial_banner: Node           = null
var _day_night:       Node           = null
var _recon_ctrl:      Node           = null
var _journal:         CanvasLayer    = null

var _active:   bool = false
var _on_day2:  bool = false  ## true once day_changed(2) fires

## Which prompts have been queued this session.
var _dawn_fired:    bool = false
var _journal_fired: bool = false
var _observe_fired: bool = false

## Signal connection flags.
var _connected_day:     bool = false
var _connected_journal: bool = false
var _connected_recon:   bool = false


## Wire all dependencies and start tracking.
## Called immediately after step_completed("gtut_complete") fires.
func activate(
		tutorial_sys:    TutorialSystem,
		tutorial_banner: Node,
		day_night:       Node,
		recon_ctrl:      Node,
		journal:         CanvasLayer,
) -> void:
	_tutorial_sys    = tutorial_sys
	_tutorial_banner = tutorial_banner
	_day_night       = day_night
	_recon_ctrl      = recon_ctrl
	_journal         = journal
	_active          = true
	_connect_signals()


func _on_day_changed(day: int) -> void:
	if day != 2 or _dawn_fired:
		return
	_on_day2    = true
	_dawn_fired = true
	if _tutorial_banner != null and _tutorial_banner.has_method("queue_hint"):
		_tutorial_banner.queue_hint(HINT_DAWN)


func _on_journal_visibility_changed() -> void:
	if not _on_day2 or not _dawn_fired or _journal_fired:
		return
	if _journal == null or not _journal.visible:
		return
	_journal_fired = true
	if _tutorial_banner != null and _tutorial_banner.has_method("queue_hint"):
		# Queued while the banner is suppressed (journal is open) — shows on close.
		_tutorial_banner.queue_hint(HINT_JOURNAL)


func _on_recon_action(message: String, success: bool) -> void:
	if not success or not _on_day2 or not _journal_fired or _observe_fired:
		return
	if not message.begins_with("Observed"):
		return
	_observe_fired = true
	if _tutorial_banner != null and _tutorial_banner.has_method("queue_hint"):
		_tutorial_banner.queue_hint(HINT_OBSERVE)
	_active = false
	_disconnect_signals()


func _connect_signals() -> void:
	if _day_night != null and _day_night.has_signal("day_changed") and not _connected_day:
		_day_night.day_changed.connect(_on_day_changed)
		_connected_day = true

	if _journal != null and not _connected_journal:
		_journal.visibility_changed.connect(_on_journal_visibility_changed)
		_connected_journal = true

	if _recon_ctrl != null and _recon_ctrl.has_signal("action_performed") and not _connected_recon:
		_recon_ctrl.action_performed.connect(_on_recon_action)
		_connected_recon = true


func _disconnect_signals() -> void:
	if _connected_day and _day_night != null and _day_night.has_signal("day_changed"):
		if _day_night.day_changed.is_connected(_on_day_changed):
			_day_night.day_changed.disconnect(_on_day_changed)
	_connected_day = false

	if _connected_journal and _journal != null:
		if _journal.visibility_changed.is_connected(_on_journal_visibility_changed):
			_journal.visibility_changed.disconnect(_on_journal_visibility_changed)
	_connected_journal = false

	if _connected_recon and _recon_ctrl != null and _recon_ctrl.has_signal("action_performed"):
		if _recon_ctrl.action_performed.is_connected(_on_recon_action):
			_recon_ctrl.action_performed.disconnect(_on_recon_action)
	_connected_recon = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_signals()
