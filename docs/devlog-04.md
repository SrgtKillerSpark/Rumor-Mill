# Day 5: What You Found, What We're Fixing

*Rumor Mill | Devlog #4 | May 2026*

---

## Platform Titles

- **itch.io:** `Day 5: What You Found, What We're Fixing [Devlog #4]`
- **Reddit (r/indiegaming):** `Day 5 of Early Access — what the community found in Rumor Mill, and what's coming in Phase 1 [Devlog #4]`
- **Reddit (r/gamedev):** `Solo dev Day 5 EA check-in — community signal themes and Phase 1 balance plans for Rumor Mill [Devlog #4]`
- **Reddit (r/IndieDev):** `Five days into Early Access, here's what Rumor Mill players are actually doing and saying [Devlog #4]`
- **Twitter/X thread opener:** `Day 5 of Rumor Mill Early Access. Here's what players found. Here's what we're tuning. 🧵 #indiedev #RumorMill`

---

## The Post

---

**Day 5: What You Found, What We're Fixing**

Five days in.

I've been reading everything — Steam discussions, itch.io comments, Reddit threads, replies to replies. This post is a synthesis of what the community found, how I'm interpreting it, and what comes next.

No raw numbers. Steam's sales data is still in the early-access reporting delay window, and I'm not going to publish estimates. What I can tell you is what players said, and what it means for Phase 1.

---

### Day 5 in Numbers (the ones that matter)

Volume settled into a healthy rhythm by Day 3 — a few hundred signals across Steam, itch, Reddit, and Mastodon, spread across players who clearly engaged with the system for multiple sessions, not just one.

The itch.io audience is producing the most substantive signal relative to its size. Players there tend to finish a scenario before commenting. They report what they were trying to do, not just what felt wrong. That's been genuinely useful.

Steam discussions are active. No major fires. The recurring complaints are recurring for reasons I understand and am addressing. More on that below.

The thing that stands out most from Day 5: the players who are frustrated are frustrated because they care. The most detailed complaints are from people who played for three or four sessions. You don't write a five-paragraph Steam discussion post about a game you don't want to like.

---

### What Players Noticed

**The Social Graph Overlay is the moment.**

The most consistent praise across every channel — Steam reviews, itch comments, Reddit — points at the same thing: the moment a player opens the Social Graph Overlay mid-campaign and watches faction edges shift in real time, something clicks. Multiple players described it as the point where the game's premise became legible to them.

One review put it better than I could:

> "The moment I opened the Social Graph Overlay mid-campaign and saw every amber thread crossing faction lines — that's when I understood what this game actually is. It's not about managing stats, it's about watching information move through a living town."

That's the game. That's what I was trying to build. It's gratifying when the design communicates itself.

**Target-shift still reads as broken to new players.**

This is not a surprise — the launch devlog mentioned it. Target-shift divides players into two groups: those who encounter it and feel cheated, and those who encounter it and immediately start asking how to constrain it. The second group is engaged at a level that keeps them playing. The first group doesn't know the second group exists.

The fix here isn't mechanical. It's clarity. I'm working on a short explainer for Steam discussions — a "How Propagation Works" post that names target-shift explicitly, explains why it exists, and tells new players how to think about it before they run into it mid-campaign. Players who understand the mechanic before encountering it respond completely differently.

**Scenario 2 has a wall.**

Six independent reports — Steam and itch — describe the same experience around Day 10–13 in Scenario 2. Sister Maren counters everything regardless of approach. Two players said they quit the scenario and moved to Scenario 3.

Here's the honest version: Maren's counter-intelligence calibration was set conservatively in testing and has not been validated against the full player base. The fear was that she'd be too weak — that players would route around her trivially. The player reports suggest the opposite edge case is occurring: for players who understand the system but get unlucky with propagation routing, Maren reads as a coin flip, not a puzzle.

We're watching the telemetry on this carefully. If the data confirms what the community reports suggest, the adjustment is a single data-file change. I'll address it directly when the numbers support it.

**Scenario 4 and the Inquisitor.**

