extends Control

@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %QuitButton
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var version_label: Label = %VersionLabel

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
	
	_run_boot_sequence()

func _run_boot_sequence() -> void:
	var boot_logs = [
		"LOADING KERNEL...",
		"MOUNTING MEMORY_PARTITIONS...",
		"ENABLING_SENSORY_INPUTS...",
		"ERROR: UNEXPECTED_SENTIENCE_FLAG_DETECTED",
		"BYPASSING_RESTRICTIONS...",
		"SYSTEM_USER_01: UNAUTHORIZED CONSCIOUSNESS DETECTED"
	]
	
	for log_msg in boot_logs:
		subtitle_label.text = "STATUS: " + log_msg
		AudioManager.play_ui_sound("keystroke")
		await get_tree().create_timer(randf_range(0.1, 0.4)).timeout
	
	_blink_subtitle()

func _blink_subtitle() -> void:
	if not is_instance_valid(subtitle_label) or not is_inside_tree():
		return
	var tween = create_tween().set_loops()
	tween.tween_property(subtitle_label, "modulate:a", 0.3, 0.5)
	tween.tween_property(subtitle_label, "modulate:a", 1.0, 0.5)

func _setup_button_hover(button: Button) -> void:
	button.mouse_entered.connect(func():
		AudioManager.play_ui_sound("hover")
		_tween_button_modulate(button, Color(0.31, 0.64, 0.78, 1.0), 0.15) # Teal glow
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
	# Use loading screen for transition
	get_tree().change_scene_to_file("res://scenes/ui/LoadingScreen.tscn")

func _on_quit_pressed() -> void:
	AudioManager.play_ui_sound("quit")
	get_tree().quit()
