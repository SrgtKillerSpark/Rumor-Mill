# Rumor Mill — Community Feedback Plan

*Defines feedback channels, monitoring cadence, collection process, and response guidelines for the itch.io demo and Steam Early Access phases.*
*Response templates and triage protocol: `docs/launch-announcements.md` §3. Do not duplicate those templates here.*

---

## Overview

The feedback window that matters most is the first two weeks of Steam Early Access (April 25 – May 9). This period generates the data that shapes Phase 1 priorities (see `docs/early-access-roadmap.md`). The goal is not to respond to everything — it is to collect signal from the right channels, route it correctly, and respond publicly where a response adds value.

---

## Feedback Channels

| Channel | Audience | Signal Type | Priority |
|---|---|---|---|
| Steam Discussions | Buyers — motivated enough to open the hub | Bugs, balance issues, questions, feature requests | High |
| itch.io Comments | Warm audience — demo players, devlog followers | Technical feedback, early impressions, bug reports | High |
| Reddit (r/indiegaming, r/gamedev) | Cold discovery audience | First impressions, friction points, systems confusion | Medium |
| Twitter/X mentions | Casual audience | Tone signal — what resonates visually, what lands badly | Low |
| Mastodon mentions | Dev-adjacent audience | Godot/indie tech feedback | Low |

**Do not monitor or respond to communities where the game was not posted.** This includes Discord servers, YouTube comments, review aggregators, and forums not listed above.

---

## Monitoring Cadence

### Days 0–3 (April 25–27) — High-frequency window

Check all high-priority channels twice daily: once in the morning (8–9am EST) and once in the evening (6–8pm EST).

- Respond to all crash reports and launch-blocking bugs within 24 hours
- Acknowledge all other bug reports within 48 hours
- Log all feedback in the running triage list (see Collection Process below)

### Days 4–7 (April 28 – May 1) — Settling window

Morning check only. Respond to direct questions within 24 hours. Bug acknowledgements can shift to 48-hour window.

### Days 8–14 (May 2–9) — Weekly rhythm

Check once daily. Focus on Steam Discussions (most signal-dense channel by this point). Respond to unanswered questions and new crash reports.

### Week 2+ (May 9+)

Steam Discussions daily, itch.io every 2–3 days. Monitor Reddit only if a new post surfaces organically.

---

## Collection Process

Maintain a running feedback log during the launch window. Format: plain text or simple spreadsheet.

**Entry format:**
```
Date | Platform | Type | Summary | Status
```

**Types:**
- `CRASH` — game-ending crash, reproduction unknown
- `BUG` — reproducible defect; not crash-level
- `BALANCE` — difficulty, timing, or probability complaint
- `UX` — confusion, discoverability, or tutorial gap
- `FEATURE` — player-requested addition
- `POSITIVE` — specific praise (log if it reveals what landed, skip generic)
- `QUESTION` — answered publicly or noted

**Status values:** `new`, `acknowledged`, `in_progress`, `patched`, `wontfix`, `monitoring`

Log everything during Days 0–7. After Day 7, log only `CRASH`, `BUG`, and `BALANCE` entries.

---

## Feedback Routing

### Crashes and major blockers
- Acknowledge publicly within 24 hours
- Post a brief notice in Steam Discussions and itch.io comments noting the issue is being investigated
- No fix timeline unless you have a specific date
- Prioritize over balance and UX work

### Recurring balance complaints (3+ independent reports)
- Log under `BALANCE` with exact player phrasing preserved
- Do not over-promise changes publicly
- Review against Phase 1 priorities in `docs/early-access-roadmap.md` before committing
- Eligible for first patch if the fix is low-risk

### UX confusion patterns (same point raised by 2+ players independently)
- These often point to tutorial gaps or missing affordances, not broken mechanics
- Log and batch for keyboard navigation / onboarding pass (Phase 1 scope)
- Respond publicly once with a clear explanation; do not repeat for each instance

### Feature requests
- Log and acknowledge with: "Feature is on the roadmap — I'll post specifics when I have a realistic timeline."
- Do not commit to unscoped features
- If a request appears 5+ times, add it to `docs/early-access-roadmap.md` backlog explicitly

### Positive feedback worth engaging
- If a player correctly identifies something intentional in the design (e.g., the reason target-shift is ungovernable), reply briefly: "That's exactly it."
- Skip generic compliments. They don't need a response.

---

## Response Principles

These extend `docs/launch-announcements.md` §3 (Community Response Plan).

- **One response per thread is usually enough.** Do not re-engage unless new information is offered.
- **On Reddit, let threads breathe.** Reply to direct questions and bug reports; do not reply to every comment in your own launch thread.
- **Silence is not absence.** Not every negative comment needs acknowledgement. Acknowledge facts; do not argue perspectives.
- **Never share bad metrics publicly.** If player count or wishlist numbers are disappointing, say nothing. Wait for something worth sharing.
- **No apology loops.** Acknowledging a bug once is correct. Apologizing in three follow-up comments is noise.

---

## First Patch Scope (Target: Week 1–2)

Collect enough `CRASH` and `BUG` reports to scope the first patch by Day 5 (April 30). Patch targeting window: Day 7–10 (May 2–5).

First patch priority order:
1. Crashes on launch or scenario start
2. Save/load corruption
3. Scenario-breaking bugs (scenario unwinnable due to defect, not difficulty)
4. High-frequency minor bugs (batched together if each fix is small)

Do not hold the first patch for balance changes. Ship bug fixes independently.

---

## Post-Launch Community Post (Week 1)

Target: Day 3–5 (April 28–30) via Steam Community Hub. Cross-post as itch.io devlog if time allows.

Follow the template in `docs/social-media-launch-plan.md` §First-Week Devlog: "What We Are Working On" Outline.

Use real data from the feedback log (bug count, most common question, one observation from player behavior). Do not perform gratitude. 200–400 words is sufficient.

---

## itch.io Demo Feedback (Ongoing)

The itch.io demo remains live through the Steam EA phase. Monitor itch.io comments at the same cadence as Steam Discussions — they are the same audience and often surface different issues (itch players tend to be more tolerant of rough edges and more likely to ask systems questions).

If a player raises a bug on itch.io that was fixed in the Steam EA build, acknowledge it and note the fix is in the Steam version. Do not ask them to switch platforms.

---

*Document version: 1.0 — 2026-04-24*
*Task: [SPA-1047](/SPA/issues/SPA-1047)*
*Extends: `docs/launch-announcements.md` §3 ([SPA-257](/SPA/issues/SPA-257), [SPA-278](/SPA/issues/SPA-278))*
*Reference: `docs/early-access-roadmap.md`, `docs/social-media-launch-plan.md` ([SPA-963](/SPA/issues/SPA-963))*
