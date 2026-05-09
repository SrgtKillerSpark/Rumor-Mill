## test_rumor_panel_evidence_cooldown_ui.gd — Regression tests for the
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

class_name TestRumorPanelEvidenceCooldownUi
extends RefCounted

const RumorPanelScript := preload("res://scripts/rumor_panel.gd")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Return a fresh PlayerIntelStore with no active cooldowns.
static func _make_store() -> PlayerIntelStore:
	return PlayerIntelStore.new()


## Return a minimal EvidenceItem usable as a test fixture.
static func _make_evidence_item() -> PlayerIntelStore.EvidenceItem:
	return PlayerIntelStore.EvidenceItem.new("Forged Document", 0.20, 0.0, [], 0)


## Return a bare RumorPanel with the given store injected, subject set to
## npc_b (different from the cooldown target npc_a).
static func _make_panel(store: PlayerIntelStore) -> CanvasLayer:
	var rp := RumorPanelScript.new()
	rp._intel_store_ref  = store
	rp._selected_subject = "npc_b"
	return rp


## Build an evidence entry via the panel and return the Attach button.
## Walks PanelContainer → VBoxContainer → Button.
static func _get_button(entry: Control) -> Button:
	for child in entry.get_children():
		if child is VBoxContainer:
			for grandchild in child.get_children():
				if grandchild is Button:
					return grandchild as Button
	return null


## Build a locked entry (cooldown active, subject ≠ cooldown target) and
## return the Attach button. Caller is responsible for freeing entry.
static func _make_locked_entry_btn() -> Dictionary:
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "normal")   # 2-day cooldown
	var rp    := _make_panel(store)
	var item  := _make_evidence_item()
	var entry: Control = rp._build_evidence_entry(item)
	var btn   := _get_button(entry)
	return {"entry": entry, "btn": btn}


## Build an unlocked entry (no cooldown) and return the Attach button.
## Caller is responsible for freeing entry.
static func _make_unlocked_entry_btn() -> Dictionary:
	var store := _make_store()
	var rp    := _make_panel(store)
	var item  := _make_evidence_item()
	var entry: Control = rp._build_evidence_entry(item)
	var btn   := _get_button(entry)
	return {"entry": entry, "btn": btn}


# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# UI-1
		"test_button_disabled_when_cooldown_active",
		# UI-2
		"test_tooltip_shows_days_at_cooldown_start",
		"test_tooltip_shows_days_at_cooldown_mid",
		"test_button_enabled_when_cooldown_expired",
		# UI-3
		"test_tooltip_absent_when_cooldown_expired",
		# UI-4
		"test_tooltip_present_when_locked",
		"test_tooltip_absent_when_not_locked",
	]

	for method_name in tests:
		GameState.evidence_economy_v2 = true
		var result: bool = call(method_name)
		GameState.evidence_economy_v2 = false
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\n  RumorPanelEvidenceCooldownUi: %d passed, %d failed" % [passed, failed])


# ---------------------------------------------------------------------------
# UI-1: Button disabled state while cooldown is active
# ---------------------------------------------------------------------------

static func test_button_disabled_when_cooldown_active() -> bool:
	var d    := _make_locked_entry_btn()
	var btn  : Button  = d["btn"]
	var entry: Control = d["entry"]

	if btn == null:
		return false
	var ok := btn.disabled
	entry.free()
	return ok


# ---------------------------------------------------------------------------
# UI-2: Tooltip shows correct days remaining at start, mid, and expiry
# ---------------------------------------------------------------------------

static func test_tooltip_shows_days_at_cooldown_start() -> bool:
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "normal")   # 2-day cooldown

	var info  : Dictionary = store.get_evidence_cooldown_info()
	var days  : int        = info.get("days_remaining", -1)

	if days != 2:
		return false

	var rp    := _make_panel(store)
	var item  := _make_evidence_item()
	var entry : Control = rp._build_evidence_entry(item)
	var btn   := _get_button(entry)

	if btn == null:
		return false
	var ok := btn.tooltip_text.contains("2d")
	entry.free()
	return ok


static func test_tooltip_shows_days_at_cooldown_mid() -> bool:
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "normal")   # 2 days
	store.decay_evidence_cooldowns()                    # → 1 day

	var info  : Dictionary = store.get_evidence_cooldown_info()
	var days  : int        = info.get("days_remaining", -1)

	if days != 1:
		return false

	var rp    := _make_panel(store)
	var item  := _make_evidence_item()
	var entry : Control = rp._build_evidence_entry(item)
	var btn   := _get_button(entry)

	if btn == null:
		return false
	var ok := btn.tooltip_text.contains("1d")
	entry.free()
	return ok


static func test_button_enabled_when_cooldown_expired() -> bool:
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "normal")   # 2 days
	store.decay_evidence_cooldowns()                    # → 1 day
	store.decay_evidence_cooldowns()                    # → 0 days (expired)

	if store.is_evidence_locked_for_target("npc_b"):
		return false

	var rp    := _make_panel(store)
	var item  := _make_evidence_item()
	var entry : Control = rp._build_evidence_entry(item)
	var btn   := _get_button(entry)

	if btn == null:
		return false
	var ok := not btn.disabled
	entry.free()
	return ok


# ---------------------------------------------------------------------------
# UI-3: Button re-enables and tooltip clears on expiry
# ---------------------------------------------------------------------------

static func test_tooltip_absent_when_cooldown_expired() -> bool:
	var store := _make_store()
	store.start_evidence_cooldown("npc_a", "normal")
	store.decay_evidence_cooldowns()
	store.decay_evidence_cooldowns()

	var rp    := _make_panel(store)
	var item  := _make_evidence_item()
	var entry : Control = rp._build_evidence_entry(item)
	var btn   := _get_button(entry)

	if btn == null:
		return false
	var ok := not ("cooldown" in btn.tooltip_text.to_lower())
	entry.free()
	return ok


# ---------------------------------------------------------------------------
# UI-4: Tooltip updates between active/ready states
# ---------------------------------------------------------------------------

static func test_tooltip_present_when_locked() -> bool:
	var d    := _make_locked_entry_btn()
	var btn  : Button  = d["btn"]
	var entry: Control = d["entry"]

	if btn == null:
		return false
	var ok := (
		not btn.tooltip_text.is_empty()
		and ("cooldown" in btn.tooltip_text.to_lower() or "locked" in btn.tooltip_text.to_lower())
	)
	entry.free()
	return ok


static func test_tooltip_absent_when_not_locked() -> bool:
	var d    := _make_unlocked_entry_btn()
	var btn  : Button  = d["btn"]
	var entry: Control = d["entry"]

	if btn == null:
		return false
	var ok := not ("cooldown" in btn.tooltip_text.to_lower())
	entry.free()
	return ok
