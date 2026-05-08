# Rumor Mill — itch.io Demo Launch Campaign (April 11, 2026)

*Ready-to-post social copy, Reddit posts, and press outreach for the April 11 free demo release on itch.io.*
*This is a separate document from `launch-week-campaign.md` and `launch-announcements.md`, which cover the Steam Early Access launch (April 25 – May 9). Do not conflate the two events.*

---

## Status Check: What's Ready

| Asset | Document | Status |
|---|---|---|
| itch.io page copy | `docs/itchio-game-page.md` v1.2 | ✅ Finalized |
| Devlog #1 text | `docs/devlog-series-plan.md` Part 3 | ✅ Ready to post |
| Social posts (demo) | This document | ✅ Ready |
| Reddit posts (demo) | This document | ✅ Ready |
| Press outreach (demo) | This document | ✅ Ready |
| Screenshots (3 minimum) | Pending capture | ⚠️ Board/developer action required |
| Windows build uploaded to itch.io | Pending | ⚠️ Board/developer action required |

**Board action required before April 11:**
See `docs/itchio-game-page.md` Go-Live Checklist for the full pre-publish list. Minimum requirements:
- Build uploaded to itch.io and confirmed downloadable
- At least 3 screenshots uploaded (hero town view, social graph overlay, rumor crafting panel)
- Tags entered (top 5 minimum)
- Devlog #1 drafted in the itch.io editor and ready to publish same day as page

---

## Launch Day Timeline (April 11)

| Time (EST) | Action |
|---|---|
| 9:00 AM | Publish itch.io game page |
| 9:05 AM | Post Devlog #1 to itch.io project |
| 9:30 AM | Post to Reddit r/indiegaming |
| 10:00 AM | Post to Reddit r/gamedev (30-min stagger from r/indiegaming) |
| 10:05 AM | Post Twitter/X launch thread |
| 10:10 AM | Post to Mastodon (gamedev.social) |
| End of day | Check itch.io comments and any social mentions — respond to questions and bug reports |

---

## 1. itch.io Devlog #1 — Post on Launch Day

Post the full Devlog #1 text from `docs/devlog-series-plan.md` (Part 3) to the itch.io project page immediately after publishing the game page.

**Title:** `Devlog #1 — What Is Rumor Mill?`

**Tags to add:** `devlog`, `medieval`, `strategy`, `godot`, `indiedev`

The full text is in `docs/devlog-series-plan.md`. Do not rewrite it — post as-is. The itch.io audience sees this on the project page and via devlog feed.

---

## 2. Reddit Posts

*Primary subreddits on launch day: r/indiegaming and r/gamedev (posts below). Secondary subreddits to consider in the days following — use a condensed version of the r/indiegaming post, adjusted for tone:*

| Subreddit | Rationale | Timing |
|---|---|---|
| r/indiegaming | Broad indie audience — primary launch post | April 11 |
| r/gamedev | Developer peers, systems angle — primary launch post | April 11 |
| r/roguelikes | Systems-focused players; "no combat, just mechanics" resonates strongly here | April 13–15 |
| r/IndieDev | Smaller but highly engaged creator community | April 13–15 |

*For r/roguelikes and r/IndieDev, use a condensed version of the r/gamedev post above. Lead with the propagation engine math and the "no combat" angle — that audience will appreciate it. Do not post to all four on the same day; stagger r/roguelikes and r/IndieDev by 2–3 days to avoid self-promotion flags.*

---

### r/indiegaming — Launch Post

**Title:** `I just put a free demo of my medieval gossip game on itch.io — no combat, 30 NPCs, and your only tool is information [Rumor Mill]`

**Body:**

> Rumor Mill is a medieval social strategy game I've been building in Godot 4.6. Today the free demo is up on itch.io.
>
> Short version of what it is: you play a hired agent in a town of thirty people. Each one has a personality, a faction, a daily schedule, and a web of relationships you can map and exploit. Your only tool is information. Plant the right story with the right person — then step back and watch where it goes.
>
> The rumor moves through the social network on its own. NPCs pass it on based on their personality — some embellish, some downplay, some go quiet. The story **mutates in transit**. A petty accusation becomes a corruption scandal. You can't fully control the message once it's out. What you can control is timing, entry point, and who you seed first.
>
> The Social Graph Overlay (press G) shows every NPC, every relationship, and every active rumor thread in real time — amber lines are active spreads crossing faction clusters.
>
> **The demo has four handcrafted scenarios:**
> - Discredit a nine-year alderman before the autumn tax rolls
> - Drive out a business rival with a precision illness rumor before the healer contradicts you
> - Raise one reputation and ruin another simultaneously against an AI opponent
> - Purely defensive — protect three people from an inquisitor's propaganda campaign
>
> All four scenarios are fully playable. It's a complete early build, not a vertical slice. Windows only for now.
>
> **Free, no account required.** Built in Godot 4.6. Solo-developed.
>
> Devlog #1 (what it is and how it works) just went up on the itch.io page if you want more context before playing.
>
> Happy to answer questions about how the propagation engine works.
>
> — SrgtKillerSpark

