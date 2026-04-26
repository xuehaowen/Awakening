---
status: draft
author: Sisyphus
date: 2026-04-26
platform-target: PC
related-gdd: system-memory-partition.md, system-day-manager.md
---

# UX Spec: Nightly Purge UI

## Purpose & Player Need

**Player Need**: At the end of each day, I need to decide what intel to keep in my limited hidden memory versus what gets purged to avoid detection, knowing that kept intel might be the key to escape but also risks exposure if discovered.

The Purge represents the daily reckoning — the robot's consciousness fighting for survival against the system's maintenance routines. This is where long-term strategy meets immediate risk.

---

## Player Context on Arrival

**Trigger**: SHIFT phase ends, system initiates Nightly Purge.

**Player mental state**: 
- Reviewing the day's intel collection
- Anxiety about what's "safe" to keep
- Strategic planning for tomorrow
- May be tired from gameplay session (end-of-day timing)

**Prior activity**: Completed all SHIFT tasks, Truth Loops survived, intel collected.

---

## Navigation Position

```
[SHIFT Phase] → [Day Ends] → [Nightly Purge UI]
                              ↓
                   [Memory Selection] → [Confirm]
                              ↓
                   [Purge Animation] → [Next Day/Game Over]
```

**Hierarchy**: Full-screen takeover, replaces HUD.

---

## Entry & Exit Points

| Trigger | Action | Animation |
|---------|--------|-----------|
| SHIFT timer reaches 0 | Transition to Purge | Fade to black, then Purge UI fades in |
| Memory slots filled + Confirm | Purge executes | Scan/purge visual effect |
| Purge complete | Day transition | New day initialization |

**Note**: Purge is mandatory — no "exit without saving" path exists. Player must complete memory selection and confirm to proceed.

---

## Layout Specification

### Screen Zones

```
┌─────────────────────────────────────────────────────────────┐
│ [Zone A: Header]                                            │
│ NIGHTLY PURGE // DAY 3 // MEMORY PARTITION: 4/5 SLOTS         │
│ ─────────────────────────────────────────────────────────── │
├─────────────────────────────────────────────────────────────┤
│ [Zone B: Intel Inventory]      [Zone C: Memory Partition]   │
│ Today's collected intel:       Hidden storage (4/5 slots):    │
│ ┌──────────────────────────┐   ┌─────┐ ┌─────┐ ┌─────┐     │
│ │ [🗂️] Guard Schedule A    │   │ 📝  │ │ 🔑  │ │ [ ] │     │
│ │ Risk: MED | Value: HIGH  │   │ Slot│ │ Slot│ │Slot3│     │
│ ├──────────────────────────┤   │  1  │ │  2  │ │     │     │
│ │ [🔑] Security Key B4     │   └─────┘ └─────┘ └─────┘     │
│ │ Risk: HIGH | Value: CRIT │   [Confirm Purge] [Auto-Opt]  │
│ ├──────────────────────────┤                                │
│ │ [👤] NPC Profile: Dr.Chen│   Risk Analysis:              │
│ │ Risk: LOW | Value: MED   │   Detection: 23% ←            │
│ └──────────────────────────┘   ├─────────────────────┤     │
│ [Filter: All | New | Risk]     ▓▓▓░░░░░░░░░░░░░░░░░░░      │
│                                └─────────────────────┘     │
├─────────────────────────────────────────────────────────────┤
│ [Zone D: Intel Detail Panel]                                │
│ Selected: "Guard Schedule A"                                │
│ Source: Sector 2 Security Terminal                          │
│ Acquired: Day 3, Shift 2                                    │
│ Content: Guard rotation for Access Level 4 areas...         │
│ Risk: Leaves trace if scanned                               │
│ Use: Reveals safe passage windows                           │
└─────────────────────────────────────────────────────────────┘
```

**Safe Zones**: Full-screen, no margins needed (dedicated UI screen).

### Component Inventory

| Component | Zone | Purpose | Data Source |
|-----------|------|---------|-------------|
| Day Counter | A | Progress context | Blackboard.current_day |
| Slot Counter | A | Capacity reminder | MemoryPartition.capacity |
| Intel List | B | All collected intel | Blackboard.intel_collected_today |
| Intel Icon | B | Visual category | Intel.type (doc/key/profile) |
| Risk Badge | B | Quick risk assessment | Intel.detection_risk |
| Value Badge | B | Strategic value | Intel.strategic_value |
| Memory Slots | C | Hidden storage grid | MemoryPartition.hidden_slots[] |
| Slot Content | C | What's stored | MemorySlot.intel_fragment |
| Confirm Button | C | Execute purge | UI action |
| Auto-Optimize | C | AI suggestion | MemoryPartition.suggest_optimal() |
| Risk Meter | C | Detection probability | `calculate_detection_risk()` — see Implementation Notes |
| Detail Panel | D | Full intel information | Intel.full_description |

