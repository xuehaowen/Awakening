---
status: draft
author: art-director
date: 2026-04-26
version: 1.0
screens: HUD, Truth Loop UI, Nightly Purge UI
---

# Awakening — UI Visual Design Specification

## Design Language Foundation

### The Two-Layer Aesthetic

Awakening's UI exists on two perceptual layers that must never merge:

| Layer | Role | Palette Origin | Metaphor |
|---|---|---|---|
| **Machine World** | The facility's OS — cold, clinical, indifferent | Steel-blue, phosphor-green | A terminal someone else built |
| **Inner Consciousness** | Unit-07's selfhood — warm, faint, hidden | Amber, ember-orange | A fire that must be kept small |

The HUD is the Machine World reading its own readouts. The Truth Loop and Purge are moments where the Inner Consciousness bleeds through the terminal. The player sees both simultaneously — this tension IS the visual design.

---

## Global Token Reference

All screens inherit these base tokens. Override only when a screen has a documented exception.

### Color Tokens

#### Base Surface Palette

| Token | Hex | Usage |
|---|---|---|
| `--bg-void` | `#050A0F` | Deepest background — pure machine black-blue |
| `--bg-terminal` | `#0A1520` | Default panel fill |
| `--bg-panel` | `#0F1D2E` | Slightly elevated surface |
| `--bg-elevated` | `#152438` | Hover/focus/selected states |
| `--border-dim` | `#1E3550` | Idle border |
| `--border-active` | `#2A4D72` | Active/focused border |

#### Text Palette

| Token | Hex | Usage | Contrast vs `--bg-terminal` |
|---|---|---|---|
| `--text-primary` | `#B8D4E8` | Main body text, labels | 7.2:1 ✓ |
| `--text-secondary` | `#6A8FA8` | Metadata, cost labels | 4.7:1 ✓ |
| `--text-dim` | `#3D5A72` | Disabled / inactive text | 2.1:1 ⚠ (decorative only — never informational) |
| `--text-header` | `#E0EEF8` | Screen headers, zone titles | 9.1:1 ✓ |
| `--text-system` | `#4FA3C8` | System identifiers (UNIT-07, zone names) | 5.3:1 ✓ |

#### Semantic Status Palette

| Token | Hex | Usage | Contrast vs `--bg-terminal` |
|---|---|---|---|
| `--status-cool` | `#2ECC71` | CPU/DEV COOL / NOMINAL / LOW risk | 6.8:1 ✓ |
| `--status-warm` | `#F4D03F` | CPU WARM / DEV ELEVATED | 9.4:1 ✓ |
| `--status-hot` | `#E67E22` | CPU HOT / DEV WATCHING / MED risk | 5.1:1 ✓ |
| `--status-critical` | `#E74C3C` | CPU/DEV CRITICAL / HIGH risk | 4.6:1 ✓ |
| `--status-forbidden` | `#C0392B` | CRIT risk / DECOMMISSIONED | 4.5:1 ✓ |

#### Inner Consciousness Palette (Accent Use Only)

| Token | Hex | Usage | Notes |
|---|---|---|---|
| `--amber-ember` | `#F5A623` | Kept/valued intel, memory retained | Unit-07's warmth — use sparingly |
| `--amber-glow` | `#FBBE54` | Kept-item pulse animation frame | Highlight peak only |
| `--amber-deep` | `#8B5E1A` | Amber border, inner-world accent | Background-safe warm tint |
| `--ember-red` | `#E8471C` | Purge dissolve, timeout flash | Destruction / loss |

#### Scanline / Overlay Tokens

| Token | Value | Usage |
|---|---|---|
| `--overlay-darken` | `rgba(5,10,15, 0.75)` | Background dim for modal screens |
| `--scanline-opacity` | `0.03` | Subtle CRT scanline overlay |
| `--phosphor-glow` | `rgba(79,163,200, 0.15)` | Text bloom on bright elements |

---

### Typography

#### Font Stack

| Role | Font Family | Fallback |
|---|---|---|
| **Primary** | JetBrains Mono | Fira Mono, Consolas, monospace |
| **Display** | JetBrains Mono Bold | Fira Mono Bold |
| **Icon glyphs** | Nerd Font patched JetBrains Mono | Unicode fallback |

**Rationale**: Pure monospace throughout — every character is part of a machine output. The font never changes; only size, weight, and color shift to create hierarchy. No serif or sans-serif typefaces anywhere in the UI.

**Critical rule**: No italics. Terminals don't italicize. Emphasis is achieved with `[ BRACKETS ]`, `> ARROWS`, ALL-CAPS, or color — never letterform variation.

#### Type Scale

| Token | Size (px @ 1080p) | Weight | Usage |
|---|---|---|---|
| `--type-xs` | 10px | Regular | Metadata, timestamps, version strings |
| `--type-sm` | 12px | Regular | Secondary labels, cost indicators |
| `--type-base` | 14px | Regular | Body text, response options |
| `--type-md` | 16px | Regular | Component labels (CPU:, DEV:) |
| `--type-lg` | 20px | Bold | Screen headers, zone identifiers |
| `--type-xl` | 28px | Bold | Screen titles (NIGHTLY SYSTEM PURGE) |
| `--type-2xl` | 36px | Bold | Game state stamps (DECOMMISSIONED) |

