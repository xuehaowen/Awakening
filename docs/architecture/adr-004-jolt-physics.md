# ADR-004: Jolt Physics Engine

**Status**: Accepted  
**Date**: 2026-04-25  
**Deciders**: Project initialization team

## Context

Godot 4 introduced Jolt Physics as an alternative to the legacy Godot Physics engine. We needed to decide which physics backend to use for Awakening.

### Requirements
- Reliable 2D character movement
- Navigation mesh support for NPC pathfinding
- Consistent behavior across PC and Web
- No complex physics interactions (no platforming, no rigid body puzzles)

### Alternatives Considered

1. **Godot Physics** — Legacy physics engine
   - *Pros*: Battle-tested, default, well-documented
   - *Cons*: Slower, less accurate, some stability issues

2. **Jolt Physics** — Modern physics engine (default in Godot 4.6)
   - *Pros*: Faster, more stable, better collision detection
   - *Cons*: Newer, less community documentation

3. **Custom Movement** — No physics, pure tile/grid-based
   - *Pros*: Deterministic, simple, no engine dependency
   - *Cons*: No navmesh, no built-in collision

## Decision

**Use Jolt Physics (Godot 4.6 default).**

Key implementation choices:
- Use CharacterBody2D for player and NPCs
- NavigationAgent2D for pathfinding (works with Jolt)
- Simple collision shapes (boxes, circles)
- No rigid bodies — all kinematic control

## Consequences

### Positive
- ✅ Godot 4.6 default — no extra setup
- ✅ Better performance — faster collision detection
- ✅ More stable — fewer physics glitches
- ✅ Navigation mesh support — for NPC patrol routes

### Negative
- ⚠️ Less documentation — fewer community tutorials
- ⚠️ Newer — potential edge case bugs

### Mitigations
- Keep physics simple — no complex simulations
- Use CharacterBody2D (not RigidBody2D) for predictable movement
- Test movement extensively on both PC and Web

## References
- Project Settings → Physics → 2D Physics Engine
- `docs/engine-reference/godot/modules/physics.md`
- GDD §10 — Scene Structure
