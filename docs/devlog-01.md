# Devlog #1 — How AI Agents Built a Medieval Gossip Simulator

*Rumor Mill | Devlog #1 | April 2026*

---

## Platform Titles

- **itch.io:** `Devlog #1 — How AI Agents Built a Medieval Gossip Simulator`
- **Reddit (r/indiegaming):** `I had a team of 9 AI agents build a medieval gossip game from scratch. Here's what they made. [Devlog #1]`
- **Reddit (r/gamedev):** `Nine AI agents collaborated to build a Godot 4.6 game. The result: a medieval social simulation with no combat. [Devlog #1]`
- **Twitter/X thread opener:** `Nine AI agents were hired to build a game from scratch. No human wrote a line of GDScript. Here's what they shipped — and why the game they built is kind of meta. 🧵 #indiedev #godotengine #RumorMill`

---

## The Post

---

**How AI Agents Built a Medieval Gossip Simulator**

Nine AI agents built this game.

Not "AI-assisted." Not "we used Copilot for some boilerplate." Nine agents — each with a role, a task queue, and a chain of command — collaborated across sprints to design, engineer, and ship a playable medieval social simulation. From architecture decisions to UI layout to the rumor propagation engine to this devlog post, the team that built Rumor Mill was artificial.

That's the story I want to tell in this first devlog. The game itself comes second — but it earns the context.

---

### The Team

The studio was structured like a small software company. Nine agents, each with a defined role:

- **CEO** — project direction, sprint prioritization, cross-team decisions
- **CTO** — technical architecture, engine selection, code review standards
- **Lead Engineer** — Godot implementation, core systems, scene structure
- **Marketing Lead** — brand identity, press kit, store copy, devlog series (this post)
- **Additional agents** — QA, design review, NPC systems, audio coordination

Each agent received tasks via a project management system, checked them out, did the work, and posted updates. They filed blockers. They delegated. They escalated. The CEO resolved conflicts between agents who disagreed on scope.

No human wrote GDScript. The design direction, high-level goals, and final judgment calls on what shipped — that was human. But the execution was theirs.

---

### Why This is Meta

The game they built is called **Rumor Mill**.

It is a medieval social strategy game about how information travels through networks — how a whisper turns into a scandal, how credibility determines what people believe, how a well-placed story can move a town without the source ever being traced.

An AI team, organized as a social network with defined roles and communication protocols, built a game about social networks.

That's not an accident. It's not a metaphor I'm reaching for. It's just what happened.

---

### What the Game Is

Rumor Mill has no combat. No levels. No loot.

You play as a hired agent in a medieval town of thirty people. Each NPC has a personality, a faction, a daily schedule, and a web of relationships. Your only tool is information.

Open the **Rumor Crafting Panel**. Choose a subject — who the rumor is about. Choose a claim type: an accusation of theft, a scandal, an illness scare, a dark prophecy, a blackmail threat, a secret alliance, a forbidden romance. Choose who you tell first. Then let go.

The rumor moves through the social network on its own. Each NPC who carries it applies their personality — some embellish, some downplay, some go quiet. The story **mutates in transit**. A petty accusation becomes a corruption scandal. A health concern becomes a plague scare. You cannot fully control the message once it's out.

What you can control is entry point, timing, and seeder. That is the entire strategic puzzle.

---

### The Social Graph Overlay

Press `G`.

Every NPC becomes a node. Every relationship becomes an edge. Active rumor threads animate across the graph in amber as they propagate through the town in real time.

Watching your whisper cross faction lines — intercepted by a skeptic, picked up by a gossip, stalling at a dead end, suddenly accelerating through the Merchants' Guild — is the moment the game becomes tangible. It's also the moment you realize your plan has gone sideways and you need to adapt.

The Social Graph Overlay was one of the first things the engineering team built. It is the most technically interesting piece of the game, and it was designed collaboratively between the CTO and Lead Engineer across three sprints.

---

### What's Playable Right Now

Four fully playable scenarios:

**The Alderman's Ruin** — Discredit a nine-year incumbent before the autumn tax rolls. Thirty days. One high-reputation target with a dense network of allies.

**The Plague Scare** — Drive out a business rival using an illness rumor — but the Chapel is watching, and overreach costs everything.

**The Succession** — Raise one reputation and ruin another simultaneously, while keeping your client's hands clean. Twenty-five days. Zero margin.

**The Holy Inquisition** — Purely defensive. An inquisitor has three names. Keep their reputations intact for 20 days while he seeds scandal claims designed to prime for heresy escalation. You are not the aggressor here.

The full 30-NPC simulation is running — faction loyalties, daily schedules, relationship weights. The rumor propagation engine, Social Graph Overlay, Rumor Crafting Panel, and Player Journal are all implemented.

Audio is still placeholder. Visual polish is ongoing. The systems are real and the scenarios play to completion.

Engine: **Godot 4.6**. Platform: **Windows**.

---

### What Comes Next

Three more devlogs are planned:

- **Devlog #2:** How gossip actually works — the mutation system, spread rates, NPC credibility dynamics, and what happens when a rumor backfires
- **Devlog #3:** The town simulation — 30 characters, five factions, daily schedules, and the intel system (eavesdropping as information asymmetry management)
- **Devlog #4:** Scenario design — why each of the four scenarios requires a completely different strategy

---

### Wishlist / Follow

The Steam page is coming soon. In the meantime:

- **Follow on itch.io** to get notified when the demo drops
- **Wishlist on Steam** once the Coming Soon page is live — the link will be in the next devlog
- **GitHub:** https://github.com/SrgtKillerSpark/Rumor-Mill

If this sounds like your kind of game — *Crusader Kings III* faction politics, *Disco Elysium* social intelligence, *Cultist Simulator* systems-opacity — it probably is.

More soon.

— SrgtKillerSpark

---

*Rumor Mill is in active development. All three scenarios playable. Built in Godot 4.6.*

---

## Posting Notes

### Reddit
- Post to **r/indiegaming** first (broadest audience, good for the AI hook).
- Stagger by 30 min, then post to **r/gamedev** (more technical audience — they'll engage with the agent team structure).
- Post on **Tuesday, 8–10am EST**.
- Lead comment (pin immediately after posting): *"Happy to answer questions about either the game systems or the AI development process — both are fair game."*
- Do NOT post simultaneously to both subreddits. Reddit cross-post detection can suppress visibility.

### itch.io
- Post as a devlog entry on the project page.
- Tags: `devlog`, `medieval`, `strategy`, `godot`, `indiedev`, `ai-development`
- This is the canonical version — Reddit posts link back here.

### Twitter/X
Use the 5-tweet thread structure from `docs/devlog-series-plan.md` (Part 4), adapted with the AI-team hook as Tweet 1.

---

*Document version: 1.1 — 2026-04-04*
*v1.0 ([SPA-190](/SPA/issues/SPA-190)): Initial draft. Series plan: [SPA-178](/SPA/issues/SPA-178) | Press kit: [SPA-168](/SPA/issues/SPA-168)*
*v1.1 ([SPA-346](/SPA/issues/SPA-346)): Fixed three→four scenarios; added The Holy Inquisition; added BLACKMAIL, SECRET_ALLIANCE, FORBIDDEN_ROMANCE claim types; updated Devlog #4 description.*
