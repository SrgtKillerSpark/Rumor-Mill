# Rumor Mill — Social Media Launch Plan (Days −3 to +7)

*Planning overview and gap-fill for launch week content. Read this alongside the existing campaign docs — do not duplicate what is already there.*
*Full ready-to-post copy lives in: `docs/launch-week-campaign.md`, `docs/launch-announcements.md`, `docs/demo-launch-campaign.md`*

---

## Calendar at a Glance

| Day | Date (Apr/May) | Theme | Platforms | Copy Source |
|-----|----------------|-------|-----------|-------------|
| −3 | Apr 22 (Tue) | Pre-launch tease — no name, no link | Twitter/X, Mastodon | **This doc** |
| −2 | Apr 23 (Wed) | Named wishlist push — demo still live | Twitter/X, Mastodon | **This doc** |
| −1 | Apr 24 (Thu) | "Tomorrow." Final countdown | Twitter/X, Mastodon | `launch-week-campaign.md` Day 1 |
| 0 | Apr 25 (Fri) | Launch day — 5-post thread + Reddit + itch.io | All platforms | `demo-launch-campaign.md` §8, `launch-announcements.md` |
| +1 | Apr 26 (Sat) | Day 1 player observations / review highlights | Twitter/X | `launch-announcements.md` Post 3 |
| +2 | Apr 27 (Sun) | Feature: Social Graph Overlay | Twitter/X, Reddit, Mastodon | `launch-week-campaign.md` Day 3 |
| +3 | Apr 28 (Mon) | Feature: Propagation engine thread | Twitter/X, Reddit | `launch-week-campaign.md` Day 4 |
| +4 | Apr 29 (Tue) | Feature: Intel + difficulty presets | Twitter/X, Mastodon | `launch-week-campaign.md` Day 5 |
| +5 | Apr 30 (Wed) | Feature: Scenarios thread | Twitter/X, Reddit | `launch-week-campaign.md` Day 6 |
| +6 | May 1 (Thu) | #ScreenshotSaturday prep / visual asset post | Twitter/X, Mastodon | **This doc** |
| +7 | May 2 (Fri) | End-of-week thank you + roadmap pointer | Twitter/X, Reddit, Mastodon | `launch-week-campaign.md` Day 7 + **This doc** |

*Adjust all dates if launch date shifts. Day 0 = actual Steam EA publish date.*

---

## New Content: Days −3 and −2

### Day −3 — April 22 (Tuesday)

**Goal:** Build curiosity before naming the game. No link, no CTA. Restraint is the hook.

**Best posting time:** 9am EST

---

**Twitter/X:**

> Information is the only weapon that works on everyone.
>
> Something launches this week.
>
> #indiedev #RumorMill

*No screenshot. No link. One or two lines maximum. The teaser works because it says nothing obvious.*

---

**Mastodon (gamedev.social):**

> A medieval town. Thirty people. Five factions. One operative with nothing but whispers.
>
> Launches this week.
>
> #indiedev #godot #RumorMill

---

### Day −2 — April 23 (Wednesday)

**Goal:** Named launch announcement with Steam wishlist CTA. Demo is still live on itch.io — use it as a friction-reducer. No new Reddit thread; save Reddit for launch day.

**Best posting time:** 9am EST

---

**Twitter/X:**

> Rumor Mill launches on Steam Early Access this Friday.
>
> Medieval social strategy. No combat. 30 NPCs. Your only weapon is information — plant the right story with the right person, then watch what the town does with it.
>
> Free demo still live on itch.io if you want to try it first.
>
> Wishlist → [STEAM_LINK] | Demo → [ITCH_LINK]
>
> #indiedev #RumorMill #godotengine

*Attach: Social Graph Overlay screenshot — amber threads crossing faction clusters, no UI labels. Asset A from the visual list below.*

---

**Mastodon:**

> Rumor Mill launches on Steam Early Access this Friday.
>
> Free demo on itch.io now. Same four scenarios.
>
> [STEAM_LINK] | [ITCH_LINK]
>
> #indiedev #godot #RumorMill

---

**Reddit (no new thread):**

If the existing demo thread on r/indiegaming is still warm (comments in last 48 hrs), reply directly:
> Quick update — Steam Early Access launches this Friday. Wishlist link: [STEAM_LINK]. First patch from demo feedback goes in at launch.

Do not post a new subreddit thread on Day −2. Reddit bandwidth reserved for launch day.

---

