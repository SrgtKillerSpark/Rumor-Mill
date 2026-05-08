# Priority 2 Asset Social Copy
# Rumor Mill — Post-Launch Week

*Companion to `docs/creative-director-asset-checklist.md` Priority 2.*
*Each section has ready-to-post copy for the scheduled slot where that asset is used.*
*Screenshots must be captured from `builds/RumorMill.exe` (post-SPA-410 build) before publishing.*
*Capture specs: `marketing/screenshots/capture-manifest-2026-04-30.md`*

---

## Asset E — ACT State NPC
**File when captured:** `marketing/screenshots/asset-e-act-state-npc-2026-04-30.png`
**Scheduled use:** Evergreen reply-to-curiosity visual

### Evergreen reply template (use when someone asks "what does the payoff look like?")

> This is what happens when a rumor lands.
>
> An NPC who's picked up and is actively spreading the story turns magenta — ACT state. The pulsing lightning icon means they're in transmission. They move toward new targets.
>
> You can't control who they talk to next. That's what makes it tense.
>
> [STEAM_LINK]

---

### Standalone Twitter/X post (can be used any post-launch day)

> The magenta NPC is your story mid-transmission.
>
> When a rumor reaches someone who's primed to spread it, they enter ACT state — tinted, pulsing lightning icon, actively moving toward new targets.
>
> Watch enough of these and you start reading the town like a heat map.
>
> Rumor Mill — Early Access now.
> [STEAM_LINK] #indiedev #RumorMill

---

### Mastodon

> In Rumor Mill, a spreading NPC turns magenta when they're actively transmitting — ACT state. Pulsing icon, movement toward targets.
>
> You seeded the story. What happens next is not fully in your hands.
>
> [ITCH_LINK] #indiedev #godot #RumorMill

---

## Asset F — Inquisitor Pressure (S4)
**File when captured:** `marketing/screenshots/asset-f-inquisitor-pressure-s4-2026-04-30.png`
**Scheduled use:** S4 feature post ("stakes" hook content)

### Twitter/X — standalone post (Day +8 or any evergreen slot)

> Scenario 4 inverts the whole game.
>
> You're not the one seeding rumors. An inquisitor has arrived with three names on his list. You have 20 days to keep their reputations above 48 while he runs a HERESY propagation campaign against them.
>
> The orange threads on the overlay aren't yours. You're the one trying to stop them.
>
> Rumor Mill — Early Access now.
> [STEAM_LINK] #indiedev #RumorMill #strategygame

---

### Twitter/X — reply hook (for players asking about difficulty or "defensive play")

> Scenario 4 is purely defensive. No aggression option. Your tools are counter-rumors, reputation repair, and the same propagation engine your opponent is using against you.
>
> Near-fail state looks like two reputation bars sitting at 42–45 with a HERESY spread thread still in the air.
>
> [STEAM_LINK]

---

### Reddit — r/indiegaming post (standalone, for Day +8 or later)

**Title:** `My medieval gossip game has a scenario where you're the one being targeted — and you can't hit back [Rumor Mill]`

**Body:**
> Rumor Mill is usually about being the operative seeding information and watching it propagate. But Scenario 4 flips that.
>
> An inquisitor arrives with three names. His specialty is HERESY rumors — high-credibility, faction-agnostic spread, primed for escalation chains. You have 20 days to keep the three targets' reputations at or above 48.
>
> There's no offensive option. You can't target the inquisitor. Your only tools are counter-rumors, reputation repair with existing NPCs, and reading the Social Graph Overlay fast enough to intercept before the story compounds.
>
> The hardest moment is watching a HERESY thread mid-flight on the overlay with two reputation bars sitting at 42. You know what it means if it lands.
>
> [Screenshot: Asset F — inquisitor pressure, two protected NPCs near fail floor, HERESY mid-propagation]
>
> Early Access now: [STEAM_LINK]

---

### Mastodon

> In Rumor Mill's fourth scenario, you are not the aggressor.
>
> An inquisitor seeds HERESY claims. You counter-rumor, repair reputation, read the overlay. No offensive options. Just the same propagation engine your opponent is using against you.
>
> Defensive play only. 20 days.
>
> [ITCH_LINK] #indiedev #godot #RumorMill

---

## Asset G — Post-Scenario Analytics Screen
**File when captured:** `marketing/screenshots/asset-g-post-scenario-analytics-s1-2026-04-30.png`
**Scheduled use:** r/gamedev audience posts, replayability angle

### Reddit — r/gamedev post

**Title:** `Post-scenario analytics in my gossip propagation game — Spread Timeline, Mutation Log, and what I learned designing a readable end-state [Rumor Mill / Godot]`

