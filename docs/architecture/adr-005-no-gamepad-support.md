# ADR-005: Keyboard/Mouse Only — No Gamepad Support

**Status**: Accepted  
**Date**: 2026-04-25  
**Deciders**: Project initialization team

## Context

Awakening is a social stealth / puzzle game with specific input requirements: WASD movement, modifier key holds (Shift, Ctrl), and precise menu navigation. We needed to decide on input method scope.

### Requirements
- PC desktop target (primary)
- Web browser target (secondary)
- Simple input mapping
- Quick iteration (no peripheral testing)

### Alternatives Considered

1. **Full Input Abstraction** — Support keyboard, gamepad, touch
   - *Pros*: Maximum accessibility, modern standard
   - *Cons*: Complex input mapping, testing burden, UI navigation redesign

2. **Keyboard/Mouse + Gamepad** — Dual support
   - *Pros*: Accessibility for controller users
   - *Cons*: UI navigation needs two modes, testing overhead

3. **Keyboard/Mouse Only** — Single input method
   - *Pros*: Simple, focused, matches terminal aesthetic
   - *Cons*: No controller support, less accessible

4. **Keyboard Only (No Mouse)** — Pure keyboard
   - *Pros*: Even simpler, retro feel
   - *Cons*: Menu navigation awkward, limits UI design

## Decision

**Support Keyboard/Mouse only. No gamepad or touch support.**

Key implementation choices:
- Input actions: movement (WASD), overrides (Shift, Ctrl, Tab), interact (E)
- Mouse for UI navigation
- No Joypad input actions mapped
- UI focuses on keyboard shortcuts (terminal aesthetic)

## Consequences

### Positive
- ✅ Simple input mapping — 6 actions total
- ✅ Matches aesthetic — terminal/command-line theme
- ✅ Faster iteration — no controller testing
- ✅ Web-friendly — keyboard works in all browsers

### Negative
- ⚠️ Less accessible — players with mobility issues may struggle
- ⚠️ No couch play — must play at desk
- ⚠️ Niche — some players expect controller support

### Mitigations
- Remappable keys — allow players to customize
- Simple controls — only movement + 4 modifiers
- Clear UI — show keybindings on screen
- Future consideration — gamepad could be added post-jam

## References
- Project Settings → Input Map
- `docs/TechSpec_Awakening.md` — §9 Input Map
- GDD §9 — UI / UX Design
- `.claude/docs/technical-preferences.md` — Input & Platform