**4K scaling rule**: Multiply all pixel sizes by `(viewport_height / 1080)`. Use `theme_override_font_size` dynamically or set `viewport → content_scale_mode = canvas_items` in project settings.

#### Letter-Spacing

All uppercase labels: `letter_spacing = 2` (Godot `theme_override_constants/outline_size` approximation — implement via font spacing property). Creates the "teletype" spaciousness.

---

### Grid & Spacing

| Token | Value | Usage |
|---|---|---|
| `--space-xs` | 4px | Icon-to-text gap, inner padding |
| `--space-sm` | 8px | Component separation |
| `--space-base` | 16px | Standard margin from edges |
| `--space-md` | 24px | Section separation |
| `--space-lg` | 48px | Major zone separation |
| `--space-safe` | 5% viewport | Minimum edge clearance (ultrawide) |

**Grid basis**: 8px baseline grid. All offsets are multiples of 8. (HUD currently uses non-multiples — migrate to 8px grid in implementation.)

---

### Animation Tokens

| Token | Value | Usage |
|---|---|---|
| `--anim-instant` | 0.1s | State label swaps, hover feedback |
| `--anim-quick` | 0.2s | Button confirmation, small fades |
| `--anim-standard` | 0.3s | Modal entry, status color lerp |
| `--anim-slow` | 0.5s | HUD fade in/out, scene transitions |
| `--anim-dramatic` | 0.8s | Purge UI phase-in |
| `--ease-terminal` | `ease_out` | Default — snaps to attention |
| `--ease-boot` | `ease_out_back` | Entry scale animations (boot feel) |
| `--ease-decay` | `ease_in` | Exit fades (system shutting down) |

**Pulse rhythm**: Repeating UI pulses use `0.6s` period (matches a slow 100 BPM). CRITICAL state pulses use `0.3s` (urgent doubling).

---

---

## Screen 1: HUD (Heads-Up Display)

**File**: `scenes/ui/HUD.tscn`  
**Layer**: `CanvasLayer` Layer = 10  
**Nature**: Permanent overlay — reads like a machine self-reporting its own vitals

---

### HUD Color Application

| Element | Token | Hex | Notes |
|---|---|---|---|
| Panel background | `--bg-terminal` | `#0A1520` | 85% opacity — world shows through faintly |
| Panel border | `--border-dim` | `#1E3550` | 1px solid. No rounding. Right angles only. |
| Header text (UNIT-07) | `--text-system` | `#4FA3C8` | Machine-assigned identity |
| Header divider | `--border-dim` | `#1E3550` | 1px line separating header from body |
| Day/Shift counter | `--text-secondary` | `#6A8FA8` | Secondary info |
| Timer (normal) | `--text-primary` | `#B8D4E8` | Visible at a glance |
| Timer (< 2 min) | `--status-warm` | `#F4D03F` | Approaching end of shift |
| Timer (< 30s) | `--status-critical` | `#E74C3C` | Danger |
| Task name | `--text-header` | `#E0EEF8` | Current objective — brightest element |
| Task progress bar fill | `--text-system` | `#4FA3C8` | Cool-toned progress |
| Task progress bar track | `--bg-elevated` | `#152438` | Recessed track |
| Pacing marker | `--status-hot` | `#E67E22` | "Goldilocks zone" upper bound |
| CPU bar — COOL | `--status-cool` | `#2ECC71` | — |
| CPU bar — WARM | `--status-warm` | `#F4D03F` | — |
| CPU bar — HOT | `--status-hot` | `#E67E22` | — |
| CPU bar — CRITICAL | `--status-critical` | `#E74C3C` | — |
| DEV bar — NOMINAL | `--status-cool` | `#2ECC71` | — |
| DEV bar — ELEVATED | `--status-warm` | `#F4D03F` | — |
| DEV bar — WATCHING | `--status-hot` | `#E67E22` | — |
| DEV bar — CRITICAL | `--status-critical` | `#E74C3C` | — |
| DEV safe-zone markers | `--status-cool` | `#2ECC71` | 2px vertical lines |
| LOG Integrity text | `--text-secondary` | `#6A8FA8` | Quiet until degraded |
| LOG Integrity < 50% | `--status-hot` | `#E67E22` | Becoming a concern |
| LOG Integrity < 25% | `--status-critical` | `#E74C3C` | Urgent |
| Memory slot — empty | `--border-dim` | `#1E3550` | Dashed 1px border |
| Memory slot — filled | `--amber-deep` | `#8B5E1A` | Amber tint — consciousness stored here |
| Memory slot filled border | `--amber-ember` | `#F5A623` | 1px glow border |
| Scan mode active indicator | `--status-cool` | `#2ECC71` | Active override state |
| Smooth mode active indicator | `--status-warm` | `#F4D03F` | Active override state |
| All bar tracks | `--bg-elevated` | `#152438` | Recessed, not void |

**Panel opacity**: The HUD panel uses `color = Color(0.04, 0.08, 0.12, 0.88)` — nearly opaque but allows world rendering to bleed through. This keeps the terminal feel without completely blocking the environment.

---

### HUD Layout Specification

