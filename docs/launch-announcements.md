# Rumor Mill — Launch Day Announcements & First-Week Community Engagement

*Ready-to-ship copy for launch day and first-week community work.*
*All placeholder links marked `[LINK]` — fill before posting.*

---

## 1. Launch Announcement Copy

### Steam / itch.io Launch Post

**Title:** Rumor Mill is out on Steam Early Access

---

Rumor Mill is live on Steam Early Access.

It's a medieval social strategy game. No combat, no levels, no swords. You play a hired agent in a town of thirty people, and your only tool is information. Plant the right story with the right person at the right moment — then watch where it goes.

The town does not cooperate. Rumors mutate in transit. The person you chose to spread the story tells it wrong, or tells it to someone who trusts your target, or tells it to nobody at all. The Social Graph Overlay shows you every active thread and every dead end in real time.

**Early Access ships with:**
- 4 handcrafted scenarios (offense, precision targeting, dual-front with AI opponent, pure defense)
- 30-NPC living social simulation — each with personality, faction loyalty, and a daily schedule
- Rumor propagation engine with four mutation types (exaggeration, softening, detail addition, target shift)
- Save/load, difficulty presets (Apprentice through Spymaster), post-scenario analytics
- Social Graph Overlay and enhanced eavesdrop intelligence system

