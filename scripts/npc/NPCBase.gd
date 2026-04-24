extends CharacterBody2D
class_name NPCBase

enum NPCState { PATROL, IDLE, WATCHING, QUERY, REPORTING }
enum NPCType { SUPERVISOR, GUARD, TECHNICIAN }

@export var npc_type: NPCType = NPCType.GUARD
@export var suspicion_score: float = 0.0
@export var audit_frequency: float = 0.5
@export var move_speed: float = 40.0
@export var watch_duration: float = 3.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var observation_area: Area2D = $ObservationArea
@onready var query_timer: Timer = $QueryTimer

var state: NPCState = NPCState.PATROL
var patrol_points: Array[Vector2] = []
var current_patrol_index: int = 0
var player_in_range: bool = false
var watch_timer: float = 0.0
var player_ref: Node = null

signal query_triggered(npc: NPCBase, query: Dictionary)
signal suspicion_changed(new_score: float)
signal decommission_threshold_reached(npc: NPCBase)
signal report_threshold_reached(npc: NPCBase, reason: String)

func _ready():
	add_to_group("npc")
	
	observation_area.body_entered.connect(_on_observation_area_entered)
	observation_area.body_exited.connect(_on_observation_area_exited)
	
	query_timer.timeout.connect(_on_query_timer_timeout)
	
	_setup_patrol()

func _physics_process(delta: float) -> void:
	match state:
		NPCState.PATROL:
			_do_patrol(delta)
		NPCState.IDLE:
			_do_idle(delta)
		NPCState.WATCHING:
			_do_watching(delta)
		NPCState.QUERY:
			_do_query()

func _setup_patrol():
	# Generate simple patrol path around spawn area
	var start_pos = global_position
	patrol_points = [
		start_pos + Vector2(100, 0),
		start_pos + Vector2(100, 100),
		start_pos + Vector2(0, 100),
		start_pos
	]

func _do_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		return
	
	var target = patrol_points[current_patrol_index]
	var dir = (target - global_position).normalized()
	
	velocity = dir * move_speed
	move_and_slide()
	
	# Update facing
	if dir.length() > 0.1:
		_update_facing(dir)
	
	# Check if reached waypoint
	if global_position.distance_to(target) < 10.0:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()

func _do_idle(delta: float) -> void:
	velocity = Vector2.ZERO
	
	if player_in_range and player_ref:
		state = NPCState.WATCHING
		watch_timer = 0.0

func _do_watching(delta: float) -> void:
	velocity = Vector2.ZERO
	watch_timer += delta
	
	if not player_in_range or not player_ref:
		state = NPCState.PATROL
		return
	
	# Face player
	var dir = (player_ref.global_position - global_position).normalized()
	_update_facing(dir)
	
	# Assess player behavior
	_assess_player_behavior(delta)
	
	# Check for query trigger
	if suspicion_score > 60.0 and state != NPCState.QUERY:
		if randf() < audit_frequency * delta:
			_trigger_query()
	
	# Check suspicion thresholds
	_check_suspicion_thresholds()

func _do_query() -> void:
	velocity = Vector2.ZERO
	# Query state is handled by TruthLoopGenerator

func _assess_player_behavior(delta: float) -> void:
	if not player_ref:
		return
	
	var gain = 0.0
	
	# Check for jitter (visible anomaly)
	if Blackboard.cpu_current > 85.0:
		gain += 10.0 * delta
	
	# Check for smooth movement (too fluid for a robot)
	if player_ref.velocity.length() > 90.0:
		gain += 3.0 * delta
	
	# Check for being off-task
	var task = TaskManager.get_current_task()
	if task.is_empty():
		gain += 2.0 * delta
	elif task.get("sector", 0) != _get_current_sector():
		gain += 1.0 * delta
	
	# Check for loitering
	if player_ref.velocity.length() < 5.0:
		gain += 1.0 * delta
	
	if gain > 0:
		_add_suspicion(gain)

func _get_current_sector() -> int:
	# Simple sector calculation based on position
	var x = floor(global_position.x / 300)
	var y = floor(global_position.y / 300)
	return (abs(x + y) % 4) + 1

func _trigger_query() -> void:
	if state == NPCState.QUERY:
		return
	
	state = NPCState.QUERY
	var query = TruthLoopGenerator.generate(self)
	Blackboard.truth_loop_requested.emit(query)
	query_triggered.emit(self, query)
	
	# Pause NPC while query is active
	await Blackboard.truth_loop_completed
	state = NPCState.WATCHING

func _check_suspicion_thresholds() -> void:
	if suspicion_score >= 86.0:
		# Emit signal instead of direct AuditSystem call (architecture fix)
		decommission_threshold_reached.emit(self)
	elif suspicion_score >= 61.0:
		if state != NPCState.REPORTING:
			state = NPCState.REPORTING
			# Emit signal instead of direct AuditSystem call
			report_threshold_reached.emit(self, "npc_suspicion_high")

func _add_suspicion(amount: float) -> void:
	var old_score = suspicion_score
	suspicion_score = min(suspicion_score + amount, 100.0)
	if suspicion_score != old_score:
		suspicion_changed.emit(suspicion_score)

func _update_facing(dir: Vector2) -> void:
	# Simple facing update
	if abs(dir.x) > abs(dir.y):
		sprite.flip_h = dir.x < 0

func _on_observation_area_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = true
		player_ref = body
		if state == NPCState.PATROL:
			state = NPCState.WATCHING
			watch_timer = 0.0
		
		# Notify player's deviation tracker
		if body.has_node("DeviationTracker"):
			body.get_node("DeviationTracker")._on_npc_entered_range(self)

func _on_observation_area_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_range = false
		player_ref = null
		
		if state == NPCState.WATCHING:
			state = NPCState.PATROL
		
		# Notify player's deviation tracker
		if body.has_node("DeviationTracker"):
			body.get_node("DeviationTracker")._on_npc_exited_range(self)

func _on_query_timer_timeout() -> void:
	if state == NPCState.WATCHING and player_in_range:
		if suspicion_score > 40.0:
			_trigger_query()

func get_npc_type() -> String:
	match npc_type:
		NPCType.SUPERVISOR: return "supervisor"
		NPCType.GUARD: return "guard"
		NPCType.TECHNICIAN: return "technician"
	return "unknown"

func on_truth_loop_completed(response_risk: float) -> void:
	# Called by game when player responds
	if response_risk > 0:
		_add_suspicion(response_risk * 2.0)
	
	state = NPCState.WATCHING
