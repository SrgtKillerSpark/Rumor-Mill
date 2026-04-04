# Rumor Mill — Early Access Roadmap

**Author:** Game Designer (SPA-275)
**Date:** 2026-04-04
**Status:** Draft for team review and player-facing publication

> This roadmap is what we share with players on launch day. It sets honest expectations, signals that the game is actively developed, and builds excitement for what's coming — without overcommitting a small team.

---

## What Ships on Day One (Early Access Launch)

Rumor Mill enters Early Access as a **complete, playable game** — not a prototype. Here's what's in the box:

### Four Full Scenarios

| # | Title | Days | Strategic Problem |
|---|-------|------|-------------------|
| 1 | **The Alderman's Ruin** | 30 | Destroy a well-protected reputation. Learn the basics of rumor warfare. |
| 2 | **The Plague Scare** | 20 | Precision targeting — spread illness rumors about a rival while dodging counter-intelligence. |
| 3 | **The Succession** | 25 | Two-front campaign: elevate one candidate while tanking another, against an active AI rival agent. |
| 4 | **The Holy Inquisition** | 20 | Pure defense: protect three accused NPCs from an inquisitor's rumor campaign. |

Each scenario is a standalone strategic puzzle with unique mechanics (bribery, rival agents, defense objectives) layered onto the core rumor engine.

### Core Systems

- **30 simulated NPCs** across 5 factions (Merchant, Noble, Clergy, Independent, Civic), each with personality stats, daily schedules, loyalty networks, and faction relationships
- **Rumor propagation engine** — stories spread through the social graph based on NPC personality, mutating in transit (exaggeration, softening, target shifts, detail additions)
- **Intel system** — observe buildings, eavesdrop on conversations, collect and deploy evidence items
- **Social graph overlay** — real-time visualization of who knows what, who's spreading, and where your rumor has traveled
- **Player journal** — track reputations, relationships, active rumors, and objectives
- **Player heat system** — NPCs grow suspicious if you intervene too often; manage your exposure
- **Save/load** — full game state persistence
- **Post-scenario analytics** — see how your campaign played out: spread patterns, mutation chains, key turning points
- **10-step contextual tutorial** — non-blocking banner hints that teach the full gameplay loop
- **Keyboard navigation and accessibility** — colorblind-safe icons, configurable fonts, full keyboard focus support

### What's Not In Yet (Honest List)

- **Audio is placeholder.** The game launches silent. Music and sound effects are a top priority for the first update.
- **Windows only.** Mac and Linux builds are planned but not yet tested.
- **Scenario 2-3 balance is rough.** These scenarios are playable and winnable, but difficulty tuning is ongoing. Player data will guide final balance.

---

## Phase 1 — Foundation (Weeks 1-4 Post-Launch)

*Priority: Listen, fix, and add the most-requested missing piece.*

### Audio Pass
The single biggest gap in the launch build. We plan to add:
- **Ambient town soundscape** — market chatter, chapel bells, tavern noise, day/night transitions
- **UI feedback sounds** — rumor seeded, evidence acquired, NPC state changes, objective progress
- **Scenario mood music** — per-scenario ambient tracks that reflect tone (intrigue, tension, dread, triumph)
- **Rumor spread audio cues** — subtle audio feedback when your rumor hits a new NPC or mutates

### Balance Tuning (Data-Driven)
The analytics system tracks every rumor seeded, every mutation, every NPC state change. With real player data:
- Tune Scenario 2 counter-intelligence difficulty (Sister Maren may be too aggressive or too passive)
- Adjust Scenario 3 rival agent pacing and dual-objective balance
- Calibrate evidence item impact across all scenarios
- Review whisper token / recon action economy — are 2 whispers per day too few? Too many?

### Bug Fixes and Quality of Life
- Respond to player-reported issues within the first week
- Prioritize anything that blocks completion of a scenario
- Objective HUD clarity improvements (surface win conditions more visibly)

### Community Channels
- **Steam Community Hub** and **itch.io comments** as primary feedback channels
- Weekly "What We're Working On" post in the first month
- Collect and tag all balance-related feedback for Phase 2 tuning

---

## Phase 2 — Expansion (Months 2-3)

*Priority: New content and the features players ask for most.*

### New Scenarios (2-3 planned)

We have several scenario concepts in development. Which ship first depends on player feedback and what mechanics prove most interesting:

**Scenario 5 — The Election** (working title)
- A contested vote for town alderman. Two candidates, three factions that matter, and a 15-day campaign window.
- New mechanic: **public opinion polling** — a visible sentiment tracker that all factions can see, creating feedback loops where rumors about who's "winning" become self-fulfilling.
- Strategic identity: fast-paced, high-visibility, offensive campaign with a clear public scoreboard.

