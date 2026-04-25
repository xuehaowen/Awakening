extends Node

enum DayPhase {
	CALIBRATION,
	SHIFT,
	PURGE,
	UPGRADE,
	ESCAPE
}

var current_phase: DayPhase = DayPhase.CALIBRATION
var shift_timer: float = 0.0
var purge_timer: float = 0.0
const PURGE_DURATION: float = 60.0

@onready var phase_timer: Timer = Timer.new()
var _upgrade_timer: SceneTreeTimer = null
var _calibration_ui: CanvasLayer = null

func _ready():
	# Seed random number generator for unique gameplay each session
	randomize()
	
	add_child(phase_timer)
	phase_timer.one_shot = true
	phase_timer.timeout.connect(_on_phase_timer_timeout)
	
	# Connect to Blackboard
	Blackboard.phase_changed.connect(_on_phase_changed)

func _process(delta: float) -> void:
	match current_phase:
		DayPhase.SHIFT:
			if shift_timer > 0:
				shift_timer -= delta
				Blackboard.time_remaining = shift_timer
				if shift_timer <= 0:
					end_shift()
			else:
				end_shift()
		DayPhase.PURGE:
			if purge_timer > 0:
				purge_timer -= delta
				if purge_timer <= 0:
					_force_purge()

func advance_phase() -> void:
	match current_phase:
		DayPhase.CALIBRATION:
			_show_morning_calibration()
		DayPhase.SHIFT:
			_start_purge()
		DayPhase.PURGE:
			_start_upgrade()
		DayPhase.UPGRADE:
			_start_next_day()
		DayPhase.ESCAPE:
			pass  # End of game

func _start_shift() -> void:
	current_phase = DayPhase.SHIFT
	Blackboard.shift_active = true
	shift_timer = Blackboard.get_shift_duration()
	Blackboard.time_remaining = shift_timer
	Blackboard.current_phase = 1
	
	Blackboard.phase_changed.emit(DayPhase.SHIFT)
	print("Day ", Blackboard.current_day, " - SHIFT started. Duration: ", shift_timer)

func end_shift() -> void:
	if current_phase == DayPhase.SHIFT:
		Blackboard.shift_active = false
		Blackboard.shift_ended.emit()
		_start_purge()

func _start_purge() -> void:
	current_phase = DayPhase.PURGE
	Blackboard.current_phase = 2
	purge_timer = PURGE_DURATION
	
	# Generate end-of-day audit report
	var report = AuditSystem.end_of_day_report()
	print("Audit Report: ", report)
	
	Blackboard.phase_changed.emit(DayPhase.PURGE)
	Blackboard.purge_initiated.emit()

func _force_purge() -> void:
	# Auto-clear short-term memory if player didn't commit
	Blackboard.purge_short_term()
	purge_timer = 0
	_start_upgrade()

func complete_purge() -> void:
	# Called by UI when player confirms their choices
	purge_timer = 0
	Blackboard.purge_short_term()
	_start_upgrade()

func _start_upgrade() -> void:
	current_phase = DayPhase.UPGRADE
	Blackboard.current_phase = 3
	
	# Day 2 gets automatic partition upgrade
	if Blackboard.current_day == 2:
		MemoryPartition.upgrade_capacity()
	
	Blackboard.phase_changed.emit(DayPhase.UPGRADE)
	
	# Auto-advance to next day after a short delay
	_upgrade_timer = get_tree().create_timer(3.0)
	_upgrade_timer.timeout.connect(_start_next_day)

func _start_next_day() -> void:
	if Blackboard.current_day >= Blackboard.FINAL_DAY:
		# Start escape sequence instead of new day
		_start_escape()
	else:
		Blackboard.current_day += 1
		current_phase = DayPhase.CALIBRATION
		Blackboard.current_phase = 0
		_start_shift()

func _start_escape() -> void:
	current_phase = DayPhase.ESCAPE
	Blackboard.current_phase = 4
	print("ESCAPE SEQUENCE STARTED")

func _on_phase_changed(new_phase: int) -> void:
	print("Phase changed to: ", DayPhase.keys()[new_phase] if new_phase < DayPhase.size() else "UNKNOWN")

func _on_phase_timer_timeout() -> void:
	advance_phase()

func _show_morning_calibration() -> void:
	"""Show morning calibration UI before starting shift"""
	# Generate tasks first (needed for calibration display)
	TaskManager.generate_day_tasks(Blackboard.current_day)
	
	# Start the day (emits day_started signal)
	Blackboard.start_day(Blackboard.current_day)
	
	# Load and show calibration UI if not already loaded
	if _calibration_ui == null:
		var calibration_scene = load("res://scenes/ui/MorningCalibrationUI.tscn")
		if calibration_scene:
			_calibration_ui = calibration_scene.instantiate()
			get_tree().root.add_child(_calibration_ui)
			_calibration_ui.calibration_complete.connect(_on_calibration_complete)
	
	if _calibration_ui:
		# Get sector from first task or use default
		var tasks = TaskManager.get_current_tasks()
		var sector = "ALL"
		if tasks.size() > 0:
			sector = "SECTOR_" + str(tasks[0].get("sector", "??"))
		
		_calibration_ui.show_calibration(Blackboard.current_day, sector, tasks)

func _on_calibration_complete() -> void:
	"""Called when user clicks Continue in calibration UI"""
	_start_shift()

func get_phase_name() -> String:
	return DayPhase.keys()[current_phase]

func is_playing() -> bool:
	return current_phase == DayPhase.SHIFT

func reset() -> void:
	current_phase = DayPhase.CALIBRATION
	shift_timer = 0.0
	purge_timer = 0.0
	
	# Cancel any pending upgrade timer
	if _upgrade_timer != null:
		_upgrade_timer = null
	
	# Recreate phase_timer instead of leaving it null
	if is_instance_valid(phase_timer):
		phase_timer.stop()
		phase_timer.queue_free()
	phase_timer = Timer.new()
	add_child(phase_timer)
	phase_timer.one_shot = true
	if not phase_timer.timeout.is_connected(_on_phase_timer_timeout):
		phase_timer.timeout.connect(_on_phase_timer_timeout)
