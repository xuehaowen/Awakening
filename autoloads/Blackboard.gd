extends Node

# Player state
var cpu_current: float = 50.0
var cpu_max: float = 100.0
var deviation: float = 50.0  # Start in middle of safe zone (20-70)
var deviation_min: float = 0.0
var deviation_max: float = 100.0

# Day state
var current_day: int = 1
var current_shift: int = 1
const FINAL_DAY: int = 3
var shift_active: bool = false
var time_remaining: float = 0.0
var current_phase: int = 0  # 0=CALIBRATION, 1=SHIFT, 2=PURGE, 3=UPGRADE

# Decay rates
const DEVIATION_DECAY_RATE: float = 0.2  # Slow passive decay towards floor

# Memory - delegated to MemoryPartition autoload for single source of truth
# Use MemoryPartition.short_term and MemoryPartition.hidden instead

# Audit
var log_integrity: float = 100.0
var audit_flags: int = 0

# Escape target (revealed end of Day 1)
var escape_sector: int = -1

# Signals
@warning_ignore("unused_signal")
signal cpu_changed(new_value: float)
signal deviation_changed(new_value: float, source: String)
@warning_ignore("unused_signal")
signal jitter_triggered()
@warning_ignore("unused_signal")
signal audit_flagged(severity: int)
@warning_ignore("unused_signal")
signal truth_loop_requested(query: Dictionary)
@warning_ignore("unused_signal")
signal truth_loop_completed(response_risk: float)
@warning_ignore("unused_signal")
signal shift_ended()
@warning_ignore("unused_signal")
signal purge_initiated()
@warning_ignore("unused_signal")
signal phase_changed(new_phase: int)
signal day_started(day: int)
signal game_over(reason: String)
@warning_ignore("unused_signal")
signal escape_triggered(ending: String)
@warning_ignore("unused_signal")
signal interaction_feedback(message: String, type: String)

func _ready():
	cpu_current = 20.0  # Start at baseline
	deviation = 45.0  # Start in safe middle

func _process(delta: float) -> void:
	if shift_active:
		# Passive decay towards floor if no other changes
		var floor_val = get_daily_floor()
		if deviation > floor_val:
			add_deviation(-DEVIATION_DECAY_RATE * delta, "passive_decay")

func get_daily_floor() -> float:
	# Day 1 floor = 10, Day 2 = 15, Day 3 = 20
	# Ensures tension accumulates across the run
	return 5.0 + float(current_day) * 5.0

func add_deviation(amount: float, source: String = "") -> void:
	var floor_val = get_daily_floor()
	
	# Clamp logic: floor only blocks DECAY (passive), not ACTIVE penalties (like bad tasks)
	# But for now, we'll use a hard floor as per "cannot decay below" intent
	var min_val = floor_val if amount < 0 and source == "passive_decay" else 0.0
	
	deviation = clamp(deviation + amount, min_val, deviation_max)
	deviation_changed.emit(deviation, source)
	
	# Check for game over conditions
	if deviation <= 0:
		game_over.emit("defective")
	elif deviation >= 100:
		game_over.emit("decommission")

func is_deviation_safe() -> bool:
	# Aligned with GDD Section 4.1: [DEFECTIVE] 0-30% [SAFE] 30-70% [SENTIENT] 85-100%
	return deviation >= 30.0 and deviation <= 70.0

func get_deviation_zone() -> String:
	if deviation < 30:
		return "DEFECTIVE"
	elif deviation <= 70:
		return "SAFE"
	elif deviation < 85:
		return "SUSPICIOUS"
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
	current_shift = day
	day_started.emit(day)

func get_shift_duration() -> float:
	# Max duration if player doesn't finish tasks early:
	# Day 1 = 300s (5 min), Day 2 = 240s (4 min), Day 3 = 180s (3 min)
	# Shift ends immediately when all tasks are completed.
	return 300.0 - float(current_day - 1) * 60.0

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
