class_name EscapeSystem
extends Node

const FINAL_DAY := 3

func attempt_escape() -> void:
	var current_day = Blackboard.current_day
	if current_day >= FINAL_DAY:
		Blackboard.interaction_feedback.emit("ESCAPE INITIATED", "success")
		Blackboard.escape_triggered.emit("ESCAPE COMPLETED - Day " + str(current_day))
		print("ESCAPE SUCCESS! Day ", current_day)
	else:
		Blackboard.interaction_feedback.emit("ESCAPE NOT YET AVAILABLE", "warning")
