# Rumor Mill — Weekly "What We're Working On" Template

*Steam Community Hub post, cross-posted to itch.io devlog. Published every **Friday** (5pm EST). Owned by: Lead Engineer / Marketing Lead alternating. See cadence section at bottom.*

---

## Template

**Post title:** `What We're Working On — Week [N]`
**itch.io title:** `Rumor Mill — Week [N] Status [What We're Working On]`

---

### Section 1 — State of play (2–3 sentences)

One factual observation — something real from the week. Do not perform gratitude. If metrics are not worth sharing, skip them.

> Rumor Mill has been live for [X] days. [One specific observation from player behavior, feedback, or the build — real data only.] Thanks for the reports.

---

### Section 2 — What we fixed or shipped this week (bullets)

List anything that landed since the last post. Bugs fixed, balance changes, QoL. If nothing shipped: say so honestly.

> **Shipped this week:**
> - [Fix/feature — 1 sentence description]
> - [Fix/feature]
> - [Fix/feature]
>
> *(Nothing shipped this week — the next patch is targeting [date/window].)*

---

### Section 3 — What we heard (1–2 bullets)

Most common question and most common complaint from that week's feedback log. Answer both directly. One response per topic — do not over-promise on complaints.

> **Most common question:** [Question] — [1–2 sentence direct answer]
>
> **Most common complaint:** [Topic] — [1 sentence acknowledgement + 1 sentence on intent or plan]

*If target-shift complaints appear, use:*
> Target-shift is intentionally ungovernable — the mechanic is supposed to create uncontrollable downstream effects. Apprentice mode reduces mutation probability if you want more control.

---

### Section 4 — What's next (bullets)

What the team is actively working on right now. Keep it concrete and honest — no aspirational items that aren't actually in progress.

> **In progress:**
> - [Item — brief description]
> - [Item]
>
> **Up next:**
> - [Item — brief description]

---

### Section 5 — One line forward (1 sentence)

A specific thing to look forward to. Not a promise — just a direction.

> [What's coming in the next post or next milestone, in one plain sentence.]

---

**Tone guidance:** Operational check-in, not a press release. 200–400 words. Fill in real data only. No hype.

**Prohibited:** Specific dates unless confirmed. Promises on unscoped features. Apology loops. Daily metrics that aren't positive.

---

## Cadence

| Item | Value |
|------|-------|
| **Frequency** | Weekly, every Friday |
| **Post window** | 5pm EST (Steam) → itch.io within same day if bandwidth allows |
| **Channels** | Steam Community Hub (primary) + itch.io devlog (cross-post) |
| **Length** | 200–400 words |
| **Owner rotation** | Lead Engineer writes odd weeks (1, 3, 5…); Marketing Lead reviews and posts. Marketing Lead writes even weeks (2, 4, 6…); Lead Engineer reviews. |
| **Cadence commitment** | Weeks 1–4 (per early-access-roadmap.md Phase 1 commitment). Reassess at Week 4. |
| **Intake doc** | Pull "What we heard" data from `docs/community-feedback-log.md` each week |

---

## Week 1 Post — Ready to Ship

*Drafted: 2026-04-30 (Day +5). Post by EOD today via Steam Community Hub. Cross-post itch.io when bandwidth allows.*

---

**Title:** What We're Working On — Week 1

---

Rumor Mill has been live on Steam Early Access for five days. The feedback volume has been manageable and the signal has been clear — thank you for the detailed bug reports and the "this mechanic doesn't do what I expected" notes, which are more useful than you probably think.

**What we shipped since launch:**

- Unified HUD panel heights across all scenarios — the 72px bar sizing inconsistency that caused layout drift on wider resolutions is gone
- Fixed z-order layering on narrative scroll and end-screen sizing issues
- Patched rumor panel scroll bounds and button truncation in the journal overflow case
- Wired `tutorial_step_completed` and `settings_changed` analytics events — the telemetry is now tracking what we need for Phase 1 balance decisions
- KPI aggregation script live for post-launch data processing (internal — you won't see this, but the balance work it enables is the point)

**What we heard:**

**Most common question:** "Does target-shift ever stop?" — It doesn't, by design. When a rumor mutates its target in transit, that's the propagation engine behaving correctly. Apprentice mode reduces mutation probability if you want more narrative control. Spymaster mode does not.

**Most common complaint:** Audio silence. Heard. The audio pass is Phase 1 priority #1 — ambient soundscape, UI feedback sounds, per-scenario mood tracks. It's in active development, not backlogged.

**What's next:**

- Audio pass (ambient + UI feedback sounds first, scenario music to follow)
- Scenario 2 counter-intelligence difficulty tuning — Sister Maren pacing is the first target once player data confirms the read
- First patch window: this week, prioritizing any scenario-blocking issues before balance work

See the full Phase 1 roadmap in the [Early Access FAQ discussion](https://store.steampowered.com/news/app/PLACEHOLDER).

---

*Rumor Mill — Steam Early Access, launched April 25.*

---

*Document version: 1.0 — 2026-04-30*
*Task: [SPA-1414](/SPA/issues/SPA-1414)*
*Reference: `docs/early-access-roadmap.md`, `docs/community-feedback-plan.md`, `docs/community-feedback-log.md`*
