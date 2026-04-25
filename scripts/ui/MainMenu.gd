extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var title_label: Label = $TitleLabel
@onready var subtitle_label: Label = $SubtitleLabel

var button_tweens: Dictionary = {}

func _ready():
	# Connect buttons
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Add hover effects
	_setup_button_hover(start_button)
	_setup_button_hover(quit_button)
	
	# Fade in
	modulate = Color.TRANSPARENT
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)
	
	# Start ambient sound
	AudioManager.start_facility_ambient()

func _setup_button_hover(button: Button) -> void:
	button.mouse_entered.connect(func():
		AudioManager.play_ui_sound("hover")
		_tween_button_modulate(button, Color.CYAN, 0.15)
	)
	button.mouse_exited.connect(func():
		_tween_button_modulate(button, Color.WHITE, 0.15)
	)
	button.button_down.connect(func():
		_tween_button_scale(button, Vector2(0.95, 0.95), 0.05)
	)
	button.button_up.connect(func():
		_tween_button_scale(button, Vector2.ONE, 0.1)
	)

func _tween_button_modulate(button: Button, target_color: Color, duration: float) -> void:
	if button_tweens.has(button):
		button_tweens[button].kill()
	var tween = get_tree().create_tween()
	button_tweens[button] = tween
	tween.tween_property(button, "modulate", target_color, duration)

func _tween_button_scale(button: Button, target_scale: Vector2, duration: float) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(button, "scale", target_scale, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

func _on_start_pressed() -> void:
	AudioManager.play_ui_sound("start_game")
	# Fade out then change scene
	var tween = get_tree().create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	tween.finished.connect(_load_game)

func _load_game() -> void:
	AudioManager.stop_ambient()
	get_tree().change_scene_to_file("res://scenes/world/Facility.tscn")

func _on_quit_pressed() -> void:
	AudioManager.play_ui_sound("quit")
	get_tree().quit()
