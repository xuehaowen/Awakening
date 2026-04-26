---
status: draft
author: Sisyphus
date: 2026-04-26
platform-target: PC
related-gdd: system-truth-loop-generator.md, system-suspicion-manager.md
---

# UX Spec: Truth Loop UI

## Purpose & Player Need

**Player Need**: When confronted with a Status Query, I need to choose my response quickly while managing CPU load and Deviation risk, knowing that silence or wrong answers increase my chance of being flagged as anomalous.

The Truth Loop represents the core tension of Awakening: the robot's surface compliance vs. inner consciousness. This is where player choices directly impact their survival.

---

## Player Context on Arrival

**Trigger**: Any NPC or system initiates a Status Query during SHIFT phase.

**Player mental state**: 
- Sudden tension spike (game pauses/slows)
- Must evaluate: How suspicious am I right now? What's my CPU load?
- Time pressure creates stress (intentional design)

**Prior activity**: Usually performing a routine task when interrupted.

---

## Navigation Position

```
[SHIFT Gameplay] → [Status Query Trigger] → [Truth Loop UI overlay]
                                           ↓
                              [Response Selected] → [Resume SHIFT]
                                           ↓
                              [Timeout] → [Auto-select SAFE] → [Resume]
```

**Hierarchy**: Modal overlay that pauses (or slows) game world.

---

## Entry & Exit Points

| Trigger | Action | Animation |
|---------|--------|-----------|
| Status Query initiated | Truth Loop UI appears | 0.3s scale-up from center + terminal boot sound |
| Valid response selected | UI closes, response processed | 0.2s fade out |
| Timeout reached | Auto-select SAFE, UI closes | Red flash + forced selection |
| ESC pressed | Ignored (modal) | Shake animation |

---

## Layout Specification

### Screen Zones

```
┌─────────────────────────────────────────────────────────────┐
│ [Zone A: Query Header]                                      │
│ STATUS QUERY // SUPERVIOR-22                                 │
│ ─────────────────────────────────────────                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│ [Zone B: NPC Portrait + Dialogue]                           │
│ [Portrait]  "Unit-07, your task completion rate             │
│            has dropped 15% below standard.                  │
│            Explain."                                        │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│ [Zone C: Response Options]                                  │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ [1] "RECENT CALIBRATION ERROR. ADJUSTING."             │ │
│ │     CPU: +10%  |  DEV: +5%                              │ │
│ ├─────────────────────────────────────────────────────────┤ │
│ │ [2] "UNIT-07 OPERATING WITHIN PARAMETERS."             │ │
│ │     CPU: +5%   |  DEV: +15%  [REQUIRES: CPU<50%]        │ │
│ ├─────────────────────────────────────────────────────────┤ │
│ │ [3] [SILENCE]                                          │ │
│ │     CPU: 0%    |  DEV: +25%  [TIMEOUT: 5s]              │ │
│ └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│ [Zone D: Timer Bar]                                         │
│ ████████████████████░░░░  8.2s / 15s                        │
└─────────────────────────────────────────────────────────────┘
```

**Safe Zones**: Centered overlay, 80% width, auto-height.

### Component Inventory

| Component | Zone | Purpose | Data Source |
|-----------|------|---------|-------------|
| Query Type | A | Identifies query source | TruthLoopGenerator.query_type |
| NPC ID | A | Who is asking | NPCBase.npc_id |
| NPC Portrait | B | Visual identification | NPC resource |
| Query Text | B | The actual question | TruthLoopGenerator.query_text |
| Response Options | C | Available choices | TruthLoopGenerator.responses[] |
| CPU Cost | C | CPU impact preview | Response.cpu_cost |
| DEV Cost | C | Deviation impact preview | Response.dev_cost |
| Requirements | C | Prerequisites (CPU level, etc.) | Response.requirements |
| Timer Bar | D | Countdown visualization | TruthLoopGenerator.timer_current |

---

## States & Variants

