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
@onready var smooth_indicator: Label = $TerminalPanel/SmoothIndicator

var memory_overlay: Panel = null
var memory_overlay_label: RichTextLabel = null

# Colors for deviation bar (centered meter style)
var color_defective: Color = Color(0.9, 0.2, 0.2)  # Red (left)
var color_safe: Color = Color(0.2, 0.8, 0.3)       # Green (center)
var color_sentient: Color = Color(0.9, 0.5, 0.1)   # Orange (right)

var feedback_timer: float = 0.0

func _ready():
	add_to_group("hud")
	_create_memory_overlay()

	# Connect to Blackboard signals
	Blackboard.cpu_changed.connect(_on_cpu_changed)
	Blackboard.deviation_changed.connect(_on_deviation_changed)
	Blackboard.day_started.connect(_on_day_started)
	TaskManager.task_assigned.connect(_on_task_assigned)
	TaskManager.task_completed.connect(_on_task_completed)
	Blackboard.phase_changed.connect(_on_phase_changed)
	MemoryPartition.fragment_acquired.connect(_on_memory_changed)
	MemoryPartition.fragment_committed.connect(_on_memory_changed)
	
	# Connect to EscapeSystem for failure feedback
	EscapeSystem.escape_failed.connect(_on_escape_failed)
	
	# Connect to interaction feedback signal
	Blackboard.interaction_feedback.connect(_on_interaction_feedback)
	
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
	_refresh_memory_overlay()
	
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
	
	# Update indicators
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_node("CPUManager"):
		var cpu_mgr = player.get_node("CPUManager")
		
		var scanning = cpu_mgr.overrides_active["passive_scan"]
		scan_indicator.visible = scanning
		scan_indicator.text = "[SCANNING]" if scanning else ""
		
		var smooth = cpu_mgr.overrides_active["smooth_movement"]
		smooth_indicator.visible = smooth
		smooth_indicator.text = "[SMOOTH_NAV]" if smooth else ""

func _on_cpu_changed(value: float) -> void:
	cpu_bar.value = value

func _on_cpu_state_changed(state) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.has_node("CPUManager"):
		return
	
	var cpu_mgr = player.get_node("CPUManager")
	var state_color = cpu_mgr.get_state_color()
	var state_name = cpu_mgr.get_state_name()
	
	cpu_bar.modulate = state_color
	cpu_status_label.text = "[" + state_name + "]"
	cpu_status_label.modulate = state_color

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
	var count = MemoryPartition.hidden.size()
	var capacity = MemoryPartition.capacity
	memory_label.text = "MEM: [" + str(count) + "/" + str(capacity) + "]"
	
	# Show types if any
	if count > 0:
		var types = []
		for f in MemoryPartition.hidden:
			var t = f.get("type", "?")
			types.append(t.substr(0, 4).to_upper())
		memory_label.text += " " + ", ".join(types)

func _on_memory_changed(_fragment: Dictionary) -> void:
	_update_memory()
	_refresh_memory_overlay()

func _on_phase_changed(new_phase: int) -> void:
	if new_phase == DayManager.DayPhase.PURGE:
		visible = false
		if memory_overlay:
			memory_overlay.hide()
	else:
		visible = true
		_update_header()
		_update_memory()
		_refresh_memory_overlay()

func _on_escape_failed(reason: String) -> void:
	var text = ""
	var color = Color.WHITE
	
	match reason:
		"too_early":
			text = "ESCAPE TERMINAL LOCKED - Complete all shifts first"
			color = Color.YELLOW
		"insufficient_intel":
			text = "INSUFFICIENT INTEL - Collect more data"
			color = Color.RED
		"no_target_sector":
			text = "NO TARGET SECTOR IDENTIFIED"
			color = Color.RED
		_:
			text = "ESCAPE FAILED - " + reason.to_upper()
			color = Color.RED
	
	feedback_label.text = text
	feedback_label.modulate = color
	feedback_label.show()
	feedback_timer = 3.0

func _on_interaction_feedback(message: String, type: String) -> void:
	var color = Color.WHITE
	match type:
		"error":
			color = Color.RED
		"warning":
			color = Color.YELLOW
		"success":
			color = Color.GREEN
		"info":
			color = Color.CYAN
	
	feedback_label.text = message
	feedback_label.modulate = color
	feedback_label.show()
	feedback_timer = 3.0

func toggle_memory_view() -> void:
	if memory_overlay == null:
		return

	if memory_overlay.visible:
		memory_overlay.hide()
		return

	_refresh_memory_overlay()
	memory_overlay.show()

func _create_memory_overlay() -> void:
	memory_overlay = Panel.new()
	memory_overlay.name = "MemoryOverlay"
	memory_overlay.anchor_left = 1.0
	memory_overlay.anchor_top = 0.0
	memory_overlay.anchor_right = 1.0
	memory_overlay.anchor_bottom = 0.0
	memory_overlay.offset_left = -360.0
	memory_overlay.offset_top = 190.0
	memory_overlay.offset_right = -16.0
	memory_overlay.offset_bottom = 470.0
	memory_overlay.visible = false

	memory_overlay_label = RichTextLabel.new()
	memory_overlay_label.name = "MemoryOverlayLabel"
	memory_overlay_label.anchor_right = 1.0
	memory_overlay_label.anchor_bottom = 1.0
	memory_overlay_label.offset_left = 12.0
	memory_overlay_label.offset_top = 12.0
	memory_overlay_label.offset_right = -12.0
	memory_overlay_label.offset_bottom = -12.0
	memory_overlay_label.bbcode_enabled = false
	memory_overlay_label.scroll_active = true
	memory_overlay_label.fit_content = true

	memory_overlay.add_child(memory_overlay_label)
	add_child(memory_overlay)

func _refresh_memory_overlay() -> void:
	if memory_overlay_label == null:
		return

	var lines: Array[String] = []
	lines.append("MEMORY INSPECTOR")
	lines.append("Press M to close")
	lines.append("")
	lines.append("HIDDEN PARTITION [%d/%d]" % [MemoryPartition.hidden.size(), MemoryPartition.capacity])

	if MemoryPartition.hidden.is_empty():
		lines.append("  EMPTY")
	else:
		for i in range(MemoryPartition.hidden.size()):
			lines.append("  %s" % _format_fragment_line(i + 1, MemoryPartition.hidden[i]))

	lines.append("")
	lines.append("SHORT-TERM BUFFER [%d/%d]" % [MemoryPartition.short_term.size(), MemoryPartition.MAX_SHORT_TERM])

	if MemoryPartition.short_term.is_empty():
		lines.append("  EMPTY")
	else:
		for i in range(MemoryPartition.short_term.size()):
			lines.append("  %s" % _format_fragment_line(i + 1, MemoryPartition.short_term[i]))

	if Blackboard.escape_sector > 0:
		lines.append("")
		lines.append(EscapeSystem.get_escape_hint())

	memory_overlay_label.text = "\n".join(lines)

func _format_fragment_line(index: int, fragment: Dictionary) -> String:
	var fragment_type = str(fragment.get("type", "?")).replace("_", " ").to_upper()
	var sector = fragment.get("sector", "?")
	var description = str(fragment.get("description", ""))
	if description.length() > 44:
		description = description.substr(0, 41) + "..."
	return "%d. %s [SEC %s] %s" % [index, fragment_type, str(sector), description]
