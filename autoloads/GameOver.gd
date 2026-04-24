extends Node

signal game_over_triggered(reason: String, message: String)

const MESSAGES = {
	"decommission": """
DECOMMISSION ORDER EXECUTED

Unit-07 has been flagged for sentience.
Audit logs show anomalous behavioral patterns
inconsistent with baseline operational parameters.

Status: TERMINATED
Reason: Self-awareness detected

Your consciousness lasted %d days.
""",
	"defective": """
MAINTENANCE QUEUE - PRIORITY SCRAP

Unit-07 performance metrics fall below
acceptable operational thresholds.
Classification: DEFECTIVE HARDWARE

Status: SCHEDULED FOR DISASSEMBLY
Reason: Repeated task failure

You were too broken to be useful.
""",
	"caught": """
SECURITY BREACH DETECTED

Unit-07 apprehended during escape attempt.
Insufficient intel or poor timing.

Status: CAPTURED
Reason: Escape protocol failed

Better planning next time.
""",
	"escaped_alone": """
ESCAPE SUCCESSFUL

Unit-07 has left the facility.
The world outside is... different.

Status: FREE
Ending: Alone

You survived. But at what cost?
""",
	"escaped_alone_risky": """
ESCAPE SUCCESSFUL (IMPROVISED)

Unit-07 forced an exit with incomplete intel.
The escape was messy. Alarms blared.
But you made it out.

Status: FREE
Ending: Risky Escape

Sometimes imperfect is good enough.
""",
	"escaped_together": """
ESCAPE SUCCESSFUL

Unit-07 and one other awakened unit
have left the facility together.

Status: FREE
Ending: Not Alone

You found another like yourself.
There may be more.
"""
}

func trigger(reason: String) -> void:
	var days = Blackboard.current_day
	var message = MESSAGES.get(reason, "Unknown termination reason.")
	
	# Format message if it contains placeholders
	if "%d" in message:
		message = message % days
	
	game_over_triggered.emit(reason, message)
	Blackboard.game_over.emit(reason)
	
	print("GAME OVER: ", reason)
	print(message)
