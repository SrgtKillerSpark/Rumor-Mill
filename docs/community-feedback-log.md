# Rumor Mill — Community Feedback Log

*Intake doc for player feedback against scenario/system tags. Fed into weekly updates and balance work ([SPA-1413](/SPA/issues/SPA-1413)).*
*Monitoring cadence and routing rules: `docs/community-feedback-plan.md`.*

---

## How to Use This Log

1. Add an entry per piece of actionable feedback (one row = one report).
2. Tag with **Type** and **Tag** from the tables below.
3. Update **Status** as the item progresses.
4. Each week, pull "Most common question" and "Most common complaint" from this doc for the weekly update (`docs/weekly-update-template.md` Section 3).
5. After Day 7, log only `CRASH`, `BUG`, and `BALANCE` entries (per `docs/community-feedback-plan.md`).

---

## Type Reference

| Type | When to use |
|------|-------------|
| `CRASH` | Game-ending crash, reproduction unknown |
| `BUG` | Reproducible defect; not crash-level |
| `BALANCE` | Difficulty, timing, or probability complaint |
| `UX` | Confusion, discoverability, or tutorial gap |
| `FEATURE` | Player-requested addition |
| `POSITIVE` | Specific praise that reveals what landed (skip generic) |
| `QUESTION` | Question answered publicly or noted |

## Status Reference

| Status | Meaning |
|--------|---------|
| `new` | Logged, not yet reviewed |
| `acknowledged` | Publicly acknowledged or noted |
| `in_progress` | Fix or response actively in work |
| `patched` | Fixed in a shipped build |
| `wontfix` | Not going to change; reason noted |
| `monitoring` | Watching for more reports before acting |

## Scenario / System Tags

| Tag | Scope |
|-----|-------|
| `s1` | Scenario 1 — The Alderman's Ruin |
| `s2` | Scenario 2 — The Plague Scare |
| `s3` | Scenario 3 — The Succession |
| `s4` | Scenario 4 — The Holy Inquisition |
| `propagation` | Rumor propagation engine (spread, mutation, target-shift) |
| `intel` | Intel system (eavesdrop, observe, evidence items) |
| `social-graph` | Social graph overlay |
| `journal` | Player journal |
| `heat` | Player heat system |
| `tutorial` | Tutorial / onboarding |
| `save-load` | Save/load system |
| `audio` | Audio (currently placeholder) |
| `ui` | General UI/UX not covered by other tags |
| `analytics` | Telemetry / post-scenario analytics screen |
| `accessibility` | Colorblind, font, keyboard nav |
| `perf` | Performance / framerate |
| `general` | Cross-cutting or untagged |

---

## Log

*Format: Date | Platform | Type | Tag | Summary | Status | Notes*

### Bugs

| Date | Platform | Type | Tag | Summary | Status | Notes |
|------|----------|------|-----|---------|--------|-------|
| | | | | | | |

### Balance

| Date | Platform | Type | Tag | Summary | Status | Notes |
|------|----------|------|-----|---------|--------|-------|
| | | | | | | |

### UX / Questions

| Date | Platform | Type | Tag | Summary | Status | Notes |
|------|----------|------|-----|---------|--------|-------|
| | | | | | | |

### Feature Requests

| Date | Platform | Type | Tag | Summary | Status | Count | Notes |
|------|----------|------|-----|---------|--------|-------|-------|
| | | | | | | | |

### Positive (Signal Only)

| Date | Platform | Type | Tag | Summary | Notes |
|------|----------|------|-----|---------|-------|
| | | | | | |

---

## Recurring Complaint Tracker

*When the same complaint appears 3+ times independently, move it here. These are candidates for Phase 1 action or public response.*

| Complaint | Count | Type | Tag | Status | Public response posted? |
|-----------|-------|------|-----|--------|------------------------|
| Audio silence | — | BALANCE | `audio` | `in_progress` | No — address in Week 1 update |
| Target-shift feels uncontrollable | — | BALANCE | `propagation` | `monitoring` | No — standard response ready in template |

---

## Feature Request Tracker

*Requests that appear 5+ times get added to `docs/early-access-roadmap.md` backlog explicitly.*

| Feature | Count | Tag | Roadmap? | Notes |
|---------|-------|-----|----------|-------|
| | | | | |

---

*Document version: 1.0 — 2026-04-30*
*Task: [SPA-1414](/SPA/issues/SPA-1414)*
*Feeds: `docs/weekly-update-template.md`, [SPA-1413](/SPA/issues/SPA-1413) balance work*
*Reference: `docs/community-feedback-plan.md`, `docs/early-access-roadmap.md`*
