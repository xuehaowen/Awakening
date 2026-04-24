# AWAKENING — Master Improvement Plan

This document synthesizes design reviews from multiple perspectives (Codex's macro-design focus, Claude's technical/mathematical analysis, and pacing/synergy insights) into a cohesive, prioritized improvement plan for the Awakening game jam prototype.

---

## 🚨 Phase 1: Critical System Overhauls (Core Gameplay Loop)

### 1. Fix the "Goldilocks" Representation (The UI & Meter)
*   **The Problem:** Boiling "too fast" and "too slow" into a single rising Deviation meter ruins the "safe middle" fantasy. Furthermore, players have no idea what the "expected duration" of a task is, making calibration blind guesswork.
*   **The Fix:** 
    *   Change the Deviation UI to a **Centered Meter** (like a pitch/balance gauge) rather than an empty-to-full bar. The 20–70 "Safe Zone" should be a marked green band in the middle. Standardize the 20-70 range across all documentation.
    *   Add a **Pacing Indicator** to the task progress bar. Put a floating marker at the 140% "safe slow" line so the player sees a boundary approaching.

### 2. Give the Player Agency (Locomotion & Pacing)
*   **The Problem:** An auto-pathing bot where the player just toggles overrides feels like a dashboard, not a stealth game. Waiting up to 240 seconds for a task is incredibly boring.
*   **The Fix:**
    *   **Direct Control:** The player manually walks the robot. Base movement is clunky/grid-locked.
    *   **Synergize `smooth_movement`:** Holding the smooth movement override allows the player to move fluidly and fast (evading guards or rushing), but it burns CPU heat.
    *   **Shorten Tasks:** Reduce expected durations to 15–45 seconds to keep the pacing punchy.

### 3. Clarify NPC Detection (Observation vs. Logs)
*   **The Problem:** The design documents contradict themselves—stating NPCs only audit logs, but also accumulate suspicion in real-time by observing.
*   **The Fix:** Split detection cleanly.
    *   **Physical Proximity (Real-time):** A radius around the NPC. If you jitter, move too smoothly, or loiter with no active task inside this circle, suspicion spikes.
    *   **Log Auditing (End of Day):** The Audit System checks your route efficiency and task timings globally.

---

## 🟡 Phase 2: Preventing Player Frustration & Soft-locks

### 4. Mitigate the Truth Loop "Fake-Safe" Trap
*   **The Problem:** Punishing a player for picking a "machine-sounding" answer because it's contextually wrong feels unfair if they can't learn from it or detect it.
*   **The Fix:** 
    *   **Mechanic:** Let the player hold `active_decrypt` during the paused Truth Loop. It rapidly burns CPU heat but visually crosses out the Fake-Safe option.
    *   **Feedback:** If they fail and pick it anyway, have the Supervisor output `[CONTEXT_MISMATCH]` before the follow-up query so they learn the rule without feeling cheated.

### 5. Fix the Escape Sequence Soft-Locks
*   **The Problem:** A 3-slot memory capacity for a 3-item requirement leaves zero margin for error. Additionally, 2-day expiration means Day 1 intel is useless by Day 3.
*   **The Fix:** 
    *   Increase base partition slots to 4. 
    *   Add an "EXPIRES: DAY X" label to fragments in the UI. 
    *   Give narrative/lore fragments actual gameplay utility so they aren't dead weight—e.g., burning a narrative fragment gives you a hint about tomorrow's guard patrol or reduces suspicion.

### 6. Balance the CPU Heat
*   **The Problem:** Without `active_decrypt` (30%), it is mathematically impossible to trigger a critical Jitter event just by moving and scanning.
*   **The Fix:** Add an ambient CPU cost when inside an NPC's proximity radius (+5-10% "Curiosity/Anxiety"). This makes doing tasks near guards inherently riskier and makes the Jitter threat real without needing decrypt.

---

## 🟢 Phase 3: Jam Hygiene & Code Architecture

### 7. Simplify the Hidden Scoring Layers
*   **The Problem:** Deviation, CPU, log integrity, suspicion, and audit flags overlap conceptually and will confuse players (and the developer during a game jam).
*   **The Fix:** Consolidate. Let Deviation handle moment-to-moment actions (speed, jitter). Let the Audit Log strictly handle macro-positioning (where you went).

### 8. Scope & Math Corrections
*   **Narrative & Scope:** Lock everything to a strict 3-Day cycle. Condense the narrative beats to fit Day 1 (Setup), Day 2 (Suspicion), Day 3 (Escape). Cut the extra NPC types.
*   **The Day 1 Floor:** Change the Deviation floor formula from `day * 5` to `max(day * 5, 15)` so Day 1 doesn't hover right over the death state (0).
*   **The Shift Timer:** Fix the tech spec formula to `900.0 - ((Blackboard.current_day - 1) * 60.0)` so Day 1 actually equals 900s.
*   **Architecture Strictness:** Enforce single-system ownership. Don't let every script write to the Blackboard directly. Have a dedicated `TaskScorer` and `SuspicionManager` that own their respective logic to prevent spaghetti bugs in the final hours of the jam.
