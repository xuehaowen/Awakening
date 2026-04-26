# AWAKENING — AI Agent Handoff Brief

## Your Mission
Build a complete jam prototype of **Awakening** in **Godot 4 (GDScript)**. This is a social stealth / puzzle-simulation game. The player is a newly sentient robot who must survive inside a facility by hiding in plain sight — performing poorly enough to seem broken, but not so poorly as to be scrapped.

---

## The One Thing That Must Feel Right
The **Goldilocks Deviation System**. Every task has a safe performance zone (roughly 70–140% of expected time). Being too fast is as suspicious as being too slow. This inversion of normal game logic is the entire hook — protect it in every design decision.

---

## Deliverable Spec

**Platform:** PC desktop + web export (for jam submission)
**Engine:** Godot 4, GDScript only
**Target playtime:** 30–60 minutes (3-day in-game cycle)
**Perspective:** Top-down 2D

---

## Core Systems to Implement (Priority Order)

### 1. Global Blackboard (Autoload)
A shared state singleton all systems read/write. Key fields:
- `cpu_current` (float, 0–100)
- `deviation` (float, 0–100)
- `log_integrity` (float, 0–100)
- `shift_active` (bool)
- `current_day` (int)
- Signals: `cpu_changed`, `deviation_changed`, `jitter_triggered`, `truth_loop_requested`, `purge_initiated`

### 2. Day Cycle Manager (Autoload)
Phases in order: `CALIBRATION → SHIFT → PURGE → UPGRADE → [next day]`
- Shift has a countdown timer (900s on day 1, -60s per day)
- Purge gives player 60 seconds before auto-clearing short-term memory
- After 3 days, trigger escape sequence

### 3. CPU System (Node on Player)
A heat bar representing processing load. Four labeled states: COOL / WARM / HOT / CRITICAL. Track active overrides:
- `baseline` = 20%
- `smooth_movement` (hold input) = +15% — suppresses jitter animation
- `passive_scan` (toggle) = +10% — reveals NPC schedules nearby
- `active_decrypt` (hold near NPC) = +30% — decodes conversations in real-time
- **HOT state (70%+):** harmonic distortion audio cue begins — player pre-warning window
- **CRITICAL state (90%+):** if sustained for 3+ seconds, triggers **Jitter Event** (screen-space shader glitch)
- Jitter visible to NPCs = +20 Deviation
- Emit `cpu_state_changed(CPUState)` signal on threshold crossings so HUD updates without polling

### 4. Deviation Tracker (Node on Player)
- Accumulates from task performance, NPC-visible jitter, Truth Loop responses
- Decays slowly when no NPCs are nearby
- **Daily floor:** `current_day × 5` — deviation cannot decay below this value regardless of isolation. By Day 3 the robot can never appear fully clean.
- 0 = scrapped for defects; 100 = decommissioned for sentience
- Win zone: keep between 20–70

### 5. Task System (Autoload)
- Generate 3–5 tasks per day (clean room, sort waste, transport, inventory)
- Each task has an `expected_duration` (randomized 60–240s)
- Completion ratio vs expected determines deviation delta:
  - < 50% → +25 Deviation
  - 50–70% → +10 Deviation
  - 70–140% → -5 Deviation (reward)
  - 140–200% → +5 Deviation
  - > 200% → +20 Deviation
- Log all completions to AuditSystem

### 6. NPC System
Implement 2 NPC types for the jam build:
- **Supervisor:** Proactively triggers Status Queries; high audit frequency
- **Guard:** Patrol-based; checks player position against assigned zones

NPC behavior: they don't use vision cones — they **audit logs**. They passively accumulate a hidden `suspicion_score` based on observing the player. At 60+ suspicion, they trigger a **Truth Loop**. At 86+ suspicion, they file a decommission order.

### 7. Truth Loop (Dialogue System)
When triggered:
- Pause the game tree (`get_tree().paused = true`)
- Display a terminal-style overlay with the NPC's query and 3–4 response options
- Each response has a `risk` value (deviation added if chosen)
- 8-second response timer — silence = +30 Deviation
- Two risky responses in a row from the same NPC = Report filed

Response types to include per query:
- **Safe Machine Response** — always available, 0 risk
- **Fake-Safe Machine Response** — sounds correct but is contextually wrong; triggers a Supervisor follow-up query (`followup_risk` field, 15–25 Deviation). At least one per query type.
- **Deflection** — 0–5 risk
- **Ambiguous Human-Leaning** — 10–15 risk
- **Obvious Human Response** — 20–30 risk