## New Content: Days +6 and +7 Supplements

### Day +6 — May 1 (Thursday / #ScreenshotSaturday adjacent)

**Goal:** Visual asset post with no pitch weight. By Day +6 the community knows what the game is. Give them something to look at.

**Best posting time:** 9am EST

---

**Twitter/X:**

> #ScreenshotSaturday (a day early)
>
> The moment a rumor crosses a faction line. Amber thread, two nodes, one credulity check.
>
> Social Graph Overlay mid-campaign. Rumor Mill — Early Access now.
>
> [STEAM_LINK] #indiedev #RumorMill #screenshotsaturday

*Attach: Asset A or Asset C from the visual list below — whichever performed better in engagement during the week.*

---

**Mastodon:**

> #screenshotsaturday
>
> When a story crosses a faction boundary it slows. When it finds a SPREAD NPC on the far side it accelerates. Every amber thread here is a live transmission.
>
> [ITCH_LINK] #indiedev #godot #RumorMill

---

*Reddit: skip Day +6 unless there is specific player discussion worth engaging. No new threads.*

---

### Day +7 — May 2 (Friday)

The end-of-week thank you post is already in `launch-week-campaign.md` Day 7. Fill in the real stats placeholder and post as written.

**Supplement — roadmap pointer (reply to that post or separate):**

> The Early Access roadmap is in Steam Discussions. Phase 1 priorities: audio pass, balance tuning from player data, bug fixes.
>
> Devlog #3 is the town simulation deep-dive — thirty characters, five factions, how the daily schedule system feeds the propagation engine.
>
> After that: new scenarios.
>
> [STEAM_DISCUSSIONS_LINK]

*Keep this short. The thank you post is the headline; the roadmap pointer is a footnote.*

---

## Visual Asset List for Social Posts

*These are social-first captures — prioritize speed of read and visual drama on a timeline. Different from the press kit screenshot guide in `marketing_brief.md`, which targets static assets for journalists and store pages.*

*Board/developer action required: all captures must be taken from the current build (post–[SPA-410](/SPA/issues/SPA-410) art pass). Do not use earlier build screenshots.*

---

### Priority 1 — Required Before Launch Day

**Asset A — Social Graph in motion (GIF, 5–8 sec)**
- Capture: Press G mid-campaign in Scenario 1 around Day 12–15 when the merchant faction is fracturing. 8+ NPCs in varied states. Let the overlay animate for 5–8 seconds — amber threads spreading, faction cluster visible.
- No UI labels in frame. Let the network speak.
- Compress to under 5MB (Twitter/X limit). 15fps capture is smoother than 30fps in feed.
- **Use:** Day −2 teaser, Launch day Tweet 1, Day +2 Social Graph feature post.

**Asset B — Rumor mid-transmission (screenshot or 3-sec GIF)**
- Capture: The exact moment an orange SPREAD NPC passes the story to a new node — speech bubble icon and ripple VFX both visible simultaneously. Market location, midday, high NPC density.
- **Use:** Launch day Tweet 3 (the hook post), Day +3 propagation engine thread.

**Asset C — Rumor Crafting panel (screenshot)**
- Capture: Panel 2 or 3 open. SCANDAL or ACCUSATION claim type selected. Evidence attached. Spread estimate visible. Clean composition — subject in frame, two NPCs in background as context.
- **Use:** Mid-week mechanic explainer. Evergreen backup when no action screenshot is available.

**Asset D — Scenario select screen (screenshot)**
- Capture: All six scenarios visible, clean state, no in-progress save data showing.
- **Use:** Day +5 scenarios thread. Any copy where all six scenarios are listed.

---

### Priority 2 — Good to Have Before Launch; Valuable Through Post-Launch Week

**Asset E — ACT state NPC (screenshot)**
- Capture: Magenta-tinted NPC with pulsing lightning icon, mid-movement, moving away from the rumor subject. Ideally one or two surrounding NPCs visible for scale.
- **Use:** Evergreen reply-to-curiosity visual. "This is what the payoff state looks like."

**Asset F — Inquisitor pressure (screenshot — Scenario 4)**
- Capture: Two protected NPCs with reputation ~42–45 (near fail floor). Inquisitor's HERESY rumor mid-propagation on Social Graph Overlay. Pressure HUD element visible.
- **Use:** Scenario 4 feature content. Strong "this game has stakes" hook for the defensive scenario angle.