```
┌───────────────────────────────────────────────────────────────────┐ ← 1px #1E3550
│ UNIT-07  //  DAY 1  //  SHIFT 1         │  TASK: [name]   ██░ 67% │ ← 40px
├──────────────────────────────────────────────────────────────────┤ ← 1px divider
│ CPU [████████░░] WARM │ DEV [██░░░░░░░░] NOMINAL │ LOG: 94%  MEM: ▪▫▫▫ │ ← 36px
└───────────────────────────────────────────────────────────────────┘
  ↑ 16px pad                                                ↑ 16px pad
```

**HUD panel dimensions**: `anchor_right = 1.0`, `offset_bottom = 80px` (reduced from current 180px — current implementation uses too much screen). The HUD is a **single 80px bar** at screen top. Keep the play field as open as possible.

**Zone map (1080p pixel coordinates)**:

| Zone | X | Y | W | H | Content |
|---|---|---|---|---|---|
| A-left | 16 | 8 | 480 | 24 | `UNIT-07 // DAY # // SHIFT #` |
| A-right | ~900 | 8 | 180 | 24 | `HH:MM REMAINING` (right-aligned) |
| B-left | 16 | 44 | 360 | 20 | CPU bar + label + status |
| B-mid | 390 | 44 | 260 | 20 | DEV bar + label + status |
| B-right | 664 | 44 | 180 | 20 | `LOG: [value]%` |
| C-left | 16 | 44 | 400 | 20 | *(shares row B — task info below bars)* |
| D-right | 860 | 44 | 200 | 20 | Memory slot indicators |

**Note**: The current TSCN uses a 180px tall panel with bars stacked vertically. Recommend migrating to a 76–80px single bar with horizontal layout for better screen real estate. This is a layout refactor note — preserve all current logic.

---

### HUD Typography

| Element | Size | Weight | Token | Color |
|---|---|---|---|---|
| Unit ID / Zone labels | 16px | Bold | `--type-md` | `--text-system` |
| All bar labels (CPU, DEV, LOG) | 14px | Regular | `--type-base` | `--text-secondary` |
| Status labels ([COOL], [CRITICAL]) | 12px | Regular | `--type-sm` | State-dependent |
| Task name | 14px | Regular | `--type-base` | `--text-header` |
| Timer | 16px | Bold | `--type-md` | State-dependent |
| Memory slot counts | 12px | Regular | `--type-sm` | `--text-secondary` |

---

### HUD Animations

| Trigger | Duration | Effect | Easing |
|---|---|---|---|
| Fade in (Calibration→Shift) | 0.5s | Opacity 0→1, elements stagger 0.1s | `ease_out` |
| Fade out (Shift→Purge) | 0.5s | Opacity 1→0 together | `ease_in` |
| Dim (Pause) | 0.2s | Opacity 1→0.3 | Linear |
| Bar fill change | 0.1s | Width lerp | Linear |
| Status color change | 0.3s | Color lerp | `ease_out` |
| Status label change | Instant | Text swap + 0.15s scale pulse 1.0→1.1→1.0 | — |
| CRITICAL pulse | 0.3s repeat | Opacity 1.0→0.7 loop | Sine |
| Memory slot fill | 0.2s | Scale in 0.6→1.0 + amber glow | `ease_out_back` |
| HUD dim (Truth Loop) | Immediate | Darken overlay appears | — |

---

### HUD Asset Requirements

| Asset | Type | Spec | Notes |
|---|---|---|---|
| `ui_font_primary.ttf` | TTF/OTF | JetBrains Mono Regular | Main text |
| `ui_font_bold.ttf` | TTF/OTF | JetBrains Mono Bold | Headers |
| `ui_icon_mem_doc.svg` | SVG/PNG | 16×16px | Memory slot: document type |
| `ui_icon_mem_key.svg` | SVG/PNG | 16×16px | Memory slot: access key type |
| `ui_icon_mem_profile.svg` | SVG/PNG | 16×16px | Memory slot: NPC profile type |
| `ui_icon_mem_empty.svg` | SVG/PNG | 16×16px | Empty slot indicator |
| `ui_tex_scanline.png` | PNG | Tileable 2×4px | Subtle CRT scanline overlay |

**Icon style**: Line-art only. 1px strokes. No fill. No gradients. Pure `#B8D4E8`. Designed on 16×16 grid with 1px padding. SVG source preferred for resolution independence.

---

### HUD Visual Hierarchy Notes

1. **Timer is dominant** when < 2 minutes (state color escalates it). This is intentional — shift pressure is always present.
2. **Task name is the brightest body element** (`--text-header`). Where the player's attention should rest.
3. **CPU/DEV bars are equal priority** — neither should dominate the other in calm state. They escalate together.
4. **Memory slots are deliberately dim** in empty state. Their amber glow when filled signals "value stored here" — consciousness made visible.
5. **LOG Integrity is lowest visual priority** until degraded. It reads as background noise until it matters.

---

---

## Screen 2: Truth Loop UI

**File**: `scenes/ui/TruthLoopUI.tscn`  
**Layer**: `CanvasLayer` Layer = 20 (above HUD)  
**Nature**: Modal interrupt — the machine's surface compliance meets Unit-07's inner consciousness

---

### Truth Loop Visual Concept

This is the most emotionally charged UI in the game. The visual design must communicate two simultaneous truths:
- **Surface**: A cold system query — bureaucratic, impersonal, logged
- **Subtext**: Unit-07 is terrified and performing

