extends StaticBody2D
class_name IntelSource

@export var sector_id: int = 1

func _ready():
	add_to_group("intel_source")

func get_sector() -> int:
	return sector_id
