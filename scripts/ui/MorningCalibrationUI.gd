extends CanvasLayer

# MorningCalibrationUI - Pre-shift calibration screen showing tasks and sector assignment

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var day_label: Label = $Panel/DayLabel
@onready var sector_label: Label = $Panel/SectorLabel
@onready var task_list: VBoxContainer = $Panel/TaskList
@onready var system_check_label: Label = $Panel/SystemCheckLabel
@onready var continue_button: Button = $Panel/ContinueButton

signal calibration_complete

var is_showing: bool = false
var _tasks_shown: int = 0

func _ready():
	panel.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Connect to day started signal
	Blackboard.day_started.connect(_on_day_started)

func show_calibration(day: int, sector: String, tasks: Array) -> void:
	if is_showing:
		return
	
	is_showing = true
	_tasks_shown = 0
	
	# Set labels
	day_label.text = "DAY " + str(day) + " INITIALIZATION"
	sector_label.text = "ASSIGNED SECTOR: " + sector
	
	# Clear previous tasks
	for child in task_list.get_children():
		child.queue_free()
	
	# Add task headers
	var header = Label.new()
	header.text = "DAILY TASK ASSIGNMENTS:"
	header.theme_type_variation = "HeaderLabel"
	task_list.add_child(header)
	
	var separator = HSeparator.new()
	task_list.add_child(separator)
	
	# Show tasks with typewriter effect
	_show_tasks_sequentially(tasks)
	
	# Reset system check
	system_check_label.text = ""
	continue_button.disabled = true
	continue_button.text = "CALIBRATING..."
	
	# Show panel
	panel.show()
	panel.modulate.a = 0.0
	
	# Animate in
	var tween = get_tree().create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	
	# Start system check animation
	tween.finished.connect(_start_system_check)

func _show_tasks_sequentially(tasks: Array) -> void:
	"""Display tasks one by one with typewriter effect"""
	for i in range(tasks.size()):
		var task = tasks[i]
		var task_label = Label.new()
		task_label.theme_type_variation = "TaskLabel"
		task_list.add_child(task_label)
		
		# Type out task text
		var task_text = "[%d] %s - SECTOR %s" % [i + 1, task.get("label", "TASK"), task.get("sector", "???")]
		await _type_text(task_label, task_text, 0.02)
		
		AudioManager.play_ui_sound("keystroke")
		await get_tree().create_timer(0.3).timeout

func _type_text(label: Label, text: String, delay: float) -> void:
	"""Type out text character by character"""
	label.text = ""
	for i in range(text.length()):
		label.text += text[i]
		if text[i] != " " and randf() > 0.3:
			AudioManager.play_ui_sound("keystroke")
		await get_tree().create_timer(delay).timeout

func _start_system_check() -> void:
	"""Run system check animation"""
	var checks = [
		"[ OK ] Neural link stable",
		"[ OK ] Motor functions nominal",
		"[ OK ] Sensors calibrated",
		"[ OK ] Memory banks online",
		"[ OK ] Ready for assignment"
	]
	
	for check in checks:
		system_check_label.text += check + "\n"
		AudioManager.play_ui_sound("keystroke")
		await get_tree().create_timer(0.4).timeout
	
	# Enable continue button
	continue_button.disabled = false
	continue_button.text = "BEGIN SHIFT"
	
	# Pulse button for attention
	_pulse_button()

func _pulse_button() -> void:
	"""Pulse animation on continue button"""
	if not is_showing:
		return
	
	var tween = get_tree().create_tween()
	tween.tween_property(continue_button, "modulate", Color(1.2, 1.2, 1.2), 0.5)
	tween.tween_property(continue_button, "modulate", Color.WHITE, 0.5)
	tween.finished.connect(_pulse_button)

func _on_continue_pressed() -> void:
	if not is_showing:
		return
	
	AudioManager.play_ui_sound("click")
	
	# Animate out
	var tween = get_tree().create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func():
		panel.hide()
		is_showing = false
		calibration_complete.emit()
	)

func _on_day_started(day: int) -> void:
	"""Called when a new day starts - calibration is now triggered by DayManager"""
	# Calibration is now shown by DayManager._show_morning_calibration()
	# This method is kept for signal compatibility but does nothing
	pass

func is_calibration_showing() -> bool:
	return is_showing
