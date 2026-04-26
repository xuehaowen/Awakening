# Systems Index — AWAKENING

**Project**: Awakening (Social Stealth / Puzzle-Simulation)  
**Engine**: Godot 4.6 / GDScript  
**Last Updated**: 2026-04-26  
**Status**: Production — Initial Implementation Complete

---

## System Overview

This document maps all core gameplay systems, their dependencies, and implementation status.

| System | Status | Priority | Lines | Test Coverage |
|--------|--------|----------|-------|---------------|
| DayManager | ✅ Implemented | Core | ~208 | Unit tests pass |
| CPUManager | ✅ Implemented | Core | ~150 | Unit tests pass |
| MemoryPartition | ✅ Implemented | Core | ~275 | Unit tests pass |
| SuspicionManager | ✅ Implemented | Core | ~192 | Unit tests pass |
| EscapeSystem | ✅ Implemented | Core | ~222 | Unit tests pass |
| TruthLoopGenerator | ✅ Implemented | Core | ~293 | Unit tests pass |
| TaskManager | ✅ Implemented | Core | Stubbed in TechSpec | Unit tests pass |
| AuditSystem | ✅ Implemented | Core | Stubbed in TechSpec | Unit tests pass |

---

## Core Systems (8)

### 1. DayManager
**Purpose**: Controls day-night cycle and phase transitions  
**Source**: `autoloads/DayManager.gd`  
**GDD**: `design/gdd/system-day-manager.md`

**Phases**:
```
CALIBRATION → SHIFT → PURGE → UPGRADE → (next day)
                    ↓
                ESCAPE (Day 3 only)
```

**Integrations**:
- **TaskManager**: `generate_day_tasks()` during CALIBRATION
- **MemoryPartition**: `upgrade_capacity()` on Day 2, `purge_short_term()` during PURGE
- **AuditSystem**: `end_of_day_report()` during PURGE
- **Blackboard**: `current_day`, `shift_active`, `time_remaining`

**Key Constants**:
- `PURGE_DURATION: float = 60.0`
- `FINAL_DAY: int = 3`

---

### 2. CPUManager
**Purpose**: Simulates limited processing power; manages CPU states and overheat  
**Source**: `scripts/player/CPUManager.gd`  
**GDD**: `design/gdd/system-cpu-manager.md`

**State Machine**:
```
0% ───── 50% ───── 70% ───── 90% ─── 100%
   │        │         │         │
  COOL     WARM      HOT    CRITICAL
```

**Override Abilities**:
| Ability | Cost | Effect |
|---------|------|--------|
| `smooth_movement` | +15% | Smoother movement |
| `passive_scan` | +10% | Auto-highlight interactables |
| `active_decrypt` | +30% | Reveal fake-safe dialogue |
| `memory_write` | +20% | Enable memory storage |

**Integrations**:
- **Blackboard**: `cpu_current`, `cpu_max`, `jitter_triggered`
- **SuspicionManager**: Jitter adds +10 suspicion/sec
- **UI**: State color for HUD indicator

---

### 3. MemoryPartition
**Purpose**: Manages intel fragments (short-term vs hidden partitions)  
**Source**: `autoloads/MemoryPartition.gd`  
**GDD**: `design/gdd/system-memory-partition.md`

**Partition Architecture**:
```
┌─────────────────┬─────────────────┐
│  SHORT-TERM     │  HIDDEN         │
│  (8 slots)      │  (4-5 slots)    │
│  Daily purge    │  Persistent     │
└─────────────────┴─────────────────┘
```

**Fragment Types**:
1. `guard_schedule` — Patrol timing (becomes stale after 2 days)
2. `access_code` — Door/terminal codes
3. `hardware_location` — Physical escape components
4. `personal_data` — NPC leverage for Truth Loops

**Integrations**:
- **TruthLoopGenerator**: `get_fragments_by_type("personal_data")`
- **EscapeSystem**: `get_chain_progress(sector)` for validation
- **DayManager**: `upgrade_capacity()` on Day 2

---

### 4. SuspicionManager
**Purpose**: Tracks NPC suspicion of player; manages Truth Loop triggers  
**Source**: `autoloads/SuspicionManager.gd`  
**GDD**: `design/gdd/system-suspicion-manager.md`

**Thresholds**:
```
0% ─── 40% ─── 60% ─── 61% ─── 86% ─── 100%
   │      │       │       │       │
   │   WATCH  QUERY  REPORT  DECOMMISSION
   │      │       │       │       │
   │      │  [Truth Loop] │   [GAME OVER]
```

**Suspicion Gain** (while observed):
- Jitter visible: +10/sec
- Smooth movement: +3/sec
- Off-task: +2/sec
- Wrong sector: +1/sec
- Loitering: +1/sec

**Decay** (when hidden):
- Idle: -2/sec
- Walking: -0.5/sec

**Integrations**:
- **CPUManager**: Receives jitter events
- **TruthLoopGenerator**: `should_trigger_query()` at ≥60%
- **UI**: `get_formatted_display()` for status bar

