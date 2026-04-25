extends Control

func _ready():
	# Connect buttons
	$VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)
	
	# Fade in
	modulate = Color.TRANSPARENT
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)

func _on_start_pressed() -> void:
	AudioManager.play_ui_sound("start_game")
	# Fade out then change scene
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	tween.finished.connect(_load_game)

func _load_game() -> void:
	get_tree().change_scene_to_file("res://scenes/world/Facility.tscn")

func _on_quit_pressed() -> void:
	AudioManager.play_ui_sound("quit")
	get_tree().quit()
