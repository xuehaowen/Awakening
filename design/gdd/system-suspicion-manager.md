---
status: reverse-documented
source: autoloads/SuspicionManager.gd
date: 2026-04-25
verified-by: implementation
---

# System Design: Suspicion Manager

> **Note**: This document was reverse-engineered from the existing implementation.
> It captures current behavior and clarified design intent.

## Overview

The Suspicion Manager tracks how suspicious NPCs are of the player. Suspicion builds when the player acts anomalously while observed, and decays when hidden. High suspicion triggers Truth Loops and eventual game over.

**Design Intent**: Create a "heat" system that punishes visible mistakes but allows recovery through stealth. The player must manage their visibility and behavior to avoid detection.

## Core Mechanics

### Suspicion Thresholds

```
0% ─── 40% ─── 60% ─── 61% ─── 86% ─── 100%
  │      │       │       │       │
  │   WATCH   QUERY  REPORT  DECOMMISSION
  │      │       │       │       │
  │      │       │       │    [GAME OVER]
  │      │       │       │
  │      │    [Truth Loop may trigger]
  │      │
  │   [NPCs watch closely]
  │
[Normal behavior expected]
```

| Threshold | Value | Effect |
|-----------|-------|--------|
| **WATCH** | 40% | NPCs observe player more carefully |
| **QUERY** | 60% | Truth Loop may trigger |
| **REPORT** | 61% | NPCs begin reporting to Audit |
| **DECOMMISSION** | 86% | **Game Over** |

### Suspicion Gain (While Observed)

| Trigger | Rate/Sec | Source |
|---------|----------|--------|
| Jitter visible | +10.0 | CPU overheat |
| Smooth movement | +3.0 | Fluid motion detected |
| Off-task | +2.0 | Not working on assigned task |
| Wrong sector | +1.0 | Outside assigned zone |
| Loitering | +1.0 | Not moving while visible |

**Max gain rate**: ~17/second (all factors)

### Suspicion Decay (When Hidden)

| State | Rate/Sec |
|-------|----------|
| Idle (not moving) | -2.0 |
| Walking normally | -0.5 |

**Design intent**: Decay rewards stealth and hiding. Full recovery from 100% takes 50 seconds idle.

## Suspicion Levels

The system exposes 5 discrete levels for AI behavior and UI:

```gdscript
enum SuspicionLevel { 
    UNAWARE,    // 0-39%
    CURIOUS,    // 40-59%
    WATCHING,   // 60-60% (QUERY threshold)
    SUSPICIOUS, // 61-85%
    ALARMED     // 86-100%
}
```

## NPC Observation System

### Observation Tracking

- NPCs register with `register_npc(npc_id)`
- NPCs call `npc_started_observing()` when player enters vision
- NPCs call `npc_stopped_observing()` when player leaves
- Multiple NPCs can observe simultaneously

### State Updates

Player state is updated via `update_player_state(state)`:

```gdscript
last_known_state = {
    "cpu_high": bool,      // CPU ≥ 70%
    "moving_fast": bool,   // Smooth movement active
    "on_task": bool,       // Working on assigned task
    "moving": bool,        // Currently in motion
    "wrong_sector": bool   // Outside assigned sector
}
```

## Signal Emissions

| Signal | Emitted When |
|--------|--------------|
| `suspicion_changed(score, delta)` | Any suspicion change |
| `suspicion_threshold_crossed(threshold)` | Crossing 40/60/61/86 |
| `global_suspicion_peak_reached` | Crossing 86% |
| `npc_suspicion_updated(npc_id, score)` | Individual NPC change |

## Truth Loop Integration

```gdscript
func should_trigger_query() -> bool:
    return global_suspicion >= THRESHOLD_QUERY and is_player_visible
```

- Requires both suspicion ≥ 60% AND player visible
- Called by NPCs to determine if they should initiate Truth Loop

## Report Observation API

NPCs report specific observations:

```gdscript
report_observation(npc_id, observation_type, severity)
```

| Type | Effect |
|------|--------|
| "jitter" | +10 × severity |
| "smooth_movement" | +3 × severity |
| "off_task" | +2 × severity |
| "wrong_sector" | +1 × severity |

## Integration Points

### CPUManager
- Receives: jitter events
- Converts to: +10 suspicion/second

### DayManager
- Reset on new day? (not implemented)
- Audit reports may add suspicion

### NPCs
- Register/unregister on spawn/despawn
- Report observations
- Check `should_trigger_query()`

### UI
- `get_formatted_display()` returns "WATCHING [45/100]"
- `_get_level_color()` for status bar

## Balance Values

```gdscript
const THRESHOLD_WATCH: float = 40.0
const THRESHOLD_QUERY: float = 60.0
const THRESHOLD_REPORT: float = 61.0
const THRESHOLD_DECOMMISSION: float = 86.0

const GAIN_JITTER_VISIBLE: float = 10.0
const GAIN_SMOOTH_MOVEMENT: float = 3.0
const GAIN_OFF_TASK: float = 2.0
const GAIN_WRONG_SECTOR: float = 1.0
const GAIN_LOITERING: float = 1.0

const DECAY_RATE_IDLE: float = 2.0
const DECAY_RATE_WALKING: float = 0.5
```

## Edge Cases

- **Multiple observers**: Suspicion accumulates faster (stacking factors)
- **Capped at 100**: Cannot exceed maximum
- **No negative**: Floors at 0%
- **Threshold crossing**: Only emits when crossing upward

## Open Questions

1. Should suspicion persist between days or reset?
2. Is 86% decommission threshold too high/low?
3. Should different NPC types have different suspicion gain rates?
4. Should completed tasks reduce suspicion?

## Implementation Notes

- Updates in `_process(delta)` only when observed
- Uses clamp() for 0-100 bounds
- Individual NPC tracking for per-NPC suspicion (not fully utilized)
- Reset function clears all state