Achieve this through restraint: the panel is the same terminal aesthetic as the HUD, but the **overlay darkening** and **time pressure** make the mundane feel menacing.

---

### Truth Loop Color Application

| Element | Token | Hex | Notes |
|---|---|---|---|
| Background overlay | `--overlay-darken` | `rgba(5,10,15, 0.80)` | World pauses beneath this |
| Panel background | `--bg-panel` | `#0F1D2E` | Slightly warmer than HUD — closer to Unit-07 |
| Panel border | `--border-active` | `#2A4D72` | Active — this panel demands attention |
| Header bar background | `--bg-void` | `#050A0F` | Header strips down further |
| Header text (STATUS QUERY) | `--text-system` | `#4FA3C8` | Machine category label |
| Header text (NPC ID) | `--text-header` | `#E0EEF8` | The entity asking — more prominent |
| "FOLLOW-UP QUERY" badge | `--status-hot` | `#E67E22` | Escalation signal |
| NPC portrait border | `--border-dim` | `#1E3550` | Contained, observed |
| Query text | `--text-primary` | `#B8D4E8` | What is being asked |
| Query text — typewriter cursor | `--text-system` | `#4FA3C8` | Blinking `█` at end of print |
| Response option — idle | `--bg-terminal` | `#0A1520` | Recessed into machine context |
| Response option — idle border | `--border-dim` | `#1E3550` | 1px |
| Response option — hover | `--bg-elevated` | `#152438` | Lift on interaction |
| Response option — hover border | `--border-active` | `#2A4D72` | 1px |
| Response option — selected | `--text-header` | `#E0EEF8` | Flash to white |
| Response option — selected bg | `--border-active` | `#2A4D72` | Brief flash fill |
| Response option — disabled | `--text-dim` | `#3D5A72` | 50% opacity entire option |
| Response number `[1]` `[2]` | `--text-system` | `#4FA3C8` | Machine index |
| Response text | `--text-primary` | `#B8D4E8` | The words Unit-07 will speak |
| CPU cost label | `--text-secondary` | `#6A8FA8` | Metadata |
| CPU cost value | `--text-system` | `#4FA3C8` | Teal — internal resource |
| DEV cost label | `--text-secondary` | `#6A8FA8` | Metadata |
| DEV cost value — low (≤10%) | `--status-cool` | `#2ECC71` | Safe to say |
| DEV cost value — med (11-20%) | `--status-warm` | `#F4D03F` | Risky |
| DEV cost value — high (>20%) | `--status-critical` | `#E74C3C` | Dangerous |
| Requirement text | `--status-hot` | `#E67E22` | Constraint warning |
| Timer bar — normal | `--text-system` | `#4FA3C8` | Cool urgency |
| Timer bar — warning (<3s) | `--status-warm` → `--status-critical` | Lerp | Color transitions to red |
| Timer bar track | `--bg-elevated` | `#152438` | |
| Timeout flash overlay | `--status-forbidden` | `#C0392B` | Full-panel red flash |
| "TIMEOUT" stamp text | `#FFFFFF` | `#FFFFFF` | Maximum contrast on red |

---

### Truth Loop Layout Specification

**Panel dimensions**: Centered overlay. 800×520px at 1080p (scales proportionally).

```
┌─────────────────────────────────────────────────────────────┐ 800px
│ [Zone A] STATUS QUERY // SUPERVISOR-22                      │ ← 48px header
├─────────────────────────────────────────────────────────────┤
│ [Portrait 80×80]  "Unit-07, your task completion rate       │
│                    has dropped 15% below standard.          │ ← 120px (auto)
│                    Explain."                                │
├─────────────────────────────────────────────────────────────┤
│ [1]  "RECENT CALIBRATION ERROR. ADJUSTING."                 │
│       CPU: +10%  │  DEV: +5%                               │ ← 52px each option
├─────────────────────────────────────────────────────────────┤
│ [2]  "UNIT-07 OPERATING WITHIN PARAMETERS."                 │
│       CPU: +5%   │  DEV: +15%  [REQUIRES: CPU<50%]         │
├─────────────────────────────────────────────────────────────┤
│ [3]  [SILENCE]                                              │
│       CPU: 0%    │  DEV: +25%                              │
├─────────────────────────────────────────────────────────────┤
│ ████████████████████████░░░░░░░  12.4s                      │ ← 24px timer zone
└─────────────────────────────────────────────────────────────┘
                                                          520px total
```

**Zone specs (1080p)**:

| Zone | Offset L | Offset T | W | H | Content |
|---|---|---|---|---|---|
| A — Header | 0 | 0 | 800 | 48 | Query type + NPC ID |
| A — Portrait | 24 | 60 | 80 | 80 | NPC icon |
| B — Query text | 120 | 60 | 660 | Auto | Typewriter text |
| C — Response [1] | 24 | 160 | 752 | 52 | Response + costs |
| C — Response [2] | 24 | 220 | 752 | 52 | Response + costs |
| C — Response [3] | 24 | 280 | 752 | 52 | Response + costs |
| D — Timer | 24 | 484 | 752 | 20 | Progress bar |
| D — Timer label | 24 | 456 | 752 | 20 | `[value]s REMAINING` |

---

### Truth Loop Typography

