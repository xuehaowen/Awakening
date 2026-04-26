# Accessibility Audit: UI Screens — All Three Implemented Screens
**Date:** 2026-04-25
**Auditor:** Accessibility Specialist (accessibility-specialist agent)
**Scope:** HUD, TruthLoopUI, NightlyPurgeUI — Standard Tier compliance review
**Standard:** WCAG 2.1 Level AA · Studio Accessibility Standard Tier
**Platform:** PC (Keyboard/Mouse) · Godot 4.6 / GDScript

---

## Audit Summary

| Screen | Verdict | Critical Blockers | High Issues | Medium Issues | Low/Advisory |
|--------|---------|-------------------|-------------|---------------|--------------|
| **HUD** | ⚠️ **CONCERNS** | 0 | 2 | 3 | 2 |
| **TruthLoopUI** | ✅ **PASS** | 0 | 1 | 2 | 2 |
| **NightlyPurgeUI** | ⚠️ **CONCERNS** | 0 | 2 | 3 | 3 |

**Overall verdict: CONCERNS — not blocking release, but remediation required before Polish milestone.**

---

## Screen 1: HUD

**Files:** `scenes/ui/HUD.tscn` · `scripts/ui/HUD.gd`

### PASS Checklist

- [x] **Color + Text (SC 1.4.1):** All status states pair color with text label. CPU bar shows `[COOL]`/`[WARM]`/`[HOT]`/`[CRITICAL]`. DEV bar shows `[NOMINAL]`/`[ELEVATED]`/`[WATCHING]`/`[CRITICAL]`. TimerLabel text changes alongside color.
- [x] **Timer urgency has text:** Timer shows `"00:00 REMAINING"` in addition to color coding — color alone is not the carrier.
- [x] **Task name label present:** `TASK: [name] [SEC#]` — sector and task name shown in text, not color-only.
- [x] **Override indicators are text:** `[SCANNING]` / `[SMOOTH NAV]` labels appear when overrides are active — not icon-only.
- [x] **Memory slot tooltips exist:** Both empty (`"EMPTY SLOT"`) and filled (fragment description) tooltip text is set. Gives keyboard/mouse-hover users text feedback.
- [x] **F1 keyboard shortcut for memory overlay works:** Implemented in `_unhandled_input`. Toggle correctly hidden when not in SHIFT phase.
- [x] **Feedback messages include text:** `_show_feedback_text()` always provides both a message string and color — content is legible without color discrimination.
- [x] **HUD is display-only / no interactive elements requiring focus:** Appropriate — HUD is a readout, not a form. No mouse-required interactions.

### FINDINGS

