---
status: draft
author: Sisyphus
date: 2026-04-26
---

# Accessibility Requirements

## Committed Accessibility Tier: **Standard**

This project commits to **Standard** tier accessibility as defined by studio guidelines.

---

## Standard Tier Requirements

### Visual Accessibility
- [x] **Color + Text**: No information conveyed by color alone; all color-coded elements have text labels or icons
- [x] **Contrast**: Text contrast ratio ≥ 4.5:1 for normal text, ≥ 3:1 for large text (18pt+)
- [x] **Focus Indicators**: All interactive elements have visible focus indicators for keyboard navigation
- [x] **Size**: Interactive elements minimum 44×44px touch targets

### Motor Accessibility
- [x] **Keyboard Complete**: All functionality accessible via keyboard-only (no mouse required)
- [x] **No Precision Required**: No interactions requiring pixel-perfect accuracy
- [x] **Timing**: Critical actions have adequate time or can be paused

### Cognitive Accessibility
- [x] **Clear Labels**: All UI elements have descriptive labels
- [x] **Consistent Patterns**: Reuse established interaction patterns throughout
- [x] **Error Prevention**: Confirm destructive actions; provide undo where possible

### Auditory Accessibility (Future)
- [ ] **Visual Alternatives**: Sound cues have visual counterparts
- [ ] **Captions**: All spoken/dialogue content has text display

### Screen Reader (Future - Post-Launch)
- [ ] **Announcements**: Critical state changes announced
- [ ] **Navigation**: Proper heading hierarchy and landmark regions

---

## Platform-Specific Notes

**Target Platform**: PC (Keyboard/Mouse)
**Gamepad**: Not supported (per adr-005-no-gamepad-support.md)
**Touch**: Not supported

### Keyboard Navigation Standards
- **Tab**: Move focus to next interactive element
- **Shift+Tab**: Move focus to previous interactive element
- **Enter/Space**: Activate focused element
- **Arrow Keys**: Navigate within groups (menus, grids)
- **Esc**: Cancel/close modal dialogs
- **Number Keys (1-9)**: Direct selection where applicable

---

## Per-Screen Compliance

| Screen | Status | Notes |
|--------|--------|-------|
| HUD | Compliant | Color + labels, keyboard shortcuts defined |
| Truth Loop | Compliant | Number key selection, arrow navigation, no color-only |
| Nightly Purge | Compliant | Drag + keyboard, icons + text, confirm protection |
| Main Menu | TBD | |
| Pause Menu | TBD | |
| Settings | TBD | |

---

## Testing Checklist

Before release, verify:
- [ ] All screens operable with keyboard-only
- [ ] All color states have non-color indicators
- [ ] Focus order is logical (left-to-right, top-to-bottom)
- [ ] No rapid flashing (avoiding seizure triggers)
- [ ] Text readable at 1080p and 4K resolutions

---

## Deferred to Post-Launch (Comprehensive Tier)

- Screen reader support
- Full closed captions
- High contrast mode
- Font size adjustment
- Motion reduction toggle (currently: animations always on)

These are acknowledged gaps to be addressed in future updates.
