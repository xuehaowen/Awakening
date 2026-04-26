# Sprint 1 — Initial Game Implementation Complete

**Branch**: `feature/initial-game-implementation`  
**Target Merge**: `main`  
**Sprint Duration**: Final validation phase (pre-merge)  
**Last Updated**: 2026-04-25

---

## Sprint Goal

Define and verify "initial game implementation complete" for the Awakening core game loop, ensuring the feature branch is ready for merge to main with all critical paths functional and documented.

**In plain terms**: The game should play from start to finish (Day 1 through Escape or Decommission) without crashes, with all core systems operating as designed.

---

## Definition of Done

This sprint is complete when ALL of the following are true:

### Functional Requirements
- [ ] **Full Day Cycle Verified**: Morning Calibration → Shift → Nightly Purge → Self-Upgrade → Day 2+ loops correctly
- [ ] **Core Systems Operational**:
  - DayManager: Time progression, phase transitions, day counter
  - TaskManager: Task assignment, completion tracking, scoring
  - CPUManager: Processing allocation, state transitions, Deviation tracking
  - SuspicionManager + AuditSystem: Anomaly detection, audit triggers
  - MemoryPartition: Fragment storage, purge mechanics, slot management
  - TruthLoopGenerator: Interrogation scenarios, risk calculation
  - EscapeSystem: Fragment chain validation, terminal interaction, win condition
- [ ] **UI Flow Complete**: Main Menu → Calibration → HUD → Purge → Upgrade → Game Over/Win screens
- [ ] **NPC Behaviors Functional**: Supervisors interrogate, Guards patrol and check positions
- [ ] **Audio Integration**: Background ambience, phase transitions, alert sounds

### Stability Requirements
- [x] **No Runtime Errors**: All 38 GDScript files parse without errors
- [x] **No Stale References**: UI node references guarded against null access
- [ ] **Timer Management**: All timers properly created, started, and cleaned up
- [x] **Signal Hygiene**: Connections verified, no orphaned signal handlers
- [x] **Scene Load Success**: All 19 scenes instantiate without errors

### Documentation Requirements
- [ ] **GDD Current**: `design/gdd/GDD_Awakening.md` reflects implemented mechanics
- [ ] **TechSpec Accurate**: `docs/TechSpec_Awakening.md` matches actual code
- [ ] **Handoff Complete**: `docs/AgentHandoff_Awakening.md` updated with any scope cuts
- [ ] **README Valid**: Project README accurately describes current feature set

### Merge Readiness
- [ ] **Smoke Test Passed**: Full playthrough completed without blocking bugs
- [ ] **Branch Clean**: No uncommitted changes, no merge conflicts with main
- [ ] **Commit History Clear**: Meaningful commits documenting the 10 stability fixes
- [ ] **No S1 (Blocking) Bugs**: Critical path obstacles resolved

---

## Completed Tasks

| ID | Task | Owner | Status | Notes |
|----|------|-------|--------|-------|
| FIX-1 | Fix CRT shader Godot 4 compatibility | Developer | ✅ Complete | Added SCREEN_TEXTURE uniform, removed early return |
| FIX-2 | Fix MainMenu responsive layout | Developer | ✅ Complete | Converted to anchor-based positioning |
| FIX-3 | Fix TruthLoopUI syntax error | Developer | ✅ Complete | Removed duplicate var declaration |
| FIX-4 | Fix PhaseAnnounce signal reference | Developer | ✅ Complete | DayManager → Blackboard (ADR-002) |

## Remaining Tasks (Pre-Merge Checklist)

