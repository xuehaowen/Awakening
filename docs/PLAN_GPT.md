# Awakening Jam Rework Plan

## Summary
This plan merges the three reviews into one direction: keep the Goldilocks “perform a C-grade” hook, but redesign the jam build around fairness, player agency, and scope discipline.

Consensus across the reviews:
- The core hook is excellent and should stay central.
- The current design risks boredom, hidden-rule frustration, and overloaded systems.
- The jam build should be simplified immediately, not later.

Added from my review:
- The player needs direct moment-to-moment agency; the game should not feel like watching an autopilot and managing meters.
- The two failure directions must be readable in play, not just described in docs.

## Key Design Changes
- Make movement player-controlled by default. Remove bot-autopilot as the main play model; keep task assignment, routing hints, and machine-style movement constraints, but the player manually chooses path, speed, and stalling behavior.
- Keep a single `deviation` meter for the jam build, but make it explicitly two-sided: `0 = defective`, `100 = sentient`, `safe band = 20–70`, `low warning = 0–20`, `high warning = 70–100`. Canonicalize these values in all docs.
- Set the Day 1 deviation floor to `15`, then rise by day: `15 / 20 / 25`. Do not allow the player to drift near zero just by playing “well.”
- Shorten task expected durations to `15–45s`. Each task must be finishable quickly, and the tension comes from pacing it into the safe band rather than waiting for minutes.
- Add “active waiting” actions during task pacing: `scan`, `decrypt`, `peek at logs`, `hover near optional intel nodes`. These actions are the intended way to spend stall time and should create CPU risk or route risk.
- Surface task pacing clearly in the HUD. Show `elapsed time` plus a visible safe band on the task bar with markers at `70%` and `140%` of expected duration. Do not make the player guess the core mechanic.
- Add immediate reason feedback whenever deviation changes. Use short HUD messages such as `TOO FAST +12`, `SAFE PACING -5`, `JITTER SEEN +20`, `LOW DEVIATION WARNING`.
- Redefine `smooth_movement`: default movement is safe but clunky/grid-like; holding smooth movement grants faster, finer control and easier escape/path correction, but increases CPU and is more suspicious if used near observers.
- Split NPC detection into two clean channels. `Observation` is real-time and radius-based via a simple `Area2D`; it only reacts to visible physical tells such as jitter, smooth/human-like movement, proximity loitering, or being in the wrong zone. `Log auditing` is end-of-shift and reacts to task timing, room dwell time, and sector mismatches. NPCs do not “see” internal CPU values directly.
- Keep only two NPC types for the jam build: `Supervisor` and `Guard`. Cut `Researcher` from v1.
- Keep only three fragment types for the jam build: `access_code`, `hardware_location`, `guard_schedule`. Cut `personal_data` and `conversation_snippet` from the core loop; reintroduce later if time remains.
- Simplify escape setup so it is solvable without retroactive guesswork. Reveal the likely escape sector by the end of Day 1 through discoverable intel. Increase base hidden partition capacity to `4`.
- Remove guard-schedule expiration from the jam build. Do not let the only valid escape path quietly expire in a 3-day run.
- Add a purge-screen chain indicator such as `SECTOR 4 CHAIN: 2/3` so players can make informed keep/discard choices.
- Rework Truth Loops to be learnable. During a Truth Loop, holding `decrypt` keeps the response timer running, adds the normal decrypt CPU load, and after a short scan reveals the fake-safe option if one exists. If the player still picks a fake-safe answer against a Supervisor, show a brief `CONTEXT_MISMATCH` cue before the follow-up query.
- Clarify system overlap: `deviation` tracks how convincingly the player performs; `audit/log integrity` tracks where they went and whether their recorded behavior matches assignment. Do not double-punish the same action unless the design intentionally surfaces both consequences.
- Fix doc/spec inconsistencies now: Day count is `3`, shift duration is `900 / 840 / 780`, narrative beats are compressed to those 3 days, and all system values match across README, GDD, handoff, and tech spec.

## Interface / System Contract Changes
- `Task` data must expose `expected_duration`, `safe_start = 0.7x`, `safe_end = 1.4x`, `elapsed_time`, and a UI-readable `pace_state`.
- `NPC` data must use explicit observation config: `observe_radius`, `zone_checking`, and `audit_role`; remove any implication that NPCs read raw CPU state.
- `TruthLoop` must support a scan state during dialogue: `decrypt_active`, `fake_safe_revealed`, and `followup_triggered`.
- `MemoryFragment` must at minimum carry `type`, `sector`, and `chain_progress`-compatible metadata so purge UI can show chain matching.

## Test Plan
- Task pacing: a player who rushes, stalls, and lands inside the safe band gets clearly different outcomes, and each outcome is explained on-screen.
- Active waiting: while delaying task completion, the player can gather intel or scan, and that time feels risky rather than empty.
- Low-end failure: a player who behaves too perfectly trends toward defective danger and gets a clear low-deviation warning before losing.
- Truth Loop fairness: fake-safe answers are punishers only if the player ignores available signals; decrypt scanning provides a real tradeoff, not a free answer.
- NPC readability: entering an observer radius and jittering causes immediate suspicion; task timing alone affects logs later, not instant magical detection.
- Escape solvability: by the end of Day 1 the player can infer the target sector, can carry enough fragments to recover from one imperfect choice, and can see chain progress during purge.
- Scope fit: one full run with 3 days, 2 NPC types, 3 fragment types, and 1 normal plus 1 risky escape ending fits the jam target and teaches all core systems by Day 2.

## Assumptions
- Target remains `Godot 4 + GDScript`, `PC + Web`, and a `3-day` jam prototype.
- The jam build prioritizes a strong single ending path plus one risky fallback, not multiple narrative endings.
- Any mechanic that is interesting on paper but not necessary to teach the Goldilocks loop is cut from v1.
- If implementation time gets tight, preserve in this order: task pacing UI, direct movement, truth-loop fairness, purge/escape chain, then audit polish.
