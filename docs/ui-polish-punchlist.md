# UI Polish Punchlist (SPA-1136)

**Date:** 2026-04-30 (updated after child fixes landed)
**Build:** post-SPA-1117 stable + SPA-1143/1144/1145 fixes (commits `8276a23`, `0de2c81`)
**Base viewport:** 1280x720, `canvas_items` stretch mode, no aspect lock
**Reviewed by:** UI/UX Designer agent

---

## Viewport Verdicts

| Viewport | Verdict | Notes |
|----------|---------|-------|
| 1280x720 | **Has issues** | Base resolution. Most layouts fit, but toast overlap, text truncation, and z-order conflicts visible. |
| 1366x768 | **Has issues** | Controls-reference panel clips right edge (780px offset). Tooltip edge-clamping uses 4px buffer (too tight). Social graph legend/search widths fixed at 215-220px look undersized. |
| 1600x900 | **Has issues** | Scenario HUD bars (160px fixed) and score labels feel small. Journal/rumor-panel content lines become uncomfortably wide (no max-width). End screen 760x640 panel is only 47.5% of viewport width. |
| 1920x1080 | **Has issues** | All hardcoded pixel sizes (HUD bars, panels, tooltips) shrink proportionally to viewport. Scenario HUD layer (14) may visually overlap speed HUD (layer 5) and objective HUD (layer 4) if content expands. No DPI scaling on recon hit-test radius (52px). |

---

## Numbered Issue List

### Scenario HUDs (all six + base)

| # | Issue | File : Line(s) | Severity |
|---|-------|---------------|----------|
| 1 | **Inconsistent panel heights across scenarios.** S1-S2: 62px, S3: 58px, S4: 96px, S5-S6: 78px. Jumps are visually jarring when switching scenarios. | scenario1_hud.gd:44, scenario3_hud.gd:56, scenario4_hud.gd:68, scenario5_hud.gd:65, scenario6_hud.gd:50 | Medium |
| 2 | **Score label font size inconsistency.** S1-S4 use 14pt, S5-S6 use 11pt. Creates an unintentional visual hierarchy break. | scenario5_hud.gd:78/86/94, scenario6_hud.gd:65/74 | Medium |
| 3 | **Days-remaining label font size inconsistency.** S1-S4 use 14pt, S5-S6 use 12pt. | scenario5_hud.gd:119, scenario6_hud.gd:104 | Small |
| 4 | **BAR_HEIGHT inconsistency.** S1-S3 use 12px, S4-S6 use 10px. Subtle but perceptible. | scenario4_hud.gd:35, scenario5_hud.gd:31, scenario6_hud.gd:27 | Small |
| 5 | **HBox separation inconsistency.** S1-S3 use 16px, S4-S6 use 14px. | scenario4_hud.gd:68, scenario5_hud.gd:65, scenario6_hud.gd:50 | Small |
| 6 | **Event toast height too short for wrapped text.** S4 toast is 22px, S6 toast is 28px. AUTOWRAP_WORD_SMART is set on S6 label but parent panel can't display a second line. Long event descriptions are clipped. | scenario4_hud.gd:109-110, scenario6_hud.gd:336-337/359 | Medium |
| 7 | **No `clip_text` on dynamic labels.** Caution, days, believers, rejecters, rival, scout, degrade, anonymous-tip, event, campaign, blackmail, guild-defense labels all lack `clip_text = true`. Long dynamic text can bleed past panel edges. | scenario1_hud.gd:60/66, scenario2_hud.gd:234/237, scenario3_hud.gd:79/90/94, scenario4_hud.gd:137/154, scenario5_hud.gd:158/177, scenario6_hud.gd:330/345 | Medium |
| 8 | **S4 faction phase bars appear instantly (no tween).** When a phase fires, the bar snaps from 0 to full width. Should animate over ~0.5s. | scenario4_hud.gd:373 | Small |
| 9 | **Rival gap bar divides by magic constant 30.** If reputation gap exceeds 30, bar is clamped at 100%. No documentation on why 30. | scenario5_hud.gd:148 | Small |
| 10 | ~~**Z-order: objective HUD (layer 4) and speed HUD (layer 5) render below scenario HUDs (layer 14).** At higher resolutions where panels expand, scenario HUD can occlude speed/objective controls.~~ **RESOLVED SPA-1179** — objective_hud raised to layer 15, speed_hud to layer 16, callout_overlay to 17. LAYER constants added to all three files; tested in `test_spa1179_z_order_layers.gd`. | base_scenario_hud.gd, objective_hud.gd, speed_hud.gd | Medium |

### Main Menu & Scenario Select

