# Regression fixture for SPA-1543 / SPA-1556.
# These patterns caused GDScript 4.6 type-inference parse errors.
# The static checker (check 5) must flag every `var x := ... \` line below.
# See commit 3a77fbf for the original fix.

extends Node

# ── Pattern 1: bool with chained and/or (npc_dialogue_panel.gd:417/420) ──────
func _pattern_bool_and_or() -> void:
	var show_bribe := _intel_store.bribe_charges > 0 \
		and npc.get_worst_rumor_state() == Rumor.RumorState.EVALUATING
	var can_bribe := _intel_store.recon_actions_remaining > 0 \
		and _intel_store.whisper_tokens_remaining > 0

# ── Pattern 2: method chain continuation (end_screen.gd:187) ────────────────
func _pattern_method_chain() -> void:
	var _enter_tw := create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

# ── Safe patterns (must NOT be flagged) ──────────────────────────────────────
func _safe_patterns() -> void:
	# Explicit type — no problem
	var ok: bool = something > 0 \
		and other > 0
	# Single-line inferred — no problem
	var x := 42
	var y := foo() and bar()