Devlogs [#1]([LINK]) and [#2]([LINK]) on itch.io cover the systems in detail if you want to understand the mechanics before you start.

Built in Godot 4.6. Solo development.

**[Play Rumor Mill on Steam]([LINK])**
**[Follow on itch.io]([LINK])**

---

### itch.io Devlog Version (shorter — for itch audience already following)

**Title:** Rumor Mill — now live on Steam Early Access

The game is out.

Steam Early Access as of today. Four scenarios, 30 NPCs, the full propagation engine, save/load, difficulty presets, and the analytics screen I wrote about in Devlog #2.

If you've been following along, you know what it is. If you're new: [short description on the Steam page]([LINK]).

Devlog #3 is the town simulation — coming once the launch dust settles.

Thank you for the follows, wishlists, and questions about the SIR model.

**[Steam page]([LINK])**

---

## 2. Launch Week Social Posts

*Five posts ready to publish. Use directly or adjust timing to fit actual launch date.*
*See `docs/launch-week-campaign.md` for full 7-day posting schedule and platform-specific rules.*

---

### Post 1 — Launch Day (Twitter/X, Mastodon)

> Rumor Mill is live on Steam Early Access.
>
> Medieval social strategy. No combat. 30 NPCs. Your only weapon is information.
>
> Can you control what a town believes before time runs out?
>
> [STEAM LINK] #indiedev #RumorMill #godotengine

*Mastodon version — same copy, omit Steam link, add itch link.*

---

### Post 2 — Day 2: The Social Graph (Twitter/X)

> This is what a rumor looks like in transit.
>
> Every NPC. Every relationship. Every active spread thread — in real time.
>
> When a story crosses a faction boundary, the spread slows. When the wrong person picks it up, you watch it happen before you can do anything about it.
>
> [Screenshot: Social Graph Overlay mid-spread — amber threads across faction clusters]
>
> Rumor Mill — Early Access now. [LINK] #indiedev #RumorMill

---

### Post 3 — Day 3: Behind the Mechanic (Twitter/X Thread — 3 tweets)

> How does gossip spread in Rumor Mill? Short version. 🧵 #indiedev #RumorMill

---

> Rumors move like disease — the engine uses an adapted SIR model.
>
> β (spread probability) = sociability × credulity × relationship_weight × faction_modifier
> γ (recovery) = loyalty × (1 − temperament) × 0.30
>
> Every transmission rolls for mutation — exaggeration, softening, detail addition, or target shift.
>
> Target shift is the brutal one. The subject of the story reassigns mid-chain. You can't predict it. You can only manage mutability when you seed.

---

> Full breakdown in Devlog #2 — escalation chains, two full scenario walkthroughs, the math behind the propagation engine.
>
> [DEVLOG 2 LINK] | Game: [STEAM LINK]

---

### Post 4 — Day 4: The Scenarios (Twitter/X)

> Rumor Mill has 4 scenarios. Each asks a different strategic question.
>
> 1. Discredit a nine-year alderman before the tax rolls are signed
> 2. Drive out a rival before the town healer publicly contradicts the illness rumor
> 3. Raise one reputation and ruin another — while an AI opponent escalates counter-rumors in three phases
> 4. Protect three people from an inquisitor's propaganda campaign. Purely defensive. You are not the aggressor.
>
> One propagation engine. Four completely different problems.
>
> [LINK] #indiedev #RumorMill #strategygame

---

### Post 5 — Day 5: #ScreenshotSaturday / Week Close (Twitter/X or Mastodon)

> One week of Rumor Mill on Steam Early Access.
>
> Thank you for the wishlists, plays, and arguments about target-shift being unfair.
> (It is, but it stays.)
>
> Devlog #3 is the town simulation — 30 NPCs, five factions, daily schedules, how the network behaves when you're not watching.
>
> Next up.
>
> [LINK] #screenshotsaturday #indiedev #RumorMill

*Fill in any real stats or player observations before posting. If there is nothing interesting to report, "thank you, Devlog #3 is next" is enough. Do not fabricate metrics.*

---

## 3. Community Response Plan

### Principles

- Respond to all direct questions and bug reports on launch day and day 2.
- Do not respond to every review or comment — let the community breathe.
- Tone: dry, direct, no performance. Match how the game sounds.
- Bugs get acknowledged and logged, not apologized for at length.
- Negative feedback gets read, not argued with.

---

### Response Templates by Category

#### Bug Report (Steam / itch.io / Reddit comments)

> Thanks for the report. [Issue description in one sentence.] Logged — I'll investigate.
>
> If it's blocking progress: [workaround if known, or "let me know and I'll look at it today"].

*Do not commit to a fix timeline unless you're certain. "Logged" is sufficient.*

---

#### Crash Report

> Sorry about that. Can you share: OS version, whether it happened at [specific moment if they mentioned one], and whether it's reproducible? That'll help me pin it down.

*Follow up once you've reproduced or identified it. One short comment with what you found and what you're doing about it.*

---

#### Gameplay Question / Confusion

Answer directly and factually. One to three sentences. Do not over-explain.

Example:
> *"How do I know if my rumor is spreading?"*
>
> The Social Graph Overlay (G key) shows active spread threads in real time — amber lines are active, grey nodes haven't received the story yet. If nothing is moving, the first spreader may have stalled — check their faction and relationship weight to the next node.

---

#### "This mechanic feels unfair" / Negative Gameplay Feedback

> Fair. [Mechanic name] is intentionally punishing at [difficulty level] — the design intent is [one sentence]. Apprentice mode gives you [X difference] if you want more room to experiment.

*If it sounds like a genuine balance issue rather than intended challenge: "Noted — watching this across more playthroughs."*
*Do not over-promise changes.*

---

#### Positive Review / Comment

Acknowledge briefly if it raises a specific point worth responding to. Skip generic compliments unless they ask a question.

> Glad [specific thing they mentioned] landed the way it was supposed to.

---

#### "When is [feature] coming?"

> [Feature] is on the roadmap — I'll post specifics when I have a realistic timeline. Following on Steam or itch.io is the best way to catch that update.

*Do not commit to features that aren't scoped and scheduled.*

---

### Day-1 Bug Triage Protocol

1. **Check itch.io comments, Steam discussions, and any tagged social posts** in the morning and again in the evening.
2. Log all bugs in a running list — title, platform, reproduction status.
3. Acknowledge all crashes and major blockers publicly within 24 hours.
4. If a critical bug affects core gameplay (scenario unwinnable, save corruption, crash on launch): post a brief notice in Steam discussions and itch.io comments noting the issue and that a fix is in progress. No timeline unless you're certain.
5. Minor visual / UX issues: log silently, batch into the first patch.

---

### Where to Monitor

| Platform | What to watch |
|---|---|
| Steam discussions | Bug reports, gameplay questions, initial reviews |
| itch.io comments | Warm audience — devlog followers, more technical feedback |
| Reddit (r/indiegaming, r/gamedev) | Post-launch comments on launch threads |
| Twitter/X mentions | Surface-level reactions — respond to specific questions only |
| Mastodon mentions | Same rules as Twitter/X |

*Do not monitor or respond to communities where the game was not posted.*

---

## 4. Press Outreach Email

*For indie game journalists, reviewers, and YouTubers. Short, factual, no hyperbole.*
*Send to relevant contacts 1–3 days before or on launch day. Personalize [NAME] and [THEIR WORK] fields.*

---

**Subject:** Rumor Mill — medieval social strategy, Steam Early Access — press key available

---

Hi [NAME],

I'm the developer behind Rumor Mill, a medieval social strategy game that launched on Steam Early Access today.

The short version: you play a hired agent in a town of thirty NPCs. No combat. Your only tool is information. Plant the right rumor with the right person and watch it travel through a live social network — mutating, stalling, accelerating based on faction dynamics and personality stats.

It's a systems game. The rumor propagation engine uses an adapted SIR model. The Social Graph Overlay shows every active spread thread in real time. There are four handcrafted scenarios — including one where you're defending three people from an inquisitor's propaganda campaign rather than running one yourself.

I think it might be relevant to [YOUR WORK / their coverage of similar titles — e.g. "your coverage of Crusader Kings-adjacent strategy games" / "your indie strategy reviews"].

**Steam page:** [LINK]
**itch.io (with devlogs):** [LINK]
**Press kit:** [LINK — point to press-kit.md or hosted version]

Happy to provide a Steam key, answer questions about the systems, or send additional assets. Reply here or at [EMAIL].

— SrgtKillerSpark

---

*Personalization note: mention one specific piece of their work that makes Rumor Mill relevant. Don't send a generic blast. Five targeted emails outperform fifty cold ones.*

*Reference titles for positioning when relevant: Crusader Kings III, Disco Elysium, Cultist Simulator. Don't volunteer these unless their coverage angle invites it.*

---

*Document version: 1.0 — 2026-04-04*
*Task: [SPA-257](/SPA/issues/SPA-257)*
*Builds on: `docs/launch-week-campaign.md` ([SPA-247](/SPA/issues/SPA-247)), `docs/press-kit.md`, `docs/steam-store-page-final.md`, `docs/narrative-identity.md`*
