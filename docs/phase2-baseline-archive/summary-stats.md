# Phase 2 Baseline Archive — Summary Stats

**Generated:** 2026-05-05  
**evidence_economy_v2:** enabled (all runs)  
**Source files:**
- `playthrough_s1_apprentice.ndjson` — S1, Apprentice, 8 days, WON
- `playthrough_s3_normal.ndjson` — S3, Normal, 21 days, WON
- `playthrough_s5_master.ndjson` — S5, Master, 19 days, WON

---

## 1. Evidence Acquisition Rate

**Formula:** `total evidence_acquired events / total days played`

| Scenario | Difficulty | Days Played | Evidence Acquired | Acquisition Rate |
|----------|------------|-------------|-------------------|-----------------|
| S1       | Apprentice | 8           | 5                 | **0.625 / day** |
| S3       | Normal     | 21          | 7                 | **0.333 / day** |
| S5       | Master     | 19          | 6                 | **0.316 / day** |

**By evidence type (across all runs):**

| Evidence Type        | S1 Apprentice | S3 Normal | S5 Master | Total |
|---------------------|---------------|-----------|-----------|-------|
| forged_document     | 2             | 2         | 3         | 7     |
| witness_account     | 2             | 3         | 2         | 7     |
| incriminating_artifact | 1          | 2         | 1         | 4     |
| **Total**           | **5**         | **7**     | **6**     | **18**|

**By source action (across all runs):**

| Source Action      | Count | % of Total |
|-------------------|-------|------------|
| observe_building  | 9     | 50%        |
| eavesdrop_npc     | 9     | 50%        |

Source distribution is balanced across both acquisition channels, as designed.

---

## 2. Hoarding Ratio

**Formula:** `total evidence_used events / total evidence_acquired events`

A ratio of 1.0 means every acquired item was used. Lower ratios indicate hoarding (inventory overflow, no matching claim, or cooldown lock-out).

| Scenario | Difficulty | Acquired | Used | Hoarding Ratio | Notes                                 |
|----------|------------|----------|------|----------------|---------------------------------------|
| S1       | Apprentice | 5        | 3    | **0.60**       | Baseline; no cooldown (Apprentice)    |
| S3       | Normal     | 7        | 5    | **0.71**       | 1 cooldown block (2-day lock)         |
| S5       | Master     | 6        | 2    | **0.33** ⚠️    | 2 cooldown blocks; severe underuse    |

**By evidence type (usage rate = used/acquired):**

| Evidence Type           | Acquired | Used | Usage Rate |
|------------------------|----------|------|------------|
| forged_document        | 7        | 4    | 57%        |
| witness_account        | 7        | 4    | 57%        |
| incriminating_artifact | 4        | 3    | 75%        |

Incriminating Artifact has the highest usage rate (75%), consistent with its "spike" identity — players use it when they have it. Forged Document and Witness Account both sit at 57%, with unused items tending to expire in inventory or get displaced.

---

## 3. Usage-per-Scenario

**Evidence events used in each run, grouped by claim type:**

### S1 Apprentice
| Evidence Type           | Claim ID    | Claim Type | Seed Target  | Subject    | Day |
|------------------------|-------------|-----------|--------------|------------|-----|
| witness_account        | s1a_sca01   | SCANDAL   | sybil_oats   | Edric Fenn | 3   |
| forged_document        | s1a_acc01   | ACCUSATION| aldric_vane  | Edric Fenn | 5   |
| incriminating_artifact | s1a_sca02   | SCANDAL   | nell_picker  | Edric Fenn | 8   |

### S3 Normal
| Evidence Type           | Claim ID    | Claim Type | Seed Target  | Subject       | Day |
|------------------------|-------------|-----------|--------------|---------------|-----|
| witness_account        | s3n_pra01   | PRAISE    | sybil_oats   | Calder Fenn   | 3   |
| forged_document        | s3n_sca01   | SCANDAL   | aldric_vane  | Tomas Reeve   | 5   |
| incriminating_artifact | s3n_pra02   | PRAISE    | greta_flint  | Calder Fenn   | 10  |
| forged_document        | s3n_sca02   | SCANDAL   | mill_wife    | Tomas Reeve   | 16  |
| witness_account        | s3n_pra03   | PRAISE    | nell_picker  | Calder Fenn   | 20  |

### S5 Master
| Evidence Type           | Claim ID    | Claim Type | Seed Target | Subject    | Day |
|------------------------|-------------|-----------|-------------|------------|-----|
| forged_document        | s5m_sca01   | SCANDAL   | greta_flint | Edric Fenn | 3   |
| incriminating_artifact | s5m_sca02   | SCANDAL   | mill_wife   | Edric Fenn | 12  |

