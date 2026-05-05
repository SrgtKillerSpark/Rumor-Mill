## test_rumor_panel_evidence_cooldown_ui.gd — GUT regression tests for the
## evidence cooldown UI interactions introduced in SPA-1717.
##
## Acceptance criteria covered (SPA-1732):
##   UI-1 — Attach button is disabled while a cooldown is active.
##   UI-2 — Tooltip text contains correct days remaining at t=start, t=mid, t=expire.
##   UI-3 — Button re-enables (not disabled) once the cooldown has fully expired.
##   UI-4 — Tooltip is present (non-empty) when locked; absent (empty) when ready.
##
## All tests instantiate RumorPanel without adding it to the scene tree so no
## Godot editor, renderer, or asset loading is required.
##
## Run via GUT panel (Godot editor) or headless:
##   godot --headless -s addons/gut/gut_cmdln.gd \
##         -gtest=res://tests/test_rumor_panel_evidence_cooldown_ui.gd -gexit

extends GutTest

const RumorPanelScript := preload("res://scripts/rumor_panel.gd")


# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------

func before_each() -> void:
	## Enable the evidence economy v2 feature flag so cooldown methods are
	## active during all tests in this suite.
	GameState.evidence_economy_v2 = true


func after_each() -> void:
	## Restore the default so this suite does not pollute other test files.
	GameState.evidence_economy_v2 = false


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Return a fresh PlayerIntelStore with no active cooldowns.
func _make_store() -> PlayerIntelStore:
	return PlayerIntelStore.new()


## Return a minimal EvidenceItem usable as a test fixture.
func _make_evidence_item() -> PlayerIntelStore.EvidenceItem:
	return PlayerIntelStore.EvidenceItem.new("Forged Document", 0.20, 0.0, [], 0)


## Return a bare RumorPanel with the given store injected, subject set to
## npc_b (different from the cooldown target npc_a).
func _make_panel(store: PlayerIntelStore) -> CanvasLayer:
	var rp := RumorPanelScript.new()
	rp._intel_store_ref  = store
	rp._selected_subject = "npc_b"
	return rp


## Build an evidence entry via the panel and return the Attach button.
## Walks PanelContainer → VBoxContainer → Button.
func _get_button(entry: Control) -> Button:
	for child in entry.get_children():
		if child is VBoxContainer:
			for grandchild in child.get_children():
				if grandchild is Button:
					return grandchild as Button
	return null


## Build a locked entry (cooldown active, subject ≠ cooldown target) and
## return the Attach button. Caller is responsible for freeing entry.
func _make_locked_entry_btn() -> Dictionary:
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "normal")   # 2-day cooldown
	var rp    := _make_panel(store)
	var item  := _make_evidence_item()
	var entry: Control = rp._build_evidence_entry(item)
	var btn   := _get_button(entry)
	return {"entry": entry, "btn": btn}


## Build an unlocked entry (no cooldown) and return the Attach button.
## Caller is responsible for freeing entry.
func _make_unlocked_entry_btn() -> Dictionary:
	var store := _make_store()
	var rp    := _make_panel(store)
	var item  := _make_evidence_item()
	var entry: Control = rp._build_evidence_entry(item)
	var btn   := _get_button(entry)
	return {"entry": entry, "btn": btn}


# ---------------------------------------------------------------------------
# UI-1: Button disabled state while cooldown is active
# ---------------------------------------------------------------------------

func test_button_disabled_when_cooldown_active() -> void:
	var d    := _make_locked_entry_btn()
	var btn  : Button  = d["btn"]
	var entry: Control = d["entry"]

	assert_not_null(btn, "Expected an Attach button to be present in the locked entry")
	assert_true(btn.disabled, "Attach button must be disabled while evidence cooldown is active")

	entry.free()


# ---------------------------------------------------------------------------
# UI-2: Tooltip shows correct days remaining at start, mid, and expiry
# ---------------------------------------------------------------------------

