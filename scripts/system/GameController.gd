#[class_name GameController]
extends Node

func _ready():
	esc_triggered.connect(_on_escape_triggered)

func _on_escape_triggered(ending: String):
	print("Escape completed: ", ending)

func _on_escape_triggered(ending: String):
	print("Escape sequence completed:", ending)
