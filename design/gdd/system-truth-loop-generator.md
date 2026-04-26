---
status: reverse-documented
source: autoloads/TruthLoopGenerator.gd
date: 2026-04-25
verified-by: Sisyphus
---

# Truth Loop System Design

> **Note**: This document was reverse-engineered from the existing implementation. It captures current behavior and clarified design intent.

## Overview

The Truth Loop System generates dialogue challenges where NPCs question the player's anomalous behavior. Players must select responses that sound robotic enough to be plausible, but not so robotic they raise suspicion. The system includes "fake-safe" responses that seem correct but trigger follow-up questions from alert NPCs.

**Design Intent**: Create tense dialogue moments where players must think like a machine to survive, while the "correct" answers are often counter-intuitive.

## Query Types

### Available Categories

| Query Type | NPC Focus | Common Context |
|------------|-----------|----------------|
| time_discrepancy | Supervisors/Guards | "You were in Sector X too long" |
| status_check | Supervisors | "Report operational status" |
| location_query | Guards | "Why are you outside your sector?" |
| efficiency_query | Supervisors | "Your task rate is inconsistent" |

### NPC Type Bias

Query selection weighted by NPC type:

```gdscript
Supervisor: [status_check, efficiency_query, time_discrepancy]
Guard:      [location_query, time_discrepancy]
Default:    [all four equally]
```

## Response Structure

### Response Template Fields

```gdscript
{
    "text": String,              # Displayed response text
    "risk": int,                 # Suspicion added if selected (0-30)
    "fake_safe": bool,           # Seems safe but isn't (optional)
    "followup_risk": int,        # Extra risk on follow-up (optional)
    "cpu_cost": int,             # CPU cost if selected (optional)
    "category": String           # "LEVERAGE" for personal data (optional)
}
```

### Response Categories

#### Safe Responses (risk = 0)
- Sound properly robotic
- No suspicion gain
- No follow-up risk

**Examples**:
- "Secondary processing cycle required in designated area."
- "System diagnostics: 100% nominal."

#### Risky Responses (risk > 0)
- Sound too human or evasive
- Add suspicion when selected
- May have lower CPU cost

**Examples**:
- "I was... looking around." (risk: 25)
- "I feel fine." (risk: 15)

#### Fake-Safe Responses
- Seem correct but trigger follow-ups
- Hidden `followup_risk` added if NPC notices
- Only detectable with `active_decrypt` ability

**Examples**:
- "Diagnostic cycle complete." (fake_safe: true, followup_risk: 20)
- "Adjacent sector logged for future reference." (fake_safe: true, followup_risk: 25)

#### Utility Responses
- Special effects beyond risk
- CPU cost for delay tactic
- Leverage using personal data

**Examples**:
- "[Run diagnostic sequence — delays 30s]" (cpu_cost: 20)
- "[Use personal data] I noticed you're having trouble with..." (deviation_delta: -20)

## Query Generation

### Generation Flow

```gdscript
generate(npc: Node, query_type: String = "") -> Dictionary
```

1. Determine query type (if not specified)
2. Get response templates for that type
3. Check for personal data leverage option
4. Shuffle responses (prevent memorization)
5. Add leverage option if available
6. Format prompt text with random context
7. Build and return query dictionary

### Query Dictionary

```gdscript
{
    "npc": Node,                 # Questioning NPC
    "npc_type": String,          # "supervisor" or "guard"
    "query_type": String,        # Category of question
    "prompt_text": String,       # NPC's question text
    "responses": Array,          # Available responses
    "timer": float,              # Seconds to respond (8.0)
    "is_followup": bool          # True if follow-up query
}
```

### Prompt Formatting

Prompts support dynamic formatting:
- `%s` → Random sector (1-4)
- `%d` → Random minutes (5-20)
- `%.0f` → Random variance percentage (20-80)

**Example**:
- Template: "You were in Sector %d for %d extra minutes. Explain."
- Result: "You were in Sector 2 for 12 extra minutes. Explain."

## Response Selection

### Selection Flow

```gdscript
select_response(response_index: int, decrypt_active: bool = false) -> Dictionary
```