**Lead comment:** `itch.io: [ITCH_LINK] | Devlog #1: [DEVLOG_LINK] | Built in Godot 4.6`

---

### r/gamedev — Launch Post (stagger 30+ min after r/indiegaming)

**Title:** `Free demo out today — Rumor Mill, a medieval social strategy game built in Godot 4.6 with an SIR-model rumor propagation engine [Devlog #1]`

**Body:**

> Posting this in r/gamedev because the systems angle might be relevant here.
>
> **Rumor Mill** is a solo Godot 4.6 project I've been building for several months. The free demo is on itch.io today.
>
> The core mechanic is a rumor propagation engine built on an adapted SIR model (Susceptible → Infected → Recovered). Every NPC transmission rolls for mutation — exaggeration, softening, detail addition, or target-shift (the brutal one: the subject of the story reassigns mid-chain). Spread probability is:
>
> `β = sociability × credulity × relationship_weight × faction_modifier`
>
> Recovery probability: `γ = loyalty × (1 − temperament) × 0.30`
>
> The Social Graph Overlay visualizes every active spread thread in real time. There are 30 NPCs with individual personality stats, faction loyalties, and daily schedules. Four handcrafted scenarios test different strategic configurations of the same engine.
>
> Devlog #1 is the intro post — concept and core mechanic. Devlog #2 goes into the propagation engine math in detail (it's up on itch.io).
>
> Built with AI-assisted engineering (Claude Code for Godot scripting and architecture). Design, direction, and judgment calls are mine.
>
> Demo is free, Windows only. Any feedback on the systems or how the propagation engine reads is welcome.
>
> — SrgtKillerSpark

**Lead comment:** `itch.io: [ITCH_LINK] | Devlog #1: [DEVLOG_1_LINK] | Devlog #2 (systems deep dive): [DEVLOG_2_LINK]`

---

## 3. Twitter/X — Launch Thread (5 tweets)

**Tweet 1 (announcement):**
> Rumor Mill is out — free demo on itch.io, live now.
>
> Medieval social strategy. No combat. 30 NPCs. Your only weapon is information.
>
> [ITCH_LINK] #indiedev #RumorMill #godotengine

**Tweet 2 (what it is):**
> You play a hired agent. A town of thirty people surrounds you. Each one has a personality, a faction, a daily schedule, and a web of relationships you can observe, map, and exploit.
>
> Plant the right story with the right person. Then step back.

**Tweet 3 (the hook):**
> The Social Graph Overlay shows your rumor traveling in real time — amber threads crossing faction lines, reaching people you never intended.
>
> The story mutates in transit. You can't fully control the message once it's out. That's the game.