| # | Finding | WCAG Criterion | Severity | Recommendation |
|---|---------|----------------|----------|----------------|
| H1 | **DEV bar safe-zone markers convey information via color/position alone.** `SafeZoneLeft` and `SafeZoneRight` are 2px `ColorRect` lines on the DEV progress bar with no text label, no tooltip, and no aria-equivalent annotation. The "Goldilocks zone" boundaries are invisible to anyone who cannot distinguish the green markers from the bar. | SC 1.4.1 Use of Color | **HIGH** | Add a `tooltip_text` to the DEVBar node: `"Safe zone: 15–30% deviation"`. Alternatively, add a small Label above/below the DEVBar reading `"SAFE: 15–30%"` or show the range in the `DEVStateLabel` text when NOMINAL. |
| H2 | **Task PacingMarker is color + position only.** The orange `PacingMarker` ColorRect on TaskProgressBar marks the Goldilocks upper bound with a small "140%" label at 9px font. At 9px this label is below the 14px minimum defined in the Standard tier requirements and is likely illegible at 1080p viewing distance. | SC 1.4.4 Resize Text · SC 1.4.1 Use of Color | **HIGH** | Increase `PacingLabel` font size to ≥ 12px. Consider replacing with a text legend near the task label such as `SAFE < 140%`. |
| H3 | **Memory slot state conveyed only by border/background color change.** Filled vs empty slots differ by amber vs dim border — no label difference in the mini-slot icons in ZoneD. The `tooltip_text` provides text differentiation but only on hover; keyboard-only users who never hover will not see this unless they also use the F1 overlay. | SC 1.4.1 Use of Color | MEDIUM | The tooltip is a valid technique but can be paired with a dedicated accessible text announcement. Add a visual count label such as `"MEM: 2/5"` (already present in Zone D — good!). Ensure keyboard-only users are prompted that `[F1] = Memory Inspector` somewhere on the HUD. |
| H4 | **Feedback label is not announced to keyboard/focus-based users.** The floating `FeedbackLabel` appears at screen center when tasks complete. It is not a focus element and there is no Godot 4 `AccessibilityManager` announcement. Users in keyboard-only mode may miss it if they are not looking at screen center. | SC 4.1.3 Status Messages | MEDIUM | This is a known gap in Godot 4 engine-level screen reader support (deferred to Post-Launch per the requirements doc). At Standard tier, recommend at minimum ensuring FeedbackLabel `z_index` is high enough to not be obscured by animations. Log as a tracked gap for Comprehensive tier. |
| H5 | **CPU bar CRITICAL pulse uses opacity change only.** The `_pulse_critical` tween pulses alpha 1.0→0.7. Flickering content can trigger photosensitivity in some users. Frequency is 0.6s full period — within the WCAG 2.3.1 safe-flash threshold (< 3 Hz) and is not a blocker, but warrants tracking. | SC 2.3.1 Three Flashes or Below Threshold | ADVISORY | The 0.3s half-period pulse is safe at ~1.67 Hz. Document and track; add a `reduce_motion` toggle in Settings (deferred to Comprehensive tier per requirements). |
| H6 | **No on-screen keyboard legend for F1.** Players must already know that F1 opens the Memory Inspector. No hint is displayed on the HUD to discover this shortcut. | SC 3.3.2 Labels or Instructions | LOW | Add a tooltip on the ZoneD_MemorySlots area (`tooltip_text = "[F1] Memory Inspector"`) or a small `[F1]` label in the corner of Zone D. |

---

## Screen 2: TruthLoopUI

**Files:** `scenes/ui/TruthLoopUI.tscn` · `scripts/ui/TruthLoopUI.gd`

### PASS Checklist

- [x] **Number keys 1/2/3 functional:** `_unhandled_input` handles `KEY_1`, `KEY_2`, `KEY_3` — direct selection. ✅
- [x] **Arrow keys (Up/Down) navigate options:** `_navigate_options()` correctly skips disabled/hidden buttons. ✅
- [x] **Enter confirms focused button:** `_confirm_focused_response()` checks which button has `.has_focus()`. ✅
- [x] **ESC handled gracefully:** ESC calls `_shake_panel()` — does not crash or exit illegally. UI communicates that ESC does not dismiss the modal. ✅
- [x] **Buttons meet 44×44px minimum:** All three `ResponseButton` nodes have `custom_minimum_size = Vector2(0, 56)` — height exceeds minimum. ✅
- [x] **focus_mode = FOCUS_ALL (2) on all response buttons:** Tab/arrow navigation will work. ✅
- [x] **Keyboard shortcut `[1]` / `[2]` / `[3]` visible in button text:** Button text format `"[1]  …"` — keyboard affordance is visible. ✅
- [x] **Disabled options reduced to 50% opacity:** `btn.modulate.a = 0.5` — reduced but still visible. Spec-compliant. ✅
- [x] **Tooltip on each button:** `tooltip_text = "CPU: +X%  |  DEV: +X%"` — cost information available as text. ✅
- [x] **Timer has text label:** `TimerValueLabel` shows `"8s REMAINING"` text alongside color-changing TimerBar. ✅
- [x] **FollowUpBadge is text ("FOLLOW-UP QUERY"), not color-only.** ✅
- [x] **Query type label is text, not color-only:** `QueryTypeLabel` shows `"STATUS QUERY"` / `"SYSTEM QUERY"`. ✅
- [x] **Context mismatch feedback is inline text:** `_on_context_mismatch()` appends colored text with message — not color-only. ✅
- [x] **TIMEOUT stamp is text label (`"TIMEOUT"`)** — color overlay is supplemental, not the sole indicator. ✅
- [x] **No simultaneous button press required.** All interactions are single-key. ✅

