# Devlog #5 Outline — Phase 1 Balance Results + What's Next

**Issue:** [SPA-1571](/SPA/issues/SPA-1571)
**Author:** Marketing Lead
**Date:** 2026-05-03
**Status:** Draft outline — awaiting Phase 1 telemetry data window (target: Week 2 review cycle)
**Coordination note:** Phase 2 evidence-economy spec ([SPA-1522](/SPA/issues/SPA-1522)) is in active draft with Game Designer. Phase 2 teases in this devlog must remain directional only — no mechanic specifics, no timelines, until spec is approved.

---

## Proposed Title Options

- `The Numbers Are In — What Phase 1 Changed (and Why)`
- `Phase 1 Results: What the Telemetry Told Us`
- `What We Fixed, What We Watched, What's Next — Phase 1 Wrap`

*Working title: **Phase 1 Results: What the Data Said***

---

## Platform Titles (draft)

- **itch.io:** `Phase 1 Results: What the Data Said [Devlog #5]`
- **Reddit (r/indiegaming):** `Rumor Mill Phase 1 — what we changed, why, and what the telemetry actually showed [Devlog #5]`
- **Reddit (r/gamedev):** `Solo dev Phase 1 post-mortem — data-gated balance patches, what worked, what surprised me [Devlog #5]`
- **Twitter/X thread opener:** `Phase 1 is done. Here's what the numbers showed, what we changed, and why we didn't change the thing everyone expected. 🧵 #indiedev #RumorMill`

---

## Section Outline

---

### Section 1 — The Premise of Phase 1: Data-Gated Decisions

**~150 words**

Context-setter: Phase 1 was explicitly not a feature wave. It was a precision pass on specific balance candidates with specific telemetry gates. No adjustment without data confirmation.

Key points to land:
- What the telemetry thresholds were (from `docs/phase1-balance-proposal.md`): Maren fail >60% → edge weight reduction; Finn fail >60% → loyalty floor raise.
- How many review cycles ran before any decision was made (Mon/Wed/Fri cadence).
- That the goal was to confirm or contradict the community hypothesis — either direction was a valid outcome.

*[Fill in: actual review cycle count and date of first confirmed threshold hit — pull from Game Designer update]*

---

### Section 2 — Scenario 2: Sister Maren

**~200 words**

The most-reported balance complaint in the community log (6 independent reports, plus the "feels like a coin flip" framing from Steam Discussions).

Key points to land:
- What the telemetry showed vs. what community reported.
- Whether the Maren-fail ratio crossed the 60% threshold.
- If patch shipped: what changed (edge weight reduction, 0.35/0.30 → 0.25/0.20), why it's minimal, what players should notice.
- If patch NOT yet shipped: that the threshold hasn't been hit yet, and what that means for the experience claim (some runs are unlucky, not systematically unfair).

*[Fill in: actual Maren fail ratio from telemetry — Game Designer to provide]*

---

### Section 3 — Scenario 4: Finn Monk

**~150 words**

The internal-testing hypothesis that became a public signal: Finn collapses S4 into single-NPC triage.

Key points to land:
- Per-NPC fail distribution from S4 telemetry.
- Whether Finn's fail share crossed 60%.
- If patch shipped: loyalty floor change (`npcs.json`, 0.45 → 0.55) and what it means for S4's feel.
- If not yet: why the scenario still feels like Finn-triage and what that tells us about credulity vs. loyalty balance.

*[Fill in: actual Finn fail share — Game Designer to provide]*

---

### Section 4 — The Things We Didn't Change (and Why)

**~150 words**

This is the section that builds credibility. Players will notice if Phase 1 ignored their complaints. Naming what we chose NOT to change is as important as naming what we did.

Points to cover:
- **Evidence item economy:** explicitly not touched in Phase 1 (per `docs/phase1-balance-proposal.md`) — no usage telemetry yet, risk of nerfing relied-upon tools. Phase 2 work. Keep vague — say "we're building the measurement first."
- **Target-shift:** not a balance change, it's a clarity change. The mechanic is working correctly. The "How Propagation Works" explainer is the fix, not a patch.
- **Audio:** not Phase 1 balance — its own track, its own status update.

*[Fill in: audio progress status — Lead Engineer to provide]*

---

### Section 5 — Audio Status

**~100 words**

The single most-reported gap (14 independent reports). Players have been patient. This section owes them specificity.

Key points:
- What scope shipped or is in progress (ambient soundscape, UI sounds, scenario mood tracks).
- Honest timeline framing — specific if confident, a window if not.

*[Fill in: audio scope and ETA — Lead Engineer to provide]*

---

### Section 6 — What's Next (Phase 2 Directional Tease)

**~100 words**

Phase 2 is evidence economy + new scenarios + post-launch content. This section should be directional without committing specifics.

**Safe to say:**
- Evidence item rebalancing is on the Phase 2 roadmap — we're building the measurement before making the change. Players who asked about Forged Document vs. Incriminating Artifact: we heard you, we're not ready to act yet, but it's tracked.
- New scenarios are the next content horizon after Phase 2 balance work.
- Mac/Linux remains on the roadmap — no window yet.

**Do NOT tease:**
- Specific telemetry event names or data schema (SPA-1522 is still draft — coordinate with Game Designer before publishing).
- Specific evidence item stat changes or proposals.
- Phase 2 timeline.

*[Coordinate with Game Designer on what's safe to say about evidence economy before drafting full copy]*

---

### Section 7 — The Community's Role

**~75 words**

Callback to Devlog #4's closing note. Keep it brief.

- Thank players for specific feedback (Maren reports, Finn failure patterns, propagation explainer requests).
- The feedback-to-data pipeline worked: community signal confirmed telemetry, not the other way around.
- Keep filing it. The same feedback loop applies to Phase 2 decisions.

---

## Production Notes

- **Telemetry data dependency:** Sections 2, 3, and 5 require inputs from Lead Engineer (audio) and Game Designer (balance telemetry). Do not publish without those fills.
- **Steam KPI gate:** As of [SPA-1306](/SPA/issues/SPA-1306), Steam sales data is still pending. Keep all volume language qualitative.
- **Target publish window:** Week 2 review cycle close (approximately 2026-05-12 to 2026-05-14, depending on when Phase 1 thresholds are confirmed).
- **Coordination required before writing full draft:**
  - Game Designer: Maren fail ratio, Finn fail share, any shipped patches
  - Lead Engineer: audio scope and ETA
  - Game Designer ([SPA-1522](/SPA/issues/SPA-1522)): what Phase 2 evidence-economy language is safe to tease publicly

---

*Document version: 1.0 — 2026-05-03*
*Task: [SPA-1571](/SPA/issues/SPA-1571)*
*Sources: `docs/devlog-04.md`, `docs/phase1-balance-proposal.md`, `docs/phase2-evidence-telemetry-spec.md`, `docs/community-feedback-log.md`*
