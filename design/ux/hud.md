---
status: draft
author: Sisyphus
date: 2026-04-26
platform-target: PC
related-gdd: system-cpu-manager.md, system-suspicion-manager.md, system-memory-partition.md
---

# UX Spec: Heads-Up Display (HUD)

## Purpose & Player Need

**Player Need**: As Unit-07, I need to monitor my internal systems and intel at a glance while navigating the facility, so I can make informed decisions about CPU usage, task performance, and escape planning without breaking immersion.

The HUD represents Unit-07's internal OS terminal — the robot's self-perception layer visible only to the player.

---

## Player Context on Arrival

The HUD is **omnipresent during gameplay** (SHIFT phase). It appears after Morning Calibration and remains visible until:
- Pause menu opened (HUD dims but remains partially visible)
- Truth Loop triggered (world pauses, HUD overlay)
- Nightly Purge phase (HUD replaced by Purge UI)
- Game Over (HUD replaced by Game Over screen)

**Player mental state**: Focused on task completion while monitoring risk levels.

---

## Navigation Position

```
[Main Menu] → [Calibration] → [SHIFT with HUD] → [Purge]
                                      ↓
                              [Truth Loop overlay]
                              [Pause Menu overlay]
```

**Hierarchy**: Always-on overlay, highest z-index during gameplay.

---

## Entry & Exit Points

| Trigger | Action | Animation |
|---------|--------|-----------|
| Calibration complete | HUD fades in | 0.5s fade from 0% to 100% opacity |
| Pause menu opened | HUD dims to 30% | 0.2s opacity change |
| Pause menu closed | HUD returns to 100% | 0.2s opacity change |
| Truth Loop triggered | HUD persists with darkening overlay | Immediate darkening layer |
| Shift ends | HUD fades out | 0.5s fade out |

---

## Layout Specification

### Screen Zones

```
┌─────────────────────────────────────────────────────────────┐
│ [Zone A: Header]                    [Zone B: System Status] │
│ UNIT-07 // SHIFT 3 // [TIME]          CPU/DEV/LOG bars      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│                    [PLAY AREA - CLEAR]                      │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ [Zone C: Task Info]           [Zone D: Memory Slots]        │
│ Current task + progress         Hidden partition icons      │
└─────────────────────────────────────────────────────────────┘
```

**Safe Zones**: Keep all HUD elements 5% from screen edges for ultrawide compatibility.

### Component Inventory

| Component | Zone | Purpose | Data Source |
|-----------|------|---------|-------------|
| Unit ID | A | Identity reinforcement | Hardcoded: "UNIT-07" |
| Day Counter | A | Progress context | Blackboard.current_day |
| Shift Timer | A | Time pressure | Blackboard.time_remaining |
| CPU Bar | B | CPU state (0-100%) | Blackboard.cpu_current |
| DEV Bar | B | Deviation level (0-100%) | Blackboard.deviation |
| LOG Integrity | B | Audit risk | Blackboard.log_integrity |
| Task Name | C | Current objective | TaskManager.current_task |
| Task Progress | C | Completion % | TaskManager.task_progress |
| Memory Slots | D | Hidden partition contents | MemoryPartition.hidden |

---

## States & Variants

### Normal State
All elements active, standard colors.

### CPU Warning States

