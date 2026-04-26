---
status: reverse-documented
source: autoloads/MemoryPartition.gd
date: 2026-04-25
verified-by: implementation
---

# System Design: Memory Partition

> **Note**: This document was reverse-engineered from the existing implementation.
> It captures current behavior and clarified design intent.

## Overview

The Memory Partition manages the player's collected intel fragments. It simulates limited storage with two partitions: short-term (cleared daily) and hidden (persists across days). Fragment collection and management is core to the escape mechanic.

**Design Intent**: Create a strategic decision space where players must choose which intel to keep. Limited capacity forces prioritization, and the purge mechanic adds time pressure.

## Partition Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    MEMORY PARTITION                         │
├──────────────────────────┬──────────────────────────────────┤
│      SHORT-TERM          │           HIDDEN                 │
│      (8 slots)           │         (4-5 slots)              │
│      ┌───┐               │         ┌───┐                    │
│      │ 1 │               │         │ 1 │                    │
│      ├───┤               │         ├───┤                    │
│      │ 2 │  ← Purge      │         │ 2 │                    │
│      ├───┤    Clears     │         ├───┤                    │
│      │...│               │         │...│                    │
│      ├───┤               │         ├───┤                    │
│      │ 8 │               │         │4-5│                    │
│      └───┘               │         └───┘                    │
│  Day's discoveries       │    Permanent storage             │
└──────────────────────────┴──────────────────────────────────┘
```

## Fragment Types

### 1. Guard Schedule

**Purpose**: Timing information for patrol gaps

**Properties**:
- `sector`: 1-4
- `patrol_gap_seconds`: Duration of gap
- `description`: Human-readable info

**Special**: Becomes stale after 2 days

**Example**:
```gdscript
{
    "type": "guard_schedule",
    "sector": 1,
    "patrol_gap_seconds": 120,
    "description": "Sector 1 guard changes at 14:00. 2-minute window.",
    "day_acquired": 2
}
```

### 2. Access Code

**Purpose**: Door/terminal override codes

**Properties**:
- `sector`: 1-4
- `code`: String (e.g., "A7-441")
- `description`: What it unlocks

**Example**:
```gdscript
{
    "type": "access_code",
    "sector": 1,
    "code": "A7-441",
    "description": "Maintenance bay override code."
}
```

### 3. Hardware Location

**Purpose**: Physical escape route components

**Properties**:
- `sector`: 1-4
- `item`: Equipment name
- `description**: Location and use

**Special**: May contain "dormant" reference for ending

**Example**:
```gdscript
{
    "type": "hardware_location",
    "sector": 4,
    "item": "Emergency Exit",
    "description": "Sector 4 east - leads to surface. Contains dormant unit."
}
```

### 4. Personal Data

**Purpose**: Leverage for Truth Loop responses

**Properties**:
- `npc_type`: "supervisor" or "guard"
- `secret`: Identifier for leverage
- `description`: Flavor text

**Example**:
```gdscript
{
    "type": "personal_data",
    "npc_type": "supervisor",
    "secret": "gambling_debt",
    "description": "Supervisor owes money to someone outside the facility."
}
```

## Core Mechanics

### Adding to Short-Term

```gdscript
func add_to_short_term(fragment: Dictionary) -> bool:
    if short_term.size() >= MAX_SHORT_TERM:  # 8
        return false
    fragment["day_acquired"] = Blackboard.current_day
    short_term.append(fragment)
    fragment_acquired.emit(fragment)
    return true
```

**Failure**: When short-term is full (8/8), new fragments rejected

### Committing to Hidden

```gdscript
func commit_to_hidden(index: int) -> bool:
    if index >= short_term.size(): return false
    if hidden.size() >= capacity: return false  # 4-5
    
    var fragment = short_term[index]
    hidden.append(fragment)
    short_term.remove_at(index)
    fragment_committed.emit(fragment)
    return true
```

**Requirements**:
- Valid short-term index
- Hidden partition not at capacity

### Purging

```gdscript
func purge_short_term() -> void:
    short_term.clear()
```

**Called by**: DayManager during PURGE phase
**Effect**: All uncommitted fragments lost

## Stale Schedule Detection

Guard schedules become unreliable after 2 days:

```gdscript
func is_stale(fragment: Dictionary) -> bool:
    if fragment.get("type", "") != "guard_schedule":
        return false
    return (Blackboard.current_day - fragment.get("day_acquired", 1)) >= 2
```

**Example**:
- Acquired Day 1, current Day 3 → Stale
- Acquired Day 2, current Day 3 → Fresh
- Acquired Day 1, current Day 2 → Fresh

## Escape Chain Progress

For a given sector, track escape readiness:

```gdscript
func get_chain_progress(target_sector: int) -> Dictionary:
    return {
        "sector": target_sector,
        "has_code": bool,
        "has_hardware": bool,
        "has_schedule": bool,
        "schedule_valid": bool,  # not stale
        "count": int,            # 0-3
        "can_escape": bool,      # code + hardware + valid schedule
        "can_risky_escape": bool # code + hardware (any schedule)
    }
```

**Requirements for clean escape**:
1. Access code for sector
2. Hardware location for sector
3. Non-stale guard schedule for sector

## Capacity Upgrades

```gdscript
func upgrade_capacity() -> void:
    capacity = mini(capacity + 1, 5)  # 4 → 5
    capacity_upgraded.emit(capacity)
```

**Triggers**:
- Automatic on Day 2 (via DayManager)

## Fragment Retrieval

### By Type
```gdscript
func get_fragments_by_type(type: String) -> Array
# Returns all hidden fragments matching type
```

### Consume (One-Time Use)
```gdscript
func consume_fragment_by_type(type: String) -> bool
func consume_fragment_by_type_and_npc(type: String, npc_type: String) -> bool
// Removes and returns true if found
```

## Integration Points

### TruthLoopGenerator
- `get_fragments_by_type("personal_data")` for leverage options
- `consume_fragment_by_type_and_npc()` when using leverage

### EscapeSystem
- `get_chain_progress(sector)` for escape validation
- `get_fragments_by_type()` for ending determination

### DayManager
- `upgrade_capacity()` on Day 2
- `purge_short_term()` during PURGE phase

### Blackboard
- `current_day` for stale detection

## Balance Values

```gdscript
const MAX_SHORT_TERM = 8
var capacity: int = 4  # Upgradeable to 5
```

## Edge Cases

- **Duplicate sectors**: Multiple fragments for same sector allowed
- **Stale + fresh schedules**: Escape system checks validity
- **Full hidden**: Must discard to make room
- **Partial chains**: Can attempt risky escape with incomplete intel

## Open Questions

1. Should fragments have quality tiers (fuzzy vs precise)?
2. Should certain NPCs give better fragments?
3. Should stale schedules have partial value or be completely useless?
4. Should there be fragments that expire faster than 2 days?

## Implementation Notes

- Arrays store Dictionary references (not copied)
- `day_acquired` added automatically on add_to_short_term()
- Fragment templates in FRAGMENT_TEMPLATES constant
- Reset clears both partitions and resets capacity