**Asset G — Post-scenario analytics screen (screenshot)**
- Capture: End-state of Scenario 1 or Scenario 3. Spread timeline and mutation log both visible. Clean win-state preferred.
- **Use:** r/gamedev audience posts. Replayability angle — "here's what happened after the scenario ends."

**Asset H — DEFENDING cascade (screenshot)**
- Capture: 1–2 sky-blue DEFENDING NPCs positioned near Edric Fenn, orange SPREAD cluster visible in the same frame. The visual contrast is the whole point.
- **Use:** Counter-intelligence mechanic explanation posts. "The town pushes back."

---

### GIF Capture Technical Notes

- Minimum resolution: 1920×1080
- Target file size: under 5MB for Twitter/X feed compatibility
- 15fps gives smoother playback in social feeds than 30fps at equivalent file size
- Teaser GIFs (Asset A, Day −2): no UI chrome in frame
- Mechanic-explainer GIFs (Assets B, E): UI elements are fine — they're the point

---

## Community Response Templates

Ready-to-use response templates for bug reports, crash reports, gameplay questions, negative feedback, positive reviews, and feature requests are in `docs/launch-announcements.md` §3 (Community Response Plan).

Day-1 Bug Triage Protocol is in the same document — use it for both itch.io demo and Steam EA.

**Do not duplicate those templates here. Reference them directly.**

One reminder not in that doc: on Reddit, do not reply to every comment in your own launch thread. Reply to direct questions and bug reports; let the community conversation breathe. Silence is not absence.

---

## First-Week Devlog: "What We Are Working On" Outline

*This is the first weekly check-in promised in `docs/early-access-roadmap.md` Phase 1 (Community Channels). It is a different post from `docs/devlog-launch.md`, which is a retrospective. This one is forward-facing.*

*Target: post to Steam Community Hub on Day +3 to +5. Cross-post as itch.io devlog if time permits. Do not wait for a full week of data — post by Day +5 at the latest.*

**Platform titles:**
- Steam Community Hub: `What We're Working On — Week 1`
- itch.io devlog: `Rumor Mill — Week 1 Status [What We're Working On]`

---

**Section 1 — State of launch** (2–3 sentences)

State how launch went without over-explaining. If there are real numbers worth sharing, share them. If not, one sentence is enough.

Fill in template:
> Rumor Mill has been live on Steam Early Access for [X] days. [One specific observation from player behavior, reviews, or feedback — real data only.] Thank you for the plays, bug reports, and questions.

---

**Section 2 — Bug status** (bullets)

- List all known issues being actively worked on (from launch-day triage log)
- Note any that are already patched or about to patch
- Give a realistic patch window: "targeting this week" or "in the next build" — no specific date unless certain

Template:
> **Known issues we're tracking:**
> - [Issue 1 — brief description, status: investigating / fix in progress / patched]
> - [Issue 2]
> - [Issue 3]
>
> First patch targeting [week / specific date if confident].

---

**Section 3 — What we heard** (1–2 bullets)

Most common question and most common complaint. Answer both directly. Do not over-promise on complaints.

Template:
> **Most common question:** [Question] — [1–2 sentence direct answer]
>
> **Most common complaint:** [Complaint topic] — [1 sentence acknowledging it + 1 sentence on intent or monitoring]

If target-shift complaints are dominant (expected), use this:
> Target-shift is intentionally ungovernable by design — the mechanic is supposed to create uncontrollable downstream effects. Apprentice mode reduces mutation probability if you want more control. Spymaster stays as-is.

---

**Section 4 — Phase 1 priorities** (bullets)

Pulled directly from `docs/early-access-roadmap.md` Phase 1. Do not rewrite — reference the roadmap and summarize:

> **What's next (Phase 1 — Weeks 1–4):**
> - Audio pass — the single biggest gap in the launch build; ambient soundscape, UI feedback sounds, scenario mood music
> - Balance tuning based on player data — Scenario 2 counter-intelligence, Scenario 3 dual-objective pacing, evidence item economy
> - Bug fixes — prioritized by encounter frequency, not severity (lesson from launch sprint)
> - Keyboard navigation improvements flagged during demo and launch week

---

**Section 5 — Next post** (1 sentence)

> Devlog #3 is the town simulation — thirty characters, five factions, daily schedules, and how the social network behaves when no one is actively targeting anyone. Coming soon.

---

