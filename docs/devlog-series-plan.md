# Rumor Mill — Devlog Series Plan & First Post

*Reference: SPA-178 | Based on press kit from SPA-168*

---

## Part 1 — Series Overview: The Community Launch Plan

### Goals

- Build a small but engaged wishlist audience before the Steam Coming Soon page launches.
- Establish a developer voice that matches the game's tone: dry, intelligent, systems-focused.
- Signal that this is a legitimate, actively-developed indie game — not vaporware.

### Target Communities

| Platform | Target Subreddit / Community | Rationale |
|---|---|---|
| Reddit | r/indiegaming | Broad indie audience, receptive to devlogs |
| Reddit | r/gamedev | Developer peers, often cross-post to gaming subs |
| Reddit | r/roguelikes | Systems-focused players; "no combat, just mechanics" resonates here |
| Reddit | r/civ | Fans of complex social/political strategy |
| Reddit | r/IndieDev | Smaller but highly engaged creator community |
| Twitter/X | General indie game audience | Hashtag-driven discovery |
| itch.io | Devlog section on itch.io project page | Permanent archive, SEO, discovery via itch |
| Mastodon | gamedev.social | Growing indie dev community; good for organic reach |

### Hashtags (Twitter/X)

Primary: `#indiedev` `#gamedev` `#godotengine`
Secondary: `#indiegame` `#strategygame` `#solodev` `#screenshotsaturday` (for visual posts)
Game-specific: `#RumorMill` `#medievalgame` `#socialsimulation`

---

## Part 2 — 4-Part Devlog Series Plan

### Posting Schedule

| Post | Title | Target Date | Primary Platform | Content Focus |
|---|---|---|---|---|
| **Devlog #1** | What Is Rumor Mill? | Week 1 | Reddit + itch.io | Game concept intro, AI-built story, core mechanic |
| **Devlog #2** | How Gossip Works (Systems Deep Dive) | Week 3 | Reddit + itch.io | Rumor propagation engine, mutation, spread mechanics |
| **Devlog #3** | Meet the Town (NPC Simulation) | Week 5 | Reddit + itch.io | 30-NPC system, factions, schedules, social graph |
| **Devlog #4** | The Three Cases (Scenario Design) | Week 7 | Reddit + itch.io | Scenario deep dives, design intent, win/fail states |

**Notes:**
- Each post ships on a Tuesday (Reddit peak engagement: Tue–Thu).
- Cross-post Twitter/X thread summary the same day.
- Mastodon post same day, shorter format.
- #ScreenshotSaturday visuals from game can supplement between devlogs.
- itch.io devlog is the canonical archive — all posts live there permanently.

---

### Devlog #1 — What Is Rumor Mill? (FULL DRAFT BELOW)

*See Part 3 for the complete written post.*

**Target length:** ~600–800 words (Reddit sweet spot for devlog posts)
**Assets needed:** None required for launch, but a GIF of the social graph overlay spreading a rumor would significantly boost engagement if available.

---

### Devlog #2 — How Gossip Works (Systems Deep Dive)

**Core angle:** Explain the rumor propagation engine from first principles. How does a rumor mutate? What determines spread rate? How does NPC credibility affect transmission?

**Outline:**
- The problem: making gossip feel *mechanically* satisfying
- Seeding: choosing subject, claim type, and first spreader
- Transmission: how personality affects what each NPC passes on
- Mutation: why the story changes in transit (and why that matters strategically)
- The Social Graph Overlay as a feedback tool
- 1–2 specific examples of a rumor chain playing out

**Assets:** Screenshot of Rumor Crafting Panel open (Shot 3 from press kit). Short GIF of spread propagation if available.

---

### Devlog #3 — Meet the Town (NPC Simulation)

**Core angle:** The town is the game. Introduce the simulation underneath the gossip mechanic.

**Outline:**
- 30 NPCs, five factions, daily schedules
- How faction loyalty affects information trust
- Relationship weights: why the Blacksmith trusts the Miller but not the Guard Captain
- The day/night cycle and why timing your seed matters
- Intel gathering: eavesdropping as information asymmetry management
- The Player Journal as your operational picture

**Assets:** Town overview screenshot (Shot 1 from press kit). Faction color key graphic if available.

---

### Devlog #4 — The Three Cases (Scenario Design)

**Core angle:** Design intent behind each scenario. What different strategic problems do they pose?

**Outline:**
- Why handcrafted scenarios over procedural generation (for now)
- The Alderman's Ruin: reputation destruction across faction lines, time pressure
- The Plague Scare: precision targeting, the cost of overreach
- The Succession: simultaneous reputation manipulation, source security
- What comes after: potential for additional scenarios, Early Access roadmap

**Assets:** Scenario select screen if available. Any in-game screenshot that conveys stakes.

---

## Part 3 — Devlog #1: Full Written Post