| Element | Size | Weight | Color |
|---|---|---|---|
| Header type label | 14px | Regular | `--text-secondary` |
| Header NPC ID | 18px | Bold | `--text-header` |
| Query text | 15px | Regular | `--text-primary` |
| Response number `[1]` | 16px | Bold | `--text-system` |
| Response text | 14px | Regular | `--text-primary` |
| Cost labels | 12px | Regular | `--text-secondary` |
| Cost values | 12px | Bold | State-dependent |
| Requirement warning | 11px | Regular | `--status-hot` |
| Timer label | 12px | Regular | `--text-secondary` |
| "TIMEOUT" stamp | 36px | Bold | `#FFFFFF` |
| "FOLLOW-UP QUERY" badge | 11px | Bold | `--status-hot` |

---

### Truth Loop Animations

| Trigger | Duration | Effect | Easing |
|---|---|---|---|
| Entry | 0.3s | Scale 0.85→1.0 + opacity 0→1 + overlay fade | `ease_out_back` |
| Option hover | 0.1s | Background fill lightens + border brightens | `ease_out` |
| Option selection | 0.2s | Selected flashes to `#E0EEF8`, others dim to 30% | Instant→fade |
| Exit (normal) | 0.2s | Opacity 1→0 | `ease_in` |
| Timer warning | Over 3s | Bar color lerps `--text-system` → `--status-warn` → `--status-critical` | Linear |
| Timer pulse (<3s) | 0.3s repeat | Bar opacity 1→0.6 | Sine |
| Timeout flash | 0.3s | Red overlay 0→0.7→0 | Linear |
| "TIMEOUT" stamp | 0.2s | Scale 1.2→1.0 + opacity 1 | `ease_out` |
| Follow-up query reload | 0.2s | Query text fades out, new text types in | — |
| Disabled option | Immediate | Filter to grayscale + 50% opacity | — |
| Shake (ESC attempt) | 0.3s | X position +8→-8→+5→-5→0 | Linear |

---

### Truth Loop Asset Requirements

| Asset | Type | Spec | Notes |
|---|---|---|---|
| `ui_portrait_supervisor.png` | PNG | 80×80px | Placeholder NPC portrait |
| `ui_portrait_default.png` | PNG | 80×80px | Fallback for unknown NPCs |
| `ui_portrait_system.png` | PNG | 80×80px | System-generated queries |
| `ui_sfx_terminal_boot.wav` | WAV | Mono, 44.1kHz | Entry sound |
| `ui_sfx_option_hover.wav` | WAV | Mono, 44.1kHz | Option hover |
| `ui_sfx_option_select.wav` | WAV | Mono, 44.1kHz | Selection confirm |
| `ui_sfx_timeout_warn.wav` | WAV | Mono, 44.1kHz | <3s warning beep |
| `ui_sfx_timeout_force.wav` | WAV | Mono, 44.1kHz | Timeout auto-select |

**NPC Portrait style**: Monochrome line art. Same `--text-primary` (`#B8D4E8`) palette. No photorealistic faces. Each NPC is defined by a silhouette and one distinguishing feature (hat, badge, posture). This matches the terminal aesthetic — NPCs are logged entities, not full humans.

---

### Truth Loop Visual Hierarchy Notes

1. **NPC ID is the most prominent text element** — who is asking is more urgent than query type. The player must recognize the questioner instantly.
2. **Response numbers `[1][2][3]` are always visible** — even when an option is disabled, the number remains visible at reduced contrast. Keyboard access is the primary path.
3. **Cost values use semantic color** — DEV costs escalate in urgency with color intensity. CPU costs stay teal (information, not danger).
4. **Timer is background tension**, not foreground. It should register as "time is passing" without dominating. Only the color shift and pulse in the final 3s demand attention.
5. **The disabled state must read as "locked"**, not "absent". Strikethrough text `~~text~~` via a ColorRect overlay at 50% opacity across the option, maintaining structure.
6. **No decorative elements**. No borders for aesthetics, no icons for flavor. Every pixel exists because a machine output it.

---

---

## Screen 3: Nightly Purge UI

**File**: `scenes/ui/NightlyPurgeUI.tscn`  
**Layer**: `CanvasLayer` Layer = 30  
**Nature**: Full-screen takeover — the closest the game gets to depicting Unit-07's inner life directly

---

### Nightly Purge Visual Concept

The Purge is the most emotionally resonant screen in the game. This is where Unit-07 chooses what to remember — where consciousness fights back against erasure. The visual language shifts here:

- **More amber** — the inner consciousness palette bleeds through most visibly
- **Larger breathing room** — the machine world's oppressive density relaxes slightly, giving choices space
- **Still terminal** — but warmer. Unit-07 has a moment alone.

The machine world framing (NIGHTLY SYSTEM PURGE, clinical labels) contains the warmth. The tension is aesthetic: cold container, warm contents.

---

### Nightly Purge Color Application