**Tone guidance:** This is an operational check-in, not a press release. 200–400 words is plenty. Fill in real data only — if there is nothing dramatic to report, "here is what we are fixing and what comes next" is sufficient and honest. Do not perform gratitude.

---

## Platform-Specific Rules Reference

*(Already in `docs/launch-week-campaign.md` — summarized here for quick reference during execution)*

- Never post to r/indiegaming and r/gamedev within 30 minutes of each other
- Reddit performs best Tuesday–Thursday, 8–10am EST
- Twitter/X threads outperform single tweets for systems content — use threads on Days 0, +3, +5
- Mastodon: shorter and warmer than Twitter/X; drop performance, keep substance
- itch.io devlog: one post on launch day, one "What We're Working On" post in Week 1. No more until Devlog #3 is ready
- Do not post daily metrics publicly unless they are positive

---

## Week 2 — 2026-05-04 → 2026-05-10: Post-Devlog #4 Engagement Push

*Added by: Marketing Lead | [SPA-1571](/SPA/issues/SPA-1571) | 2026-05-03*
*Anchor event: Devlog #4 published 2026-05-03*

---

### Calendar

| Date | Day | Theme | Platform(s) | Copy |
|------|-----|-------|-------------|------|
| Mon May 4 | +9 | Devlog #4 announcement + itch.io link | Twitter/X, Mastodon, Reddit | See below |
| Tue May 5 | +10 | Community spotlight — Social Graph Overlay praise | Twitter/X, Mastodon | Pull from feedback log digest |
| Wed May 6 | +11 | "How Propagation Works" explainer — pin in Steam Discussions | Twitter/X (thread), Reddit reply, Steam pin | See below |
| Thu May 7 | +12 | Phase 1 balance watching — brief status tease | Twitter/X, Mastodon | See below |
| Fri May 8 | +13 | Community reply sweep | Reddit (r/indiegaming, r/gamedev) | Reply outstanding target-shift + S2 threads |
| Sat May 9 | +14 | #ScreenshotSaturday — Social Graph Overlay | Twitter/X, Mastodon | Asset A or Social Graph GIF |
| Sun May 10 | +15 | No post scheduled — reply-only if active threads | — | — |

*Reddit posts: respect the no-duplicate-sub-within-30-min rule. Tuesday–Thursday 8–10am EST is optimal window.*

---

### Copy — Monday May 4: Devlog #4 Announcement

**Twitter/X:**

> Day 5 devlog is up.
>
> What players found. What the community said. What's coming in Phase 1.
>
> → [DEVLOG_4_ITCH_URL]
>
> #indiedev #RumorMill

**Mastodon:**

> Devlog #4 — Day 5 of Early Access.
>
> Five hundred signals across Steam, itch.io, and Reddit. What the community found, what it means for Phase 1.
>
> → [DEVLOG_4_ITCH_URL]
>
> #indiedev #godot #RumorMill

**Reddit (reply to r/indiegaming launch thread):**

> **Devlog #4 is up — Day 5 EA check-in.**
>
> Synthesizing what we've heard from players across Steam, itch.io, and Reddit over the first five days. Covers the Social Graph praise, target-shift confusion, the Maren and Finn balance candidates, and what Phase 1 will and won't include.
>
> Full post: [DEVLOG_4_ITCH_URL]
>
> Happy to answer questions here.

---

### Copy — Wednesday May 6: "How Propagation Works" Explainer

*Pin this in Steam Discussions as a standalone post. Cross-post as Twitter/X thread.*

**Steam Discussions post (full text):**

> **How Propagation Works in Rumor Mill — specifically, target-shift**
>
> Nine players have reported target-shift as feeling uncontrollable or broken. It's not broken. Here's what's actually happening.
>
> **What target-shift is:**
> When a rumor is in transit, if the intended target fails their credulity check, the rumor can shift to an adjacent NPC in the social graph. This is intentional. Information in Rumor Mill behaves like real gossip: once it's released, it finds its own path through faction relationships. You are a catalyst, not a controller.
>
> **Why it exists:**
> The mechanic creates the emergent narrative that makes runs feel different. If you could perfectly control where a rumor lands every time, the game would be a puzzle with one solution. Target-shift is what makes the Social Graph Overlay interesting to watch.
>
> **How to work with it (not against it):**
> - Seed to high-credulity NPCs: they pass the credulity check more often, shortening the propagation path.
> - Avoid seeding near neutral faction members if you need the rumor contained — they're more likely to carry it sideways.
> - On Apprentice mode, mutation probability is reduced. Use it if you want more predictable spread while you learn the system.
> - On Master/Spymaster, the unpredictability is the difficulty setting. Plan for drift.
>
> This won't be patched out. But if you're hitting it and it feels unfair rather than interesting, that's feedback worth knowing — post here.

