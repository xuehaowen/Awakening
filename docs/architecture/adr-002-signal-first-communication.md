# ADR-002: Signal-First Communication Architecture

**Status**: Accepted  
**Date**: 2026-04-25  
**Deciders**: Project initialization team

## Context

With Blackboard as the shared state store, we needed a communication mechanism for systems to react to changes without direct coupling.

### Requirements
- Decoupled system-to-system communication
- Godot-native patterns
- Observable for debugging and testing
- Support for both immediate and deferred reactions

### Alternatives Considered

1. **Direct Method Calls** — System A calls `SystemB.update_state()`
   - *Pros*: Simple, type-safe, synchronous
   - *Cons*: Tight coupling, circular dependencies, hard to refactor

2. **Callback/Delegate Pattern** — Pass function references
   - *Pros*: Flexible, C#-style events
   - *Cons*: Verbose in GDScript, memory management complexity

3. **Godot Signals** — Built-in observer pattern
   - *Pros*: Godot-native, loose coupling, visual in editor
   - *Cons*: String-based (runtime errors), slightly more overhead

4. **Custom Event Bus** — Central dispatcher with event types
   - *Pros*: Type-safe events, filtering, logging
   - *Cons*: Extra abstraction, not Godot-native

## Decision

**Adopt Godot Signals as the primary cross-system communication mechanism.**

Key implementation choices:
- Blackboard emits signals on state changes (`cpu_changed`, `deviation_changed`)
- Systems connect to relevant signals in `_ready()`
- No direct calls between autoloads except via Blackboard
- Signals use typed parameters where possible (GDScript 2.0)

## Consequences

### Positive
- ✅ Godot-idiomatic — uses engine features as intended
- ✅ Visual debugging — signal connections visible in editor
- ✅ Loose coupling — systems don't know about each other
- ✅ Testable — can spy on signal emissions

### Negative
- ⚠️ String-based connection — typos fail silently at runtime
- ⚠️ Connection management — must connect/disconnect carefully
- ⚠️ Order dependency — signal handlers may run in undefined order

### Mitigations
- Use `Callable` with method references instead of strings: `my_signal.connect(_on_my_signal)`
- Disconnect signals in `_exit_tree()` to avoid dangling references
- Document signal flow in system docs
- Integration tests verify signal chains

## References
- `autoloads/Blackboard.gd` — signal definitions
- `docs/TechSpec_Awakening.md` — "Signals over direct calls"
- Godot 4 Signal documentation
