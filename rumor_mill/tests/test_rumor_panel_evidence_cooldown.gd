## test_rumor_panel_evidence_cooldown.gd — Slice E cooldown UI tests (SPA-1717).
##
## Covers acceptance tests E1, E2, E3, E6 from docs/phase2-acceptance-tests.md:
##
##   E1 — Evidence items are locked (greyed) for a different target NPC during cooldown.
##   E2 — Evidence items become available after the cooldown expires.
##   E3 — Evidence items remain available when targeting the SAME NPC as the cooldown.
##   E6 — Items are still visible but greyed out with a tooltip explaining the cooldown.
##
## All tests operate on plain data objects (PlayerIntelStore) or on a bare RumorPanel
## instance not added to the scene tree. No Godot editor/scene required.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestRumorPanelEvidenceCooldown
extends RefCounted

const RumorPanelScript := preload("res://scripts/rumor_panel.gd")


# ── Analytics spy ─────────────────────────────────────────────────────────────

## Minimal AnalyticsLogger subclass that records log_target_shift_cooldown_blocked
## calls without writing to disk or checking SettingsManager.
class AnalyticsLoggerSpy extends AnalyticsLogger:
	var events_logged: Array = []

	func log_target_shift_cooldown_blocked(
		evidence_type: String,
		target_npc_id: String,
		cooldown_remaining_days: int,
		day: int,
		scenario_id: String,
		difficulty: String
	) -> void:
		events_logged.append({
			"evidence_type":           evidence_type,
			"target_npc_id":           target_npc_id,
			"cooldown_remaining_days": cooldown_remaining_days,
			"day":                     day,
			"scenario_id":             scenario_id,
			"difficulty":              difficulty,
		})


# ── Helpers ───────────────────────────────────────────────────────────────────

## Return a fresh PlayerIntelStore.
static func _make_store() -> PlayerIntelStore:
	return PlayerIntelStore.new()


## Return a minimal EvidenceItem usable as a test fixture.
static func _make_evidence_item() -> PlayerIntelStore.EvidenceItem:
	return PlayerIntelStore.EvidenceItem.new("Forged Document", 0.20, 0.0, [], 0)


## Return a bare RumorPanel instance (not in scene tree).
static func _make_panel() -> CanvasLayer:
	return RumorPanelScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# E1 — locked for a different target
		"test_e1_locked_for_different_target",
		# E2 — unlocked after cooldown expires
		"test_e2_unlocked_after_cooldown_expires",
		# E3 — still available for the same NPC target
		"test_e3_available_for_same_target",
		# Apprentice: 0-day cooldown is always unlocked
		"test_e_apprentice_never_locked",
		# E6 — entry modulate alpha is 0.4 when locked
		"test_e6_entry_modulate_reduced_when_locked",
		# E6 — entry has full opacity when not locked
		"test_e6_entry_modulate_full_when_not_locked",
		# E6 — locked button carries cooldown tooltip
		"test_e6_locked_button_has_tooltip",
		# E6 — locked button is disabled (not selectable)
		"test_e6_locked_button_is_disabled",
		# T1 (SPA-1772) — clicking a locked button fires target_shift_cooldown_blocked
		"test_t1_cooldown_blocked_event_fires_on_locked_click",
		# T2 (SPA-1772) — the event carries the correct evidence_type (snake_case)
		"test_t2_cooldown_blocked_event_has_correct_evidence_type",
		# T3 (SPA-1772) — no event fires when the evidence is not locked
		"test_t3_cooldown_blocked_event_not_fired_when_unlocked",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nRumorPanelEvidenceCooldown tests: %d passed, %d failed" % [passed, failed])


# ── E1: locked for a different target ─────────────────────────────────────────

## E1 — On Normal difficulty, after cooldown is started for npc_a, evidence is
## locked when the subject is a different NPC (npc_b).
func test_e1_locked_for_different_target() -> bool:
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "normal")   # 2-day cooldown on npc_a
	return store.is_evidence_locked_for_target("npc_b")


# ── E2: unlocked after cooldown expires ───────────────────────────────────────

## E2 — After all cooldown days have been decremented, evidence is no longer
## locked for any target.
func test_e2_unlocked_after_cooldown_expires() -> bool:
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "normal")   # 2 days
	store.decay_evidence_cooldowns()
	store.decay_evidence_cooldowns()
	return not store.is_evidence_locked_for_target("npc_b")


# ── E3: still available for the same target ───────────────────────────────────

## E3 — During an active cooldown, evidence remains available when the subject
## is the same NPC as the one that triggered the cooldown.
func test_e3_available_for_same_target() -> bool:
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "normal")
	return not store.is_evidence_locked_for_target("npc_a")


# ── Apprentice: 0-day cooldown, never locked ──────────────────────────────────

## E4 (sanity) — Apprentice difficulty triggers a 0-day cooldown (no-op),
## so evidence must never be locked even for a different target.
func test_e_apprentice_never_locked() -> bool:
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "apprentice")
	return not store.is_evidence_locked_for_target("npc_b")


# ── E6: entry visuals when locked ────────────────────────────────────────────

