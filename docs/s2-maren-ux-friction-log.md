# S2 Sister Maren — UX Heuristic Friction Log (Apprentice, Phase 1 Signal Lane)

**Issue:** SPA-1523  
**Author:** UI/UX Designer  
**Date:** 2026-05-03  
**Method:** Two playthroughs of Scenario 2 ("The Plague Scare") on Apprentice difficulty — one win-oriented, one intentional Maren-trigger  
**Framework:** Nielsen's 10 Usability Heuristics  

---

## Playthrough A — Win-Oriented (Goal: reach 7 believers without triggering Maren)

### Entry A1 — Early game (Days 1–4): Mental model mismatch on propagation risk

| Field | Value |
|-------|-------|
| **Time** | Day 1, first seed action |
| **Heuristic violated** | H2 — Match between system and real world |
| **Friction** | Player must choose seed targets from the NPC list but has no upfront indication of which NPCs are in Maren's social-graph orbit. The (!) danger flag only appears *after* an NPC becomes a believer — by then the damage vector is active. No pre-seed risk assessment is available. |
| **Severity** | High — directly correlates with perceived "RNG coin flip" frustration identified in phase1-balance-proposal.md. Players cannot make an informed first move. |
| **Current mitigation** | Social Graph Overlay exists (togglable) but is not scenario-contextual: it shows generic edge weights without highlighting the Maren→Alys propagation path. |

### Entry A2 — Mid game (Days 5–10): Escalation label lacks causal chain

| Field | Value |
|-------|-------|
| **Time** | Day 8, autonomous escalation fires |
| **Heuristic violated** | H1 — Visibility of system status |
| **Friction** | Escalation label changes to "Rumours: Day 8 — illness spreading on its own" but does not indicate *which* NPC was auto-seeded or *where* in the graph the spread occurred. Player cannot assess whether the auto-spread moved the rumor closer to Maren's orbit. |
| **Severity** | Medium — creates anxiety without actionable information. Player must open Social Graph Overlay and manually trace edges to assess risk. |
| **Current mitigation** | Tooltip explains risk conceptually ("Each auto-spread increases the risk Sister Maren will notice") but provides no spatial/relational data. |

### Entry A3 — Mid game (Days 8–12): Quarantine cost mismatch in tooltip vs. button

| Field | Value |
|-------|-------|
| **Time** | Day 9, attempting quarantine |
| **Heuristic violated** | H4 — Consistency and standards |
| **Friction** | Quarantine dropdown tooltip says "Costs 2 Whisper tokens" but the button label reads "Quarantine (1R+1W)" (1 Recon Action + 1 Whisper). These are different costs. One is wrong or the dropdown tooltip is stale from a pre-SPA-868 iteration. |
| **Severity** | Medium — inconsistency erodes trust in displayed resource costs, causing hesitation on a time-critical decision. |
| **Current mitigation** | None. |

### Entry A4 — Late game (Days 14–18): No forward-looking win probability indicator

| Field | Value |
|-------|-------|
| **Time** | Day 15, 5/7 believers |
| **Heuristic violated** | H1 — Visibility of system status |
| **Friction** | Progress bar and pip row show current state (5/7) but offer no signal about whether the remaining 2 targets are achievable given remaining days, whispers, and graph topology. Player is left guessing whether a win is still mathematically viable or whether they should restart. |
| **Severity** | Low — advanced players can compute this, but Apprentice players cannot. Acceptable design debt for Phase 1. |
| **Current mitigation** | Day counter provides time pressure awareness but no resource-sufficiency signal. |

---

## Playthrough B — Intentional Maren Trigger (Goal: seed near Maren's orbit to provoke counter-intelligence fail)

### Entry B1 — Pre-trigger: No preview of grace window mechanic

| Field | Value |
|-------|-------|
| **Time** | Day 3, seeding NPC adjacent to Maren |
| **Heuristic violated** | H6 — Recognition rather than recall; H10 — Help and documentation |
| **Friction** | Before Maren rejects, the player has **zero UI indication** that a grace window mechanic exists. The `_maren_warning_lbl` is hidden until the signal fires. A first-time player on Apprentice has no mental model for what happens when Maren catches the rumor — they may expect instant game-over with no recourse. The mechanic is purely recall-dependent: you must have failed before (or read external docs) to know recovery is possible. |
| **Severity** | High — directly amplifies "binary, RNG-flavored" perception. If the player doesn't know 2 days of grace exist, the fail feels immediate and unrecoverable. This is the #1 UX contributor to perceived unfairness. |
| **Current mitigation** | End-screen shows strategic defeat hint ("NEXT TIME: …") and names the carrier NPC. This is post-hoc — it does not help during the critical 2-day grace window. |

### Entry B2 — Trigger moment: Grace window warning appears but lacks actionable guidance

| Field | Value |
|-------|-------|
| **Time** | Day 5, Maren rejects |
| **Heuristic violated** | H9 — Help users recognize, diagnose, and recover from errors |
| **Friction** | Warning label shows "⚠ Maren rejected — 2 days to reach 7 believers!" with a tooltip explaining the mechanic. However: (1) Tooltip requires hover — not discoverable under time panic. (2) No indication of *how* the rumor reached Maren (which propagation path). (3) No suggested recovery action (e.g., "Use quarantine to slow counter-spread" or "Focus seeds on isolated NPCs"). Player knows the clock is ticking but not what lever to pull. |
| **Severity** | High — the grace window is the game's most important error-recovery mechanic for S2, but its UX treats it as a passive countdown rather than an actionable recovery state. |
| **Current mitigation** | Double-flash animation draws attention to the warning. Tooltip text is accurate but buried. |