### FINDINGS

| # | Finding | WCAG Criterion | Severity | Recommendation |
|---|---------|----------------|----------|----------------|
| T1 | **Disabled response buttons have no text explanation for *why* they are disabled.** When a button is unavailable (CPU too high), the button shows dimmed text but no label explaining the cause. A player relying on keyboard-only navigation would see a skipped option with no explanation. The `tooltip_text` shows `"CPU: +X% | DEV: +X%"` but not the threshold that prevents selection. | SC 1.3.1 Info and Relationships · SC 4.1.2 Name, Role, Value | **HIGH** | Update the disabled button tooltip to include the constraint: `"CPU: +X%  |  DEV: +X%  [REQUIRES CPU < Y%]"`. The string is already stored as `btn.get_meta("requires_cpu_below")` — it just needs to appear in the tooltip text. This is a one-line fix in `_populate_responses()`. |
| T2 | **Timer bar color-state transition has no secondary indicator at the critical threshold.** When ≤3s remain, the TimerBar transitions from blue to red via lerp. The text label updates accurately, but there is no non-color indicator (e.g., a blinking text, shake animation, or symbol prefix) added at the warning moment. Users who cannot distinguish the red-to-blue lerp rely entirely on the `TimerValueLabel` text — which does update, so this is mitigated but not ideal. | SC 1.4.1 Use of Color | MEDIUM | At the `TIMER_WARNING_THRESHOLD` moment, append a `"⚠"` or `"!"` symbol to the `TimerValueLabel` text, e.g. `"3s REMAINING !"`. Already very close to compliant — this is a minor enhancement. |
| T3 | **ESC produces a panel-shake animation but no text feedback.** When a player presses ESC (which is blocked), the panel shakes but nothing tells them *why* ESC doesn't close the dialog. Sighted users will infer from context, but this is not explicit. | SC 3.3.2 Labels or Instructions | MEDIUM | Consider adding a brief FeedbackLabel message such as `"RESPONSE REQUIRED — ESC DISABLED"` when ESC is pressed inside an active Truth Loop. This makes the constraint explicit for keyboard-first users. |
| T4 | **NPC portrait `TextureRect` has no alt-text equivalent.** `_npc_portrait.texture = null` (placeholder). When assets are integrated, the portrait will display an NPC image with no accessible description. Godot 4 does not expose `alt` attributes natively, but best-practice is to ensure the NPC's identity is provided via the `NPCIDLabel` text, which it is. | SC 1.1.1 Non-text Content | ADVISORY | When portrait textures are added, ensure the NPC name and role is always shown in `NPCIDLabel` text. Current design satisfies this — track for asset integration phase. |

---

## Screen 3: NightlyPurgeUI

**Files:** `scenes/ui/NightlyPurgeUI.tscn` · `scripts/ui/NightlyPurgeUI.gd`

### PASS Checklist

