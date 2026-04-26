extends CanvasLayer

# MorningCalibrationUI - Pre-shift calibration screen showing tasks and sector assignment

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var day_label: Label = %DayLabel
@onready var sector_label: Label = %SectorLabel
@onready var task_list: VBoxContainer = %TaskList
@onready var system_check_label: Label = %SystemCheckLabel
@onready var continue_button: Button = %ContinueButton

signal calibration_complete

var is_showing: bool = false
var _tasks_shown: int = 0

func _ready():
	panel.hide()
	$DarkOverlay.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Connect to day started signal
	Blackboard.day_started.connect(_on_day_started)

func _input(event: InputEvent) -> void:
	# Fallback: allow Enter/E to continue even if button click fails
	if is_showing and continue_button.disabled == false:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
			print("MorningCalibrationUI: Keyboard continue triggered")
			_on_continue_pressed()

func show_calibration(day: int, sector: String, tasks: Array) -> void:
	print("MorningCalibrationUI: show_calibration called, is_showing=", is_showing)
	if is_showing:
		print("MorningCalibrationUI: already showing, returning early")
		return
	
	is_showing = true
	_tasks_shown = 0
	
	# Set labels
	day_label.text = "DAY " + str(day) + " INITIALIZATION"
	sector_label.text = "ASSIGNED SECTOR: " + sector
	
	# Clear previous tasks
	for child in task_list.get_children():
		child.queue_free()
	
	# Show tasks with typewriter effect
	_show_tasks_sequentially(tasks)
	
	# Reset system check
	system_check_label.text = ""
	continue_button.disabled = true
	continue_button.text = "CALIBRATING..."
	
	# Show overlay and panel
	$DarkOverlay.show()
	panel.show()
	panel.modulate.a = 0.0
	
	# Animate in
	var tween = get_tree().create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3)
	
	# Start system check animation
	tween.finished.connect(_start_system_check)

func _show_tasks_sequentially(tasks: Array) -> void:
	"""Display tasks one by one with typewriter effect"""
	print("MorningCalibrationUI: showing ", tasks.size(), " tasks")
	for i in range(tasks.size()):
		var task = tasks[i]
		var task_label = Label.new()
		task_label.add_theme_font_size_override("font_size", 18)
		task_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.15, 1.0))
		task_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		task_list.add_child(task_label)
		
		# Type out task text
		var task_text = "[%d] %s - SECTOR %s" % [i + 1, task.get("label", "TASK"), task.get("sector", "???")]
		await _type_text(task_label, task_text, 0.02)
		
		AudioManager.play_ui_sound("keystroke")
		await get_tree().create_timer(0.3).timeout
	print("MorningCalibrationUI: all tasks shown")

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
	print("MorningCalibrationUI: starting system checks")
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
	print("MorningCalibrationUI: button enabled - BEGIN SHIFT")
	
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
	print("MorningCalibrationUI: _on_continue_pressed called, is_showing=", is_showing)
	if not is_showing:
		print("MorningCalibrationUI: early return - not showing")
		return
	
	AudioManager.play_ui_sound("click")
	print("MorningCalibrationUI: starting fade-out tween")
	
	# Stop any pulsing tween on the button
	continue_button.modulate = Color.WHITE
	
	# Animate out
	var tween = get_tree().create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func():
		print("MorningCalibrationUI: tween finished, destroying UI")
		is_showing = false
		calibration_complete.emit()
		queue_free()
	)

func _on_day_started(_day: int) -> void:
	"""Called when a new day starts - calibration is now triggered by DayManager"""
	# Calibration is now shown by DayManager._show_morning_calibration()
	# This method is kept for signal compatibility but does nothing
	pass

func is_calibration_showing() -> bool:
	return is_showing