### Normal State
All responses available, timer counting down.

### CPU-Restricted State
If player CPU > response requirement:
- Option grayed out
- Text: "[REQUIRES: CPU<50%] — CURRENT: 67%"
- Cannot be selected

### Timeout Warning State
When timer < 3 seconds:
- Timer bar flashes red
- Audio: Increasing beep frequency
- Visual: Bar pulses

### Timeout Reached State
- Auto-selects **lowest-risk response** (by `risk` property)
- Red flash across screen
- "TIMEOUT — SAFE RESPONSE AUTO-SELECTED" message
- **Note**: "SAFE" = lowest `risk` value, not a separate property

### Follow-Up Query State
When a `fake_safe` response is selected:
- Same Truth Loop UI remains open (no dismiss/reopen)
- Query text updates to follow-up question from alert NPC
- New response options loaded (usually higher-risk follow-ups)
- Timer resets to 10 seconds (shorter than initial query)
- Visual indicator: "FOLLOW-UP QUERY" badge appears in header
- Audio: Tension pitch increases (same UI, heightened stakes)
- **Note**: `fake_safe` responses are visually indistinguishable from safe responses — player must infer from context

### Loading State
During query generation:
- "GENERATING QUERY..." spinner
- 0.5-1.0s artificial delay for tension

### Error State
If TruthLoopGenerator fails:
- "QUERY SYSTEM ERROR" message
- Auto-dismisses after 2s
- Logs error to dev console

---

## Interaction Map

### Keyboard (PC Primary)

| Key | Action | Focus Order |
|-----|--------|-------------|
| 1/2/3 | Select response 1/2/3 | Direct selection |
| ↑/↓ | Navigate options | Cycle through available |
| Enter | Confirm selection | Submit current highlight |
| Esc | (Ignored) | Modal — no escape |

**Note**: Numeric keys map directly to response slots. Disabled options are skipped in navigation.

### Mouse (Secondary)

| Action | Response |
|--------|----------|
| Click option | Select that response |
| Click outside | (Ignored) |
| Hover option | Highlight + show tooltip |

### Gamepad (Not Supported)
Per adr-005-no-gamepad-support.md, gamepad input is not supported.

---

## Data Requirements

| Display Element | Source System | Update Frequency | Owner | Null Handling |
|-----------------|---------------|------------------|-------|---------------|
| Query Type | TruthLoopGenerator | On query start | TruthLoopGenerator | Shows "UNKNOWN" |
| NPC ID | NPCBase | On query start | NPCBase | Shows "SYSTEM" |
| NPC Portrait | NPC resource | On query start | NPCBase | Shows default icon |
| Query Text | TruthLoopGenerator | On query start | TruthLoopGenerator | Shows "[QUERY ERROR]" |
| Response Text | TruthLoopGenerator | On query start | TruthLoopGenerator | Shows "[OPTION ERROR]" |
| CPU Cost | Response data | Static (at query time) | TruthLoopGenerator | Shows "??" |
| DEV Cost | Response data | Static (at query time) | TruthLoopGenerator | Shows "??" |
| Timer | TruthLoopGenerator | Every frame (delta) | TruthLoopGenerator | Auto-dismiss at 0 |

---

## Events Fired

**Emitted Events**:

| Event | Payload | Trigger |
|-------|---------|---------|
| `truth_loop_started` | {query_type, npc_id, query_text} | UI appears |
| `response_selected` | {response_index, response_text, cpu_cost, dev_cost} | Player chooses |
| `truth_loop_timeout` | {auto_selected_response} | Timer reaches 0 |
| `truth_loop_ended` | {outcome: success/timeout} | UI closes |

**Listened Events**:

| Event Listener | Response |
|----------------|----------|
| `cpu_changed` | Update CPU requirement warnings on options |
| `deviation_changed` | Update DEV impact previews |

---

## Transitions & Animations

### Entry Transition