- [x] **Tab cycles focus zones (intel → slots → buttons):** `_cycle_focus_zone()` implemented. ✅
- [x] **Arrow keys navigate intel list and slot grid:** `_move_intel_focus()` and `_move_slot_focus()` implemented. ✅
- [x] **Enter assigns intel to slot / confirms purge:** `_handle_enter_key()` handles all three focus zones. ✅
- [x] **Delete/Backspace removes intel from slot:** `KEY_DELETE` and `KEY_BACKSPACE` handled. ✅
- [x] **C key opens confirm modal:** `KEY_C` triggers `_request_confirm_purge()`. ✅
- [x] **A key runs auto-optimize:** `KEY_A` triggers `_auto_optimize()`. ✅
- [x] **ESC closes confirm modal (only):** ESC is always consumed; if `_is_confirming` it closes modal, otherwise does nothing. ✅
- [x] **Confirm modal exists for destructive purge action:** `_request_confirm_purge()` → modal shows keep/purge lists before committing. ✅
- [x] **Modal shows what will be kept/purged in text:** `modal_keep_list` and `modal_purge_list` display text summaries. ✅
- [x] **Modal buttons ≥ 44×44px:** `ModalCancelBtn` and `ModalConfirmBtn` `custom_minimum_size = Vector2(160, 48)`. ✅
- [x] **Filter buttons have focus_mode = FOCUS_ALL:** All three filter buttons are keyboard-navigable. ✅
- [x] **Intel rows have focus_mode = FOCUS_ALL and focus_entered signal:** `row.focus_mode = Control.FOCUS_ALL` and `row.focus_entered.connect()` are set in `_create_intel_row()`. ✅
- [x] **Detection risk shown with text + color:** `detection_value_label` shows `"Detection: X%"` text. ✅
- [x] **High risk warning is text label:** `HighRiskWarning` Label reads `"HIGH DETECTION RISK"`. ✅
- [x] **Intel row risk/value badges are text:** `"RISK:LOW"` / `"VAL:MED"` shown as text labels, color is supplemental. ✅
- [x] **Intel type shown in text:** `name_label.text = intel.get("type", "UNKNOWN").to_upper()` — not icon-only. ✅
- [x] **Countdown shows text:** `"RESET IN: 60s"` text alongside color change. ✅

### FINDINGS

| # | Finding | WCAG Criterion | Severity | Recommendation |
|---|---------|----------------|----------|----------------|
| N1 | **Intel row icon labels use `[D]`/`[K]`/`[P]`/`[?]` codes without explanation.** The icon column uses bracketed abbreviations (`[D]` = document, `[K]` = key, `[P]` = profile). There is no legend or tooltip explaining these codes. Keyboard-only users focusing the icon `Label` will see the code but not know what it means. The name label on the same row does contain the full type string, which partially mitigates this, but the icon column itself is ambiguous. | SC 1.4.1 Use of Color · SC 3.3.2 Labels or Instructions | **HIGH** | Add a `tooltip_text` to the `icon_label` in `_create_intel_row()` with the full expansion: e.g. `"[D] = Document"`, `"[K] = Access Key"`, `"[P] = Personal Profile"`. Alternatively, expand the icon text to the full word (the row has sufficient space), removing the ambiguity entirely. |
| N2 | **Active filter button state is color-only (`COLOR_AMBER_EMBER` modulate vs. `Color.WHITE`).** When a filter is active, the button is tinted amber but its text label does not change. A user who cannot distinguish amber from white will not know which filter is active. | SC 1.4.1 Use of Color | **HIGH** | Append `" ✓"` or `" [ON]"` to the active filter button text, or prepend `"[ALL]"` → `"[ALL ▶]"` for the active state. Change in `_set_filter()` — simple string swap. |
| N3 | **`FilterAllBtn` / `FilterNewBtn` / `FilterRiskBtn` are 32px tall** (`custom_minimum_size = Vector2(80, 32)`). This falls below the Standard tier 44×44px interactive element requirement. | SC 2.5.5 Target Size (minimum requirement equivalent) | MEDIUM | Increase `custom_minimum_size` from `Vector2(80, 32)` to `Vector2(80, 44)` for all three filter buttons in `NightlyPurgeUI.tscn`. |
| N4 | **Confirm modal has no initial focus set.** When the confirm modal opens via `_request_confirm_purge()`, focus is not programmatically moved to a button inside the modal. Keyboard users must Tab twice (or more) to reach the Cancel/Confirm buttons after the modal appears. | SC 2.4.3 Focus Order | MEDIUM | In `_request_confirm_purge()`, after `confirm_modal.show()`, add: `modal_cancel_btn.grab_focus()`. Cancel is the safer default per the error-prevention principle. |
| N5 | **Keyboard shortcut legend not visible on screen.** The comprehensive keyboard bindings (`Tab`, `↑↓`, `←→`, `Enter`, `Delete`, `C`, `A`) are not documented anywhere on the screen. Only the `CANCEL [ESC]` button hints at a shortcut. A player using keyboard-only navigation must discover all other shortcuts by trial. | SC 3.3.2 Labels or Instructions | MEDIUM | Add a collapsible help row or a small `[?]` button in the header that shows a keyboard shortcut legend. Alternatively, add `tooltip_text` strings to the main action buttons showing their shortcut: `confirm_purge_btn.tooltip_text = "Confirm Purge [C]"`, `auto_optimize_btn.tooltip_text = "Auto-Optimize [A]"`. The latter is a 2-line fix. |
| N6 | **Right-click to remove from slot is a mouse-only action.** Removing intel from a slot via right-click has no keyboard announcement. The `Delete`/`Backspace` key does handle this, but there is no visual hint that right-click is available or that Delete is the keyboard equivalent. | SC 2.1.1 Keyboard (all functionality) | LOW | The Delete/Backspace path exists and is functionally complete — this is primarily a discoverability issue. Mitigated by fixing N5 (keyboard legend). Add `"Right-click or [Del] to remove"` tooltip on slot panels. |
| N7 | **Left-accent `ColorRect` bar on intel rows conveys type category via color with no tooltip.** The 4px left-bar uses `_get_icon_color()` to differentiate `access_code` (amber) from `guard_schedule`/`hardware_location` (system blue) from `personal_data` (primary). This color distinction is not paired with a text alternative on the accent bar itself. However, the icon and name labels on the same row do contain the type text, so information is not *solely* conveyed by the accent color. | SC 1.4.1 Use of Color | ADVISORY | The accent bar is a purely decorative visual reinforcement; the type is already communicated by text labels. Document as intentional decorative element. No action required if the row text is always present. |

