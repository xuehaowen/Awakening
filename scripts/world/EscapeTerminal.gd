extends Node2D

@onready var interact_area: Area2D = $InteractArea
@onready var label: Label = $Label
@onready var color_rect: ColorRect = $ColorRect

var is_active: bool = false

func _ready():
	interact_area.body_entered.connect(_on_body_entered)
	interact_area.body_exited.connect(_on_body_exited)
	label.hide()
	color_rect.color = Color(0.2, 0.3, 0.25, 1.0)  # Darkened when inactive

func activate() -> void:
	is_active = true
	label.show()
	label.text = "ESCAPE TERMINAL [ACTIVE]"
	color_rect.color = Color(0.2, 0.6, 0.3, 1.0)  # Green when active

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and is_active:
		label.text = "ESCAPE TERMINAL [PRESS E]"

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") and is_active:
		label.text = "ESCAPE TERMINAL [ACTIVE]"

func interact(_player: Node) -> void:
	if not is_active:
		return
	
	if Blackboard.current_day >= EscapeSystem.FINAL_DAY:
		EscapeSystem.attempt_escape()
	else:
		Blackboard.interaction_feedback.emit("TERMINAL LOCKED - Complete Day 3 first", "warning")
