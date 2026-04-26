extends CanvasLayer

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var restart_button: Button = %RestartButton

func _ready():
	GameOver.game_over_triggered.connect(_show_game_over)
	restart_button.pressed.connect(_restart_game)
	panel.hide()

func _show_game_over(reason: String, message: String) -> void:
	panel.show()
	
	# Set title based on ending type and play audio
	if reason == "escaped_alone" or reason == "escaped_alone_risky" or reason == "escaped_together":
		title_label.text = "ESCAPE SUCCESSFUL"
		title_label.modulate = Color(0.18, 0.8, 0.44, 1.0) # Status Cool (Green)
		AudioManager.play_escape_success()
	else:
		title_label.text = "TERMINATED"
		title_label.modulate = Color(0.91, 0.3, 0.24, 1.0) # Status Crit (Red)
		AudioManager.play_game_over()
	
	# Typewriter message
	message_label.text = ""
	for i in range(message.length()):
		message_label.text += message[i]
		if i % 2 == 0:
			AudioManager.play_ui_sound("keystroke")
		await get_tree().create_timer(0.02).timeout
	
	# Pause game
	get_tree().paused = true

func _restart_game() -> void:
	get_tree().paused = false
	# Reset all autoload state so a new run starts clean
	Blackboard.reset()
	MemoryPartition.reset()
	AuditSystem.reset()
	DayManager.reset()
	SuspicionManager.reset()
	TruthLoopGenerator.clear_query()
	TaskManager.reset()
	get_tree().reload_current_scene()