**Twitter/X thread (condensed):**

> Devlog #4 mentioned a short explainer for target-shift. Here it is. 🧵
>
> 1/ Target-shift is not a bug. When a rumor misses its intended target's credulity check, it shifts to a nearby NPC in the social graph. This is intentional — gossip doesn't go where you send it, it goes where the relationships take it.
>
> 2/ Why does it exist? Because the Social Graph Overlay would be boring if you could predict exactly where every rumor lands. The unpredictability is what makes the emergent narrative possible.
>
> 3/ How to work with it: seed high-credulity NPCs → shorter propagation path → less drift. Avoid neutral faction adjacency if you need the rumor contained. Apprentice mode reduces mutation probability if you're still learning the system.
>
> 4/ Spymaster: the drift is the difficulty. Plan for it.
>
> Full explanation pinned in Steam Discussions: [STEAM_DISCUSSIONS_LINK]
>
> #indiedev #RumorMill

---

### Copy — Thursday May 7: Phase 1 Status Tease

**Twitter/X:**

> Phase 1 review cycle is running (Mon/Wed/Fri cadence).
>
> Two balance candidates on watch: Scenario 2 counter-intel calibration and Scenario 4 Finn vulnerability. Both are telemetry-gated — no adjustment until data confirms.
>
> If thresholds hit this week, patch follows within days. Watching.
>
> #indiedev #RumorMill

**Mastodon:**

> Phase 1 balance watching: Sister Maren (S2) and Finn Monk (S4) are the two candidates. Each has a specific telemetry threshold before any change ships. Review cycle is Mon/Wed/Fri.
>
> No adjustment until data confirms the community reports. That's the rule.
>
> #indiedev #godot #RumorMill

---

### Copy — Saturday May 9: #ScreenshotSaturday

**Twitter/X:**

> #ScreenshotSaturday
>
> Eleven factions. Thirty people. Every amber thread is a live transmission — a story in transit through the social graph.
>
> Rumor Mill — Early Access now.
>
> [STEAM_LINK] #indiedev #RumorMill #screenshotsaturday

*Attach: Asset A (Social Graph GIF) or whichever Social Graph screenshot had the highest engagement this week.*

**Mastodon:**

> #screenshotsaturday
>
> The moment information crosses a faction boundary, it slows. When it finds a willing carrier on the far side, it accelerates again. Every thread here is a rumor in motion.
>
> [ITCH_LINK] #indiedev #godot #RumorMill

---

### Community Reply Sweep — Friday May 8

Target threads for engagement (based on community-feedback-log.md digest, Days 5–7):

**Target-shift confusion threads (9 reports outstanding):**

Reply template:
> Target-shift is intentional — when a rumor misses its credulity check it shifts to an adjacent NPC via the social graph. The mechanic exists because information in this game behaves like real gossip: you're a catalyst, not a controller. Apprentice mode reduces mutation probability if you want more predictable spread while learning the system. More detail in the Steam Discussions explainer: [STEAM_DISCUSSIONS_LINK]

**Social Graph Overlay praise threads (12 positive mentions):**

Reply template:
> Thank you — the Social Graph Overlay is the game's heartbeat. That moment when faction threads start crossing and you realize information is moving on its own is exactly what we were building toward. More scenarios and faction dynamics are on the roadmap for after Phase 1. Glad it landed.

*Do not reply to every comment in the launch thread. Direct questions, bug reports, and target-shift confusion only.*

---

*Section added: Document version 1.1 — 2026-05-03*
*Task: [SPA-1571](/SPA/issues/SPA-1571)*

---

*Document version: 1.0 — 2026-04-24*
*Task: [SPA-963](/SPA/issues/SPA-963)*
*Extends: `docs/launch-week-campaign.md` ([SPA-247](/SPA/issues/SPA-247)), `docs/launch-announcements.md` ([SPA-257](/SPA/issues/SPA-257), [SPA-278](/SPA/issues/SPA-278)), `docs/demo-launch-campaign.md` ([SPA-939](/SPA/issues/SPA-939))*
*Reference: `marketing_brief.md`, `docs/early-access-roadmap.md`, `docs/devlog-launch.md`*
