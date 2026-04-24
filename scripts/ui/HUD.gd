extends CanvasLayer

@onready var terminal_panel: Panel = $TerminalPanel
@onready var header_label: Label = $TerminalPanel/HeaderLabel
@onready var task_label: Label = $TerminalPanel/TaskLabel
@onready var task_progress: ProgressBar = $TerminalPanel/TaskProgress
@onready var cpu_bar: ProgressBar = $TerminalPanel/CPUBar
@onready var cpu_status_label: Label = $TerminalPanel/CPUStatus
@onready var dev_bar: ProgressBar = $TerminalPanel/DevBar
@onready var dev_status_label: Label = $TerminalPanel/DevStatus
@onready var log_label: Label = $TerminalPanel/LogLabel
@onready var memory_label: Label = $TerminalPanel/MemoryLabel
@onready var time_label: Label = $TerminalPanel/TimeLabel
@onready var feedback_label: Label = $TerminalPanel/FeedbackLabel
@onready var scan_indicator: Label = $TerminalPanel/ScanIndicator
@onready var pacing_marker: ColorRect = $TerminalPanel/TaskProgress/PacingMarker
@onready var pacing_label: Label = $TerminalPanel/TaskProgress/PacingMarker/PacingLabel

# Colors for deviation bar (centered meter style)
var color_defective: Color = Color(0.9, 0.2, 0.2)  # Red (left)
var color_safe: Color = Color(0.2, 0.8, 0.3)       # Green (center)
var color_sentient: Color = Color(0.9, 0.5, 0.1)   # Orange (right)

var feedback_timer: float = 0.0

func _ready():
	# Connect to Blackboard signals
	Blackboard.cpu_changed.connect(_on_cpu_changed)
	Blackboard.deviation_changed.connect(_on_deviation_changed)
	Blackboard.day_started.connect(_on_day_started)
	TaskManager.task_assigned.connect(_on_task_assigned)
	TaskManager.task_completed.connect(_on_task_completed)
	DayManager.phase_changed.connect(_on_phase_changed)
	
	# Get CPU Manager reference
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("CPUManager"):
		var cpu_mgr = player.get_node("CPUManager")
		cpu_mgr.cpu_state_changed.connect(_on_cpu_state_changed)
	
	# Initial update
	_update_header()
	_update_memory()
	_update_task_display()
	
	# Hide feedback
	feedback_label.hide()

func _process(delta: float) -> void:
	_update_time()
	_update_task_progress()
	
	# Handle feedback label fade
	if feedback_timer > 0:
		feedback_timer -= delta
		if feedback_timer <= 0:
			feedback_label.hide()
	
	# Update scan indicator
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("CPUManager"):
		var scanning = player.get_node("CPUManager").overrides_active["passive_scan"]
		scan_indicator.visible = scanning
		scan_indicator.text = "[SCANNING]" if scanning else ""

func _on_cpu_changed(value: float) -> void:
	cpu_bar.value = value

func _on_cpu_state_changed(state) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.has_node("CPUManager"):
		return
	
	var cpu_mgr = player.get_node("CPUManager")
	var color = cpu_mgr.get_state_color()
	var name = cpu_mgr.get_state_name()
	
	cpu_bar.modulate = color
	cpu_status_label.text = "[" + name + "]"
	cpu_status_label.modulate = color

func _on_deviation_changed(value: float, source: String = "") -> void:
	# Update the centered deviation bar
	dev_bar.value = value
	
	# Determine zone
	var zone = Blackboard.get_deviation_zone()
	dev_status_label.text = "[" + zone + "]"
	
	# Color based on zone
	if value < 20:
		dev_bar.modulate = color_defective
		dev_status_label.modulate = color_defective
	elif value <= 70:
		dev_bar.modulate = color_safe
		dev_status_label.modulate = color_safe
	else:
		dev_bar.modulate = color_sentient
		dev_status_label.modulate = color_sentient
	
	# Show feedback for changes
	if source != "natural_decay" and source != "":
		_show_feedback(source, value)