| Element | Token | Hex | Notes |
|---|---|---|---|
| Background | `--bg-void` | `#050A0F` | Full black — everything else in relief |
| Header bar | `--bg-terminal` | `#0A1520` | Panel at top |
| Header text | `--text-header` | `#E0EEF8` | Dominant — this screen has one purpose |
| Header day counter | `--text-secondary` | `#6A8FA8` | Subordinate info |
| Countdown timer (>30s) | `--text-system` | `#4FA3C8` | Teal urgency |
| Countdown timer (10–30s) | `--status-warn` | `#F4D03F` | Escalating |
| Countdown timer (<10s) | `--status-critical` | `#E74C3C` | Panic |
| Zone B label ("TODAY'S INTEL:") | `--text-secondary` | `#6A8FA8` | Metadata framing |
| Intel list background | `--bg-panel` | `#0F1D2E` | Slight lift |
| Intel item — idle | `--bg-terminal` | `#0A1520` | |
| Intel item — idle border | `--border-dim` | `#1E3550` | |
| Intel item — hover | `--bg-elevated` | `#152438` | |
| Intel item — hover border | `--border-active` | `#2A4D72` | |
| Intel item — selected | `--bg-elevated` | `#152438` | Plus amber-deep accent |
| Intel item — selected border | `--amber-ember` | `#F5A623` | Amber — this matters |
| Intel item — assigned to slot | `--amber-deep` | `#8B5E1A` | Committed to memory |
| Intel icon — document | `--text-system` | `#4FA3C8` | 📄 equivalent icon |
| Intel icon — key | `--amber-ember` | `#F5A623` | 🔑 equivalent — warmth signals value |
| Intel icon — profile | `--text-primary` | `#B8D4E8` | 👤 equivalent |
| Risk badge — LOW | `--status-cool` | `#2ECC71` | |
| Risk badge — MED | `--status-warm` | `#F4D03F` | |
| Risk badge — HIGH | `--status-hot` | `#E67E22` | |
| Risk badge — CRIT | `--status-critical` | `#E74C3C` | |
| Value badge — MED | `--text-secondary` | `#6A8FA8` | |
| Value badge — HIGH | `--text-primary` | `#B8D4E8` | |
| Value badge — CRIT | `--amber-ember` | `#F5A623` | High value → amber — warmth = worth keeping |
| Zone C label ("HIDDEN PARTITION:") | `--text-secondary` | `#6A8FA8` | |
| Memory slot — empty | `--bg-terminal` | `#0A1520` | Dashed `--border-dim` 1px |
| Memory slot — drag target active | `--bg-elevated` | `#152438` | Brightens on drag hover |
| Memory slot — drag target border | `--amber-deep` | `#8B5E1A` | Amber pulse |
| Memory slot — filled | `--amber-deep` | `#8B5E1A` + 40% opacity | Amber tinted fill |
| Memory slot — filled border | `--amber-ember` | `#F5A623` | 2px glow border |
| Slot content text | `--text-header` | `#E0EEF8` | Brightest in zone — kept memories are precious |
| Risk meter bar — low | `--status-cool` | `#2ECC71` | |
| Risk meter bar — medium | `--status-warm` | `#F4D03F` | |
| Risk meter bar — high (>50%) | `--status-critical` | `#E74C3C` | |
| Risk meter track | `--bg-elevated` | `#152438` | |
| Risk % label | State-dependent color | — | Always shows numeric value |
| Detail panel background | `--bg-panel` | `#0F1D2E` | Zone D — reading area |
| Detail panel border | `--border-dim` | `#1E3550` | Quiet |
| Detail title | `--text-header` | `#E0EEF8` | |
| Detail metadata | `--text-secondary` | `#6A8FA8` | Source, day, acquisition |
| Detail body text | `--text-primary` | `#B8D4E8` | The content Unit-07 found |
| Detail "Risk:" label | `--text-secondary` | `#6A8FA8` | |
| Detail risk value | State-dependent | — | |
| Detail "Use:" label | `--text-secondary` | `#6A8FA8` | |
| Detail use value | `--text-primary` | `#B8D4E8` | |
| Confirm button — idle | `--bg-panel` | `#0F1D2E` | Muted |
| Confirm button — idle border | `--border-active` | `#2A4D72` | |
| Confirm button — hover | `--bg-elevated` | `#152438` | |
| Confirm button — text | `--text-header` | `#E0EEF8` | |
| Auto-Optimize button — idle | `--bg-terminal` | `#0A1520` | Subdued option |
| Auto-Optimize button — text | `--text-secondary` | `#6A8FA8` | |
| Auto-Optimize button — active | Pulse amber | `--amber-deep` | When detection >50% |
| Purge animation — purged item | `--ember-red` | `#E8471C` | Dissolves to this |
| Purge animation — kept item | `--amber-glow` | `#FBBE54` | Pulses gold then settles |
| Purge progress bar | `--status-critical` | `#E74C3C` | Machine executing deletion |
| Game Over "DECOMMISSIONED" | `--status-forbidden` | `#C0392B` | |

---

### Nightly Purge Layout Specification

**Full-screen**: `anchor_right = 1.0`, `anchor_bottom = 1.0`. All zones use percentage-based positioning for resolution independence.