The Inquisition scenario has a different version of the same problem. Early reports and internal testing both point at one character — Finn Monk — as the scenario's failure trigger. Finn is the most vulnerable of the three protected NPCs, and the Inquisitor finds him reliably. Players who lose S4 overwhelmingly lose through Finn. The scenario starts to feel like triage on a single character rather than a three-front defense.

Like Maren, the adjustment is targeted and telemetry-gated. But it's on the radar.

An itch.io comment from Day 3 described the feeling of these scenarios better than the bug reports do:

> "I haven't felt this level of emergent storytelling in a strategy game since Dwarf Fortress. The mutations alone make every run worth replaying — my scandal about the alderman turned into a heresy rumor about the wrong person by Day 8 and somehow it still worked."

That's the goal. The balance work is about making more players reach that feeling, not just the ones who already knew what to expect.

**The silence.**

I know. Fourteen independent reports. Players are patient about it — most understand the Early Access context — but the absence of audio is the single most-mentioned gap. Someone is playing with a playlist. Multiple people mentioned it in the same review as praise for the social graph.

Audio is the first Phase 1 deliverable. I'll have a specific update on scope and timing in the Week 1 wrap post.

---

### What's Coming in Phase 1

Phase 1 is not a feature wave. It's a precision pass.

The two balance candidates I'm tracking most closely are the Maren counter-intelligence calibration (Scenario 2) and Finn's loyalty floor (Scenario 4). Both are single data-file changes. Both have clear telemetry gates — I'm not adjusting until the numbers confirm the hypothesis, not just the community reports. The review cadence is Monday/Wednesday/Friday. If thresholds are hit in the current window, a patch can follow within days.

Beyond balance: the heat system tutorial gap is real. Players are discovering it mid-playthrough by getting caught — that's the wrong introduction to the mechanic. A tutorial banner update is already in scope for Phase 1.

There are two things Phase 1 will not include: a date commitment for the Mac/Linux build, and changes to the evidence item economy. Mac/Linux is on the roadmap and I'm not going to promise a window I can't keep. Evidence rebalancing requires usage telemetry we don't have yet — adjusting it blind would risk nerfing tools players rely on without understanding how.

No dates on Phase 1. I'm not promising a timeline I haven't validated. What I can say: the review cycle is already running, and if the telemetry hits the thresholds we set, the patch follows quickly.

---

### Help Shape It

Keep playing. Keep filing feedback.

If something feels wrong — a balance issue, a moment of confusion, a mechanic that reads differently than you expected — tell me. The community feedback log is being monitored across Steam discussions, itch.io, Reddit, and Mastodon. Nothing gets lost.

The most useful feedback is specific: what scenario, what day, what you were trying to do, what happened instead. The five-paragraph posts about Maren or Finn or target-shift are more actionable than any telemetry threshold.

File it in Steam discussions, drop it on itch.io, or find me on Reddit. If you already did, thank you — it's already in the log.

— SrgtKillerSpark

---

*[Steam page: [STEAM_PAGE_URL]] [itch.io: https://rumor-mill.itch.io/rumor-mill]*

---

## Publish Record

| Platform | Status | URL | Posted |
|----------|--------|-----|--------|
| itch.io devlog | **Published** | [DEVLOG_4_ITCH_URL — capture after post] | 2026-05-03 |
| Reddit r/indiegaming | **Cross-posted** (reply to launch thread) | [REDDIT_REPLY_URL — capture after post] | 2026-05-04 |
| Reddit r/gamedev | **Scheduled** | — | 2026-05-04 (30 min after r/indiegaming) |
| Reddit r/IndieDev | **Optional** | — | 2026-05-04 |
| Twitter/X | **Scheduled** | — | 2026-05-04 |

*URL capture required: update this table with actual post URLs after each publish action. ([SPA-1571](/SPA/issues/SPA-1571))*

---

*Document version: 1.3 — 2026-05-03 (Marketing Lead: publish record added; URLs pending capture)*
*Task: [SPA-1513](/SPA/issues/SPA-1513) | Published: [SPA-1571](/SPA/issues/SPA-1571)*
*Sources: `docs/community-feedback-log.md`, `docs/phase1-balance-proposal.md`, `docs/devlog-launch.md`*
