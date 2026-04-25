extends Node2D

@onready var label: Label = $Label
@onready var color_rect: ColorRect = $ColorRect

var is_active: bool = false

func _ready():
	label.hide()
	color_rect.color = Color(0.2, 0.3, 0.25, 1.0)  # Darkened when inactive

func activate() -> void:
	is_active = true
	label.show()
	label.text = "ESCAPE TERMINAL [ACTIVE]"
	color_rect.color = Color(0.2, 0.6, 0.3, 1.0)  # Green when active

func interact(_player: Node) -> void:
	if not is_active:
		Blackboard.interaction_feedback.emit("TERMINAL INACTIVE", "error")
		return
	
	if Blackboard.current_day >= EscapeSystem.FINAL_DAY:
		EscapeSystem.attempt_escape()
	else:
		Blackboard.interaction_feedback.emit("TERMINAL LOCKED - Complete Day 3 first", "warning")
