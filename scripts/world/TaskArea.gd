extends Area2D
class_name TaskArea

@export var sector_id: int = 1
@export var task_tag: String = "general"

var player_inside: Node = null

func _ready():
	add_to_group("task_area")

	# Set up collision to detect player (layer 2)
	collision_layer = 0
	collision_mask = 2

	# Create subtle visual indicator so players can see task zones
	var visual: ColorRect = ColorRect.new()
	visual.color = Color(0.2, 0.5, 0.8, 0.08)
	visual.size = Vector2(100, 100)
	visual.position = Vector2(-50, -50)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)

	# Add a subtle border outline
	var border: Line2D = Line2D.new()
	border.width = 1.5
	border.default_color = Color(0.3, 0.6, 0.9, 0.2)
	border.points = PackedVector2Array([
		Vector2(-50, -50), Vector2(50, -50),
		Vector2(50, 50), Vector2(-50, 50),
		Vector2(-50, -50)
	])
	add_child(border)

	# Add sector label (subtle)
	var label: Label = Label.new()
	label.text = "SECTOR " + str(sector_id)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = Color(1, 1, 1, 0.25)
	label.set("theme_override_font_sizes/font_size", 12)
	label.position = Vector2(-50, -10)
	label.size = Vector2(100, 20)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	# Connect signals
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
		Blackboard.interaction_feedback.emit("[E] COMPLETE TASK", "info")
	else:
		body.is_at_task = false

func get_sector() -> int:
	return sector_id