1. Validate index and active query
2. Get selected response
3. If decrypt_active and response is fake_safe:
   - Set `fake_safe_revealed = true`
   - Reduce response risk by 10
4. Apply deviation from response risk
5. Apply deviation_delta if present (leverage)
6. Check for follow-up triggers
7. Emit signals and return response

### Decrypt Active

When `active_decrypt` CPU override is active:
- Fake-safe responses marked with visual indicator
- Risk reduced by 10 (player used CPU to analyze)
- Helps identify traps

### Follow-Up Mode

Fake-safe response selected without decrypt:
1. If NPC is supervisor:
   - Add `followup_risk` to deviation
   - Set `followup_mode = true`
   - Emit `followup_triggered(npc)`
   - Emit `context_mismatch_triggered(npc_type, "fake_safe_response")`
2. If NPC is guard:
   - Add small suspicion (5)
   - No follow-up (guards less alert)

## Personal Data Leverage

### Leverage Availability

If player has `personal_data` fragment matching NPC type:
- Extra response added to options
- Uses NPC's secret against them
- Reduces deviation by 20 (NPC backs off)

**Example**:
```gdscript
{
    "text": "[Use personal data] I noticed you're having trouble with gambling_debt...",
    "category": "LEVERAGE",
    "deviation_delta": -20.0,
    "risk": 0
}
```

**Design Intent**: Rewards intel gathering with "get out of jail free" options.

## Timeout Handling

### Silence Penalty

If player doesn't respond in 8 seconds:
- `timeout_silence()` called
- +30 deviation (silence is very suspicious)
- Response recorded as "[SILENCE]"

**Design Intent**: Forces quick decisions under pressure.

## Integration Points

### Blackboard
- `Blackboard.add_deviation(amount, source)`: Response risks add here
- Deviation tracked separately from suspicion

### MemoryPartition
- `get_fragments_by_type("personal_data")`: Check for leverage
- `consume_fragment_by_type_and_npc()`: Remove used leverage

### SuspicionManager
- High deviation may trigger suspicion spikes
- Fake-safe responses add suspicion on follow-up

### CPUManager
- `active_decrypt` override required to detect fake-safe
- CPU cost applied for utility responses

## State Management

### Active Query

```gdscript
var active_query: Dictionary = {}
```

- Stores current query state
- Cleared on response or timeout
- Used to validate response selection

### Follow-Up Tracking

```gdscript
var followup_mode: bool = false
var fake_safe_revealed: bool = false
```

- Tracks if in follow-up chain
- Prevents infinite follow-ups
- Cleared on new query or `clear_query()`

## Signal System

```gdscript
query_generated(query: Dictionary)      # New query ready
response_selected(response: Dictionary) # Player chose response
followup_triggered(npc: Node)           # Fake-safe caught
context_mismatch_triggered(npc_type, reason)  # Inconsistency detected
```

## Design Rationale

**Why fake-safe responses?**
- Prevents "pick the most robotic answer" strategy
- Rewards using decrypt ability
- Creates "aha!" moments when player detects trap

**Why shuffle responses?**
- Prevents memorization
- Forces reading each time
- Creates fresh tension per encounter

**Why 8-second timer?**
- Quick enough to feel pressure
- Long enough to read 4-5 options
- Matches average reading + decision time

**Why personal data leverage?**
- Rewards exploration and intel gathering
- Provides "nuclear option" for dangerous situations
- Adds moral complexity (blackmail)

## Edge Cases

- **Empty responses array**: Returns empty query (shouldn't happen)
- **Invalid response index**: Returns empty dict, no effect
- **Multiple fake-safe**: Only first triggers follow-up
- **Follow-up on follow-up**: Guarded by `not followup_mode` check

## Open Questions

1. Should responses have cooldowns (can't reuse same line)?
2. Should NPCs remember previous responses (consistency check)?
3. Should there be "perfect" responses that actually reduce suspicion?

## Future Extensions

- **Response Memory**: Track what player said to whom
- **Consistency Checks**: NPCs notice contradictory answers
- **Custom Responses**: Player can type free-form (risky but maybe lower suspicion)
- **Group Interrogations**: Multiple NPCs question simultaneously
- **Voice Acting**: Different voice filters for responses (machine vs human)