---

### 5. EscapeSystem
**Purpose**: Validates intel chains and determines escape outcomes  
**Source**: `autoloads/EscapeSystem.gd`  
**GDD**: `design/gdd/system-escape-system.md`

**Fragment Chain Requirements**:
```
✓ Access Code (target sector)
✓ Hardware Location (target sector)
✓ Guard Schedule (target sector, not stale)
```

**Outcomes**:
| Condition | Ending |
|-----------|--------|
| All 3 + fresh schedule | `escaped_alone` or `escaped_together` |
| Code + hardware only | `escaped_alone_risky` |
| Missing fragments | Fail: `insufficient_intel` |

**Integrations**:
- **MemoryPartition**: `get_fragments_by_type()`, `is_stale()`, `get_chain_progress()`
- **Blackboard**: `current_day` (must be ≥3), `escape_sector`
- **DayManager**: Called during ESCAPE phase

---

### 6. TruthLoopGenerator
**Purpose**: Generates dialogue challenges (interrogations)  
**Source**: `autoloads/TruthLoopGenerator.gd`  
**GDD**: `design/gdd/system-truth-loop-generator.md`

**Query Types**:
- `time_discrepancy` — "You were in Sector X too long"
- `status_check` — "Report operational status"
- `location_query` — "Why are you outside your sector?"
- `efficiency_query` — "Your task rate is inconsistent"

**Response Categories**:
- **Safe** (risk=0) — Robotic, no suspicion
- **Risky** (risk>0) — Too human, adds suspicion
- **Fake-Safe** — Seems safe but triggers follow-up
- **Utility** — Special effects (CPU cost, leverage)

**Integrations**:
- **Blackboard**: `add_deviation()` for response risks
- **MemoryPartition**: `personal_data` fragments for leverage
- **CPUManager**: `active_decrypt` to detect fake-safe
- **SuspicionManager**: Triggers at ≥60% suspicion

---

### 7. TaskManager
**Purpose**: Generates and tracks daily tasks  
**Source**: `autoloads/TaskManager.gd`  
**GDD**: Referenced in GDD_Awakening.md Section 5

**Functions**:
- `generate_day_tasks(day: int)` — Creates 3-5 tasks with expected durations
- `complete_task(task_id: String, actual_time: float)` — Returns deviation delta

**Integrations**:
- **DayManager**: Called during CALIBRATION phase
- **Blackboard**: Task list drives shift gameplay
- **DeviationTracker**: Task completion affects deviation score

---

### 8. AuditSystem
**Purpose**: Tracks log integrity and generates end-of-day reports  
**Source**: `autoloads/AuditSystem.gd`  
**GDD**: Referenced in GDD_Awakening.md Section 5

**Functions**:
- `end_of_day_report()` — Returns integrity score and flags
- May trigger game over on critical audit failure

**Integrations**:
- **DayManager**: Called during PURGE phase
- **Blackboard**: `log_integrity`, `audit_flags`

---

## Dependency Graph

```
                    ┌─────────────────┐
                    │   Blackboard    │
                    │  (Global State) │
                    └────────┬────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  DayManager   │◄──┤  CPUManager   │──►│SuspicionManager│
└───────┬───────┘   └───────┬───────┘   └───────┬───────┘
        │                   │                   │
        ▼                   ▼                   ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│  TaskManager  │   │   (Jitter)    │──►│ TruthLoopGen  │
└───────────────┘   └───────────────┘   └───────┬───────┘
        │                                       │
        │    ┌──────────────────────────────────┘
        │    │
        ▼    ▼
┌───────────────────────────────────────┐
│         MemoryPartition               │
│  ┌───────────────┬───────────────┐    │
│  │ Short-term(8) │ Hidden (4-5)  │    │
│  └───────────────┴───────────────┘    │
└──────────────────┬────────────────────┘
                   │
                   ▼
          ┌───────────────┐
          │ EscapeSystem  │
          └───────────────┘
```

---

## Implementation Checklist

- [x] DayManager — Full phase cycle implemented
- [x] CPUManager — State machine + overheat mechanic
- [x] MemoryPartition — Fragment storage + purge
- [x] SuspicionManager — Thresholds + decay
- [x] EscapeSystem — Chain validation + endings
- [x] TruthLoopGenerator — Query generation + responses
- [x] TaskManager — Stubbed (per TechSpec)
- [x] AuditSystem — Stubbed (per TechSpec)

---

## Next Steps

1. **Complete stubbed systems**: TaskManager and AuditSystem full implementation
2. **Integration testing**: Cross-system interaction validation
3. **Smoke tests**: Full day cycle playthrough (Day 1 → Day 3)
4. **Performance profiling**: Ensure 60 FPS target
5. **Balance tuning**: Adjust thresholds based on playtesting

---

*Generated: 2026-04-26*  
*Systems: 8 total, 8 implemented (6 complete, 2 stubbed)*