| # | Issue | File : Line(s) | Severity |
|---|-------|---------------|----------|
| 11 | **Menu panel widths are hardcoded (440-700px).** At viewports below ~800px wide, the 700px credits/settings panel would exceed viewport. Not critical with canvas_items stretch but limits future aspect-ratio support. | main_menu.gd:440-441 | Small |
| 12 | ~~**Narrative RichTextLabel uses `fit_content=true` with `custom_maximum_size.y=120`.** If wrapped narrative text exceeds 120px, it overflows. No scroll fallback.~~ **RESOLVED SPA-1179** — the relevant label is `_intro_body` in `main_menu_briefing_panel.gd` (code was refactored from `main_menu.gd`). `scroll_active` changed from `false` to `true`; `SIZE_EXPAND_FILL` added so the label grows to fill the panel before scrolling. | main_menu_briefing_panel.gd:208 | Medium |
| 13 | **Scenario-select description truncated to 180 chars with no scroll.** If full teaser text is longer, users only see a cut version. `scroll_active = false`. | main_menu_scenario_select.gd:133-140 | Small |

### End Screen

| # | Issue | File : Line(s) | Severity |
|---|-------|---------------|----------|
| 14 | ~~**End screen panel is fixed 760x640px.** Doesn't adapt to viewport. On 1600x900+ it becomes a small island; on sub-1024 it could clip.~~ **RESOLVED SPA-1179** — fixed PANEL_W/PANEL_H replaced with PANEL_MIN_W(640)/PANEL_MIN_H(560)/PANEL_MAX_W(1100)/PANEL_MAX_H(900)/PANEL_VP_W(0.62)/PANEL_VP_H(0.88). `build()` reads viewport size and clamps within min/max. Tests updated in `test_end_screen_panel_builder.gd`. | end_screen_panel_builder.gd:31-38 | Medium |
| 15 | **Button height mismatch.** End screen buttons are 40px, pause menu buttons are 42px. 2px inconsistency. | end_screen_panel_builder.gd:265-266 vs main_menu.gd:365 | Small |
| 16 | **Disabled "Next Scenario" button has no tooltip.** Greyed out at 35% opacity with no explanation. Should say e.g. "Win this scenario to unlock." | end_screen_panel_builder.gd:205-208 | Small |
| 17 | **NPC name label width hardcoded to 130px.** Long or localized names will truncate. | end_screen_scoring.gd:264 | Small |
| 18 | **Top-influencer name width hardcoded to 140px.** Same localization risk. | end_screen_replay_tab.gd:162-163 | Small |
| 19 | **Feedback panel is fixed 500x360px.** No responsive sizing. | end_screen_feedback.gd:19-20 | Small |

### Pause Menu & Settings

| # | Issue | File : Line(s) | Severity |
|---|-------|---------------|----------|
| 20 | **Pause menu panel hardcoded to 300x540px.** Content-heavy scenarios may need more width; narrow for slot picker labels. | pause_menu.gd:213 | Small |
| 21 | **Content margin inconsistency across panels.** Values range from 10px (scenario-select cards) to 28px (main menu panels) with no clear rationale. | main_menu.gd:464, main_menu_scenario_select.gd:287, end_screen_panel_builder.gd:82 | Small |

### Journal & Rumor Panel

| # | Issue | File : Line(s) | Severity |
|---|-------|---------------|----------|
| 22 | **Journal slide animation uses hardcoded 40px offset.** Not viewport-relative; feels different at different scales. | journal.gd:151 | Small |
| 23 | **Rumor panel status label has no width constraint.** Long reward/risk text can overflow panel bounds. `autowrap` set but no `custom_minimum_size`. | rumor_panel.gd:491-500 | Medium |
| 24 | **Rumor panel subject portrait hardcoded to 48x60px.** No DPI scaling. | rumor_panel_subject_list.gd:95 | Small |
| 25 | **Journal font-size hierarchy is muddy.** Factions section uses 18 -> 14 -> 13 -> 13. The jump from header to sub-items is too subtle. | journal_factions_section.gd:52/63/67 | Small |
| 26 | **Timeline event labels have no `clip_text`.** Long event messages can overflow. | journal_timeline_section.gd:268 | Small |
| 27 | **Rumor tracker side panel has `MAX_ROWS=4` and 240px width.** Concatenated claim+subject text can overflow. No truncation guard. | rumor_tracker_hud.gd:160/189 | Medium |

### Social Graph Overlay

| # | Issue | File : Line(s) | Severity |
|---|-------|---------------|----------|
| 28 | **Search panel width fixed at 215px; legend panel at 220px (with conflicting 210px min-size).** Neither adapts to viewport. Contradictory sizing is confusing. | social_graph_overlay.gd:379/710-711 | Medium |
| 29 | **NPC name labels drawn with no width constraint.** Long names can overflow their background rect. | social_graph_overlay.gd:835/854 | Small |

### Tooltips & Toasts