---

## Cross-Screen Findings

| # | Finding | Affected Screens | WCAG Criterion | Severity | Recommendation |
|---|---------|-----------------|----------------|----------|----------------|
| X1 | **Progress bars (`CPUBar`, `DEVBar`, `TaskProgressBar`, `TimerBar`, `DetectionMeter`, `PurgeProgressBar`) have no accessible value announcement.** `show_percentage = false` is set on all bars, meaning visual value is conveyed only via bar fill and color. All bars pair with a text label, which satisfies Standard tier. At Comprehensive tier, these would need programmatic value announcements. | HUD, TruthLoopUI, NightlyPurgeUI | SC 4.1.2 Name, Role, Value | ADVISORY (Standard) / HIGH (Comprehensive) | Accepted gap at Standard tier per `accessibility-requirements.md`. Track for Comprehensive tier. Each bar has a paired text label that carries the essential value. |
| X2 | **No motion-reduction option exists.** All screens have entry animations, tweens, scale pulses, and shake effects that run unconditionally. Players with vestibular disorders cannot disable these. | All screens | SC 2.3.3 Animation from Interactions | ADVISORY | Acknowledged in `accessibility-requirements.md` as deferred to Comprehensive tier. Document explicitly in release notes as a known gap. |
| X3 | **Font sizes are consistent across screens (12–28px) and meet minimum 12px threshold.** The 9px `PacingLabel` on the HUD is the only exception (flagged as H2 above). All other text is ≥ 12px. | All screens | SC 1.4.4 Resize Text | — | No issue except H2. |

---

## Remediation Priority

### Must-Fix Before Polish Gate