**Body:**
> After each scenario in Rumor Mill, the end screen shows two panels: the Spread Timeline (when and where your rumor moved through the 30-NPC network across the scenario's 20–30 days) and the Mutation Log (every point where the story's content, target, or severity shifted in transit).
>
> The design intent: make a single playthrough feel like a story worth reviewing. The mutation log in particular often surfaces things you didn't notice in real time — target-shift mutations where the subject of your rumor reassigned to an unintended NPC mid-chain, or exaggeration chains where a mild accusation became something much worse by the time it reached the target faction.
>
> Technical note on implementation: the Mutation Log is built from the event queue that fires during propagation steps — each mutation event is tagged with the mutator NPC's ID, the mutation type (exaggeration/softening/detail-add/target-shift), and the resulting diff on the rumor struct. The end-screen replay tab replays this log against the spread timeline.
>
> [Screenshot: Asset G — end screen, Spread Timeline and Mutation Log both visible, win-state]
>
> Game is out on Steam Early Access: [STEAM_LINK]
> Devlog #2 has the full propagation engine breakdown: [DEVLOG_2_LINK]

---

### Twitter/X

> When a scenario ends in Rumor Mill, the end screen shows two things: the Spread Timeline (where your rumor went) and the Mutation Log (how it changed in transit).
>
> The mutation log is the one that surprises people. You can see exactly when target-shift fired and where the story reassigned mid-chain. Usually explains why something worked that shouldn't have — or didn't work that should have.
>
> [STEAM_LINK] #indiedev #RumorMill #gamedev

---

### Mastodon

> Post-scenario analytics in Rumor Mill: Spread Timeline + Mutation Log. See exactly when your rumor mutated, what changed, and why it ended up where it did.
>
> The mutation log makes it a post-game puzzle as much as the scenario itself.
>
> [ITCH_LINK] #indiedev #godot #RumorMill

---

## Asset H — DEFENDING Cascade
**File when captured:** `marketing/screenshots/asset-h-defending-cascade-2026-04-30.png`
**Scheduled use:** Counter-intelligence mechanic posts ("the town pushes back")

### Twitter/X

> The town pushes back.
>
> When a counter-rumor lands near an NPC cluster, DEFENDING state activates — sky-blue tint, spread-block behavior. These NPCs actively resist the original story instead of propagating it.
>
> The shot shows what you want to see: sky-blue DEFENDING cluster in front of the target, orange SPREAD cluster stalled behind it.
>
> It doesn't always hold. But when it does, it looks like this.
>
> Rumor Mill — Early Access now.
> [STEAM_LINK] #indiedev #RumorMill

---

### Twitter/X — thread (for a counter-intelligence deep-dive)

Tweet 1:
> Rumor Mill isn't just about spreading information. It's also about blocking it.
>
> Thread on the counter-intelligence side of the mechanics. #indiedev #RumorMill 🧵

Tweet 2:
> NPCs in DEFENDING state (sky-blue) actively reduce the spread probability of the original rumor when it tries to transmit through them. They don't debunk — they absorb and attenuate.
>
> Seeding a counter-rumor near the right NPC cluster is the primary defense tool.

Tweet 3:
> The risk: counter-rumors also mutate. A protective story can shift targets, exaggerate, or turn into something that damages the NPC you were trying to help.
>
> The DEFENDING cascade is not a perfect shield. It's a managed intervention with its own failure modes.

Tweet 4:
> [Screenshot: Asset H — sky-blue DEFENDING cluster vs. orange SPREAD cluster]
>
> Rumor Mill — Early Access now.
> [STEAM_LINK]

---

### Reddit — r/indiegaming post

**Title:** `Counter-intelligence in my medieval gossip game — planting protective rumors to block an incoming spread [Rumor Mill]`

**Body:**
> A question I get a lot: can you defend against rumor spread in Rumor Mill, or is the mechanic purely offensive?
>
> Yes — via counter-rumors. Seed a protective story near a target NPC cluster and some of those NPCs will enter DEFENDING state (sky-blue). In that state, they attenuate the spread probability of the original hostile rumor when it tries to move through them.
>
> The visual contrast is clear in the screenshot: sky-blue DEFENDING cluster vs. incoming orange SPREAD cluster. The DEFENDING state is the only reliable way to protect a reputation mid-campaign without just hoping the story stalls naturally.
>
> Two caveats: counter-rumors also mutate (four types), and a DEFENDING NPC's state has a finite duration based on their loyalty stat. It's not a permanent block — it's a window.
>
> [Screenshot: Asset H]
>
> Early Access now: [STEAM_LINK]

---

### Mastodon

> In Rumor Mill, DEFENDING-state NPCs (sky-blue) actively reduce the spread probability of incoming hostile rumors. They're protection, not debunk.
>
> You get them by seeding counter-rumors near the right cluster at the right time.
>
> The catch: your counter-rumor can mutate too.
>
> [ITCH_LINK] #indiedev #godot #RumorMill

---

## Asset I — Night at the Noble Estate
**File when captured:** `marketing/screenshots/asset-i-noble-estate-night-2026-04-30.png`
**Scheduled use:** Press kit, atmospheric social post

### Twitter/X — atmospheric post (no pitch weight, purely visual)

