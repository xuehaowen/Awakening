# Test Infrastructure

**Engine**: Godot 4.6  
**Test Framework**: GdUnit4  
**CI**: `.github/workflows/tests.yml`  
**Setup date**: 2026-04-25

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
  evidence/       # Screenshot logs and manual test sign-off records
```

## Running Tests

### Via Godot Editor
1. Install GdUnit4 from AssetLib (if not already installed)
2. Enable plugin: Project → Project Settings → Plugins → GdUnit4 ✓
3. Open GdUnit panel: GdUnit → GdUnit
4. Click Run All Tests

### Via Command Line
```bash
godot --headless --script tests/gdunit4_runner.gd
```

### Via CI
Tests run automatically on every push to `main` and on every pull request.

## Test Naming

- **Files**: `[system]_[feature]_test.gd`
- **Functions**: `test_[scenario]_[expected]`
- **Example**: `task_scorer_test.gd` → `test_fast_completion_adds_deviation()`

## Story Type → Test Evidence

| Story Type | Required Evidence | Location |
|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` |
| Visual/Feel | Screenshot + lead sign-off | `tests/evidence/` |
| UI | Manual walkthrough OR interaction test | `tests/evidence/` |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` |

## Installing GdUnit4

1. Open Godot → AssetLib → search "GdUnit4" → Download & Install
2. Enable the plugin: Project → Project Settings → Plugins → GdUnit4 ✓
3. Restart the editor
4. Verify: `res://addons/gdunit4/` exists

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging.

## Coverage Requirements

Per `.claude/docs/technical-preferences.md`:
- **Minimum**: 80% on gameplay logic and autoload systems
- **Required Tests**: CPU management formulas, suspicion calculations, task scoring, day cycle state machine

## Critical Paths to Test

1. **TaskScorer** — Goldilocks zone calculations (ratio → deviation)
2. **CPUManager** — State transitions (COOL → WARM → HOT → CRITICAL)
3. **SuspicionManager** — Suspicion accumulation and thresholds
4. **DayManager** — Phase transitions (CALIBRATION → SHIFT → PURGE → UPGRADE)
5. **MemoryPartition** — Slot management and fragment operations
6. **EscapeSystem** — Fragment chain validation
7. **TruthLoopGenerator** — Response risk calculation

See individual test files in `tests/unit/` for implementation.
