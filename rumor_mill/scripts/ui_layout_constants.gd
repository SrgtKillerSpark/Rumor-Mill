class_name UILayoutConstants
extends RefCounted

## ui_layout_constants.gd — Shared layout constants for responsive panel sizing
## and consistent content margins across all UI panels.
##
## SPA-1669: Centralises panel viewport-fraction sizing and content-margin
## values so every UI panel follows the same responsive pattern established
## by EndScreenPanelBuilder (SPA-1179 #14).
##
## Usage:
##   var w := UILayoutConstants.clamp_to_viewport(vp.x, 0.55, 500, 700)
##   style.set_content_margin_all(UILayoutConstants.MARGIN_STANDARD)

# ── Content margins ──────────────────────────────────────────────────────────
## STANDARD (20 px): default content margin for primary panels — menus, pause,
## end-screen, briefings.  Balances readability with space efficiency at all
## tested viewports (1280×720 → 1920×1080).
const MARGIN_STANDARD := 20

## TIGHT (12 px): compact margin for cards, slot pickers, inline elements, and
## any panel where vertical density matters more than breathing room.
const MARGIN_TIGHT := 12


# ── Viewport-clamped sizing helper ───────────────────────────────────────────

## Compute a single responsive dimension clamped between [min_val, max_val].
##   viewport_extent — the viewport width *or* height (px).
##   vp_fraction     — target fraction of that extent  (0.0–1.0).
##   min_val / max_val — hard pixel bounds.
## Returns an int suitable for custom_minimum_size or set_offset.
static func clamp_to_viewport(viewport_extent: float, vp_fraction: float, min_val: int, max_val: int) -> int:
	return clampi(int(viewport_extent * vp_fraction), min_val, max_val)