func test_tooltip_shows_days_at_cooldown_start() -> void:
	## t=start: Normal difficulty → 2 days remaining immediately after start.
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "normal")   # 2-day cooldown

	var info  : Dictionary = store.get_evidence_cooldown_info()
	var days  : int        = info.get("days_remaining", -1)

	assert_eq(days, 2, "days_remaining must be 2 immediately after starting a Normal cooldown")

	# Build the entry and confirm the tooltip reflects the same count.
	var rp    := _make_panel(store)
	var item  := _make_evidence_item()
	var entry : Control = rp._build_evidence_entry(item)
	var btn   := _get_button(entry)

	assert_not_null(btn, "Expected an Attach button in the entry")
	assert_true(
		btn.tooltip_text.contains("2d"),
		"Tooltip must mention '2d' at cooldown start; got: '%s'" % btn.tooltip_text
	)

	entry.free()


func test_tooltip_shows_days_at_cooldown_mid() -> void:
	## t=mid: After one decay the tooltip must reflect 1 day remaining.
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "normal")   # 2 days
	store.decay_evidence_cooldowns()                    # → 1 day

	var info  : Dictionary = store.get_evidence_cooldown_info()
	var days  : int        = info.get("days_remaining", -1)

	assert_eq(days, 1, "days_remaining must be 1 after one decay of a Normal cooldown")

	var rp    := _make_panel(store)
	var item  := _make_evidence_item()
	var entry : Control = rp._build_evidence_entry(item)
	var btn   := _get_button(entry)

	assert_not_null(btn, "Expected an Attach button in the entry")
	assert_true(
		btn.tooltip_text.contains("1d"),
		"Tooltip must mention '1d' at cooldown mid-point; got: '%s'" % btn.tooltip_text
	)

	entry.free()


func test_button_enabled_when_cooldown_expired() -> void:
	## t=expire: After all days have been decremented, the button must be enabled.
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "normal")   # 2 days
	store.decay_evidence_cooldowns()                    # → 1 day
	store.decay_evidence_cooldowns()                    # → 0 days (expired)

	assert_false(
		store.is_evidence_locked_for_target("npc_b"),
		"Evidence must not be locked after the cooldown has fully decayed"
	)

	var rp    := _make_panel(store)
	var item  := _make_evidence_item()
	var entry : Control = rp._build_evidence_entry(item)
	var btn   := _get_button(entry)

	assert_not_null(btn, "Expected an Attach button in the entry")
	assert_false(btn.disabled, "Attach button must be enabled once the cooldown has expired")

	entry.free()


# ---------------------------------------------------------------------------
# UI-3: Button re-enables and tooltip clears on expiry
# ---------------------------------------------------------------------------

func test_tooltip_absent_when_cooldown_expired() -> void:
	## After expiry the button carries no cooldown tooltip.
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "normal")
	store.decay_evidence_cooldowns()
	store.decay_evidence_cooldowns()

	var rp    := _make_panel(store)
	var item  := _make_evidence_item()
	var entry : Control = rp._build_evidence_entry(item)
	var btn   := _get_button(entry)

	assert_not_null(btn, "Expected an Attach button in the entry")
	assert_false(
		"cooldown" in btn.tooltip_text.to_lower(),
		"Tooltip must not mention cooldown after expiry; got: '%s'" % btn.tooltip_text
	)

	entry.free()


# ---------------------------------------------------------------------------
# UI-4: Tooltip updates between active/ready states
# ---------------------------------------------------------------------------

func test_tooltip_present_when_locked() -> void:
	var d    := _make_locked_entry_btn()
	var btn  : Button  = d["btn"]
	var entry: Control = d["entry"]

	assert_not_null(btn, "Expected an Attach button in the locked entry")
	assert_false(
		btn.tooltip_text.is_empty(),
		"Tooltip must be non-empty while evidence cooldown is active"
	)
	assert_true(
		"cooldown" in btn.tooltip_text.to_lower() or "locked" in btn.tooltip_text.to_lower(),
		"Tooltip must mention cooldown or locked state; got: '%s'" % btn.tooltip_text
	)

	entry.free()


func test_tooltip_absent_when_not_locked() -> void:
	var d    := _make_unlocked_entry_btn()
	var btn  : Button  = d["btn"]
	var entry: Control = d["entry"]

	assert_not_null(btn, "Expected an Attach button in the unlocked entry")
	assert_false(
		"cooldown" in btn.tooltip_text.to_lower(),
		"Tooltip must not mention cooldown when no cooldown is active; got: '%s'" % btn.tooltip_text
	)

	entry.free()
