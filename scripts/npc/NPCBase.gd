extends CharacterBody2D
class_name NPCBase

enum NPCState { PATROL, IDLE, WATCHING, QUERY, REPORTING }
enum NPCType { SUPERVISOR, GUARD, TECHNICIAN }

@export var npc_type: NPCType = NPCType.GUARD
@export var suspicion_score: float = 0.0
@export var audit_frequency: float = 0.5
@export var move_speed: float = 40.0
@export var sector_bounds: Vector2 = Vector2(800, 700) # Total facility size for quadrant logic

@onready var sprite: Polygon2D = $Sprite2D
@onready var observation_area: Area2D = $ObservationArea
@onready var query_timer: Timer = $QueryTimer
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var state: NPCState = NPCState.PATROL
var patrol_points: Array[Vector2] = []
var current_patrol_index: int = 0
var player_in_range: bool = false
var watch_timer: float = 0.0
var player_ref: PlayerController = null

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
			_do_idle(_delta)
		NPCState.WATCHING:
			_do_watching(delta)
		NPCState.QUERY:
			_do_query()
		NPCState.REPORTING:
			_do_reporting(_delta)

func _setup_patrol():
	# Only generate a default path if one wasn't pre-assigned (e.g. from Facility.gd)
	if not patrol_points.is_empty():
		return
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
	nav_agent.target_position = target
	
	if nav_agent.is_navigation_finished():
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		return
		
	var next_path_pos = nav_agent.get_next_path_position()
	var dir = (next_path_pos - global_position).normalized()
	
	velocity = dir * move_speed
	move_and_slide()
	
	# Update facing
	if dir.length() > 0.1:
		_update_facing(dir)

func _do_idle(_delta: float) -> void:
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
	
	# Assess player behavior (every 5 frames for performance)
	if Engine.get_physics_frames() % 5 == 0:
		_assess_player_behavior(delta * 5.0)
	
	# Check for query trigger
	if suspicion_score > 60.0 and state != NPCState.QUERY:
		if randf() < audit_frequency * delta:
			_trigger_query()
	
	# Check suspicion thresholds
	_check_suspicion_thresholds()

func _do_query() -> void:
	velocity = Vector2.ZERO
	# Query state is handled by TruthLoopGenerator

func _do_reporting(_delta: float) -> void:
	# Move toward nearest supervisor (or a fixed reporting point)
	var supervisors = get_tree().get_nodes_in_group("supervisor")
	if supervisors.is_empty():
		state = NPCState.PATROL # Nowhere to report
		return
	
	# Visual indicator - red tint while reporting
	if sprite:
		sprite.modulate = Color(0.9, 0.3, 0.3)
	
	# Guard against empty supervisors array
	if supervisors.is_empty():
		state = NPCState.PATROL
		return
		
	var nearest = supervisors[0]
	var min_dist = global_position.distance_to(nearest.global_position)
	for s in supervisors:
		var d = global_position.distance_to(s.global_position)
		if d < min_dist:
			min_dist = d
			nearest = s
			
	nav_agent.target_position = nearest.global_position
	
	if nav_agent.is_navigation_finished():
		# Report completed
		AuditSystem.add_flag(2, "npc_reported_behavior")
		state = NPCState.PATROL
		suspicion_score = 40.0 # Reset suspicion partially
		if sprite:
			sprite.modulate = Color.WHITE
		return
		
	var next_path_pos = nav_agent.get_next_path_position()
	var dir = (next_path_pos - global_position).normalized()
	
	velocity = dir * move_speed
	move_and_slide()
	_update_facing(dir)

func _assess_player_behavior(delta: float) -> void:
	if not player_ref:
		return
	
	var gain = 0.0
	
	# Check for jitter (visible anomaly)
	if Blackboard.cpu_current > 85.0:
		gain += 10.0 * delta
	
	# Check for smooth movement (too fluid for a robot)
	if player_ref.velocity.length() > 65.0:
		gain += 3.0 * delta
	
	# Check for being off-task
	var task = TaskManager.get_current_task()
	if task.is_empty():
		gain += 2.0 * delta
	elif task.get("sector", 0) != _get_current_sector(player_ref.global_position):
		gain += 1.0 * delta
	
	# Check for loitering
	if player_ref.velocity.length() < 5.0:
		gain += 1.0 * delta
	
	if gain > 0:
		_add_suspicion(gain)

func _get_current_sector(pos: Vector2 = global_position) -> int:
	# Quadrant-based sector calculation based on dynamic bounds
	var half_x = sector_bounds.x / 2.0
	var half_y = sector_bounds.y / 2.0
	
	var col = 0 if pos.x < half_x else 1
	var row = 0 if pos.y < half_y else 1
	return (row * 2) + col + 1

func _trigger_query() -> void:
	if state == NPCState.QUERY:
		return
	
	state = NPCState.QUERY
	var query = TruthLoopGenerator.generate(self)
	Blackboard.truth_loop_requested.emit(query)
	query_triggered.emit(self, query)
	
	# Pause NPC while query is active - with timeout to prevent soft-lock
	var timeout_timer = get_tree().create_timer(15.0)
	timeout_timer.timeout.connect(_on_query_timeout)
	await Blackboard.truth_loop_completed
	
	if state == NPCState.QUERY:  # Only change if still in QUERY (not already changed by timeout)
		state = NPCState.WATCHING

func _on_query_timeout() -> void:
	# Reset NPC to PATROL if still stuck in QUERY state
	if state == NPCState.QUERY:
		state = NPCState.PATROL

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
	# Simple facing update - Polygon2D uses scale.x instead of flip_h
	if abs(dir.x) > abs(dir.y):
		sprite.scale.x = -1.0 if dir.x < 0 else 1.0

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
