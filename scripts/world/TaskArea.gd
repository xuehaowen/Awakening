extends Area2D
class_name TaskArea

@export var sector_id: int = 1
@export var task_tag: String = "general"

var player_inside: Node = null

func _ready():
	add_to_group("task_area")
	
	# Connect area signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Re-evaluate when a new task is assigned (player may already be inside)
	TaskManager.task_assigned.connect(_on_task_assigned)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = body
		_update_player_task_state(body)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside = null
		body.is_at_task = false

func _on_task_assigned(_task: Dictionary) -> void:
	# If player is already inside this area, re-evaluate when task changes
	if player_inside:
		_update_player_task_state(player_inside)

func _update_player_task_state(body: Node) -> void:
	var current_task = TaskManager.get_current_task()
	if not current_task.is_empty() and current_task.get("sector", 0) == sector_id:
		body.is_at_task = true
		print("Player in task area for sector ", sector_id, " - task ready to complete")
	else:
		body.is_at_task = false

func get_sector() -> int:
	return sector_id