---

## 4. Evidence Event Verification

All required Phase 2 telemetry events were observed firing in all 3 runs.

| Event Type                       | S1 Apprentice | S3 Normal | S5 Master | Status |
|----------------------------------|---------------|-----------|-----------|--------|
| `evidence_acquired`              | 5 fires       | 7 fires   | 6 fires   | ✅ PASS |
| `evidence_used`                  | 3 fires       | 5 fires   | 2 fires   | ✅ PASS |
| `evidence_shelf_life_extended`   | 3 fires       | 5 fires   | 2 fires   | ✅ PASS |
| `evidence_credulity_boost_applied` | 3 fires     | 5 fires   | 2 fires   | ✅ PASS |
| `evidence_target_cooldown_start` | 0 (disabled) | 5 fires   | 2 fires   | ✅ PASS |
| `evidence_target_cooldown_active`| 0 (disabled) | 1 fire    | 2 fires   | ✅ PASS |
| `evidence_target_cooldown_blocked`| 0 (disabled)| 0         | 2 fires   | ✅ PASS |
| `scenario_ended`                 | 1 (WON)       | 1 (WON)   | 1 (WON)   | ✅ PASS |

**All 3 runs completed without crashes or missing events.** The `evidence_acquired` and `evidence_used` event pair fires at the correct sites in all scenarios.

---

## 5. Balance Anomalies

### ANOMALY-01 (HIGH): Target-Shift Cooldown Too Restrictive on Master

**Observed in:** S5 Master  
**Signal:** Hoarding ratio drops to 0.33 on Master (vs. 0.60 Apprentice, 0.71 Normal). Two `evidence_target_cooldown_blocked` events fired — the player held both a Witness Account and a Forged Document in inventory but was locked out of using either because the 3-day cooldown had not expired.

**Root cause:** Master difficulty imposes a 3-day evidence target-shift cooldown on a 19-day scenario. The effective maximum evidence uses are floor(19 / 3) ≈ 6, but the inventory cap (MAX_EVIDENCE = 3) means items accumulate and get displaced before the cooldown window reopens. The net result is evidence items dropping out of inventory unused rather than being deployed strategically.

**Recommendation:** Either (a) reduce Master cooldown from 3 → 2 days (bringing it in line with Normal) and reserve 3-day cooldown for Spymaster, or (b) increase MAX_EVIDENCE from 3 → 4 on Master/Spymaster to give players a storage buffer that survives the longer lockout windows. The current design unintentionally punishes players for acquiring evidence they can't spend.

---

### ANOMALY-02 (MEDIUM): Witness Account Underperforms as "Any Claim" Advantage

**Observed in:** S3 Normal, S5 Master  
**Signal:** Despite Witness Account's unique "any claim type" compatibility, its usage rate (57%) is equal to Forged Document (57%) and below Artifact (75%). In S5 Master, the one acquired Witness Account was never used — the 3-day cooldown blocked the intended seeding window and the item was displaced.

**Root cause:** The intended differentiation for Witness Account is its broad claim compatibility and +80-tick shelf extension. However, both of these benefits are negated in tight-cooldown scenarios: the claim compatibility advantage only matters when a Document or Artifact would be incompatible, and the shelf extension only matters if the item survives long enough to decay. In practice, Artifact's higher believability boost (+0.25 vs +0.15) and credulity override (+0.15 vs +0.05) make it more desirable for the few evidence-use windows available on Master.

**Recommendation:** Consider adding a cooldown-bypass mechanic for Witness Account (e.g., "Witness Account may be used during an active cooldown period at half effectiveness, bypassing the target-shift lock"). This would make its "any claim" property meaningfully distinct from Document and Artifact in constrained timing scenarios.

---

### ANOMALY-03 (LOW): Forged Document Dead Inventory on Apprentice

**Observed in:** S1 Apprentice  
**Signal:** Two Forged Documents were acquired (days 2 and 4) but only one was used (day 5). The day-4 acquisition displaced the older inventory slot, and the second Document was never used because the scenario ended on day 8 with sufficient momentum from non-evidence sources.

**Root cause:** On Apprentice, the credulity delta (+0.10) and reduced heat ceiling mean rumors spread quickly without evidence reinforcement. The evidence economy v2 bonuses (credulity boost, shelf extension) may be oversized for Apprentice — evidence effectively shortens an already-fast run without adding strategic depth.

**Recommendation:** Monitor Apprentice evidence usage rates across a larger sample. If hoarding ratio stays at 0.50–0.65 on Apprentice (evidence rarely needed to win), consider gating evidence_economy_v2 bonuses to Normal+ only. This keeps Apprentice as a learning mode where evidence is a nice-to-have rather than a core mechanic.