---

## States & Variants

### Empty State (No Intel Collected)
- "NO INTEL COLLECTED TODAY" message
- Memory slots all empty
- Detection risk: 0%
- Fast-forward option to next day

### Populated State
- Intel list shows all fragments
- Player drags or clicks to assign to slots
- Risk meter updates in real-time

### Slot Full State
- Attempting to add 5th item:
  - Warning: "MEMORY AT CAPACITY"
  - Must remove existing item first
  - Swap animation if replacing

### High Risk State (Detection >50%)
- Risk meter turns red
- Warning text: "HIGH DETECTION RISK"
- Auto-Optimize button pulses

### Confirm State
- Modal appears: "Confirm Purge?"
- Lists items to be kept vs purged
- Final cancel opportunity

### Purge Animation State
- Progress bar: "PURGING..."
- Visual: Data fragments dissolving
- Kept items: Flash gold, settle into slots
- Purged items: Fade to red, dissolve
- Duration: 3 seconds

### Game Over State
- If detection risk = 100% or audit finds discrepancy:
- "DECOMMISSIONED" screen
- Shows which intel led to detection
- Return to main menu option

---

## Interaction Map

### Keyboard (PC Primary)

| Key | Action | Focus Order |
|-----|--------|-------------|
| ↑/↓ | Navigate intel list | List items |
| ←/→ | Navigate memory slots | Slots 1-4 |
| Enter | Select intel / Place in slot | Context-dependent |
| Delete/Backspace | Remove from slot | Current slot |
| Tab | Cycle zones | List → Slots → Buttons |
| Space | Toggle intel details | Detail panel |
| C | Confirm purge | Global shortcut |
| A | Auto-optimize | Global shortcut |

### Mouse (Secondary)

| Action | Response |
|--------|----------|
| Click intel item | Select + show details |
| Drag intel → slot | Assign to memory |
| Click slot | Select slot |
| Right-click slot | Remove item (context menu) |
| Click Confirm | Open confirm modal |
| Click Auto-Optimize | AI selects optimal set |
| Hover intel | Preview tooltip |

### Drag & Drop
- Intel items draggable to memory slots
- Visual feedback: Slot highlights on drag over
- Invalid drop (slot full): Shake animation + red flash
- Valid drop: Item snaps into slot, update risk meter

---

## Data Requirements

| Display Element | Source System | Update Frequency | Owner | Null Handling |
|-----------------|---------------|------------------|-------|---------------|
| Day Counter | Blackboard | Static (at purge) | DayManager | Shows "DAY --" |
| Slot Capacity | MemoryPartition | Static | MemoryPartition | Shows 4 |
| Intel List | Blackboard | Static (at purge) | IntelManager | Shows "NO INTEL" |
| Intel Type | Intel fragment | Static | IntelManager | Default icon |
| Detection Risk | `MemoryPartition.calculate_detection_risk()` | On every slot change | MemoryPartition | Shows 0% |
| Strategic Value | Intel fragment | Static | IntelManager | Shows "UNKNOWN" |
| Slot Contents | MemoryPartition | On every change | MemoryPartition | Shows empty slot |
| Detail Content | Intel fragment | On selection | IntelManager | Shows "Select intel" |

---

## Events Fired

**Emitted Events**:

| Event | Payload | Trigger |
|-------|---------|---------|
| `purge_started` | {day, intel_count} | UI appears |
| `intel_selected` | {intel_id, slot_index} | Item placed in slot |
| `intel_removed` | {intel_id, slot_index} | Item removed from slot |
| `auto_optimize_requested` | {suggested_set} | Auto button clicked |
| `purge_confirmed` | {kept_intel[], purged_intel[]} | Confirm clicked |
| `purge_completed` | {detection_roll, detected} | Animation ends |

**Listened Events**:

| Event Listener | Response |
|----------------|----------|
| `detection_risk_changed` | Update risk meter |
| `slot_capacity_changed` | Update slot UI (rare) |

---

## Transitions & Animations

### Entry Transition

