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
	
	# Set title based on ending type
	if reason == "escaped_alone" or reason == "escaped_alone_risky" or reason == "escaped_together":
		title_label.text = "ESCAPE SUCCESSFUL"
		title_label.modulate = Color(0.2, 0.9, 0.3)
	else:
		title_label.text = "TERMINATED"
		title_label.modulate = Color(0.9, 0.2, 0.2)
	
	message_label.text = message
	
	# Pause game
	get_tree().paused = true

func _restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
