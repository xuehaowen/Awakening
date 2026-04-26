---
status: reverse-documented
source: scripts/player/CPUManager.gd
date: 2026-04-25
verified-by: implementation
---

# System Design: CPU Manager

> **Note**: This document was reverse-engineered from the existing implementation.
> It captures current behavior and clarified design intent.

## Overview

The CPU Manager simulates the player's limited processing power as a rogue AI inhabiting a maintenance drone. Managing CPU usage is critical to avoid detection—high CPU causes visible "jitter" anomalies that NPCs can observe.

**Design Intent**: Create a resource management tension where the player must balance powerful abilities against the risk of exposure. CPU serves as both a tactical resource and a stealth meter.

## Core Mechanics

### Baseline CPU Usage

All activity consumes baseline CPU:
- **Baseline**: 20% (always active)
- **Maximum**: 100% (capped via Blackboard.cpu_max)

### Override Abilities

Players can toggle 4 CPU-intensive abilities:

| Ability | Cost | Effect |
|---------|------|--------|
| `smooth_movement` | +15% | Smoother player movement |
| `passive_scan` | +10% | Auto-highlight interactables |
| `active_decrypt` | +30% | Reveal fake-safe dialogue options |
| `memory_write` | +20% (burst) | Enable memory fragment storage |

**Total maximum**: 20 + 15 + 10 + 30 + 20 = 95%

### CPU State Machine

The CPU exists in 4 states based on current usage:

```
0% ───── 50% ───── 70% ───── 90% ─── 100%
  │        │         │         │
 COOL     WARM      HOT    CRITICAL
```

| State | Range | Visual | Risk |
|-------|-------|--------|------|
| **COOL** | 0-49% | Green | None |
| **WARM** | 50-69% | Yellow | Low |
| **HOT** | 70-89% | Orange | Elevated |
| **CRITICAL** | 90-100% | Red | **Jitter imminent** |

State transitions emit `cpu_state_changed` signal for UI updates.

### Overheat Mechanic

**Critical state triggers overheat timer**:
- Timer accumulates while CPU ≥ 90%
- Timer decays at 2x speed when below threshold
- **After 3 consecutive seconds at CRITICAL**: Jitter event triggers

**Jitter Event**:
- Emits `Blackboard.jitter_triggered`
- Visible anomaly that NPCs can detect
- Adds +10 suspicion/second while visible
- Timer resets after trigger

### NPC Proximity Bonus

When NPCs are near the player:
- **+8% CPU** added to total
- Simulates "nervous system" load from being watched
- Creates tension: abilities riskier when observed

## State Transitions

### Entering WARM (50%)
- UI changes to yellow
- Early warning—no immediate danger

### Entering HOT (70%)
- UI changes to orange  
- "Harmonic distortion begins" (player pre-warning)
- NPCs may comment on strange behavior

### Entering CRITICAL (90%)
- UI changes to red
- Overheat timer starts counting
- Player should reduce usage immediately

### Jitter Trigger
- Visual shake effect
- NPCs in observation range detect anomaly
- Suspicion gain increases significantly

## Integration Points

### Blackboard
- Reads: `cpu_max` (default: 100)
- Writes: `cpu_current` (calculated total)
- Emits: `cpu_changed`, `jitter_triggered`

### SuspicionManager
- Jitter visible → +10 suspicion/sec
- High CPU state visible to NPCs

### UI
- State color for HUD indicator
- State name for status display
- Progress bar showing current %

## Balance Values

```gdscript
const OVERHEAT_THRESHOLD: float = 90.0
const WARNING_THRESHOLD: float = 70.0
const OVERHEAT_DURATION: float = 3.0
const NPC_PROXIMITY_COST: float = 8.0

var cpu_costs: Dictionary = {
    "baseline": 20.0,
    "smooth_movement": 15.0,
    "passive_scan": 10.0,
    "active_decrypt": 30.0,
    "memory_write": 20.0,
}
```

## Edge Cases

- **CPU capped at 100**: Even with all overrides + proximity, cannot exceed max
- **Timer decay**: Below threshold, timer decreases at 2x frame delta
- **State signal**: Only emits when state changes (not every frame)

## Open Questions

1. Should memory_write cost be sustained or burst-only?
2. Is 3-second overheat threshold too generous or too punishing?
3. Should different NPC types react differently to jitter?

## Implementation Notes

- Updates every frame via `_process(delta)`
- Uses clamp() to enforce 0-100 bounds
- Signals connected to Blackboard for global access
- Reset function clears all state for new game
