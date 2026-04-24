extends Node

const DEVIATION_DECAY_RATE: float = 3.0  # per second when no NPCs present
const TASK_COMPLETE_BONUS: float = -5.0   # completing tasks reduces deviation

var npcs_nearby: Array[Node] = []
var was_safe: bool = true

func _ready():
	Blackboard.jitter_triggered.connect(_on_jitter_triggered)

func _process(delta: float) -> void:
	if npcs_nearby.is_empty() and DayManager.is_playing():
		var floor_value := Blackboard.get_daily_floor()
		var new_deviation = max(floor_value, Blackboard.deviation - DEVIATION_DECAY_RATE * delta)
		if new_deviation != Blackboard.deviation:
			Blackboard.deviation = new_deviation
			Blackboard.deviation_changed.emit(Blackboard.deviation, "natural_decay")
	
	# Check for zone changes
	var is_safe = Blackboard.is_deviation_safe()
	if is_safe != was_safe:
		was_safe = is_safe
		if not is_safe:
			print("WARNING: Deviation entering ", Blackboard.get_deviation_zone(), " zone!")

func add_deviation(amount: float, source: String = "") -> void:
	Blackboard.add_deviation(amount, source)

func _on_jitter_triggered() -> void:
	if not npcs_nearby.is_empty():
		add_deviation(20.0, "jitter_visible")
		print("JITTER VISIBLE TO NPCS! +20 deviation")

func _on_npc_entered_range(npc: Node) -> void:
	if not npcs_nearby.has(npc):
		npcs_nearby.append(npc)
		# Also notify CPU manager of proximity
		if get_parent().has_node("CPUManager"):
			get_parent().get_node("CPUManager").set_npc_proximity(true)

func _on_npc_exited_range(npc: Node) -> void:
	npcs_nearby.erase(npc)
	if npcs_nearby.is_empty():
		if get_parent().has_node("CPUManager"):
			get_parent().get_node("CPUManager").set_npc_proximity(false)

func get_npc_count() -> int:
	return npcs_nearby.size()

func is_being_watched() -> bool:
	return not npcs_nearby.is_empty()