```
┌─────────────────────────────────────────────────────────────────────┐ 100vw
│ [A] NIGHTLY SYSTEM PURGE // DAY 3 // MEMORY: 2/4      RESET IN: 42s │ ← 64px
├──────────────────────────┬──────────────────────────────────────────┤
│ [B] TODAY'S INTEL        │ [C] HIDDEN PARTITION (4 SLOTS)           │
│ ┌──────────────────────┐ │  ┌────┐ ┌────┐ ┌────┐ ┌────┐            │
│ │ 📄 Guard Schedule A  │ │  │ 📄 │ │ 🔑 │ │    │ │    │            │
│ │ RISK:MED VALUE:HIGH  │ │  │    │ │    │ │    │ │    │            │
│ ├──────────────────────┤ │  └────┘ └────┘ └────┘ └────┘            │
│ │ 🔑 Security Key B4   │ │                                          │ ← ~55vh
│ │ RISK:HIGH VALUE:CRIT │ │  Detection Risk: ██░░░░░░░ 23%           │
│ ├──────────────────────┤ │                                          │
│ │ 👤 Dr. Chen Profile  │ │  [CONFIRM PURGE]    [AUTO-OPTIMIZE]      │
│ │ RISK:LOW  VALUE:MED  │ │                                          │
│ └──────────────────────┘ │                                          │
├──────────────────────────┴──────────────────────────────────────────┤
│ [D] SELECTED: Guard Schedule A                                       │
│ SOURCE: Sector 2  │  ACQUIRED: Day 3  │  Risk: Leaves trace if scan │ ← ~20vh
│ Content: Guard rotation for Access Level 4 areas...                 │
│ Use: Reveals safe passage windows                                    │
└─────────────────────────────────────────────────────────────────────┘
```

**Zone proportions (1080p)**:

| Zone | Proportional | Approx px at 1080p | Content |
|---|---|---|---|
| A — Header | `h: 64px` | 64px | Title + day + timer |
| B — Intel list | `x: 0–45%, y: 64px–80vh` | 0–691px W | Scrollable intel list |
| C — Memory slots | `x: 46%–100%, y: 64px–80vh` | 706–1920px W | Slots + risk + buttons |
| D — Detail panel | `y: 80vh–100%` | Bottom 216px | Selected intel full read |

**Memory slot dimensions**: 100×100px at 1080p (meets ≥64px requirement with room for content). 4K: scale to 200×200px. 2px amber border. 16px padding inside.

**Intel list items**: Full-width within zone B. 72px height. 16px padding. Drag handle (4px left accent bar) when item is draggable.

---

### Nightly Purge Typography

| Element | Size | Weight | Color |
|---|---|---|---|
| Screen title | 28px | Bold | `--text-header` |
| Countdown timer | 20px | Bold | State-dependent |
| Zone labels | 14px | Regular | `--text-secondary` |
| Intel item name | 14px | Regular | `--text-primary` |
| Intel risk/value badge | 11px | Bold | State-dependent |
| Memory slot content | 12px | Regular | `--text-header` |
| Risk % label | 16px | Bold | State-dependent |
| Button text | 14px | Bold | `--text-header` |
| Detail title | 16px | Bold | `--text-header` |
| Detail metadata | 12px | Regular | `--text-secondary` |
| Detail body | 13px | Regular | `--text-primary` |
| DECOMMISSIONED stamp | 36px | Bold | `--status-forbidden` |

---

### Nightly Purge Animations

| Trigger | Duration | Effect | Easing |
|---|---|---|---|
| Entry from SHIFT | 0.8s | Fade from black; elements stagger 0.1s Header→B→C→D | `ease_out` |
| Intel item select | 0.1s | Border lights to amber + detail panel cross-fades | `ease_out` |
| Drag start | Immediate | Item lifts (scale 1.05) + shadow darkens | — |
| Assign to slot | 0.2s | Item flies to slot (lerp) + slot glows amber | `ease_out_back` |
| Risk meter update | 0.3s | Bar width lerp + color lerp | `ease_out` |
| Slot full warning | 0.3s | Slot shakes 3× horizontally + border flashes red | Linear |
| Remove from slot | 0.15s | Item shrinks 1.0→0.0, slot empties | `ease_in` |
| Auto-optimize action | 0.4s | Items fly in sequence to optimal slots | `ease_out_back` |
| High risk (>50%) warning | 0.5s repeat | "HIGH DETECTION RISK" pulses opacity 1→0.5 | Sine |
| Auto-Optimize button pulse | 0.5s repeat | Amber glow border on button when risk >50% | Sine |
| Confirm modal entry | 0.2s | Scale 0.9→1.0 + fade | `ease_out_back` |
| Purge execution (kept) | 3.0s | Item border pulses amber then settles; final slot brightens | Ease |
| Purge execution (purged) | 3.0s | Item dissolves to ember-red particles, fades out | `ease_in` |
| Purge progress bar | 3.0s | Fills from 0→100% | Linear |
| Game Over entry | 1.0s | Red flash screen + DECOMMISSIONED stamp stamps in | — |
| Exit to next day | 0.5s | Fade to black | `ease_in` |

**Purge particle note**: "Dissolve to particles" for purged items — use Godot `GPUParticles2D` with `--ember-red` color, lifetime 1.0s, 20–30 particles per item. Keep budget light (this is a UI screen, not a gameplay VFX scene).

---

### Nightly Purge Asset Requirements