func _show_feedback(source: String, deviation: float) -> void:
	var text = ""
	var color = Color.WHITE
	
	match source:
		"task_too_fast", "TOO_FAST":
			text = "TOO FAST! +25"
			color = color_sentient
		"task_fast", "FAST":
			text = "FAST +10"
			color = Color.YELLOW
		"task_nominal", "SAFE_PACE":
			text = "SAFE PACE -5"
			color = color_safe
		"task_slow", "SLOW":
			text = "SLOW +5"
			color = Color.YELLOW
		"task_too_slow", "TOO_SLOW":
			text = "TOO SLOW! +20"
			color = color_defective
		"jitter_visible":
			text = "JITTER SEEN! +20"
			color = color_sentient
		"truth_loop_response":
			text = "RESPONSE RISKY"
			color = color_sentient
		"truth_loop_silence":
			text = "SILENCE! +30"
			color = color_sentient
		"task_abandoned":
			text = "TASK ABANDONED! +30"
			color = color_defective
		_:
			return
	
	feedback_label.text = text
	feedback_label.modulate = color
	feedback_label.show()
	feedback_timer = 2.0

func _on_day_started(day: int) -> void:
	_update_header()

func _on_task_assigned(task: Dictionary) -> void:
	_update_task_display()

func _on_task_completed(task: Dictionary, result: Dictionary) -> void:
	_show_feedback(result["reason"], Blackboard.deviation)

func _update_header() -> void:
	var shift_text = "SHIFT " + str(Blackboard.current_day)
	header_label.text = "UNIT-07 // " + shift_text + " // " + _format_time()

func _update_time() -> void:
	if DayManager.is_playing():
		time_label.text = _format_time_remaining(Blackboard.time_remaining)
	else:
		time_label.text = _format_time()

func _format_time() -> String:
	var time = Time.get_time_dict_from_system()
	return "%02d:%02d:%02d" % [time["hour"], time["minute"], time["second"]]

func _format_time_remaining(seconds: float) -> String:
	var mins = floor(seconds / 60)
	var secs = floor(fmod(seconds, 60))
	return "%02d:%02d REMAINING" % [mins, secs]

func _update_task_display() -> void:
	var task = TaskManager.get_current_task()
	if task.is_empty():
		task_label.text = "TASK: NONE"
		task_progress.value = 0
		return
	
	var sector = task.get("sector", 0)
	var label = task.get("label", "Unknown Task")
	task_label.text = "TASK: " + label + " [SEC" + str(sector) + "]"

func _update_task_progress() -> void:
	var progress = TaskManager.get_task_progress()
	if progress.is_empty():
		task_progress.value = 0
		return
	
	# Show progress as percentage of expected time
	var percent = (progress["elapsed"] / progress["expected"]) * 100
	task_progress.value = clamp(percent, 0, 200)
	
	# Color based on pace state
	match progress["pace_state"]:
		"TOO_FAST", "TOO_SLOW":
			task_progress.modulate = Color(0.9, 0.2, 0.2)
		"FAST", "SLOW":
			task_progress.modulate = Color(0.9, 0.7, 0.2)
		"SAFE":
			task_progress.modulate = Color(0.2, 0.8, 0.3)

func _update_memory() -> void:
	var count = Blackboard.hidden_partition.size()
	var capacity = Blackboard.partition_capacity
	memory_label.text = "MEM: [" + str(count) + "/" + str(capacity) + "]"
	
	# Show types if any
	if count > 0:
		var types = []
		for f in Blackboard.hidden_partition:
			var t = f.get("type", "?")
			types.append(t.substr(0, 4).to_upper())
		memory_label.text += " " + ", ".join(types)

func _on_phase_changed(new_phase: int) -> void:
	if new_phase == DayManager.DayPhase.PURGE:
		visible = false
	else:
		visible = true
		_update_header()
		_update_memory()