| CPU Level | Bar Color | Label | Visual Effect |
|-----------|-----------|-------|---------------|
| COOL (0-49%) | Green (#00FF00) | "COOL" | None |
| WARM (50-69%) | Yellow (#FFFF00) | "WARM" | None |
| HOT (70-89%) | Orange (#FF8800) | "HOT" | Subtle pulse animation |
| CRITICAL (90-100%) | Red (#FF0000) | "CRITICAL" | Rapid pulse + scanline distortion |

### Deviation Warning States

| Deviation | Bar Color | Label |
|-----------|-----------|-------|
| 0-39% | Green | "NOMINAL" |
| 40-59% | Yellow | "ELEVATED" |
| 60-85% | Orange | "WATCHING" |
| 86-100% | Red | "CRITICAL" |

### Loading State
During scene transitions:
- HUD freezes at current values
- Opacity reduces to 50%
- "SYNCING..." text appears in header

### Error State
If data source disconnects:
- Affected element shows "[NO DATA]" in red
- Other elements remain functional

---

## Interaction Map

### Keyboard (PC Primary)

| Key | Action | Focus Order |
|-----|--------|-------------|
| Tab | Toggle passive_scan CPU override | N/A (direct) |
| Hold Ctrl | Enable smooth_movement override | N/A (direct) |
| Hold Shift | Enable active_decrypt override | N/A (direct) |
| M | Open Memory Management | Opens NightlyPurgeUI |
| Esc | Open Pause Menu | Pauses game, dims HUD |

**Note**: HUD elements are read-only displays, not interactive controls. Input actions modify underlying systems that reflect in HUD.

### Gamepad (Not Supported)
Per adr-005-no-gamepad-support.md, gamepad input is not supported.

---

## Data Requirements

| Display Element | Source System | Update Frequency | Owner | Null Handling |
|-----------------|---------------|------------------|-------|---------------|
| Day Counter | Blackboard | On day change | DayManager | Shows "--" |
| Shift Timer | Blackboard | Every frame (delta) | DayManager | Shows "00:00" |
| CPU Bar | Blackboard | Every frame | CPUManager | Shows 0% |
| DEV Bar | Blackboard | Every frame | SuspicionManager | Shows 0% |
| LOG Integrity | Blackboard | On audit event | AuditSystem | Shows 100% |
| Task Name | TaskManager | On task change | TaskManager | Shows "NO TASK" |
| Task Progress | TaskManager | Every frame | TaskManager | Shows 0% |
| Memory Slots | MemoryPartition | On memory change | MemoryPartition | Shows empty slots |

---

## Events Fired

The HUD listens for but does not emit events:

| Event Listener | Response |
|----------------|----------|
| `cpu_changed` | Update CPU bar and state label |
| `deviation_changed` | Update DEV bar and state label |
| `task_updated` | Update task name and progress |
| `memory_committed` | Update memory slot display |
| `shift_ended` | Fade out HUD |
| `purge_initiated` | Fade out HUD |

---

## Transitions & Animations

### State Change Transitions

**CPU State Change (COOL → WARM, etc.)**:
- Duration: 0.3s
- Effect: Color lerp from old to new
- Audio: Subtle state change beep (different pitch per state)

**Deviation Threshold Cross**:
- Duration: 0.5s
- Effect: Bar color flash + label text scale pulse (1.0 → 1.2 → 1.0)

**Task Progress Update**:
- Duration: 0.1s
- Effect: Progress bar width smooth lerp

### Enter/Exit Transitions

**Fade In (Calibration → Shift)**:
- Duration: 0.5s
- Easing: ease-out
- Elements stagger: Header → Status → Task → Memory (0.1s delay each)

**Fade Out (Shift → Purge)**:
- Duration: 0.5s
- Easing: ease-in
- All elements fade together

---

## Accessibility Requirements

**Tier**: Standard (per project requirements)

### Visual
- [x] All state indicators use color + text label (not color-only)
- [x] Bar values readable at 1080p and 4K
- [x] Text contrast ratio ≥ 4.5:1 for all labels

### Screen Reader (Future)
- [ ] CPU state changes announced when crossing thresholds
- [ ] Deviation warnings announced at 60%, 86%
- [ ] Task completion announced

### Colorblind
- [x] CPU/ DEV bars use distinct positions (top vs middle) not just color
- [x] State labels always visible (COOL, WARM, HOT, CRITICAL)

---

## Localization Considerations

| Element | Current Text | Max Length | Notes |
|---------|--------------|------------|-------|
| Unit ID | "UNIT-07" | 10 chars | Hardcoded, no translation |
| CPU Label | "CPU" | 5 chars | Acronym, translate carefully |
| DEV Label | "DEV" | 5 chars | Short for Deviation |
| LOG Label | "LOG" | 5 chars | Short for Log Integrity |
| State Labels | "COOL", "WARM", etc. | 10 chars | Emotional states, context matters |
| Task Placeholder | "NO TASK" | 15 chars | Error state |

**Expansion Buffer**: Allow 40% text expansion for German translations.

---

## Acceptance Criteria

1. **Performance**: HUD renders at 60fps without frame drops during CPU state changes
2. **Responsiveness**: All values update within 1 frame of Blackboard change
3. **Visibility**: All elements readable on 16:9, 21:9, and 4:3 aspect ratios
4. **Contrast**: Passes WCAG 2.1 AA contrast requirements for all text
5. **State Accuracy**: CPU state label matches actual threshold (test at 49%, 50%, 69%, 70%, 89%, 90%)
6. **Memory Display**: Shows correct fragment count and types (0-5 slots)
7. **Timer Accuracy**: Shift timer counts down accurately (no drift over 15 minutes)
8. **Task Progress**: Progress bar matches actual task completion percentage

---

## Implementation Notes

- Use Godot `CanvasLayer` with Layer = 10 (above game world)
- Monospace font required: JetBrains Mono or similar
- All color values defined in `ui_theme.tres` for easy modification
- Consider `ProgressBar` nodes for CPU/DEV/LOG bars
- Memory slots use custom `TextureRect` with fragment icons
- Update via `_process()` for smooth timer, signal connections for discrete events
