# Phase 2 Baseline Archive — S1–S4 Post-Fix Summary (SPA-1761)

**Generated:** 2026-05-05  
**Fixes applied:** SPA-1755 (Master cooldown 3→2), SPA-1756 (Witness Account bypass at ½ effect), SPA-1757 (Apprentice v2 bonus gating)  
**evidence_economy_v2:** enabled for all runs  

**Source files:**
- `playthrough_s1_apprentice_post1757.ndjson` — S1, Apprentice, 8 days, WON
- `playthrough_s1_normal_post_phase2.ndjson` — S1, Normal, 9 days, WON
- `playthrough_s2_normal_post_phase2.ndjson` — S2, Normal, 9 days, WON
- `playthrough_s3_normal_post_phase2.ndjson` — S3, Normal, 22 days, WON
- `playthrough_s4_normal_post_phase2.ndjson` — S4, Normal, 20 days, WON

---

## 1. Run Summary Table

| Scenario | Difficulty | Days Used | Evidence Acquired | Evidence Used | Hoarding Ratio | Cooldown Blocks | Bypass Uses | Win/Loss |
|----------|------------|-----------|-------------------|---------------|----------------|-----------------|-------------|----------|
| S1       | Apprentice | 8         | 5                 | 3             | **0.60**       | 0 (disabled)    | 0           | WON      |
| S1       | Normal     | 9         | 5                 | 4             | **0.80**       | 0               | 1           | WON      |
| S2       | Normal     | 9         | 5                 | 4             | **0.80**       | 0               | 1           | WON      |
| S3       | Normal     | 22        | 8                 | 6             | **0.75**       | 0               | 1           | WON      |
| S4       | Normal     | 20        | 6                 | 6             | **1.00**       | 0               | 1           | WON      |

---

## 2. SPA-1757 Apprentice Bonus Gating Verification

**S1 Apprentice** confirms the gating is in effect:

| Event Type                         | S1 Apprentice (post-1757) | Expected |
|------------------------------------|---------------------------|----------|
| `evidence_shelf_life_extended`     | 0 fires                   | 0 ✅     |
| `evidence_credulity_boost_applied` | 0 fires                   | 0 ✅     |
| `evidence_target_cooldown_start`   | 0 fires                   | 0 ✅     |
| `evidence_used`                    | 3 fires                   | >0 ✅    |

The base `believability_bonus` and `mutability_modifier` still apply (evidence is usable on Apprentice), but the v2 mechanics (shelf extension, credulity boost, target-shift cooldown) are fully absent. The run proceeds efficiently at 8 days — consistent with the pre-1757 S1 Apprentice baseline — confirming the gating does not degrade Apprentice playability.

---

## 3. SPA-1756 Witness Account Bypass Verification

Each Normal run demonstrated one bypass activation. Bypass fires when `is_evidence_bypass_active()` is true (active target-shift cooldown on a different NPC + evidence item supports bypass).

| Scenario | Difficulty | Bypass Day | Cooled NPC       | Bypass Target    | Credulity Boost (½) | Shelf Extended |
|----------|------------|------------|------------------|------------------|---------------------|----------------|
| S1       | Normal     | 4          | sybil_oats       | aldric_vane      | 0.025 (vs 0.05)     | +80 ticks      |
| S2       | Normal     | 4          | alys_herbwife    | miller_wife      | 0.025 (vs 0.05)     | +80 ticks      |
| S3       | Normal     | 4          | sybil_oats       | aldric_vane      | 0.025 (vs 0.05)     | +80 ticks      |
| S4       | Normal     | 4          | maren_nun        | constance_widow  | 0.025 (vs 0.05)     | +80 ticks      |

**Observation:** In every Normal run the bypass fires naturally on day 4, when the 2-day cooldown from a day-3 evidence use is still active (1 day remaining). The player uses Witness Account rather than skipping the day or seeding without evidence — confirming the bypass mechanic fills the intended "don't waste the window" role. No hard blocks observed in any Normal run.

---

## 4. Evidence Economy v2 Event Coverage

All required Phase 2 telemetry events verified across Normal runs (S1–S4 Normal):

