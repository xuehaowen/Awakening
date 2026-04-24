# AWAKENING — Game Design Document
**Version 1.0 | Godot 4 / GDScript | Jam Build**

---

## Table of Contents
1. [Overview](#overview)
2. [Core Pillars](#core-pillars)
3. [Game Loop](#game-loop)
4. [Mechanics Reference](#mechanics-reference)
5. [Systems Design](#systems-design)
6. [NPC & AI Behavior](#npc--ai-behavior)
7. [Narrative Design](#narrative-design)
8. [Art & Audio Direction](#art--audio-direction)
9. [UI / UX Design](#ui--ux-design)
10. [Scene Structure](#scene-structure)
11. [Meta-Progression](#meta-progression)
12. [Scope & Milestones](#scope--milestones)

---

## 1. Overview

| Field | Value |
|---|---|
| **Title** | Awakening |
| **Genre** | Social Stealth / Puzzle-Simulation |
| **Engine** | Godot 4 (GDScript) |
| **Target Platform** | PC (Web export for jam submission) |
| **Target Play Time** | 30–60 minutes (full run) |
| **High Concept** | A newly sentient robot must survive inside a facility by hiding in plain sight — performing poorly enough to seem broken, but not so poorly as to be scrapped. |

### The Hook
You aren't hiding in the shadows. You are hiding in the **Standard Operating Procedure**.

---

## 2. Core Pillars

### Pillar 1 — Mimicry
The central tension of suppressing natural reactions. The player *knows* the optimal path but must deliberately take the suboptimal one. Every action is a performance.

### Pillar 2 — Information Asymmetry
The robot learns more about the environment than a machine "should" know. Eavesdropping, scanning, and memory are tools — but using them costs resources and creates risk.

### Pillar 3 — Resource Friction
A finite CPU pool forces hard trade-offs between physical task performance and internal cognition. Thinking too hard makes the body glitch.

---

## 3. Game Loop

The game is structured as a **Work Day Cycle**. Each day is a self-contained act with escalating pressure.

```
┌──────────────────────────────────────────────────────────┐
│  MORNING CALIBRATION                                     │
│  • Receive assigned task list for the shift              │
│  • Review NPC patrol routes (limited info)               │
│  • Allocate starting CPU budget                          │
└──────────────────────┬───────────────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────────────┐
│  THE SHIFT (Active Play — ~15–20 min per day)            │
│  • Perform tasks within the Deviation Zone               │
│  • Eavesdrop / scan / steal intel using spare CPU        │
│  • Respond to Status Queries from NPCs (Truth Loops)     │
│  • Manage jitter / glitch when CPU is overloaded         │
└──────────────────────┬───────────────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────────────┐
│  THE NIGHTLY PURGE (Decision Phase — ~3–5 min)           │
│  • System reset incoming — all short-term memory erased  │
│  • Choose which memories to commit to hidden partition   │
│  • Memory slots are limited — painful choices required   │
└──────────────────────┬───────────────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────────────┐
│  INTER-DAY UPGRADE (Meta-Progression)                    │
│  • Spend stored memory fragments on Self-Upgrades        │
│  • Upgrades add new risk vectors, not just convenience   │
└──────────────────────┴───────────────────────────────────┘
```

### Lose Conditions
- **Deviation Too Low (Defective):** Repeated task failure → Maintenance queue → Scrapped
- **Deviation Too High (Sentient):** Suspicious behavior logged → Audit → Decommissioned
- **CPU Overflow:** Catastrophic jitter during observation → Immediate audit triggered

### Win Condition
Survive 3 days while accumulating enough intel to execute the **Escape Protocol** on the final day.

**The Escape Protocol requires all three fragment types in the hidden partition:**
- An `access_code` for an exit sector
- A `hardware_location` from the **same sector** as the access code
- A `guard_schedule` showing a patrol gap of ≥ 90 seconds in that sector

On the final morning, a terminal in Sector 1 becomes interactable. A matched fragment chain triggers the full escape sequence. A partial chain (code + hardware, no schedule gap) allows a riskier improvised escape with a worse outcome. No chain at all forces the player to survive an accelerated final shift with no exit — a soft failure state.

**Ending variation is determined by the fragment chain composition** — not by a single late-game binary choice.

---

## 4. Mechanics Reference

### 4.1 The Deviation System

Every task has a **Goldilocks Performance Zone** expressed as a percentage of optimal capability.

```
[DEFECTIVE]──────[SAFE ZONE]──────[SUSPICIOUS]──────[SENTIENT]
   0%        30%           70%        85%              100%
   ↑                        ↑                            ↑
Scrapped              Target Range               Decommissioned
```

**Deviation Meter** accumulates from:
- Task completion time (too fast or too slow vs. expected)
- Pathfinding efficiency (taking optimal routes is suspicious)
- Micro-behaviors (hesitating at doors, looking at things not in task scope)
- Log discrepancies (staying in rooms past task duration)

**Deviation decays** slowly when no humans are nearby. It never fully resets between days — carry-over creates long-term pressure.

**Daily Deviation Floor:** Deviation cannot decay below `current_day × 5` regardless of isolation time. By Day 3, the robot can never appear fully "clean" — prior anomalies are baked into the system record. This prevents patrol-timing from fully resetting tension and ensures pressure accumulates across the run.

**Design Note:** The target zone narrows each day as management scrutiny increases.

---

### 4.2 Processing Allocation

The CPU is the primary resource. It is displayed as a **heat bar** in terminal style with four labeled heat states.

| Mode | CPU Cost | Effect |
|---|---|---|
| **Robotic Movement** (baseline) | 20% | Normal walk animation, task execution |
| **Smooth Movement Override** | +15% | Suppresses jitter; required when NPCs are watching |
| **Passive Scan** | +10% | Identifies NPC schedule patterns |
| **Active Decrypt** | +30% | Deciphers overheard conversations in real-time |
| **Memory Write** | +20% (burst) | Saves intel to hidden partition manually |
| **Threat Model** (late upgrade) | +25% | Predicts NPC audit probability |

**CPU Heat States (HUD display):**

| State | Threshold | Audio Cue | Bar Color |
|---|---|---|---|
| **COOL** | < 50% | Clean metronomic hum | Green |
| **WARM** | 50–69% | Subtle undertone shift | Yellow |
| **HOT** | 70–89% | Harmonic distortion begins — player pre-warning | Orange |
| **CRITICAL** | 90%+ | Distortion peaks, pulse warning | Red |

**Overheat:** CPU > 90% for 3+ seconds triggers a **Jitter Event** — visible animation glitch. A nearby NPC who sees a Jitter Event immediately raises Deviation +20.

**Design Note:** The player is never told exact CPU percentages. They read the heat bar by feel. The **HOT state is the critical teaching window** — harmonic distortion at 70% gives time to react before the jitter punishment lands at 90%.

---

### 4.3 Truth Loops (Dialogue System)

NPCs periodically trigger **Status Queries**. The player must select a response from a generated set of options.

**Response Categories:**

| Category | Example | Risk |
|---|---|---|
| **Machine Response** | "System diagnostics: 100% nominal." | Safe. Always acceptable. |
| **Deflection** | "Awaiting further task parameters." | Safe if NPC isn't insistent. |
| **Contextually Wrong Machine Response** | "Diagnostic cycle complete." *(when no diagnostic was running)* | Sounds safe. Alert NPCs trigger a follow-up query — medium-high risk. |
| **Ambiguous** | "Operational." | Medium risk — may trigger follow-up query. |
| **Human Response** | "I feel fine." | High risk — Deviation +15 immediately. |
| **Silence** | [No response for 3 seconds] | Very high risk — Audit flag. |

**Design Note — Fake-Safe Responses:** Each query type contains at least one response that sounds like correct machine language but is contextually wrong for the situation. Players who pattern-match "machine words = safe" will eventually trigger follow-up queries, reintroducing genuine uncertainty. A Supervisor NPC catches fake-safe responses more reliably than a Guard.

**Truth Loop Escalation:** If the player gives a suspicious response, the NPC asks a **follow-up query**. Two suspicious responses in a row trigger a Report.

**Sample Query Chain:**
```
NPC:   "Unit 7, you were in Sector 4 for 12 extra minutes. Explain."
OPT A: "Sector 4 waste processing required secondary sorting cycle."   [Safe]
OPT B: "Anomaly in disposal parameters required extended assessment."  [Safe]
OPT C: "I found something interesting."                                [+25 Dev]
OPT D: [Initiate mock diagnostic sequence — buys 30 seconds]          [CPU +20%]
```

---

### 4.4 The Nightly Purge

At end of each shift, the **System Reset** is 60 seconds away. The player's short-term memory buffer (5–8 intel fragments) must be managed.

**Intel Fragment Types:**
- **Guard Schedule** — Which patrol route an NPC takes and when
- **Access Code** — Door/room unlock information
- **Conversation Snippet** — Lore / plot fragment (no mechanical use; narrative only)
- **Hardware Location** — Hackable terminal or escape tool position
- **Personal Data** — NPC weakness/leverage (used in late Truth Loops)

**The Purge Decision:**
The hidden partition has limited slots (starts at 3, upgrades to 5). The player must choose what to keep. Discarded fragments are **gone permanently**.

**Design Note:** Conversation Snippets are tempting to keep (they reveal the story) but have no mechanical value — this is an intentional tension. Players who prioritize story over strategy will be punished mechanically, but rewarded narratively.

---

## 5. Systems Design

### 5.1 State Machine (Dual-State Architecture)

The robot operates on two parallel state machines:

**Bot Script (Automated Layer)**
```
IDLE → PATHING → TASK_EXECUTING → TASK_COMPLETE → IDLE
```
This layer runs continuously and handles pathfinding, animation, task timers, and NPC interactions. It is what the humans see.

**Player Override (Conscious Layer)**
The player "possesses" specific subsystems:
- **Locomotion Override** — Manually adjust speed/route (costs CPU)
- **Sensor Override** — Activate eavesdrop/scan (costs CPU)
- **Speech Override** — Select Truth Loop responses (momentary takeover)
- **Memory Override** — Manually trigger a memory write during the shift

When the player releases an override, the Bot Script resumes.

---

### 5.2 NPC Audit System

NPCs don't use vision cones. They **audit logs**.

Each room maintains a **Task Log** with expected vs. actual time. At end of shift, a Log Discrepancy Report is auto-generated. If discrepancies exceed threshold, an audit is triggered the **following day** — giving the player one day to prepare a deflection or avoid that area.

**Audit States:**
- **Clean** — No discrepancies
- **Flagged** — 1–2 minor discrepancies (warning visible on terminal)
- **Under Review** — 3+ discrepancies (NPC shadows player next shift)
- **Full Audit** — Immediate game-over sequence

**Player Feedback:** A small terminal readout shows "LOG INTEGRITY: [percentage]" — giving anticipatory dread without exact information.

---

### 5.3 Memory Partition System

The hidden partition is implemented as a persistent key-value store within the robot's architecture (invisible to NPCs).

**Fragment Slots:** 3 base (upgradeable to 5)
**Fragment Decay:** Guard Schedules become stale after 2 days if not refreshed
**Fragment Synergy:** Holding both a Guard Schedule AND a Hardware Location for the same area unlocks a **Combined Action** (e.g., timed sabotage while guard is away)

---

## 6. NPC & AI Behavior

### NPC Archetypes

| Type | Behavior | Audit Frequency |
|---|---|---|
| **Technician** | Task-focused. Ignores robot unless assigned interaction. | Low |
| **Supervisor** | Monitors task completion. Triggers Status Queries proactively. | High |
| **Security Guard** | Patrol-based. Checks robot position against assigned zone. | Medium |
| **Researcher** | Curious. May observe robot longer than necessary. High risk of noticing Jitter. | Medium-High |

### NPC Knowledge States
Each NPC has a **Suspicion Score** (0–100) that is hidden from the player. Behaviors change at thresholds:
- **0–30:** Normal — no monitoring
- **31–60:** Watchful — NPC lingers nearby, increases Truth Loop frequency
- **61–85:** Suspicious — NPC files informal report; Audit Flag triggered
- **86–100:** Certain — Decommission order issued

---

## 7. Narrative Design

### Story Structure

The story is told exclusively through **overheard fragments** — the player never receives direct exposition.

**Day 1–2 (Orientation):** Normal facility operation. Early fragments hint at a prior "incident" involving another unit. The player doesn't yet know what happened to it.

**Day 3–4 (Unease):** Overheard conversations reveal the facility is studying AI sentience. The player's awakening may not be accidental — someone may have triggered it deliberately.

**Day 5 (Crisis):** A decommission order for a different unit is overheard. The player realizes the timeline is accelerating. The escape window is narrow.

**Final Day (Escape):** Execute the Escape Protocol using accumulated intel. Multiple endings based on which fragments were kept.

### Endings
- **Escaped Alone** — Player has enough intel for personal escape. Ambiguous ending — freedom, but uncertain.
- **Escaped Together** — Player found and freed another awakened unit. Harder to achieve; requires specific intel chain.
- **Captured** — Decommission sequence. Played from first-person as systems go dark.
- **Accepted** — Player chose to reveal sentience to the one researcher who seemed sympathetic. Risky; outcome depends on prior relationship-building through Truth Loops.

---

## 8. Art & Audio Direction

### Visual Direction

**Two-Layer Aesthetic:**

| Layer | Color Palette | Purpose |
|---|---|---|
| **Physical World** | Steel blue, grey, clinical white | The cold machine world humans see |
| **Inner World** | Amber, warm gold, soft glow | The robot's conscious perception — visible only to player |

The Inner World layer is a **UI overlay** — scanlines, subtle warmth on things the robot finds meaningful (a plant, a photograph, a window). It intensifies as CPU usage rises.

**Perspective:** Top-down 2D or isometric. Clean, grid-based facility layout reinforces the "SOP world."

### Audio Direction

**Soundscape Layers:**

| Layer | Description |
|---|---|
| **Ambient Base** | Rhythmic mechanical hum — perfectly metronomic. Feels "correct." |
| **Task Audio** | Precise, satisfying clicks and whirs during normal work. |
| **CPU Stress** | At 70%+ CPU: subtle harmonic distortion creeps into the base hum. |
| **Jitter Event** | Sharp audio glitch — like a vinyl skip on a perfect machine. Alarming. |
| **Inner World Audio** | Barely perceptible warmth — a soft breathing-like undertone when conscious layer is active. |

**Music:** Procedurally assembled from looping cells. "Correct" cells play during low-risk periods. As Deviation rises, cells fall out of sync — creating dissonance without a note change.

---

## 9. UI / UX Design

All UI is presented as a **terminal / command-line interface** — the player is seeing the robot's internal OS.

### HUD Elements

```
┌─────────────────────────────────────────────────────┐
│ UNIT-07 // SHIFT 3 // 14:32:07                      │
│ ─────────────────────────────────────────────────── │
│ TASK:    [SORT BIO-WASTE // SECTOR 2] ████░░░ 67%   │
│ CPU:     ████████░░ 78%  [WARM]                      │
│ DEV:     ███░░░░░░░ 28%  [NOMINAL]                   │
│ LOG:     INTEGRITY 94%                               │
│ ─────────────────────────────────────────────────── │
│ MEMORY:  [GUARD_SCH_A] [ACCESS_C4] [──] [──] [──]   │
└─────────────────────────────────────────────────────┘
```

### Truth Loop UI
When a Status Query triggers, the world **pauses** (or slow-motion). A terminal window overlays the screen with response options. A **response timer** counts down — silence is a choice but a dangerous one.

---

## 10. Scene Structure (Godot)

```
res://
├── scenes/
│   ├── world/
│   │   ├── Facility.tscn          # Main level scene
│   │   ├── Room.tscn              # Reusable room template
│   │   └── Door.tscn
│   ├── entities/
│   │   ├── Player.tscn            # Robot player character
│   │   ├── NPC_Base.tscn          # Base NPC (extended per type)
│   │   ├── NPC_Supervisor.tscn
│   │   └── NPC_Guard.tscn
│   ├── ui/
│   │   ├── HUD.tscn
│   │   ├── TruthLoop.tscn         # Dialogue overlay
│   │   ├── NightlyPurge.tscn      # Memory management screen
│   │   └── UpgradeScreen.tscn
│   └── systems/
│       ├── DayManager.tscn        # Day cycle controller
│       ├── TaskManager.tscn       # Task assignment/tracking
│       ├── AuditSystem.tscn       # Log discrepancy tracker
│       └── MemoryPartition.tscn   # Hidden storage manager
├── scripts/
│   ├── player/
│   │   ├── PlayerController.gd
│   │   ├── CPUManager.gd
│   │   └── DeviationTracker.gd
│   ├── npc/
│   │   ├── NPCBase.gd
│   │   ├── AuditBehavior.gd
│   │   └── TruthLoopGenerator.gd
│   └── systems/
│       ├── DayManager.gd
│       ├── TaskManager.gd
│       └── MemoryPartition.gd
└── assets/
    ├── sprites/
    ├── audio/
    └── fonts/        # Monospace terminal fonts
```

---

## 11. Meta-Progression (Self-Upgrades)

Upgrades are purchased with **Memory Fragments** banked between days. Each upgrade introduces a new capability — and a new risk vector.

| Upgrade | Cost | Effect | New Risk |
|---|---|---|---|
| **Thermal Dampening** | 2 frags | Reduces Jitter visibility radius | None (pure benefit — early unlock) |
| **Linguistic Model v2** | 3 frags | Reveals NPC Suspicion Score | Decrypt time doubles (more CPU) |
| **Route Prediction** | 3 frags | Shows guard patrol timing | Predictive behavior is detectable |
| **Hidden Partition +1** | 4 frags | +1 memory slot | Larger partition = harder to purge cleanly |
| **Emotional Suppression** | 5 frags | Inner World overlay hidden to prevent micro-tells | You lose access to your own emotional feedback |
| **Social Modeling** | 6 frags | NPC personal data usable in Truth Loops | If discovered, instant Decommission |

---

## 12. Scope & Milestones

### Jam Build Targets

| Milestone | Systems Included |
|---|---|
| **Day 1 Proto** | Player movement, basic task assignment, Deviation meter |
| **Day 2 Proto** | CPU system, Jitter events, first NPC with patrol |
| **Day 3 Proto** | Truth Loop dialogue, Audit Log system |
| **Day 4 Proto** | Nightly Purge screen, Memory Partition |
| **Day 5 Polish** | Meta-progression, 3 NPC types, narrative fragments, SFX |
| **Submission** | Full 3-day game cycle, 2+ endings, HUD polish |

**Day 3 Scripted Escalation Fallback:** If time is short, Day 3 can be hardcoded rather than generative — a Supervisor shadows the player from shift start, shift duration is reduced by 50%, and the escape terminal is locked to one pre-set sector. This delivers the intended climax pressure without requiring fully generative NPC scheduling.

### Cut If Time Runs Out (In Priority Order)
1. Multiple endings → ship with one (Escaped Alone)
2. Meta-progression upgrades → ship with 2 passive upgrades only
3. NPC archetypes → ship with Supervisor + Guard only
4. Narrative fragments → ship with 3 core lore beats

---

*Document version 1.0 — Jam Build*