> After 18:00, the Noble Estate is accessible.
>
> Some recon only unlocks at night.
>
> [STEAM_LINK] #indiedev #RumorMill

---

### Twitter/X — with more context (Day +6 or any atmospheric slot)

> Night at the Noble Estate.
>
> The Incriminating Artifact recon action only opens after 18:00. By that point the manor is dark, the entrance lit by lantern, one NPC at the door.
>
> The evidence system in Rumor Mill is how you improve spread probability against skeptical targets. Finding it requires being in the right place at the right time.
>
> Rumor Mill — Early Access now.
> [STEAM_LINK] #indiedev #RumorMill #medievalgame

---

### Mastodon

> Night at the Noble Estate in Rumor Mill. Some recon only unlocks after 18:00 — including the Incriminating Artifact acquisition that boosts credibility checks against skeptical targets.
>
> Timing the approach is part of the puzzle.
>
> [ITCH_LINK] #indiedev #godot #RumorMill

---

### Press kit caption (for press-kit screenshot slot)

> The Noble Estate at night. In Rumor Mill, certain recon opportunities are time-gated — the Incriminating Artifact acquisition only becomes available after 18:00 in-game time. Evidence collected in the field improves a rumor's credibility check when seeded against skeptical NPCs.

---

## Asset J — Scenario 3 Dual-Track Split-Screen
**File when captured:** `marketing/screenshots/asset-j-s3-dual-track-split-2026-04-30.png`
**Scheduled use:** S3 feature post, AI rival angle

### Twitter/X — standalone post

> Scenario 3 asks you to raise one reputation and destroy another simultaneously.
>
> The Social Graph Overlay shows both objectives at once: Calder Fenn's reputation tracker climbing in the top half, Tomas Reeve's falling in the lower — and the rival agent's rumor trail in the background, targeting whichever of your objectives is currently most vulnerable.
>
> Two tracks. One town. An opponent who adapts.
>
> Rumor Mill — Early Access now.
> [STEAM_LINK] #indiedev #RumorMill #strategygame

---

### Twitter/X — AI rival thread

Tweet 1:
> Scenario 3 in Rumor Mill has an AI opponent.
>
> Short thread on how it works. #indiedev #RumorMill 🧵

Tweet 2:
> The rival agent runs a metric-driven strategy: it evaluates the current state of both your objectives every turn and targets whichever is closest to failure.
>
> Phase 1: probing attacks on the weaker objective. Phase 2: compound pressure — simultaneous rumors on both tracks. Phase 3: escalation chains targeting your seeder NPCs directly.

Tweet 3:
> You can see its rumor trail on the Social Graph Overlay — a thread in a distinct color from your own spreads. When its phase shifts, the trail pattern changes.
>
> You're not watching a neutral simulation. There's something in the town working against you.

Tweet 4:
> [Screenshot: Asset J — dual-track HUD, rival agent thread visible on overlay]
>
> Rumor Mill — Early Access now.
> [STEAM_LINK]

---

### Reddit — r/gamedev post (AI design angle)

**Title:** `Designing a metric-driven AI opponent for a social simulation game — how the rival agent in Scenario 3 works under the hood [Rumor Mill / Godot]`

**Body:**
> Scenario 3 in Rumor Mill pits the player against an AI rival agent who seeds counter-rumors and adapts its strategy through three escalating phases. Brief design notes on how it works:
>
> The rival evaluates the current game state on each day-tick: it scores both player objectives by proximity to failure and selects a target. Phase 1 is linear pressure on the most vulnerable objective. Phase 2 introduces compound moves — simultaneous rumors on both tracks, forcing the player to divide resources. Phase 3 targets seeder NPCs directly, cutting off the player's most reliable spread paths.
>
> The rival uses the same propagation engine as the player (same β formula, same mutation system). It doesn't cheat. It just plays faster than you because it doesn't hesitate.
>
> The dual-track HUD makes both objectives legible at a glance — Calder Fenn's tracker climbing, Tomas Reeve's falling — and the rival's rumor trail is color-differentiated on the overlay so you can see where it's applying pressure.
>
> Happy to answer questions on the state machine or phase transition logic.
>
> [Screenshot: Asset J — dual HUD + rival trail visible]
> Game: [STEAM_LINK] | Devlog #2: [DEVLOG_2_LINK]

---

### Mastodon

> Scenario 3 in Rumor Mill has an AI opponent that reads the board state every turn and targets whichever of your two objectives is closest to failure.
>
> You can see its rumor trail on the Social Graph Overlay. When its phase shifts, the trail pattern changes.
>
> [ITCH_LINK] #indiedev #godot #RumorMill #gamedev

---

*Document version: 1.0 — 2026-04-30*
*Task: SPA-1467*
*Assets: E, F, G, H, I, J from `docs/creative-director-asset-checklist.md` Priority 2*
*Capture manifest: `marketing/screenshots/capture-manifest-2026-04-30.md`*
*Fill [STEAM_LINK], [ITCH_LINK], [DEVLOG_2_LINK] before publishing.*
