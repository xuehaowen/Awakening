# Smoke Test: Critical Paths

**Purpose**: Run these checks in under 15 minutes before any QA hand-off.  
**Run via**: `/smoke-check` (which reads this file)  
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to main menu without crash
2. New game / session can be started from the main menu
3. Main menu responds to all inputs without freezing

## Core Game Loop

4. Morning Calibration displays assigned tasks for the day
5. Shift timer starts and counts down correctly
6. Player can move and interact with task areas
7. Task completion updates deviation based on timing
8. CPU heat increases with overrides and triggers jitter at 90%+
9. NPCs trigger Truth Loops when suspicion is high
10. Nightly Purge screen allows memory fragment selection
11. Day transitions to next day after purge

## Data Integrity

12. Short-term memory accumulates intel fragments during shift
13. Hidden partition persists fragments across days
14. Audit log tracks task completion times

## Escape Protocol (Day 3)

15. Escape terminal becomes interactable on final day
16. Valid fragment chain triggers escape sequence
17. Invalid chain shows failure message

## Performance

18. No visible frame rate drops on target hardware (60fps target)
19. No memory growth over 5 minutes of play