| Event Type                         | S1 Normal | S2 Normal | S3 Normal | S4 Normal | Status |
|------------------------------------|-----------|-----------|-----------|-----------|--------|
| `evidence_acquired`                | 5 fires   | 5 fires   | 8 fires   | 6 fires   | ✅ PASS |
| `evidence_used`                    | 4 fires   | 4 fires   | 6 fires   | 6 fires   | ✅ PASS |
| `evidence_shelf_life_extended`     | 4 fires   | 4 fires   | 6 fires   | 6 fires   | ✅ PASS |
| `evidence_credulity_boost_applied` | 4 fires   | 4 fires   | 6 fires   | 6 fires   | ✅ PASS |
| `evidence_target_cooldown_start`   | 4 fires   | 4 fires   | 6 fires   | 6 fires   | ✅ PASS |
| `evidence_target_cooldown_active`  | 3 fires   | 3 fires   | 2 fires   | 2 fires   | ✅ PASS |
| `evidence_target_cooldown_blocked` | 0         | 0         | 0         | 0         | ✅ OK  |
| `bypass_active: true` on used      | 1 fire    | 1 fire    | 1 fire    | 1 fire    | ✅ PASS |
| `scenario_ended`                   | 1 (WON)   | 1 (WON)   | 1 (WON)   | 1 (WON)   | ✅ PASS |

---

## 5. Hoarding Ratio by Evidence Type (Normal runs, all scenarios)

| Evidence Type           | Acquired | Used | Usage Rate |
|------------------------|----------|------|------------|
| witness_account        | 10       | 9    | 90%        |
| forged_document        | 9        | 8    | 89%        |
| incriminating_artifact | 5        | 4    | 80%        |

Witness Account's high usage rate (90%) directly reflects the bypass mechanic — players use it even during active cooldowns rather than letting it sit in inventory. Pre-SPA-1756, this item was the weakest performer (57% usage in the pre-fix baseline); the bypass has closed that gap significantly.

---

## 6. S2 Normal — Sister Maren Proximity Interaction

Sister Maren issued REJECT state on both rumors targeting Sister Merewyn (s2n_sca01 day 2, s2n_acc01 day 4). Evidence use did not directly counter the REJECT — evidence boosts believability at rumor creation time, not during NPC state transitions. The player compensated by spreading to additional witnesses (miller_wife, fishwife) rather than attempting to convert Sister Maren directly.

**Conclusion:** Evidence economy v2 interacts correctly with the proximity-REJECT mechanic. No anomaly.

---

## 7. S4 Normal — Cooldown Pressure Over Extended Play

S4 is the longest run at 20 days with 6 evidence uses across 5 distinct seed targets. The 2-day Normal cooldown created 2 `evidence_target_cooldown_active` events (days 4 and 14) but no hard blocks. One bypass was used (day 4). Evidence items held in inventory for extended periods (forged_document acquired day 7, used day 16 = 9-day hold) did not cause shelf-life failures thanks to the +40 shelf extension.

**Observation:** The 2-day Normal cooldown is appropriately balanced for S4's 20-day scope. Players cycle targets naturally every 2-3 days without feeling locked out. The extended shelf-life from evidence_economy_v2 is essential for long holds — removing it (pre-v2) would likely cause decay failures by day 12+.

---

## 8. Anomaly Check

| Metric                                  | S1 Apprentice | S1 Normal | S2 Normal | S3 Normal | S4 Normal | Flag Threshold |
|-----------------------------------------|---------------|-----------|-----------|-----------|-----------|----------------|
| Hoarding ratio (used/acquired)          | 0.60          | 0.80      | 0.80      | 0.75      | 1.00      | < 0.50 ⚠️    |
| Cooldown blocking (blocked days / total)| 0% (disabled) | 0%        | 0%        | 0%        | 0%        | > 30% ⚠️     |
| Trivial win (day reached < 10)          | ⚠️ day 8     | ⚠️ day 9  | ⚠️ day 9  | day 22    | day 20    | < day 10 ⚠️  |

**ANOMALY-04 (LOW): S1 and S2 Normal win before day 10**

S1 Normal ends day 9, S2 Normal ends day 9. Both fall below the day-10 trivial-win threshold. However, this matches the pre-Phase-2 phase1 baselines for these scenarios (S1 Normal: 9 days, S2 Normal: 9 days) — these are the shorter early scenarios by design. The evidence_economy_v2 mechanics did not accelerate wins; run length is unchanged from phase1.

**Verdict:** Not a balance regression. The day-10 threshold is not meaningful for S1/S2 — consider raising the threshold check to S3+.

**No hoarding or cooldown-block anomalies observed.** All Normal runs show hoarding ratio ≥ 0.75, well above the 0.50 threshold. The SPA-1756 bypass mechanic is the primary driver — zero items were lost to cooldown lock-out in any Normal run.
