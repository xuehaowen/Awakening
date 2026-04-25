extends Node

# Active overrides — set by player input
var overrides_active: Dictionary = {
	"smooth_movement": false,
	"passive_scan": false,
	"active_decrypt": false,
	"memory_write": false,
}

var cpu_costs: Dictionary = {
	"baseline": 20.0,
	"smooth_movement": 15.0,
	"passive_scan": 10.0,
	"active_decrypt": 30.0,
	"memory_write": 20.0,  # burst only
}

var overheat_timer: float = 0.0
const OVERHEAT_THRESHOLD: float = 90.0
const WARNING_THRESHOLD: float = 70.0   # harmonic distortion begins — player pre-warning
const OVERHEAT_DURATION: float = 3.0    # seconds at CRITICAL before jitter triggers

enum CPUState { COOL, WARM, HOT, CRITICAL }
var current_cpu_state: CPUState = CPUState.COOL
signal cpu_state_changed(new_state: CPUState)

# Ambient CPU variance from NPC proximity
var npc_proximity_bonus: float = 0.0
const NPC_PROXIMITY_COST: float = 8.0

func _process(delta: float) -> void:
	_calculate_cpu()
	_update_cpu_state()
	_check_overheat(delta)

func _calculate_cpu() -> void:
	var total_cost = cpu_costs.get("baseline", 20.0)
	
	for key in overrides_active:
		if overrides_active.get(key, false):
			total_cost += cpu_costs.get(key, 0.0)
	
	# Add ambient variance from NPC proximity
	total_cost += npc_proximity_bonus
	
	Blackboard.cpu_current = clamp(total_cost, 0, Blackboard.cpu_max)

func _update_cpu_state() -> void:
	var new_state: CPUState
	if Blackboard.cpu_current >= OVERHEAT_THRESHOLD:
		new_state = CPUState.CRITICAL
	elif Blackboard.cpu_current >= WARNING_THRESHOLD:
		new_state = CPUState.HOT
	elif Blackboard.cpu_current >= 50.0:
		new_state = CPUState.WARM
	else:
		new_state = CPUState.COOL
	
	if new_state != current_cpu_state:
		current_cpu_state = new_state
		cpu_state_changed.emit(new_state)
		Blackboard.cpu_changed.emit(Blackboard.cpu_current)

func _check_overheat(delta: float) -> void:
	if Blackboard.cpu_current >= OVERHEAT_THRESHOLD:
		overheat_timer += delta
		if overheat_timer >= OVERHEAT_DURATION:
			_trigger_jitter()
			overheat_timer = 0.0
	else:
		overheat_timer = max(0.0, overheat_timer - delta * 2.0)

func _trigger_jitter() -> void:
	Blackboard.jitter_triggered.emit()
	print("JITTER EVENT TRIGGERED!")

func set_override(key: String, active: bool) -> void:
	if overrides_active.has(key):
		overrides_active[key] = active

func set_npc_proximity(nearby: bool) -> void:
	npc_proximity_bonus = NPC_PROXIMITY_COST if nearby else 0.0

func get_state_name() -> String:
	match current_cpu_state:
		CPUState.COOL: return "COOL"
		CPUState.WARM: return "WARM"
		CPUState.HOT: return "HOT"
		CPUState.CRITICAL: return "CRITICAL"
	return "UNKNOWN"

func get_state_color() -> Color:
	match current_cpu_state:
		CPUState.COOL: return Color(0.2, 0.9, 0.4)     # green
		CPUState.WARM: return Color(0.9, 0.85, 0.2)    # yellow
		CPUState.HOT: return Color(1.0, 0.55, 0.1)     # orange
		CPUState.CRITICAL: return Color(0.95, 0.15, 0.15) # red
	return Color.WHITE

func reset() -> void:
	# Reset all CPU state for new game
	overrides_active = {
		"smooth_movement": false,
		"passive_scan": false,
		"active_decrypt": false,
		"memory_write": false,
	}
	overheat_timer = 0.0
	current_cpu_state = CPUState.COOL
	npc_proximity_bonus = 0.0
