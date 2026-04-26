# ADR-001: Blackboard Pattern for Global State

**Status**: Accepted  
**Date**: 2026-04-25  
**Deciders**: Project initialization team

## Context

Awakening requires multiple systems (CPU management, deviation tracking, day cycle, memory, audit) to share state and communicate. We needed to decide on an architecture for cross-system data flow.

### Requirements
- Global access to player state (CPU, deviation, current day)
- Loose coupling between systems
- Testability — ability to mock state for unit tests
- Godot 4.6 / GDScript compatibility

### Alternatives Considered

1. **Direct References** — Systems hold direct references to each other
   - *Pros*: Simple, no indirection
   - *Cons*: Tight coupling, circular dependency risk, hard to test

2. **Dependency Injection** — Pass references via constructor
   - *Pros*: Testable, explicit dependencies
   - *Cons*: Verbose in GDScript, complex initialization order

3. **Blackboard Pattern** — Central autoload singleton all systems read/write
   - *Pros*: Decoupled, signal-based, Godot-native via autoloads
   - *Cons*: Global state (anti-pattern risk), needs discipline

4. **Event Bus Only** — Pure pub/sub with no shared state
   - *Pros*: Maximum decoupling
   - *Cons*: State reconciliation complexity, harder to debug

## Decision

**Adopt the Blackboard pattern** as the primary global state architecture.

Key implementation choices:
- `Blackboard.gd` as an autoload singleton
- Signals for state change notification (`cpu_changed`, `deviation_changed`)
- Systems write to Blackboard, emit signals, other systems react
- No direct method calls between systems

## Consequences

### Positive
- ✅ Systems are decoupled — can refactor one without touching others
- ✅ Godot-native — uses autoloads and signals idiomatically
- ✅ Debuggable — all state visible in one place
- ✅ Testable — can mock Blackboard state in unit tests

### Negative
- ⚠️ Global state — requires discipline to avoid spaghetti
- ⚠️ No compile-time safety — typos in signal names fail at runtime
- ⚠️ Signal order matters — initialization race conditions possible

### Mitigations
- Document all Blackboard fields and signals
- Use string constants for signal names (or strong typing where possible)
- Initialize systems in consistent order via autoload priority
- Unit tests validate signal emission, not just state changes

## References
- `autoloads/Blackboard.gd` — implementation
- `docs/TechSpec_Awakening.md` — architecture overview
- GDD §5.1 — State Machine (Dual-State Architecture)
