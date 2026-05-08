## test_spa1685_1691_1693_fix_coverage.gd — Regression tests for three post-launch
## fixes (SPA-1685, SPA-1691, SPA-1693).
##
## Covers:
##   SPA-1685 — NpcDialoguePanel._build_canvas() sets _canvas.process_mode to
##              PROCESS_MODE_ALWAYS so the dialogue UI remains interactive while
##              the game tree is paused.
##
##   SPA-1691 — illness_hotspot_buildings declared on npc.gd; field is readable
##              and writable without INVALID_GET / INVALID_SET errors.
##
##   SPA-1693 — quarantine_ref declared on npc.gd; field is null by default and
##              accepts a QuarantineSystem reference without INVALID_DECLARATION.
##
## Strategy: All three fixes are on script fields / method calls that can be
## exercised on orphaned nodes without a running scene tree.
## NpcDialoguePanel has no _ready(), so _build_canvas() can be called directly
## on a bare .new() instance.
##
## Run from the Godot editor: Scene → Run Script.

class_name TestSpa1685_1691_1693FixCoverage
extends RefCounted

const NpcDialoguePanelScript := preload("res://scripts/npc_dialogue_panel.gd")
const NpcScript               := preload("res://scripts/npc.gd")
const QuarantineSystemScript  := preload("res://scripts/quarantine_system.gd")


# ── helpers ───────────────────────────────────────────────────────────────────

static func _make_panel() -> Node:
	return NpcDialoguePanelScript.new()


static func _make_npc() -> Node2D:
	return NpcScript.new()


static func _make_qs() -> QuarantineSystem:
	return QuarantineSystemScript.new()


# ── Test runner ───────────────────────────────────────────────────────────────

func run() -> void:
	var passed := 0
	var failed := 0

	var tests := [
		# SPA-1685 — dialogue canvas process mode (commit a5e9f00)
		"test_spa1685_canvas_process_mode_is_always",

		# SPA-1691 — illness_hotspot_buildings field (commit 47d7304)
		"test_spa1691_illness_hotspot_buildings_declared_empty",
		"test_spa1691_illness_hotspot_buildings_is_writable",

		# SPA-1693 — quarantine_ref field (commit a404f01)
		"test_spa1693_quarantine_ref_declared_null",
		"test_spa1693_quarantine_ref_accepts_instance",
	]

	for method_name in tests:
		var result: bool = call(method_name)
		if result:
			print("  PASS  %s" % method_name)
			passed += 1
		else:
			push_error("  FAIL  %s" % method_name)
			failed += 1

	print("\nSPA-1685/1691/1693 fix-coverage: %d passed, %d failed" % [passed, failed])


# ══════════════════════════════════════════════════════════════════════════════
# SPA-1685 — NpcDialoguePanel canvas process mode (commit a5e9f00)
# ══════════════════════════════════════════════════════════════════════════════

func test_spa1685_canvas_process_mode_is_always() -> bool:
	## _build_canvas() must set _canvas.process_mode = PROCESS_MODE_ALWAYS so
	## the dialogue UI stays interactive when the game tree is paused.
	var p := _make_panel()
	p._build_canvas()
	var ok: bool = p._canvas.process_mode == Node.PROCESS_MODE_ALWAYS
	p.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# SPA-1691 — illness_hotspot_buildings declared on npc.gd (commit 47d7304)
# ══════════════════════════════════════════════════════════════════════════════

func test_spa1691_illness_hotspot_buildings_declared_empty() -> bool:
	## illness_hotspot_buildings must exist and default to an empty Dictionary.
	var npc := _make_npc()
	var ok: bool = npc.illness_hotspot_buildings is Dictionary and npc.illness_hotspot_buildings.is_empty()
	npc.free()
	return ok


func test_spa1691_illness_hotspot_buildings_is_writable() -> bool:
	## World pushes building→true entries into the field each day tick; the
	## field must accept writes without INVALID_SET / INVALID_GET errors.
	var npc := _make_npc()
	npc.illness_hotspot_buildings["tavern"] = true
	var ok: bool = npc.illness_hotspot_buildings.has("tavern")
	npc.free()
	return ok


# ══════════════════════════════════════════════════════════════════════════════
# SPA-1693 — quarantine_ref declared on npc.gd (commit a404f01)
# ══════════════════════════════════════════════════════════════════════════════

func test_spa1693_quarantine_ref_declared_null() -> bool:
	## quarantine_ref must default to null (injected only for Scenario 2).
	var npc := _make_npc()
	var ok: bool = npc.quarantine_ref == null
	npc.free()
	return ok


func test_spa1693_quarantine_ref_accepts_instance() -> bool:
	## World._setup_world_systems() injects a QuarantineSystem for S2 NPCs.
	## The field must accept the assignment without INVALID_DECLARATION errors.
	## QuarantineSystem extends RefCounted — no .free() needed; ref drops on scope exit.
	var npc := _make_npc()
	var qs  := _make_qs()
	npc.quarantine_ref = qs
	var ok: bool = npc.quarantine_ref == qs
	npc.free()
	return ok