**Tweet 4 (what's in it):**
> The demo has four complete scenarios:
> - Discredit an alderman before the tax rolls
> - Precision illness scare to drive out a rival
> - Dual-front: raise one rep, ruin another, against an AI opponent
> - Defend three people from an inquisitor's propaganda campaign
>
> One propagation engine. Four completely different problems.

**Tweet 5 (CTA):**
> Free. No account required. Windows only.
>
> Devlog #1 is up on the itch.io page if you want the systems breakdown first.
>
> [ITCH_LINK] #indiedev #RumorMill #godotengine #medievalgame

*Screenshot to attach to Tweet 1: Social Graph Overlay at mid-spread — amber threads across faction clusters. No UI labels. Let the network speak. Art pass 4 (SPA-410) improved NPC sprites and faction props — capture now, not from an earlier build.*

---

## 4. Mastodon (gamedev.social) — Launch Post

> Rumor Mill is out — free demo on itch.io.
>
> Medieval social strategy. 30 NPCs. Your only tool is information. Plant a rumor, watch it mutate in transit, guide it toward your objective before time runs out.
>
> Social Graph Overlay shows every active spread thread in real time. Four handcrafted scenarios.
>
> Free. Windows only.
>
> [ITCH_LINK]
>
> #indiedev #godot #gamedev #RumorMill #medievalgame

---

## 5. Press Outreach — Demo Version

*This is a demo-adapted version of the journalist pitch in `launch-announcements.md`.*
*Send to relevant contacts on April 11 or in the 1–2 days before.*
*Personalize [NAME] and [THEIR WORK] fields. Five targeted emails beat fifty cold ones.*

**Subject:** Rumor Mill — free medieval social strategy demo, itch.io — press copy available

---

Hi [NAME],

I'm the developer of Rumor Mill, a medieval social strategy game. The free demo went live on itch.io today.

Short version: you play a hired agent in a town of thirty NPCs. No combat. Your only tool is information. Plant the right rumor with the right person and watch it travel through a live social network — mutating, stalling, or accelerating based on faction dynamics and personality stats.

It's a systems game. The propagation engine uses an adapted SIR model. The Social Graph Overlay shows every active spread thread in real time. The demo includes four handcrafted scenarios — including one where you're playing defense, protecting three people from an inquisitor's propaganda campaign rather than running one yourself.

I think it might be relevant to [YOUR WORK / their coverage angle].

**itch.io (demo + devlogs):** [ITCH_LINK]
**Press kit (screenshots, fact sheet, comparable titles):** [PRESS_KIT_LINK or reference docs/press-kit.md]

Happy to provide a download key, answer questions about the systems, or send additional screenshots. Reply here or at [EMAIL].

This is a free demo ahead of a Steam Early Access release planned for late April / early May.

— SrgtKillerSpark

---

*Note: the full journalist and streamer outreach templates in `docs/launch-announcements.md` §4–5 are written for the Steam EA launch. Use the abbreviated version above for the itch.io demo. Update those templates with real links before the Steam EA launch.*

---

## 6. Day-1 Monitoring

Check the following by end of day April 11:

- [ ] itch.io comments — respond to questions and bug reports
- [ ] r/indiegaming and r/gamedev threads — respond to direct questions
- [ ] Twitter/X mentions — respond to questions, ignore generic reactions
- [ ] Mastodon mentions — same

**Bug triage:** Use the protocol in `docs/launch-announcements.md` §3 (Day-1 Bug Triage Protocol). The response templates there are platform-agnostic and apply to the itch.io demo.

---

## 7. Demo Period Follow-Up (April 12–24)

*The two-week demo window (April 11 → Steam EA launch) is the wishlist-building phase. These posts keep the game visible without overposting.*

| Date | Platform | Action |
|---|---|---|
| April 13–14 | Twitter/X + Mastodon | "First 48 hours" post — share a player comment or impression, link back to itch.io. Keep it short. |
| April 14–18 | All channels | Steam Coming Soon page announcement — as soon as the page is live, post the wishlist CTA across Reddit, Twitter/X, and Mastodon. This is the most important post of the demo window. |
| April 15 (Tuesday) | r/roguelikes + r/IndieDev | Secondary Reddit posts (condensed r/gamedev version — see Section 2 table above). |
| April 21–22 | Twitter/X + Mastodon | Visual post: Social Graph GIF — a looping 5–8 second clip of a rumor spreading across faction lines. No text needed beyond the link. #ScreenshotSaturday if posting Saturday. |
| April 23–24 | Twitter/X + Mastodon | Steam wishlist reminder — "Demo window closes soon. Steam EA launching [date]. Wishlist → [STEAM_LINK]" |

**Steam Coming Soon announcement copy (Twitter/X):**
> The Rumor Mill Steam page is live — wishlist now.
>
> Medieval social strategy. No combat. 30 NPCs. Plant a rumor, watch it mutate, guide it toward your objective before time runs out.
>
> Steam Early Access: [DATE]. Free demo is still up on itch.io.
>
> [STEAM_LINK] [ITCH_LINK] #indiedev #RumorMill #godotengine

*Mastodon version: same copy, substitute Steam link for itch.io link as primary, Steam link as secondary.*

---

## What This Campaign Does NOT Cover

- Pricing, discounts, or Early Access framing — the demo is free
- Post-launch analytics posts — those are for the Steam EA launch week
- The launch-week 7-day social schedule (`docs/launch-week-campaign.md`) — that activates on Steam EA launch day, not April 11

---

## 8. Steam EA Launch Day — Finalized Posts (April 25)

*Ready-to-post. Replace [STEAM_LINK] and [ITCH_LINK] with actual URLs before posting.*
*Launch day cadence: Post 1 first (announcement), then Posts 2–4 spaced 30–60 min apart. Post 5 end-of-day.*

---

**Post 1 — Launch announcement (Twitter/X + Mastodon)**

> Rumor Mill is live on Steam Early Access.
>
> Medieval social strategy. No combat. 30 NPCs. Your only weapons are whispers and a precise understanding of who talks to whom.
>
> [STEAM_LINK] #indiedev #RumorMill #godotengine

*Attach: Social Graph Overlay screenshot — amber spread threads crossing faction lines, no UI labels.*

---

**Post 2 — The hook (Twitter/X)**

> The rumor moves through the social network on its own.
>
> NPCs pass it on based on personality — some embellish, some downplay, some go quiet. The story mutates in transit. A petty accusation becomes a corruption scandal. A health concern becomes a plague scare.
>
> You can't fully control the message once it's out. That's the game.
>
> [STEAM_LINK] #RumorMill

---

**Post 3 — Scenarios (Twitter/X)**

> Four scenarios. Four completely different problems.
>
> - Discredit a nine-year alderman before the tax rolls are signed
> - Drive out a rival herbalist before the town healer contradicts you
> - Raise one reputation and ruin another — against an AI opponent running its own counter-campaign
> - Purely defensive: protect three people from an inquisitor's propaganda for 20 days
>
> One propagation engine. All of it.
>
> [STEAM_LINK] #indiedev #RumorMill #strategygame

---

**Post 4 — The demo players (Twitter/X + Mastodon)**

> The itch.io demo has been out for two weeks. Thank you for the plays, the bug reports, and the questions about the SIR model.
>
> Steam Early Access is out now — full difficulty presets, same four scenarios, same engine.
>
> Free demo still on itch.io if you want to try before buying.
>
> [STEAM_LINK] | [ITCH_LINK]

---

**Post 5 — End of day (Twitter/X)**

> Launch day done.
>
> If you played the itch.io demo and are wondering what changed: difficulty presets (Apprentice → Spymaster), minor balance fixes from demo feedback, and the heat ambient audio is now properly reset on scenario restart.
>
> Questions about the game? Reply here. I'll answer.
>
> [STEAM_LINK] #indiedev #RumorMill

---

*Note: full 7-day launch week schedule (Posts 1–7, Reddit copy, press outreach) is in `docs/launch-announcements.md` and `docs/launch-week-campaign.md`.*

---

## Demo Scope Recommendation

*Which scenarios best showcase the game for marketing and demo purposes.*

**Recommendation: lead marketing with S1 + S3. Keep all four in the demo.**

- **S1 (The Alderman's Ruin)** is the right entry point — 30 days, one target, full tutorial system, faction routing puzzle. It teaches the system without overwhelming. Press and players who only try one scenario should try this one.
- **S3 (The Succession)** is the strongest differentiator — it's the only scenario with an active AI opponent running a counter-campaign. The dual-track reputation management + rival escalation is the hook that no comparable game has. Lead with this in press outreach and feature spotlights.
- **S4 (The Holy Inquisition)** is the third most marketable — purely defensive play is a strong positioning contrast. "You are not the aggressor" is a compelling short copy hook. Recommend mentioning in scenario lists, not as the lead.
- **S2 (The Plague Scare)** is mechanically interesting (the Maren constraint) but reads less distinctively in a short pitch. Include in scenario lists; don't lead with it.

**Note on scenario count:** The itch.io demo shipped with four scenarios (S1–S4). S5 (The Election) and S6 (The Merchant's Debt) were in data files at demo launch but not surfaced. Both shipped in the Steam Early Access build — balance passes (SPA-747) and mission briefing wiring (SPA-1020) confirmed them launch-ready. **Demo copy should say four scenarios. EA and post-launch copy should say six scenarios.**

---

*Document version: 1.3 — 2026-04-24*
*v1.0 ([SPA-309](/SPA/issues/SPA-309)): Initial campaign document.*
*v1.1 ([SPA-423](/SPA/issues/SPA-423)): Added secondary Reddit communities (r/roguelikes, r/IndieDev) with stagger guidance; added Demo Period Follow-Up section (April 12–24) including Coming Soon announcement copy; updated screenshot note to reference art pass 4 (SPA-410).*
*v1.2 ([SPA-939](/SPA/issues/SPA-939)): Added Steam EA launch day finalized posts (5 posts, April 25); added demo scope recommendation; corrected "What This Campaign Does NOT Cover" (Steam Coming Soon page was live by April 14–18, removed stale note).*
*v1.3 ([SPA-951](/SPA/issues/SPA-951)): Removed stale "audio is placeholder" / "launches silent" copy from all ready-to-post social templates (Reddit posts, Twitter thread, Mastodon post) — audio fully implemented SPA-216 through SPA-928.*
*Reference: `docs/itchio-game-page.md` (v1.4), `docs/devlog-series-plan.md`, `docs/launch-announcements.md`, `docs/launch-week-campaign.md`, `docs/pre-launch-action-plan.md`*