**Title:** What Is Rumor Mill? (Devlog #1)

**Platform-specific title variants:**
- Reddit: `What Is Rumor Mill? A medieval gossip simulation I've been building in Godot [Devlog #1]`
- itch.io: `Devlog #1 — What Is Rumor Mill?`
- Twitter/X: Thread opening line — `I've been building a medieval game with no combat, no levels, and no loot. Just 30 NPCs, five factions, and one question: can you control what people believe? 🧵`

---

### The Post

---

**What Is Rumor Mill? (Devlog #1)**

I've been building a medieval social strategy game for the past several months, and I want to start talking about it.

The game is called **Rumor Mill**.

The pitch: you are a hired agent in a medieval town. Thirty people live there. Each one has a personality, a faction, a daily schedule, and a web of relationships you can observe and exploit. Your only tool is information. You plant the right rumor with the right person, and then you watch it travel.

There is no combat. There are no levels. There is only the town, the people in it, and what they believe about each other.

---

**The Core Mechanic**

Every scenario in Rumor Mill gives you an objective that requires changing what people *think* — discrediting a target before a vote, driving out a business rival, elevating one faction and undermining another. You accomplish this through gossip.

The gossip system works like this: you choose a **subject** (who the rumor is about), a **claim type** (accusation, scandal, illness scare, prophecy), and a **seeder** (who you tell first). Then you step back.

The rumor travels through the social network on its own. NPCs spread it based on their personality traits — some embellish, some downplay, some stay quiet. The story *mutates in transit*. A whisper about petty dishonesty becomes a rumor of corruption. A suspicion of illness becomes a plague scare. You cannot fully control the message once it's out.

What you can control is entry point, timing, and who you seed. That's the strategic puzzle.

---

**The Social Graph Overlay**

The town's relationship network is visible in real time through the Social Graph Overlay (toggle with G). Every NPC is a node. Every relationship is an edge. Active rumor threads animate across the graph in amber as they propagate.

Watching your rumor move through the network — crossing faction boundaries, getting picked up and dropped by different NPCs, eventually reaching your target — is the moment the game becomes tangible. It's also the moment you realize you miscalculated and need to adapt.

---

**What's in the Game Right Now**

This is not a demo announcement or an Early Access pitch. I'm documenting the build as it progresses.

Current state: all three core scenarios are playable end-to-end. The full 30-NPC simulation is running, including faction loyalties, daily schedules, and relationship weights. The rumor propagation engine, social graph visualization, Rumor Crafting Panel, and Player Journal are all implemented. Audio is in placeholder state.

The game is being built in **Godot 4.6**.

---

**The AI-Assisted Development Story**

Something I want to be upfront about: parts of this project were built with AI tools — specifically using Claude Code as an engineering assistant for Godot scripting, UI systems, and architecture decisions. The design, direction, and judgment calls are mine. The AI helped me move faster than I could alone.

I'm mentioning this because I think it's relevant context for the indie development community. Solo development is hard. The tools are getting better. I'm using them.

---

**What Comes Next**

Over the next few devlogs, I want to go deeper on the systems:

- **Devlog #2:** How the rumor propagation engine actually works — the mutation system, spread rates, and NPC credibility dynamics.
- **Devlog #3:** The NPC simulation — thirty characters, five factions, daily schedules, and what it looks like when they're all running at once.
- **Devlog #4:** Scenario design — why the three scenarios require completely different strategies.

If this sounds like your kind of game: it's a medieval social strategy puzzle with a simulation underneath it. Comparable territory to **Crusader Kings III** (faction politics), **Disco Elysium** (social intelligence as gameplay), and **Cultist Simulator** (systems-first opacity, dark tone). Without the RPG elements.

More soon.

— SrgtKillerSpark

---

*Rumor Mill is in active development. Steam page coming soon.*
*GitHub: https://github.com/SrgtKillerSpark/Rumor-Mill*

---

## Part 4 — Cross-Platform Adaptation Notes

### Reddit Posting Guidelines

- **r/indiegaming:** Self-post with full text. Title must mention the game name and `[Devlog #N]`. No solicitation. Images/GIFs preferred but optional for text devlogs.
- **r/gamedev:** Label as `[Devlog]` in title. The community is technical — lean into systems explanations. Mention Godot specifically.
- **r/roguelikes:** Frame around "systems depth, no combat" — this audience values mechanical complexity.
- Post at **8–10am EST Tuesday** for peak visibility.
- Do NOT post to r/indiegaming and r/gamedev within 10 minutes of each other. Stagger by at least 30 minutes.

### Twitter/X Thread Format (Devlog #1)

Tweet 1 (hook):
> I've been building a medieval game with no combat, no levels, and no loot. Just 30 NPCs, five factions, and one question: can you control what people believe? Thread on Rumor Mill — Devlog #1 🧵

Tweet 2 (concept):
> You play as a hired agent. Your only tool is information. Plant the right rumor with the right person — then watch it travel through the social network on its own. The story mutates in transit. You can't fully control it once it's out.

Tweet 3 (the overlay):
> The Social Graph Overlay shows every NPC, every relationship, and every active rumor thread in real time. Watching your whisper cross faction lines and reach your target is the game's core payoff moment.

Tweet 4 (current state):
> Current state: all 3 scenarios playable. 30-NPC simulation running. Rumor propagation, social graph, crafting panel, player journal — all implemented. Built in Godot 4.6. Audio still placeholder.

Tweet 5 (CTA):
> More devlogs incoming — systems deep dive, NPC simulation, scenario design. Steam page coming soon. Follow along if medieval gossip games are your thing. #indiedev #godotengine #RumorMill

### itch.io Devlog Format

- Post full text as a devlog entry on the itch.io project page.
- Add tags: `medieval`, `strategy`, `simulation`, `godot`, `indie`, `social-simulation`
- Use the itch.io devlog as the canonical post — Reddit links back to it or stands alone.

---

*Document version: 1.0 — 2026-04-03*
*Task: [SPA-178](/SPA/issues/SPA-178) | Press kit reference: [SPA-168](/SPA/issues/SPA-168)*