| ID | Screen | Action | Effort |
|----|--------|--------|--------|
| H1 | HUD | Add tooltip to DEVBar safe-zone markers | 15 min |
| H2 | HUD | Increase PacingLabel font size to ≥ 12px | 5 min |
| T1 | TruthLoopUI | Add CPU threshold to disabled button tooltip | 10 min |
| N1 | NightlyPurgeUI | Add tooltips to `[D]`/`[K]`/`[P]` icon labels | 20 min |
| N2 | NightlyPurgeUI | Add non-color indicator to active filter button | 15 min |
| N3 | NightlyPurgeUI | Increase filter button height to 44px | 5 min |
| N4 | NightlyPurgeUI | `grab_focus()` on Cancel button when confirm modal opens | 5 min |

### Should-Fix Before Release

| ID | Screen | Action | Effort |
|----|--------|--------|--------|
| H3 | HUD | Add F1 hint to Zone D area | 10 min |
| H6 | HUD | F1 discovery tooltip on memory slots | 5 min |
| T2 | TruthLoopUI | Add `"!"` suffix to timer label at warning threshold | 5 min |
| T3 | TruthLoopUI | Add ESC-blocked feedback text | 10 min |
| N5 | NightlyPurgeUI | Add keyboard shortcut tooltips to buttons | 15 min |
| N6 | NightlyPurgeUI | Add slot tooltip for right-click / Delete affordance | 10 min |

### Deferred (Acknowledged Gap — Post-Launch Comprehensive Tier)

- Screen reader announcements (SC 4.1.3 Status Messages)
- Motion reduction toggle (SC 2.3.3)
- Font size adjustment setting
- High contrast mode
- Full closed captions / audio alternatives

---

## WCAG 2.1 AA Compliance Status

| Criterion | HUD | TruthLoopUI | NightlyPurgeUI | Notes |
|-----------|-----|-------------|----------------|-------|
| 1.1.1 Non-text Content | ✅ | ⚠️ (T4) | ✅ | Mitigated by text labels |
| 1.3.1 Info and Relationships | ⚠️ (H1) | ⚠️ (T1) | ⚠️ (N1, N2) | Partially compliant |
| 1.4.1 Use of Color | ⚠️ (H1, H2) | ✅ | ⚠️ (N2) | All status states have text; edge cases flagged |
| 1.4.3 Contrast (Minimum) | ✅ | ✅ | ✅ | Dark background with high-contrast text palette |
| 1.4.4 Resize Text | ⚠️ (H2, 9px) | ✅ | ✅ | One violation (PacingLabel) |
| 2.1.1 Keyboard | ✅ | ✅ | ✅ | Full keyboard path exists for all actions |
| 2.4.3 Focus Order | N/A | ✅ | ⚠️ (N4) | Modal opens without focus transfer |
| 2.5.5 Target Size | ✅ | ✅ | ⚠️ (N3, 32px buttons) | Filter buttons too small |
| 3.3.2 Labels or Instructions | ⚠️ (H6) | ⚠️ (T3) | ⚠️ (N5) | Keyboard shortcuts undiscoverable |
| 4.1.2 Name, Role, Value | ✅ | ⚠️ (T1) | ✅ | Disabled state reason not exposed |
| 4.1.3 Status Messages | Advisory | Advisory | Advisory | Deferred per requirements doc |

---

## Overall Verdict

**No screen has a BLOCKING accessibility barrier** — all primary information is available via text, all core interactions have keyboard paths, and no information is conveyed by color alone at the critical-gameplay level.

**CONCERNS exist on HUD and NightlyPurgeUI** primarily around:
1. Status markers / filter states that supplement text with color but could fail in edge cases
2. Interactive element size (filter buttons sub-44px)
3. Focus management (confirm modal focus not set on open)
4. Undiscoverable keyboard shortcuts

**TruthLoopUI is the strongest screen** — it was clearly designed with accessibility in mind (explicit number key labels, focus_mode on all buttons, tooltip-encoded costs, arrow navigation with skip-disabled logic).

All BLOCKING and HIGH findings are low-effort fixes (< 1 hour total). Recommend addressing the Must-Fix items in a dedicated accessibility pass before the Polish gate.