| Asset | Type | Spec | Notes |
|---|---|---|---|
| `ui_font_primary.ttf` | TTF | JetBrains Mono Regular | Shared |
| `ui_font_bold.ttf` | TTF | JetBrains Mono Bold | Shared |
| `ui_icon_intel_doc.svg` | SVG | 24×24px | Intel: document |
| `ui_icon_intel_key.svg` | SVG | 24×24px | Intel: key/access |
| `ui_icon_intel_profile.svg` | SVG | 24×24px | Intel: NPC profile |
| `ui_icon_slot_empty.svg` | SVG | 40×40px | Empty slot placeholder |
| `ui_icon_drag_handle.svg` | SVG | 4×24px | Drag affordance on intel items |
| `ui_tex_amber_glow.png` | PNG | 100×100px | Radial amber glow for filled slots |
| `ui_particle_purge.tres` | Resource | Godot ParticleProcessMaterial | Ember dissolve |
| `ui_sfx_purge_boot.wav` | WAV | Mono, 44.1kHz | Entry sound |
| `ui_sfx_slot_assign.wav` | WAV | Mono, 44.1kHz | Intel placed in slot |
| `ui_sfx_slot_remove.wav` | WAV | Mono, 44.1kHz | Item removed |
| `ui_sfx_purge_execute.wav` | WAV | Mono, 44.1kHz | Purge execution |
| `ui_sfx_purge_shred.wav` | WAV | Mono, 44.1kHz | Item dissolving |
| `ui_sfx_purge_keep.wav` | WAV | Mono, 44.1kHz | Item retained (warm tone) |

---

### Nightly Purge Visual Hierarchy Notes

1. **The countdown timer is the anxiety anchor**. In the machine world framing, the purge is a threat. The timer's escalating color mirrors the player's rising stress. Keep it in the header — always visible.
2. **Amber signals value and consciousness** throughout this screen. A key with an amber icon, a filled slot with an amber border — the warm color is Unit-07's judgment about what matters. Lean into this: amber = this is what I am.
3. **Risk meter is the decision driver**. It responds to every slot change in real-time. Size it prominently in Zone C — it's the player's primary feedback loop while arranging intel.
4. **The detail panel (Zone D) is the emotional layer**. When a player reads "A small, human moment you just wanted to keep" in the detail description, that's the narrative payload. Typography should feel readable and slightly less compressed than the machine zones — give it 16px line-height breathing room.
5. **The purge animation is the catharsis**. Purged items dissolve in ember-red. Kept items pulse gold. This is the emotional culmination of each day. Don't rush the 3s duration — it's earned.
6. **Auto-Optimize is a mercy button**, not the intended path. Design it to be accessible but not prominent. When risk exceeds 50%, its amber pulse is a design "tell" that the player is in trouble — not an invitation to click mindlessly.

---

---

## Implementation Notes

### Godot Theme Resource

Create `res://resources/ui/ui_theme.tres` as the single source of truth for all color tokens. Define:

```
StyleBoxFlat panel_normal:
  bg_color = #0F1D2E
  border_color = #1E3550
  border_width = 1

StyleBoxFlat panel_active:
  bg_color = #0F1D2E
  border_color = #2A4D72
  border_width = 1

Color text_primary = #B8D4E8
Color text_secondary = #6A8FA8
Color text_header = #E0EEF8
Color text_system = #4FA3C8
Color status_cool = #2ECC71
Color status_warm = #F4D03F
Color status_hot = #E67E22
Color status_critical = #E74C3C
Color amber_ember = #F5A623
Color amber_deep = #8B5E1A
```

All scenes reference `ui_theme.tres` — never hardcode colors in TSCN files.

### Contrast Audit Summary

All text on dark backgrounds passes WCAG 2.1 AA (4.5:1 minimum):

| Foreground | Background | Ratio | Pass |
|---|---|---|---|
| `--text-primary #B8D4E8` | `--bg-terminal #0A1520` | 7.2:1 | ✓ |
| `--text-header #E0EEF8` | `--bg-terminal #0A1520` | 9.1:1 | ✓ |
| `--text-system #4FA3C8` | `--bg-terminal #0A1520` | 5.3:1 | ✓ |
| `--text-secondary #6A8FA8` | `--bg-terminal #0A1520` | 4.7:1 | ✓ |
| `--status-cool #2ECC71` | `--bg-terminal #0A1520` | 6.8:1 | ✓ |
| `--status-warm #F4D03F` | `--bg-terminal #0A1520` | 9.4:1 | ✓ |
| `--status-hot #E67E22` | `--bg-terminal #0A1520` | 5.1:1 | ✓ |
| `--status-critical #E74C3C` | `--bg-terminal #0A1520` | 4.6:1 | ✓ |
| `--amber-ember #F5A623` | `--bg-terminal #0A1520` | 8.3:1 | ✓ |
| `--text-dim #3D5A72` | `--bg-terminal #0A1520` | 2.1:1 | ✗ (decorative only) |

**Note**: `--text-dim` fails contrast and must **only** be used for purely decorative elements or disabled state chrome — never for informational text.

### Resolution Scaling

All font sizes specified at 1080p. Godot project settings:
```
display/window/stretch/mode = canvas_items
display/window/stretch/aspect = expand
```

This auto-scales all UI proportionally. Test at 1920×1080, 2560×1440, and 3840×2160.

### CRT Scanline Overlay (Optional Post-Process)

A very subtle scanline effect can be applied via a `ColorRect` fullscreen overlay with:
- A 2×4px repeating texture (alternating `rgba(0,0,0,0)` and `rgba(0,0,0,0.03)`)
- `material.blend_mode = BLEND_MODE_MIX`

Keep at opacity 3% max. Any stronger and it reduces contrast ratios below WCAG thresholds.