**Scenario 6 — The Merchant's Debt** (working title)
- A trade dispute where reputation is collateral. Discredit a merchant enough and their creditors call in debts — but damage the wrong merchant and you collapse the market that pays your employer.
- New mechanic: **economic consequences** — reputation damage to merchants affects trade prices and NPC daily routines, creating collateral damage the player must manage.
- Strategic identity: precision surgery with systemic side effects.

**Scenario 7 — The Heretic's Trial** (working title)
- A longer scenario (30+ days) combining offense and defense: protect your client from heresy charges while building a counter-narrative that implicates the accuser.
- New mechanic: **evidence chains** — linked evidence items that build a coherent counter-story, more powerful than individual evidence but harder to assemble.
- Strategic identity: the most complex scenario, requiring both Scenario 4's defense skills and Scenario 1's offensive campaign.

### Scenario Variants
- **Hard mode modifiers** for existing scenarios: reduced whisper tokens, faster NPC memory decay, higher starting heat, stronger counter-intelligence
- **Speed run mode** — same objectives, tighter day limits, for players who've mastered the base scenarios

### Platform Expansion
- **Mac build** (Godot 4.6 exports natively; needs testing and store page updates)
- **Linux build** (same pipeline; community testing via itch.io before Steam)

---

## Phase 3 — Depth (Months 4-6)

*Priority: Systems that extend replayability and invite the community in.*

### Scenario Editor (Stretch Goal)
The most ambitious planned feature. If player demand supports it:
- **Custom scenario creation** — define objectives, select active NPCs, set day limits, choose which mechanics are enabled
- **Shareable scenarios** — export/import scenario files for community sharing
- **Custom NPC tweaks** — adjust personality stats, faction assignments, and starting relationships for custom setups

This is a stretch goal because it requires significant UI work and validation logic. We'll scope it based on how the community grows.

### Advanced Rumor Mechanics
- **Rumor chains** — plant a sequence of rumors that build on each other, with escalating believability if the chain holds
- **Counter-rumors** — craft defensive rumors to protect allies or undermine competing narratives (currently only AI agents do this)
- **Faction-wide events** — periodic events (market day, festival, funeral) that temporarily change NPC schedules, faction tensions, and rumor spread rates

### Replay and Meta-Progression
- **Campaign mode** — play scenarios in sequence with persistent reputation consequences; your success (or notoriety) in one town follows you to the next
- **Scenario scoring** — letter grades based on efficiency (days used, rumors seeded, heat accumulated, collateral damage)
- **Unlockable difficulty modifiers** — earn hard mode options by completing scenarios with high scores

---

## What We Won't Do (Scope Boundaries)

Keeping scope honest is how small teams ship good games. These are intentionally out of scope for Early Access:

- **Multiplayer.** The simulation is designed for single-player strategic thinking. Multiplayer rumor-spreading is a fascinating concept but a different game.
- **Procedural generation.** The 30 NPCs, their relationships, and the town layout are hand-crafted. Randomization would undermine the strategic depth that comes from learning the social graph.
- **Voice acting.** The game's text-forward, clerk-narrated tone is a deliberate aesthetic choice, not a budget limitation.
- **Mobile.** The UI is designed for mouse/keyboard interaction with dense information displays. A mobile port would require a full redesign.

---

## How Player Feedback Shapes This Roadmap

This roadmap is a plan, not a promise. Here's how we decide what ships and when:

1. **Analytics data** — the built-in telemetry shows us where players struggle, which mechanics get used, and where scenarios break. Balance changes are data-driven, not guesswork.
2. **Community feedback** — Steam reviews, community hub discussions, itch.io comments, and (if demand warrants) a Discord server. We read everything.
3. **Completion rates** — if players aren't finishing scenarios, that's a design problem we fix before adding new content.
4. **Feature requests** — we track what players ask for and weigh it against development cost. The scenario editor, for instance, only happens if enough players want it to justify the work.

**Our commitment:** At least one substantial content update per month during Early Access. We'll post patch notes for every update and a monthly roadmap check-in so you always know what's next.

---

## Timeline Summary

| Phase | Window | Focus | Key Deliverables |
|-------|--------|-------|-----------------|
| **Launch** | Day 1 | Complete base game | 4 scenarios, 30 NPCs, full rumor engine, save/load, analytics, tutorial |
| **Phase 1** | Weeks 1-4 | Foundation | Audio pass, balance tuning, bug fixes, community setup |
| **Phase 2** | Months 2-3 | Expansion | 2-3 new scenarios, scenario variants, Mac/Linux builds |
| **Phase 3** | Months 4-6 | Depth | Scenario editor (stretch), advanced mechanics, campaign mode |

---

*Rumor Mill is built by a small team that cares about systems-driven design and respects your time. We'd rather ship four great scenarios than twelve forgettable ones. Thank you for trusting us with your Early Access support.*

*— The Rumor Mill Team*