| # | Issue | File : Line(s) | Severity |
|---|-------|---------------|----------|
| 30 | **Achievement toasts can overlap.** No queue/stacking system. If multiple achievements fire in quick succession, they render on top of each other. | achievement_toast.gd (entire file) | Large |
| 31 | **Suggestion toasts can overlap.** Same problem — PanelContainer siblings at the same screen position with no vertical offset management. | suggestion_toast.gd:11-12 | Large |
| 32 | ~~**Tooltip manager and HUD tooltip use different canvas layers (100 vs 25).** If both are active, tooltip_manager always wins. Inconsistent tooltip behavior.~~ **RESOLVED SPA-1179** — `hud_tooltip.gd` raised from layer 25 to layer 99. Documented precedence in both files: `hud_tooltip`(99) = auto-detected hover tooltips; `TooltipManager`(100) = explicit data-driven tooltips, always wins by design. Both scripts now have matching inline doc comments. | tooltip_manager.gd, hud_tooltip.gd | Medium |
| 33 | **Tooltip edge-clamping uses 4px buffer.** Too tight at 1366x768; tooltips can appear to hug screen edge. | tooltip_manager.gd:77, hud_tooltip.gd:205-212 | Small |
| 34 | **Building tooltip uses 4 different font sizes (16/13/12/12).** Visual hierarchy between description and NPC count is unclear. | building_tooltip.gd:158-185 | Small |
| 35 | **NPC tooltip state icon has no fallback image.** Missing texture shows empty box. | npc_tooltip.gd:251-252 | Small |

### Event & Mission Modals

| # | Issue | File : Line(s) | Severity |
|---|-------|---------------|----------|
| 36 | **Mission briefing card uses hardcoded offsets (+-310px).** Not viewport-relative. On 1600x900, card appears slightly off-center. | mission_briefing.gd:146-148 | Small |
| 37 | **Event choice modal panel is 700px wide with no viewport safety.** No max-width cap relative to viewport. | event_choice_modal.gd:164-166 | Small |
| 38 | **Ready overlay card hardcoded to 580px wide (+-290).** Same issue as mission briefing. | ready_overlay.gd:89-92 | Small |
| 39 | **Event card body RTL has `fit_content=true` with no size bounds.** Very long event descriptions expand panel unbounded. | event_card.gd:154 | Medium |

### Other UI Components

| # | Issue | File : Line(s) | Severity |
|---|-------|---------------|----------|
| 40 | **Controls-reference panel offset_right hardcoded to 780px.** Extends off-screen at 1024px-wide viewports. | context_controls_panel.gd:107 | Medium |
| 41 | **NPC dialogue panel uses hardcoded screen offset `Vector2(12, -80)`.** Doesn't adapt to viewport aspect ratio. No vertical clamp for tall panels. | npc_dialogue_panel.gd:160-163 | Medium |
| 42 | **NPC dialogue panel `await process_frame` can hang if game is paused.** UI freeze risk. | npc_dialogue_panel.gd:435 | Medium |
| 43 | **Tutorial banner accent stripe is 5px.** May be imperceptible at higher DPI/resolution. | tutorial_banner.gd:43 | Small |
| 44 | **Loading tips label `custom_minimum_size` is 640x60 with `fit_content=true`.** Long tips can exceed 60px height. | loading_tips.gd:81 | Small |
| 45 | **Zone indicator offset_right hardcoded to 200px.** Can overflow at narrow viewports. | zone_indicator.gd:62-66 | Small |
| 46 | **NPC info panel close animation (0.14s) faster than open (0.18s).** Feels abrupt. | npc_info_panel.gd:99/110 | Small |
| 47 | **Thought-bubble legend uses hard pixel offsets (-180, -280, -90).** No grow-direction ensures proper scaling. | thought_bubble_legend.gd:72-75 | Small |

---

## Top 3 Fixes to Prioritise Before Launch

### 1. ~~Toast/notification stacking (Issues #30, #31) -- Large~~ RESOLVED
Fixed in SPA-1143 / SPA-1144 (commit `8276a23`). Achievement and suggestion toasts now queue sequentially instead of overlapping. Regression test added in `test_achievement_toast.gd`.

### 2. ~~Scenario HUD consistency pass (Issues #1, #2, #3, #4, #5, #7) -- Medium~~ RESOLVED
Fixed in SPA-1145 (commit `0de2c81`). Unified BAR_HEIGHT=12, score font_size=14, days font_size=14, hbox_separation=16 across all six scenarios. S3 panel height corrected to 62px. `clip_text=true` added to all dynamic labels.

### 3. Event toast clipping and text overflow (Issues #6, #7, #39, #23) -- Medium
**Still open.** Event toasts in S4 (22px) and S6 (28px) are too short for wrapped text. The S6 toast has autowrap enabled but the parent panel can only show one line. Similarly, rumor panel status labels, event card bodies, and rumor tracker entries have no width/height constraints, so long dynamic text overflows. **Recommended fix:** increase toast panel height to at least 44px (two-line capacity), add `clip_text=true` or `custom_maximum_size` guards on all dynamic labels, and enable `scroll_active=true` on event card bodies.

---

## Notes

- The `canvas_items` stretch mode with no `stretch/aspect` set means the engine scales the entire UI proportionally to the window. This mitigates many hardcoded-pixel issues at the tested viewports (1280-1920) but does not eliminate them -- panels and labels designed for 1280x720 become proportionally smaller at larger windows, and text truncation is resolution-independent.
- All UI is procedurally built from GDScript (no .tscn UI trees except the CanvasLayer roots). This makes theme-resource-based fixes impractical; constants and code changes are the path forward.
- No screenshots are attached because the review was conducted via code analysis. A visual playthrough at each viewport is recommended to confirm the issues above and catch any rendering-only problems (e.g., font rendering, anti-aliasing artefacts).
