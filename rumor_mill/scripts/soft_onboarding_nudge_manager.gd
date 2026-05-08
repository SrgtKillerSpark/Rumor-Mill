extends Node

## soft_onboarding_nudge_manager.gd — SPA-2081
## Fires up to 3 soft contextual nudges for players who skipped the tutorial.
##
## Only active when the tutorial was skipped (not completed).  Uses the same
## tutorial_banner system as the guided tutorial, but as non-blocking
## suggestions with no action gates.
##
## Nudge conditions (real-time elapsed since tutorial skip):
##   1. No Observe action after 90 s  → hint "soft_nudge_observe"
##   2. Player observed but no Journal opened within 60 s of first observe
##                                    → hint "soft_nudge_journal"
##   3. No rumor crafted after 120 s  → hint "soft_nudge_rumor"
##
## A session cap of 3 total nudges is enforced.  Each hint is marked seen in
## TutorialSystem on dismissal (via the banner's normal flow), so it will not
## repeat if the player reloads their save mid-session.
##
## Usage (tutorial_wiring.gd):
##   var nudge_mgr := SoftOnboardingNudgeManager.new()
##   nudge_mgr.name = "SoftOnboardingNudgeManager"
##   add_child(nudge_mgr)
##   nudge_mgr.activate(tutorial_sys, tutorial_banner, recon_ctrl, journal, rumor_panel)

class_name SoftOnboardingNudgeManager

# ── Configuration ─────────────────────────────────────────────────────────────

## Seconds of elapsed time before nudge 1 fires (no Observe performed).
const NUDGE1_OBSERVE_SECS  := 90.0
## Seconds after first Observe before nudge 2 fires (Journal still not opened).
const NUDGE2_JOURNAL_SECS  := 60.0
## Seconds of elapsed time before nudge 3 fires (no rumor crafted).
const NUDGE3_RUMOR_SECS    := 120.0
## Maximum number of nudges to show this session.
const MAX_NUDGES           := 3

# ── Hint IDs (defined in TutorialSystem.CONTEXT_HINT_DATA) ───────────────────

const HINT_OBSERVE := "soft_nudge_observe"
const HINT_JOURNAL := "soft_nudge_journal"
const HINT_RUMOR   := "soft_nudge_rumor"

# ── External refs ─────────────────────────────────────────────────────────────

var _tutorial_sys:    TutorialSystem = null
var _tutorial_banner: Node           = null
var _recon_ctrl:      Node           = null
var _journal:         CanvasLayer    = null
var _rumor_panel:     CanvasLayer    = null

# ── Runtime state ─────────────────────────────────────────────────────────────

var _active:          bool  = false
## Elapsed real-time seconds since activate() was called.
var _elapsed:         float = 0.0
## Total nudges fired this session (enforces MAX_NUDGES cap).
var _nudges_shown:    int   = 0

var _observed:        bool  = false
var _journal_opened:  bool  = false
var _rumor_crafted:   bool  = false

var _nudge1_fired:    bool  = false
var _nudge2_fired:    bool  = false
var _nudge3_fired:    bool  = false

## Value of _elapsed at the moment of the first Observe, used for nudge 2 timer.
var _observe_elapsed: float = 0.0

# ── Signal connection flags ───────────────────────────────────────────────────

var _connected_recon:   bool = false
var _connected_journal: bool = false
var _connected_rumor:   bool = false


## Wire all dependencies and start nudge tracking.
## Call this immediately after the tutorial_skipped signal fires.
func activate(
		tutorial_sys:    TutorialSystem,
		tutorial_banner: Node,
		recon_ctrl:      Node,
		journal:         CanvasLayer,
		rumor_panel:     CanvasLayer
) -> void:
	_tutorial_sys    = tutorial_sys
	_tutorial_banner = tutorial_banner
	_recon_ctrl      = recon_ctrl
	_journal         = journal
	_rumor_panel     = rumor_panel
	_active          = true
	_elapsed         = 0.0
	_connect_signals()


func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	_check_nudges()


func _check_nudges() -> void:
	if _nudges_shown >= MAX_NUDGES:
		_active = false
		return

	# Nudge 1: no Observe performed within 90 s.
	if not _nudge1_fired and not _observed and _elapsed >= NUDGE1_OBSERVE_SECS:
		_nudge1_fired = true
		_fire_nudge(HINT_OBSERVE)

	# Nudge 2: player has observed but has not opened the Journal within 60 s
	# of their first Observe.  Skip if nudge 1 already fired (player was still
	# guided toward observing first).
	if not _nudge2_fired and _observed and not _journal_opened and not _nudge1_fired \
			and (_elapsed - _observe_elapsed) >= NUDGE2_JOURNAL_SECS:
		_nudge2_fired = true
		_fire_nudge(HINT_JOURNAL)

	# Nudge 3: no rumor crafted within 120 s.
	if not _nudge3_fired and not _rumor_crafted and _elapsed >= NUDGE3_RUMOR_SECS:
		_nudge3_fired = true
		_fire_nudge(HINT_RUMOR)


func _fire_nudge(hint_id: String) -> void:
	if _tutorial_sys == null or _tutorial_banner == null:
		return
	if _tutorial_sys.has_seen(hint_id):
		return
	if not _tutorial_banner.has_method("queue_hint"):
		return
	_tutorial_banner.queue_hint(hint_id)
	_nudges_shown += 1


# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_read_the_room_shown(_location_id: String) -> void:
	if _observed:
		return
	_observed        = true
	_observe_elapsed = _elapsed


func _on_journal_visibility_changed() -> void:
	if _journal != null and _journal.visible:
		_journal_opened = true


func _on_rumor_seeded(_rumor_id: String, _subject: String, _claim: String, _target: String) -> void:
	_rumor_crafted = true


# ── Signal wiring / cleanup ───────────────────────────────────────────────────

func _connect_signals() -> void:
	if _recon_ctrl != null and _recon_ctrl.has_signal("read_the_room_shown") \
			and not _connected_recon:
		_recon_ctrl.read_the_room_shown.connect(_on_read_the_room_shown)
		_connected_recon = true

	if _journal != null and not _connected_journal:
		_journal.visibility_changed.connect(_on_journal_visibility_changed)
		_connected_journal = true

	if _rumor_panel != null and _rumor_panel.has_signal("rumor_seeded") \
			and not _connected_rumor:
		_rumor_panel.rumor_seeded.connect(_on_rumor_seeded)
		_connected_rumor = true


func _disconnect_signals() -> void:
	if _connected_recon and _recon_ctrl != null \
			and _recon_ctrl.has_signal("read_the_room_shown"):
		if _recon_ctrl.read_the_room_shown.is_connected(_on_read_the_room_shown):
			_recon_ctrl.read_the_room_shown.disconnect(_on_read_the_room_shown)
	_connected_recon = false

	if _connected_journal and _journal != null:
		if _journal.visibility_changed.is_connected(_on_journal_visibility_changed):
			_journal.visibility_changed.disconnect(_on_journal_visibility_changed)
	_connected_journal = false

	if _connected_rumor and _rumor_panel != null \
			and _rumor_panel.has_signal("rumor_seeded"):
		if _rumor_panel.rumor_seeded.is_connected(_on_rumor_seeded):
			_rumor_panel.rumor_seeded.disconnect(_on_rumor_seeded)
	_connected_rumor = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_signals()
