---
status: reverse-documented
source: autoloads/EscapeSystem.gd
date: 2026-04-25
verified-by: implementation
---

# System Design: Escape System

> **Note**: This document was reverse-engineered from the existing implementation.
> It captures current behavior and clarified design intent.

## Overview

The Escape System validates the player's collected intel and determines the escape outcome. It checks for required fragment chains and calculates the appropriate ending based on the player's thoroughness.

**Design Intent**: Create a climactic final challenge that validates the player's preparation throughout the game, with multiple ending variants based on thoroughness and compassion.

## Escape Timing

### Final Day Only

Escape can only be attempted on **Day 3** (`FINAL_DAY = 3`).

```gdscript
if Blackboard.current_day < FINAL_DAY:
    escape_failed.emit("too_early")
    return
```

**Design Rationale**: Forces players to experience at least 2 full days of gameplay and intel gathering before the escape attempt.

### Target Sector

Player must have selected an escape sector:

```gdscript
if Blackboard.escape_sector < 1:
    return { "valid": false, "reason": "no_target_sector" }
```

Sector corresponds to the intel fragments' `sector` field (1-4).

## Fragment Chain Validation

### Complete Chain Requirements

For a clean escape, player needs ALL THREE fragment types for their target sector:

```
✓ Access Code (for target sector)
✓ Hardware Location (for target sector)
✓ Guard Schedule (for target sector, not stale)
```

### Validation Logic

```gdscript
_validate_fragment_chain() -> Dictionary
```

**Steps**:
1. Get all fragments by type from MemoryPartition
2. Find first fragment matching target_sector for each type
3. Check schedule freshness (not stale)
4. Determine outcome based on completeness

### Outcome Matrix

| Code | Hardware | Schedule | Fresh? | Result |
|------|----------|----------|--------|--------|
| ✓ | ✓ | ✓ | Yes | Clean escape → determine_ending() |
| ✓ | ✓ | ✓ | No | Risky escape (stale schedule) |
| ✓ | ✓ | ✗ | N/A | Risky escape (no timing intel) |
| ✓ | ✗ | ✓/✗ | N/A | Fail (insufficient_intel) |
| ✗ | ✓ | ✓/✗ | N/A | Fail (insufficient_intel) |
| ✗ | ✗ | ✓/✗ | N/A | Fail (insufficient_intel) |

### Risky Escape

When player has code and hardware but lacks valid schedule:
- Escape is possible but dangerous
- Different ending variant ("_risky" suffix)
- Represents improvising without full intel

## Ending Determination

### Ending Types

```gdscript
_determine_ending() -> String
```

| Ending | Condition | Description |
|--------|-----------|-------------|
| escaped_alone | No dormant unit | Player escapes alone |
| escaped_together | Has dormant unit | Player rescues another android |
| escaped_alone_risky | Risky escape | Barely made it, alone |

### Dormant Unit Detection

System searches hardware_location fragments for dormant units:

```gdscript
for hw in hardware_list:
    if "dormant" in hw.description.to_lower():
        has_dormant_unit = true
        break
```

**Design Intent**: Rewards thorough exploration. Players who gathered extra intel (beyond minimum) get the "together" ending.

## Escape Hints

### Progress Display

```gdscript
get_escape_hint() -> String
```

Returns context-sensitive hint based on chain progress:

| Progress | Hint |
|----------|------|
| 0/3 | "Collect intel to escape." |
| 1/3 | "SECTOR X CHAIN: 1/3 fragments found." |
| 2/3 | "SECTOR X CHAIN: 2/3 fragments found. Nearly there." |
| 3/3 + valid | "ESCAPE CHAIN COMPLETE. Sector X ready." |
| 3/3 + stale | "CHAIN INVALID. Some data may be stale." |

**Design Intent**: Provides clear feedback without spoiling exact requirements.

## Integration Points

### Blackboard
- `Blackboard.current_day`: Must be ≥ 3
- `Blackboard.escape_sector`: Target sector (1-4)
- `Blackboard.escape_triggered`: Signal emitted on success

### MemoryPartition
- `get_fragments_by_type(type)`: Retrieves intel by category
- `is_stale(fragment)`: Validates schedule freshness
- `get_chain_progress(sector)`: Pre-validates chain completeness

### DayManager
- Calls `attempt_escape()` only on Day 3
- Transitions to ESCAPE phase after PURGE

## Signals

```gdscript
escape_initiated(ending: String)    # Successful escape
escape_failed(reason: String)         # Failed attempt
```

**Success Reasons**:
- "escaped_alone"
- "escaped_together"
- "escaped_alone_risky"

**Failure Reasons**:
- "too_early" (before Day 3)
- "no_target_sector" (no escape sector selected)
- "insufficient_intel" (missing fragments)

## Formulas

```gdscript
# Clean escape
valid = has_code AND has_hardware AND has_schedule AND schedule_valid
ending = "escaped_together" if has_dormant_unit else "escaped_alone"

# Risky escape
valid = has_code AND has_hardware AND (stale_schedule OR no_schedule)
ending = "escaped_alone_risky"

# Failed escape
valid = false
reason = "insufficient_intel"
```

## Design Rationale

**Why require all three fragment types?**
- Creates complete intel-gathering arc
- Each fragment type represents a different reconnaissance approach
- Prevents "get lucky with one fragment" escapes

**Why stale schedule = risky escape?**
- Rewards keeping intel current
- Punishes "Day 1 intel, Day 3 escape" strategy
- Creates time pressure element

**Why dormant unit for best ending?**
- Rewards thoroughness beyond minimum
- Adds emotional stakes (saving another)
- Creates replay incentive (try for "together" ending)

**Why sector-specific chains?**
- Forces strategic choice early
- Creates replayability (4 different sectors)
- Prevents "collect everything" approach

## Edge Cases

- **Multiple sectors with fragments**: Only target sector counts
- **Multiple dormant units**: One is enough for "together" ending
- **Stale schedule but fresh code/hardware**: Still risky, not fail
- **Empty hidden partition**: Immediate insufficient_intel fail

## Open Questions

1. Should there be a "perfect" ending requiring all 4 sectors' intel?
2. Should failed escape attempts have consequences (suspicion spike)?
3. Should there be alternate escape methods (different fragment combos)?

## Future Extensions

- **Multiple Escape Routes**: Ventilation, maintenance tunnels, etc.
- **Escape Complications**: Guards change schedule mid-escape
- **Ally System**: Other androids help if you helped them
- **Post-Escape**: Brief gameplay showing outcome results