## Build a RumorPanel, inject a store with an active cooldown, set the subject to
## a different NPC than the cooldown target, then call _build_evidence_entry and
## inspect the returned Control node.
func _make_locked_entry() -> Control:
	var rp    := _make_panel()
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "normal")   # cooldown on npc_a
	rp._intel_store_ref = store
	rp._selected_subject = "npc_b"                    # different NPC → locked
	var item := _make_evidence_item()
	return rp._build_evidence_entry(item)


## Build a RumorPanel with no active cooldown and call _build_evidence_entry.
func _make_unlocked_entry() -> Control:
	var rp    := _make_panel()
	var store := _make_store()
	# No cooldown started → always unlocked.
	rp._intel_store_ref  = store
	rp._selected_subject = "npc_b"
	var item := _make_evidence_item()
	return rp._build_evidence_entry(item)


## E6 — A locked evidence entry must have modulate alpha ≤ 0.4 (greyed out).
func test_e6_entry_modulate_reduced_when_locked() -> bool:
	var entry := _make_locked_entry()
	var ok    := entry.modulate.a <= 0.41
	entry.free()
	return ok


## E6 — An unlocked evidence entry must have full (alpha ≈ 1.0) modulate.
func test_e6_entry_modulate_full_when_not_locked() -> bool:
	var entry := _make_unlocked_entry()
	var ok    := entry.modulate.a > 0.99
	entry.free()
	return ok


## E6 — The Attach button on a locked entry must carry a tooltip that mentions
## the cooldown.
func test_e6_locked_button_has_tooltip() -> bool:
	var entry := _make_locked_entry()
	# Walk children to find the VBox then the Button.
	var btn: Button = null
	for child in entry.get_children():
		if child is VBoxContainer:
			for grandchild in child.get_children():
				if grandchild is Button:
					btn = grandchild as Button
					break
		if btn != null:
			break
	var ok := btn != null and ("cooldown" in btn.tooltip_text.to_lower() or "locked" in btn.tooltip_text.to_lower())
	entry.free()
	return ok


## E6 — The Attach button on a locked entry must be disabled (not selectable).
func test_e6_locked_button_is_disabled() -> bool:
	var entry := _make_locked_entry()
	var btn: Button = null
	for child in entry.get_children():
		if child is VBoxContainer:
			for grandchild in child.get_children():
				if grandchild is Button:
					btn = grandchild as Button
					break
		if btn != null:
			break
	var ok := btn != null and btn.disabled
	entry.free()
	return ok


# ── T1–T3: target_shift_cooldown_blocked telemetry (SPA-1772) ────────────────

## Walk the entry's child tree and return the first Button found, or null.
static func _find_button(entry: Control) -> Button:
	for child in entry.get_children():
		if child is VBoxContainer:
			for grandchild in child.get_children():
				if grandchild is Button:
					return grandchild as Button
	return null


## Build a locked entry with an analytics spy wired up.
func _make_locked_entry_with_spy() -> Dictionary:
	var rp    := _make_panel()
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "normal")   # 2-day cooldown on npc_a
	rp._intel_store_ref  = store
	rp._selected_subject = "npc_b"                    # different NPC → locked
	var spy := AnalyticsLoggerSpy.new()
	rp._analytics_ref = spy
	var item  := _make_evidence_item()
	var entry = rp._build_evidence_entry(item)
	return {"entry": entry, "spy": spy}


## Simulate a left mouse-button press on a Control by emitting gui_input directly.
static func _simulate_left_click(control: Control) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed      = true
	control.gui_input.emit(ev)


## T1 (SPA-1772) — clicking a locked evidence button fires the telemetry event.
func test_t1_cooldown_blocked_event_fires_on_locked_click() -> bool:
	var d     := _make_locked_entry_with_spy()
	var entry := d["entry"] as Control
	var spy   := d["spy"]   as AnalyticsLoggerSpy
	var btn   := _find_button(entry)
	if btn == null or not btn.disabled:
		entry.free()
		return false
	_simulate_left_click(btn)
	var ok: bool = not spy.events_logged.is_empty()
	entry.free()
	return ok


## T2 (SPA-1772) — the fired event carries the correct snake_case evidence_type.
func test_t2_cooldown_blocked_event_has_correct_evidence_type() -> bool:
	var d     := _make_locked_entry_with_spy()
	var entry := d["entry"] as Control
	var spy   := d["spy"]   as AnalyticsLoggerSpy
	var btn   := _find_button(entry)
	if btn == null:
		entry.free()
		return false
	_simulate_left_click(btn)
	var ok: bool = (
		not spy.events_logged.is_empty()
		and spy.events_logged[0].get("evidence_type") == "forged_document"
	)
	entry.free()
	return ok


## T3 (SPA-1772) — no telemetry fires when the evidence is not cooldown-locked.
func test_t3_cooldown_blocked_event_not_fired_when_unlocked() -> bool:
	var rp    := _make_panel()
	var store := _make_store()
	# No cooldown started → evidence not locked for any target.
	rp._intel_store_ref  = store
	rp._selected_subject = "npc_b"
	var spy := AnalyticsLoggerSpy.new()
	rp._analytics_ref = spy
	var item  := _make_evidence_item()
	var entry = rp._build_evidence_entry(item)
	var btn   := _find_button(entry)
	if btn != null:
		_simulate_left_click(btn)
	var ok: bool = spy.events_logged.is_empty()
	entry.free()
	return ok