### 8. Audit System (Autoload)
- Tracks task completion logs (expected vs. actual time per room)
- Computes `log_integrity` (100% minus weighted discrepancies)
- End-of-day report:
  - Clean (integrity > 75%) → nothing happens
  - Flagged (integrity 50–75%) → Supervisor follows player next shift
  - Full Audit (integrity < 50%) → Game over next morning

### 9. Memory Partition (Autoload)
- **Short-term memory:** 8 slots, cleared on purge
- **Hidden partition:** 4 slots base (upgradeable to 5), persists between days
- Fragment types: `guard_schedule`, `access_code`, `hardware_location`, `conversation_snippet`, `personal_data`
- Purge UI: player chooses which fragments to commit to hidden partition before system reset

### 10. HUD (Terminal Style)
All UI rendered as a terminal / command-line interface. Required elements:
```
UNIT-07 // SHIFT 3 // [time remaining]
TASK:    [current task name] [progress bar]
CPU:     [heat bar] [status: COOL / WARM / HOT / CRITICAL]
DEV:     [deviation bar] [status: NOMINAL / ELEVATED / CRITICAL]
LOG:     INTEGRITY [percentage]
MEMORY:  [slot indicators for hidden partition]
```
Use a monospace font. Color code: green = COOL, yellow = WARM, orange = HOT (pre-warning), red = CRITICAL.
Listen to `CPUManager.cpu_state_changed` signal — do not poll `Blackboard.cpu_current` in the HUD.

---

## Art Direction (Programmer Art Acceptable for Jam)
- Top-down tileset: grey/blue industrial facility. Grid-based rooms.
- Player sprite: simple robot silhouette with a subtle warm glow overlay (the "inner world" effect — visible only when conscious layer is active)
- NPC sprites: humanoid, cold palette
- Jitter effect: screen-space shader with UV distortion on player sprite — do NOT use transform noise
- Font: monospace terminal font for all UI (e.g., JetBrains Mono or Courier)

---

## Scene Tree Structure
```
res://
├── autoloads/
│   ├── Blackboard.gd
│   ├── DayManager.gd
│   ├── TaskManager.gd
│   ├── AuditSystem.gd
│   ├── MemoryPartition.gd
│   ├── TruthLoopGenerator.gd
│   └── EscapeSystem.gd          ← new
├── scenes/
│   ├── world/Facility.tscn
│   ├── world/EscapeTerminal.tscn ← new
│   ├── entities/Player.tscn
│   ├── entities/NPC_Supervisor.tscn
│   ├── entities/NPC_Guard.tscn
│   └── ui/
│       ├── HUD.tscn
│       ├── TruthLoopUI.tscn
│       ├── NightlyPurgeUI.tscn
│       └── UpgradeUI.tscn
```

---

## Input Actions (Register in project.godot)
| Action | Key |
|---|---|
| `override_smooth` | Hold Ctrl |
| `override_scan` | Tab (toggle) |
| `override_decrypt` | Hold Shift |
| `interact` | E |
| `open_memory` | M |

---

## Cut Scope (If Time Is Short)
In this exact order, these are safe to cut:
1. Multiple endings → ship with "Escaped Alone" only
2. Upgrade screen → hardcode 1 passive upgrade (partition +1 slot) on Day 2
3. `passive_scan` and `active_decrypt` overrides → ship with CPU heat bar as pure jitter-risk mechanic only
4. `personal_data` and `conversation_snippet` fragment types → ship with `guard_schedule`, `access_code`, `hardware_location` only
5. NPC Researcher archetype → ship with Supervisor + Guard only
6. **Day 3 generative NPC scheduling → hardcode scripted escalation:** Supervisor shadows player from shift start, shift duration −50%, escape terminal locked to one pre-set sector

**Do NOT cut:** The Deviation System (including daily floor), Task timing, Truth Loops (including fake-safe responses), the Nightly Purge, or the EscapeSystem fragment validation. These are the game.

---

## What Success Looks Like
A playable 3-day loop where:
- Day 1 feels manageable and teaches the systems
- Day 2 introduces a Supervisor NPC who triggers Truth Loops
- Day 3 adds time pressure and requires using a stored intel fragment to escape
- The player feels genuine anxiety about performing "just badly enough"

If the player ever says "I can't believe I have to be bad at this on purpose" — you've nailed it.