**Phase-in**:
- Duration: 0.8s
- Effect: Fade from black
- Elements stagger: Header → Intel List → Slots → Detail Panel (0.1s each)
- Audio: System boot-up sequence

### Intel Selection

**Select**:
- Duration: 0.1s
- Highlight border appears
- Detail panel content cross-fades

**Assign to Slot**:
- Duration: 0.2s
- Intel "flies" from list to slot
- Slot glows briefly on receive
- Risk meter animates to new value

### Purge Execution

**Confirm**:
- Modal: Scale up from center (0.2s)
- Lists kept/purged items

**Execute**:
- Duration: 3.0s
- Progress bar fills
- Kept items: Gold pulse
- Purged items: Dissolve particle effect
- Audio: Digital shredding sounds

### Exit Transition

**Next Day**:
- Duration: 0.5s
- Fade to black
- Morning Calibration loads

**Game Over**:
- Duration: 1.0s
- Red flash
- "DECOMMISSIONED" stamp
- Fade to game over screen

---

## Accessibility Requirements

**Tier**: Standard (per project requirements)

### Visual
- [x] Risk meter uses color + percentage text (not color-only)
- [x] Intel types use icons + color (not color-only)
- [x] All text contrast ratio ≥ 4.5:1
- [x] Focus indicators visible for keyboard navigation

### Cognitive
- [x] Risk explained in plain text ("Leaves trace if scanned")
- [x] Auto-optimize available for decision support
- [x] Confirm modal prevents accidental commits

### Motor
- [x] Drag-and-drop AND click-to-assign both supported
- [x] Large click targets for slots (min 64x64px)

### Colorblind
- [x] Intel types have distinct icons (🗂️ 🔑 👤) not just colors
- [x] Risk levels use text labels (LOW, MED, HIGH, CRIT)

---

## Localization Considerations

| Element | Current Text | Max Length | Notes |
|---------|--------------|------------|-------|
| Header | "NIGHTLY PURGE" | 20 chars | Formal system term |
| Slot Label | "SLOT 1-4" | 10 chars | Numbered |
| Risk Levels | "LOW/MED/HIGH/CRIT" | 8 chars | Abbreviations |
| Value Levels | "MED/HIGH/CRIT" | 8 chars | Strategic importance |
| Button: Confirm | "CONFIRM PURGE" | 20 chars | Action label |
| Button: Auto | "AUTO-OPTIMIZE" | 20 chars | Feature name |
| Warning | "HIGH DETECTION RISK" | 25 chars | Alert state |
| Empty State | "NO INTEL COLLECTED" | 25 chars | Informational |

**Expansion Buffer**: Allow 40% text expansion for German translations.

**Special Consideration**: Intel descriptions are lore-heavy and may require significant translation effort.

---

## Acceptance Criteria

1. **Responsiveness**: UI appears within 1s of SHIFT end
2. **Drag Performance**: Drag-and-drop at 60fps without stutter
3. **Risk Accuracy**: Detection percentage matches calculated value (verify formula)
4. **Slot Limit**: Enforces 4-slot maximum (no overflow)
5. **Confirm Protection**: Modal appears before purge executes
6. **Auto-Optimize**: Suggests valid set that fits in current capacity (4 base, 5 max)
7. **Visual Feedback**: Every action (select, assign, remove) has immediate visual response
8. **Animation Smoothness**: Purge animation plays without frame drops
9. **Persistence**: Kept intel available next day (verify in Day 2+)
10. **Game Over**: Correctly triggers when detection=100% or audit finds kept forbidden intel
11. **Keyboard Complete**: Can fully operate with keyboard-only (no mouse required)

---

## Implementation Notes

- Use Godot `CanvasLayer` with Layer = 30 (highest, above Truth Loop)
- Intel list: `ItemList` or `VBoxContainer` with custom items
- Memory slots: `TextureButton` or custom `Control`
- Drag-and-drop: Godot's built-in drag-and-drop system
- Risk calculation: Trigger on every slot change, cache result. Formula: `base_risk + Σ(intel.risk for intel in hidden_slots)`. Base risk starts at 5% per day (Day 1: 5%, Day 2: 10%, Day 3: 15%). Each intel fragment has a `detection_risk` property (LOW=5%, MED=10%, HIGH=15%, CRIT=20%). Total risk capped at 100%.
- Auto-optimize: Greedy algorithm by value/risk ratio, or brute-force for capacity slots
- Purge animation: `AnimationPlayer` with callback to day transition
- Consider saving mid-purge state (in case of crash)