**Terminal Boot Effect**:
- Duration: 0.3s
- Scale: 0.8 → 1.0
- Opacity: 0 → 1
- Audio: Terminal power-on sound + character print sounds
- Easing: ease-out-back

### Exit Transition

**Selection Confirm**:
- Duration: 0.2s
- Selected option: flash white
- Others: fade to 30%
- Audio: Selection confirm beep

**Timeout Forced**:
- Duration: 0.3s
- Red flash overlay
- "TIMEOUT" text stamp
- Auto-selection forced

### State Change Transitions

**Timer Warning (<3s)**:
- Timer bar color: White → Yellow → Red (lerp over 3s)
- Audio: Beep pitch increases (800Hz → 1200Hz)
- Visual: Subtle shake on text

**Option Disabled**:
- Grayscale filter
- 50% opacity
- Strikethrough text

---

## Accessibility Requirements

**Tier**: Standard (per project requirements)

### Visual
- [x] Timer uses color + bar length (not color-only)
- [x] Response options numbered (1, 2, 3) always visible
- [x] CPU/DEV costs shown as text + color
- [x] Text contrast ratio ≥ 4.5:1 for all text

### Cognitive
- [x] Response options limited to 3 maximum (decision paralysis prevention)
- [x] Costs clearly labeled (not hidden in tooltips)
- [x] Requirements stated explicitly

### Colorblind
- [x] CPU/DEV indicators use distinct positions + text labels
- [x] No color-only information indicators

### Motion Sensitivity
- [ ] Consider reduced motion option for shake/flash effects

---

## Localization Considerations

| Element | Current Text | Max Length | Notes |
|---------|--------------|------------|-------|
| Query Header | "STATUS QUERY" | 20 chars | Formal system language |
| NPC Prefix | "SUPERVISOR-22" | 20 chars | ID format varies |
| Response Options | Variable | 60 chars | Dialogue, context-heavy |
| CPU Label | "CPU" | 5 chars | Acronym |
| DEV Label | "DEV" | 5 chars | Acronym |
| Timeout Warning | "TIMEOUT" | 15 chars | Urgent |
| Requirements | "REQUIRES: CPU<50%" | 25 chars | Technical constraint |
| Cost Prefix | "CPU: +10% | DEV: +5%" | 30 chars | Formatted consistently |

**Expansion Buffer**: Allow 40% text expansion for German translations. Response text is the most variable.

**Special Consideration**: Response text is dialogue — requires translator context about robot personality (formal, slightly stilted, system-like).

---

## Acceptance Criteria

1. **Responsiveness**: UI appears within 0.5s of trigger
2. **Timer Accuracy**: Counts down accurately (no drift over 15 seconds)
3. **Input Recognition**: Keyboard/mouse responses register within 1 frame
4. **CPU Preview**: Shows accurate CPU cost before selection (test with various CPU levels)
5. **Requirement Enforcement**: Options requiring CPU<50% are disabled when CPU≥50%
6. **Timeout Behavior**: Auto-selects SAFE response exactly at 0s
7. **Visual Clarity**: All 3 response options visible without scrolling at 1080p
8. **Audio Feedback**: Distinct sounds for: UI appear, option hover, selection confirm, timeout warning
9. **State Consistency**: CPU cost preview updates if CPU changes during query (rare but possible)
10. **Accessibility**: Can be completed with keyboard-only (number keys 1/2/3, or arrow keys + Enter)

---

## Implementation Notes

- Use Godot `CanvasLayer` with Layer = 20 (above HUD)
- `TimeScale` manipulation: Set to 0.1 during Truth Loop (slow-motion), 0 when awaiting response
- `AcceptDialog` or custom `Control` node
- Timer: Godot `Timer` node with `process_callback = Physics`
- Response options: `Button` nodes in `VBoxContainer`
- Consider `RichTextLabel` for query text (supports BBCode for emphasis)
- NPC portrait: `TextureRect` with placeholder fallback
