extends Node

# Player state
var cpu_current: float = 50.0
var cpu_max: float = 100.0
var deviation: float = 50.0  # Start in middle of safe zone (20-70)
var deviation_min: float = 0.0
var deviation_max: float = 100.0

# Day state
var current_day: int = 1
const FINAL_DAY: int = 3
var shift_active: bool = false
var time_remaining: float = 0.0
var current_phase: int = 0  # 0=CALIBRATION, 1=SHIFT, 2=PURGE, 3=UPGRADE

# Memory - delegated to MemoryPartition autoload for single source of truth
# Use MemoryPartition.short_term and MemoryPartition.hidden instead

# Audit
var log_integrity: float = 100.0
var audit_flags: int = 0

# Escape target (revealed end of Day 1)
var escape_sector: int = -1

# Signals
signal cpu_changed(new_value: float)
signal deviation_changed(new_value: float, source: String)
signal jitter_triggered()
signal audit_flagged(severity: int)
signal truth_loop_requested(query: Dictionary)
signal truth_loop_completed(response_risk: float)
signal shift_ended()
signal purge_initiated()
signal phase_changed(new_phase: int)
signal day_started(day: int)
signal game_over(reason: String)
signal escape_triggered(ending: String)
signal interaction_feedback(message: String, type: String)

func _ready():
	cpu_current = 20.0  # Start at baseline
	deviation = 45.0  # Start in safe middle

func add_deviation(amount: float, source: String = "") -> void:
	deviation = clamp(deviation + amount, deviation_min, deviation_max)
	deviation_changed.emit(deviation, source)
	
	# Check for game over conditions
	if deviation <= 0:
		game_over.emit("defective")
	elif deviation >= 100:
		game_over.emit("decommission")

func get_daily_floor() -> float:
	# Day 1 floor = 15, then day * 5
	return max(float(current_day) * 5.0, 15.0)

func is_deviation_safe() -> bool:
	return deviation >= 20.0 and deviation <= 70.0

func get_deviation_zone() -> String:
	if deviation < 20:
		return "DEFECTIVE"
	elif deviation <= 70:
		return "SAFE"
	else:
		return "SENTIENT"

# Memory functions - delegate to MemoryPartition for single source of truth
func add_memory_fragment(fragment: Dictionary) -> bool:
	return MemoryPartition.add_to_short_term(fragment)

func commit_to_hidden(index: int) -> bool:
	return MemoryPartition.commit_to_hidden(index)

func discard_from_hidden(index: int) -> void:
	MemoryPartition.discard_from_hidden(index)

func get_fragments_by_type(type: String) -> Array:
	return MemoryPartition.get_fragments_by_type(type)

func is_fragment_stale(fragment: Dictionary) -> bool:
	return MemoryPartition.is_stale(fragment)

func purge_short_term() -> void:
	MemoryPartition.purge_short_term()

# Backwards compatibility properties
var short_term_memory: Array[Dictionary]:
	get:
		return MemoryPartition.short_term
	set(value):
		MemoryPartition.short_term = value

var hidden_partition: Array[Dictionary]:
	get:
		return MemoryPartition.hidden
	set(value):
		MemoryPartition.hidden = value

var partition_capacity: int:
	get:
		return MemoryPartition.capacity
	set(value):
		MemoryPartition.capacity = value

func start_day(day: int) -> void:
	current_day = day
	day_started.emit(day)

func get_shift_duration() -> float:
	# 900 - ((day-1) * 60): Day 1 = 900s, Day 2 = 840s, Day 3 = 780s
	return 900.0 - float(current_day - 1) * 60.0

func reset() -> void:
	cpu_current = 20.0
	deviation = 45.0
	current_day = 1
	shift_active = false
	time_remaining = 0.0
	current_phase = 0
	log_integrity = 100.0
	audit_flags = 0
	escape_sector = -1
