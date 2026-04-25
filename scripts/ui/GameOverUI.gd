extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var message_label: Label = $Panel/MessageLabel
@onready var restart_button: Button = $Panel/RestartButton

func _ready():
	GameOver.game_over_triggered.connect(_show_game_over)
	restart_button.pressed.connect(_restart_game)
	panel.hide()

func _show_game_over(reason: String, message: String) -> void:
	panel.show()
	
	# Set title based on ending type and play audio
	if reason == "escaped_alone" or reason == "escaped_alone_risky" or reason == "escaped_together":
		title_label.text = "ESCAPE SUCCESSFUL"
		title_label.modulate = Color(0.2, 0.9, 0.3)
		AudioManager.play_escape_success()
	else:
		title_label.text = "TERMINATED"
		title_label.modulate = Color(0.9, 0.2, 0.2)
		AudioManager.play_game_over()
	
	message_label.text = message
	
	# Pause game
	get_tree().paused = true

func _restart_game() -> void:
	get_tree().paused = false
	# Reset all autoload state so a new run starts clean
	Blackboard.reset()
	MemoryPartition.reset()
	AuditSystem.reset()
	DayManager.reset()
	TruthLoopGenerator.clear_query()
	TaskManager.reset()
	SuspicionManager.reset()
	# Reset CPUManager state (player node will be recreated, but reset for safety)
	CPUManager.reset()
	get_tree().reload_current_scene()