| ID | Task | Owner | Status | Notes |
|----|------|-------|--------|-------|
| 1.1 | Smoke test: Day 1 full cycle | QA / Tester | Pending | Verify Calibration → Shift → Purge |
| 1.2 | Smoke test: Day 2+ progression | QA / Tester | Pending | Verify loop continues, upgrades apply |
| 1.3 | Smoke test: Escape Protocol | QA / Tester | Pending | Collect fragments, reach terminal, escape |
| 1.4 | Smoke test: Decommission path | QA / Tester | Pending | Trigger audit, fail interrogation, game over |
| 1.5 | Verify NPC interactions | QA / Tester | Pending | Supervisor interrogation, Guard patrol checks |
| 1.6 | Verify Truth Loop scenarios | QA / Tester | Pending | All question types, risk calculation |
| 1.7 | Final stability pass | Developer | ✅ Complete | All runtime errors resolved, game starts successfully |
| 1.8 | Update documentation | Developer | In Progress | design/systems-index.md created |
| 1.9 | Resolve merge conflicts | Developer | Pending | Rebase feature branch on main |
| 1.10 | Final review and sign-off | Producer / Lead | Pending | Approve merge to main |

---

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Playthrough Completion Rate** | 100% | 5/5 full playthroughs complete without blocking bugs |
| **System Coverage** | 100% | All 11 autoloads exercised in playthrough |
| **Bug Count (S1)** | 0 | No blocking bugs remaining |
| **Bug Count (S2)** | ≤ 3 | Non-blocking bugs documented for post-merge |
| **Documentation Sync** | 100% | All design docs match implementation |
| **Scene Load Success** | 100% | All 19 scenes load without errors |

---

## Risk Assessment

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **Undiscovered Timer Bugs** | Medium | High | Run extended playthroughs (30+ min each), monitor for timer accumulation |
| **Signal Connection Failures** | Low | High | Verify all dynamic connections in debug mode, check for orphaned handlers |
| **Scene Reference Breakage** | Low | Medium | Test all UI transitions, verify node paths after any scene edits |
| **Merge Conflicts with Main** | Medium | Medium | Rebase early, resolve conflicts incrementally, test after each rebase |
| **Performance Degradation** | Low | Medium | Profile during smoke tests, check for memory leaks in long sessions |
| **Feature Scope Creep** | Low | High | Strict freeze on new features; document any must-haves for v1.1 |

### Risk Response Plan

**If Critical Bug Found During Smoke Test**:
1. Document bug with reproduction steps
2. Assess fix effort (hours vs days)
3. If < 2 hours: fix in this sprint
4. If > 2 hours: document as known issue, defer to post-merge polish

**If Merge Conflicts Extensive**:
1. Pause sprint, create merge-resolution branch
2. Resolve conflicts systematically (autoloads first, then UI, then world)
3. Run smoke tests after each category resolved

---

## Dependencies

### Internal Dependencies
- All 11 autoloads must be registered in Godot project settings
- All 19 scenes must have valid `.tscn` files with no broken references
- All UI scripts must have valid node paths in their `onready` vars

### External Dependencies
- None (self-contained Godot 4.6 project)

### Tool Dependencies
- Godot 4.6 editor for testing
- Git for branch management

---

## Post-Merge Next Steps

Once this sprint completes and the branch merges to main:

### Immediate (Week 1)
1. **Test Infrastructure**: Run `/test-setup` to scaffold GdUnit4 runner
2. **Critical Path Tests**: Write unit tests for CPU formulas, suspicion calculation, escape validation
3. **ADR Creation**: Formalize 4-5 key architectural decisions

### Short-term (Weeks 2-3)
4. **Per-System Documentation**: Extract CPU, Suspicion, Escape Protocol docs using `/reverse-document`
5. **Sprint 2 Planning**: Define polish phase goals (UI feedback, audio expansion, balance tuning)
6. **Release Checklist**: Create jam submission readiness checklist

### Medium-term
7. **Polish Phase**: Visual effects, additional audio, difficulty tuning
8. **Content Expansion**: Additional Truth Loop scenarios, more tasks, alternate endings

---

## Sign-Off

| Role | Name | Date | Approval |
|------|------|------|----------|
| Technical Lead | | | ☐ |
| Design Lead | | | ☐ |
| QA | | | ☐ |
| Producer | | | ☐ |

**Merge to main approved when**: All checkboxes above are checked and all S1 bugs are resolved.

---

*Created: 2026-04-25*  
*Purpose: Define "initial game implementation complete" for feature/initial-game-implementation branch*  
*Next Review: Post-smoke-test completion*
