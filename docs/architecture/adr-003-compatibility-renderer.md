# ADR-003: Compatibility Renderer for Web Export

**Status**: Accepted  
**Date**: 2026-04-25  
**Deciders**: Project initialization team

## Context

Awakening targets both PC and Web (browser-playable) platforms. Godot 4 offers two rendering backends: Forward+ (modern, feature-rich) and Compatibility (OpenGL 3.3 / WebGL 2.0).

### Requirements
- PC desktop build (full features)
- Web browser export (jam submission requirement)
- Consistent visual style across platforms
- No duplicate asset pipelines

### Alternatives Considered

1. **Forward+ Renderer** — Modern Vulkan-based renderer
   - *Pros*: Better graphics, more features, default in Godot 4
   - *Cons*: Not supported in WebGL, requires separate web build pipeline

2. **Compatibility Renderer** — OpenGL 3.3 / WebGL 2.0 backend
   - *Pros*: Works on PC and Web, single build pipeline
   - *Cons*: Fewer advanced rendering features

3. **Dual Renderer** — Forward+ for PC, Compatibility for Web
   - *Pros*: Best quality on each platform
   - *Cons*: Double the testing, potential visual inconsistencies

## Decision

**Use Compatibility Renderer for all builds.**

Key implementation choices:
- Project setting: `rendering/renderer/rendering_method = "gl_compatibility"`
- Design art style around Compatibility renderer capabilities
- Test primarily on Web export to ensure PC performance is acceptable

## Consequences

### Positive
- ✅ Single renderer — one test matrix, consistent visuals
- ✅ Web-ready — no separate pipeline needed
- ✅ Broader compatibility — runs on older GPUs
- ✅ Faster iteration — export to web for quick testing

### Negative
- ⚠️ No advanced lighting — no VoxelGI, SDFGI
- ⚠️ Limited post-processing — some effects unavailable
- ⚠️ Lower visual ceiling — art style must be intentional, not default

### Mitigations
- Design around the constraint — industrial/clean aesthetic fits the theme
- Use 2D lighting and shaders for visual interest
- CRT effects via shaders (screen-space, not render-pipeline dependent)

## References
- Project Settings → Rendering → Renderer
- `docs/engine-reference/godot/modules/rendering.md`
- GDD §8 — Art & Audio Direction
