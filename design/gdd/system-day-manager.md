---
status: reverse-documented
source: autoloads/DayManager.gd
date: 2026-04-25
verified-by: implementation
---

# System Design: Day Manager

> **Note**: This document was reverse-engineered from the existing implementation.
> It captures current behavior and clarified design intent.

## Overview

The Day Manager controls the game's day-night cycle, managing phases from morning calibration through the work shift, memory purge, and upgrade. On Day 3, the escape sequence begins instead of a new day.

**Design Intent**: Create structured gameplay loops where each day has distinct phases with different player activities. The 3-day structure builds tension toward the final escape.

## Day Phase Cycle

```
Day 1, 2:
CALIBRATION → SHIFT → PURGE → UPGRADE → (next day)

Day 3 (Final):
CALIBRATION → SHIFT → [Escape Available]
```

### Phase Enum

```gdscript
enum DayPhase {
    CALIBRATION,  // Morning prep, task assignment
    SHIFT,        // Active gameplay
    PURGE,        // Memory management
    UPGRADE,      // Brief intermission
    ESCAPE        // Final day only
}
```

## Phase Details

### CALIBRATION (Phase 0)

**Entry**: Day start or after UPGRADE

**Activities**:
- Task generation via TaskManager
- Morning calibration UI display
- Sector assignment reveal

**Duration**: Until player clicks "Continue"

**Transitions to**: SHIFT

**Implementation**:
```gdscript
func _show_morning_calibration() -> void:
    TaskManager.generate_day_tasks(Blackboard.current_day)
    Blackboard.start_day(Blackboard.current_day)
    # Show MorningCalibrationUI
```

### SHIFT (Phase 1)

**Entry**: After calibration complete

**Activities**:
- Active gameplay
- Task completion
- Intel collection
- Truth Loops
- Suspicion management

**Duration**: Configurable (default 900s / 15 min)

**Timer Behavior**:
```gdscript
if shift_timer > 0:
    shift_timer -= delta
    Blackboard.time_remaining = shift_timer
    if shift_timer <= 0:
        end_shift()
```

**Transitions to**: PURGE (automatic at timer expiry or `end_shift()`)

### PURGE (Phase 2)

**Entry**: Shift end or manual trigger

**Activities**:
- Audit report generation
- Memory commit/discard decisions
- Short-term memory cleared after 60s

**Duration**: 60 seconds (PURGE_DURATION)

**Auto-clear**: If player doesn't manually commit
```gdscript
func _force_purge() -> void:
    Blackboard.purge_short_term()  # Clear uncommitted memories
    purge_timer = 0
    _start_upgrade()
```

**Transitions to**: UPGRADE

### UPGRADE (Phase 3)

**Entry**: After purge complete

**Activities**:
- Automatic upgrades (Day 2: memory capacity +1)
- Brief intermission

**Special (Day 2)**:
```gdscript
if Blackboard.current_day == 2:
    MemoryPartition.upgrade_capacity()  # 4 → 5
```

**Duration**: 3 seconds (auto-advance)

**Transitions to**: 
- CALIBRATION (if day < FINAL_DAY)
- ESCAPE (if day == FINAL_DAY)

### ESCAPE (Phase 4)

**Entry**: Day 3 after upgrade

**Activities**:
- Final escape sequence
- Ending determination
- Game conclusion

**Duration**: Until escape attempted or game over

## Day Progression Logic

```gdscript
func _start_next_day() -> void:
    if Blackboard.current_day >= Blackboard.FINAL_DAY:
        _start_escape()
    else:
        Blackboard.current_day += 1
        current_phase = DayPhase.CALIBRATION
        _show_morning_calibration()
```

## Key Constants

```gdscript
const PURGE_DURATION: float = 60.0
const FINAL_DAY: int = 3

# In Blackboard:
const FINAL_DAY: int = 3
var current_day: int = 1
```

## Integration Points

### TaskManager
- `generate_day_tasks(day)` called during calibration
- Tasks drive shift gameplay

### MemoryPartition
- `upgrade_capacity()` on Day 2
- `purge_short_term()` during purge phase

### AuditSystem
- `end_of_day_report()` during purge
- May trigger game over on critical audit failure

### Blackboard
- `shift_active` flag
- `time_remaining` countdown
- `current_phase` index
- `current_day` tracking
- Signals: `day_started`, `shift_ended`, `purge_initiated`

### UI
- MorningCalibrationUI during CALIBRATION
- Timer display during SHIFT
- Purge interface during PURGE

## Edge Cases

- **Manual shift end**: `end_shift()` can be called early
- **Scene reload**: Calibration UI reference invalidated and recreated
- **Final day**: No UPGRADE phase, goes directly to ESCAPE
- **Audit failure**: May trigger game over during purge

## Open Questions

1. Should shift duration vary by day (longer on later days)?
2. Should purge duration be player-controlled or fixed?
3. Should there be more upgrade types beyond memory capacity?
4. What happens if player tries to escape before Day 3?

## Implementation Notes

- Uses `randomize()` in `_ready()` for unique gameplay
- Phase timer recreated on reset (handles scene reloads)
- Auto-advance from UPGRADE uses SceneTreeTimer
- Calibration UI instantiated dynamically
