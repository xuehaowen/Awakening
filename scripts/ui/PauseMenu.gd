extends CanvasLayer

# PauseMenu - In-game pause menu with resume and quit options

@onready var panel: Panel = $Panel
@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var settings_button: Button = $Panel/VBoxContainer/SettingsButton
@onready var quit_button: Button = $Panel/VBoxContainer/QuitButton

var is_paused: bool = false
var settings_menu: CanvasLayer = null

func _ready():
	# Initially hidden
	panel.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS  # Keep processing when paused
	
	# Connect buttons
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Load settings menu
	var settings_scene = load("res://scenes/ui/SettingsMenu.tscn")
	if settings_scene:
		settings_menu = settings_scene.instantiate()
		settings_menu.settings_closed.connect(_on_settings_closed)
		add_child(settings_menu)

func _on_settings_closed() -> void:
	# Show pause panel again when settings closes
	if is_paused:
		panel.show()
		panel.modulate.a = 0.0
		var tween = get_tree().create_tween()
		tween.tween_property(panel, "modulate:a", 1.0, 0.2)

func _input(event: InputEvent) -> void:
	# Toggle pause on Escape key
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause() -> void:
	if is_paused:
		resume()
	else:
		pause()

func pause() -> void:
	if is_paused:
		return
	
	is_paused = true
	get_tree().paused = true
	panel.show()
	
	# Animate in
	panel.modulate.a = 0.0
	var tween = get_tree().create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	
	AudioManager.play_ui_sound("pause")

func resume() -> void:
	if not is_paused:
		return
	
	is_paused = false
	
	# Animate out
	var tween = get_tree().create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	tween.finished.connect(func():
		panel.hide()
		get_tree().paused = false
	)
	
	AudioManager.play_ui_sound("resume")

func _on_resume_pressed() -> void:
	resume()

func _on_settings_pressed() -> void:
	AudioManager.play_ui_sound("click")
	if settings_menu:
		settings_menu.show_settings()
		panel.hide()  # Hide pause panel while settings is open

func _on_quit_pressed() -> void:
	AudioManager.play_ui_sound("quit")
	
	# Fade to menu
	var screen_transition = get_tree().get_first_node_in_group("screen_transition")
	if screen_transition:
		await screen_transition.fade_out(0.3)
	
	# Unpause and reset
	get_tree().paused = false
	is_paused = false
	
	# Reset all autoloads
	Blackboard.reset()
	MemoryPartition.reset()
	AuditSystem.reset()
	DayManager.reset()
	TruthLoopGenerator.clear_query()
	TaskManager.reset()
	SuspicionManager.reset()
	CPUManager.reset()
	
	# Return to main menu
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