### Entry B3 — During grace window: Counter-seeding invisible

| Field | Value |
|-------|-------|
| **Time** | Days 5–7, grace window active |
| **Heuristic violated** | H1 — Visibility of system status |
| **Friction** | Maren enters DEFENDING state and broadcasts -0.15 credulity penalty to her neighbors. This mechanical effect is completely invisible in the HUD. Player cannot see which NPCs are being suppressed by Maren's counter-intelligence. Believer count may plateau or drop without any explanation. If a believer de-converts due to Maren's penalty, there is no toast or log entry explaining why. |
| **Severity** | High — the system is actively working against the player with no visible feedback. Violates the most fundamental heuristic (visibility). This makes the grace period feel hopeless even when strategic counter-play exists. |
| **Current mitigation** | None at the HUD level. Social Graph Overlay shows edge weights but does not highlight active debuffs or Maren's defense radius. |

### Entry B4 — Fail moment: End screen carrier name is helpful but late

| Field | Value |
|-------|-------|
| **Time** | Day 7, scenario fails |
| **Heuristic violated** | H9 — Help users recognize, diagnose, and recover from errors |
| **Friction** | End screen says "The rumor reached her through [NPC name]" — this is good post-mortem feedback. However, on Apprentice, a first-time player needed this information *during* play to avoid the path, not after failure. The gap between in-game opacity and post-game clarity creates a "the game knew and didn't tell me" frustration. |
| **Severity** | Medium — end-screen feedback is structurally sound (SPA-948 strategic hint is well-designed), but the absence of equivalent in-game signaling creates an asymmetric information feel. |
| **Current mitigation** | End-screen carrier reveal + strategic defeat hint. Both are good; the gap is the in-game layer. |

### Entry B5 — Retry: No scenario briefing reminds player of Maren threat

| Field | Value |
|-------|-------|
| **Time** | Retry start |
| **Heuristic violated** | H6 — Recognition rather than recall |
| **Friction** | On retry, the scenario starts with the same HUD state (believers 0/7, days 22/24). There is no reminder that Sister Maren is a counter-intelligence threat, which NPCs are in her orbit, or that a grace window exists. Player must recall all learned information from the previous failed run. No "scenario briefing" or "known threats" panel exists. |
| **Severity** | Low-Medium — experienced players adapt, but Apprentice-difficulty players (the target audience for this issue) may repeat the same mistake. |
| **Current mitigation** | Suggestion toast system (tier 3 hints) could theoretically surface a contextual hint, but no S2-specific Maren-proximity hint appears to be wired. |

---

## Top 3 UX Wins to Ship Before Any Balance Change

These are ordered by impact-to-effort ratio. Each addresses the core "perceived RNG" problem through comprehension/feedback fixes without touching balance constants.

### 1. Pre-seed Maren proximity warning (addresses A1, B1, B5)

**What:** When the player hovers or selects a seed target NPC who is a direct neighbor of Maren in the social graph, show an inline warning: "⚠ Close to Sister Maren's circle — rumor may reach her." Display this in the seed-target selection UI (rumor panel), not only after the NPC becomes a believer.

**Why:** Transforms Maren from an invisible tripwire into a visible constraint. Players can make informed risk/reward decisions. Converts "RNG fail" perception into "I chose to take that risk."

**Effort:** Low — `_maren_neighbours` dictionary is already cached in `scenario2_hud.gd` (line 36). Wire a lookup into the rumor panel's target-selection highlight. No new data, no balance change.

### 2. Grace window onboarding + recovery guidance (addresses B1, B2)

**What:** Two changes:  
(a) Add a passive HUD element (initially dimmed/collapsed) that says "Maren's Watch: dormant" before trigger, making the mechanic discoverable before failure.  
(b) When the grace window activates, expand the warning to include one actionable hint: "Tip: Quarantine buildings near Maren to slow counter-spread" or "Seed NPCs far from her circle."

**Why:** The grace window is the game's primary error-recovery mechanic for S2, but its UX makes it feel like a countdown to inevitable death rather than a strategic pivot moment. Making it visible pre-trigger removes the "binary surprise" and making it actionable post-trigger gives players agency during the crisis.

**Effort:** Medium-low — the warning label infrastructure exists; this adds a pre-trigger dimmed state and a one-line contextual hint on activation. No balance change.

### 3. Counter-intelligence visibility during grace window (addresses B3)

**What:** When Maren enters DEFENDING state, add a subtle visual indicator on affected NPCs in the believers/rejecters list (e.g., a shield icon or "suppressed" tag) and a one-line HUD status: "Maren is actively countering rumors among her neighbors." Optionally pulse the (!) flags on affected NPCs.

**Why:** The system is working against the player with zero feedback — this is the most severe visibility violation in S2. Making the counter-intelligence visible lets players understand *why* their progress stalled, reducing "the game cheated" perception and enabling strategic quarantine or re-routing decisions.

**Effort:** Medium — requires reading Maren's DEFENDING state from `scenario_manager` and mapping her neighbor penalties onto the existing HUD name list. The penalty data is already computed in `npc_rumor_processing.gd`; this is a display-layer wire-up.

---

## Summary Assessment

The S2 HUD is well-engineered for progress tracking (believers bar, pip row, day counter) and has strong post-mortem feedback (carrier reveal, strategic hint). The critical UX gap is the **pre-failure and during-failure information layer**: players cannot assess Maren risk before seeding, cannot discover the grace mechanic before triggering it, and cannot see counter-intelligence effects during the grace window. These three gaps compound to create the "binary RNG coin flip" perception flagged in the balance proposal — a perception that UX can significantly reduce without any balance constant changes.

---

*Document key: `s2-maren-ux-friction-log`*
