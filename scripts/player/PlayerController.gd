extends CharacterBody2D

@onready var cpu_manager: Node = $CPUManager
@onready var deviation_tracker: Node = $DeviationTracker
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Polygon2D = $Sprite2D
@onready var jitter_shader: ShaderMaterial = $Sprite2D.material
@onready var interaction_area: Area2D = $InteractionArea
@onready var scan_area: Area2D = $ScanArea

# Movement
const BASE_SPEED: float = 60.0
const SMOOTH_SPEED: float = 69.0  # +15% speed boost (was 100.0 = +67%)
const JITTER_NOISE: float = 15.0

var current_speed: float = BASE_SPEED
var is_moving: bool = false
var facing_direction: Vector2 = Vector2.DOWN

# Task handling
var current_task_target: Vector2 = Vector2.ZERO
var is_at_task: bool = false

# Jitter effect
var jitter_active: bool = false
var jitter_intensity: float = 0.0

# Passive scan timer
var scan_tick_timer: float = 0.0
const SCAN_TICK_INTERVAL: float = 5.0  # Roll for intel every 5s while scan is on

func _ready():
	add_to_group("player")
	
	# Connect to Blackboard signals
	Blackboard.jitter_triggered.connect(_on_jitter_triggered)
	Blackboard.game_over.connect(_on_game_over)
	
	# Setup navigation
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	
	# Setup areas
	interaction_area.body_entered.connect(_on_interaction_area_entered)
	scan_area.body_entered.connect(_on_scan_area_entered)
	scan_area.body_exited.connect(_on_scan_area_exited)

func _physics_process(delta: float) -> void:
	_handle_input()
	_update_movement(delta)
	_update_jitter(delta)
	_update_animation()
	_update_scan_tick(delta)

func _handle_input() -> void:
	if not DayManager.is_playing():
		return
	
	# Toggle passive scan
	if Input.is_action_just_pressed("override_scan"):
		var new_state = not cpu_manager.overrides_active["passive_scan"]
		cpu_manager.set_override("passive_scan", new_state)
		print("Passive scan: ", "ON" if new_state else "OFF")
	
	# Active decrypt is handled in Truth Loop UI
	
	# Smooth movement override
	var smooth_active = Input.is_action_pressed("override_smooth")
	cpu_manager.set_override("smooth_movement", smooth_active)
	
	# Interaction
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	
	if Input.is_action_just_pressed("open_memory"):
		# Toggle memory view visibility via HUD
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("toggle_memory_view"):
			hud.toggle_memory_view()
		else:
			# Fallback: show memory info as interaction feedback
			var mem_count = MemoryPartition.hidden.size()
			var mem_capacity = MemoryPartition.capacity
			Blackboard.interaction_feedback.emit("HIDDEN MEMORY: %d/%d slots used" % [mem_count, mem_capacity], "info")

func _update_movement(delta: float) -> void:
	var input_dir = Vector2.ZERO
	
	# Get input
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	
	is_moving = input_dir.length() > 0.1
	
	if is_moving:
		facing_direction = input_dir.normalized()
		
		# Determine speed based on smooth movement override
		var target_speed = SMOOTH_SPEED if cpu_manager.overrides_active["smooth_movement"] else BASE_SPEED
		
		# Apply jitter noise if CPU is high and not using smooth movement
		if Blackboard.cpu_current > 85.0 and not cpu_manager.overrides_active["smooth_movement"]:
			input_dir += Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
			target_speed *= 0.8  # Jitter slows you down
		
		current_speed = lerp(current_speed, target_speed, delta * 10.0)
		velocity = input_dir.normalized() * current_speed
	else:
		velocity = Vector2.ZERO
		current_speed = lerp(current_speed, 0.0, delta * 10.0)
	
	move_and_slide()

func _update_jitter(delta: float) -> void:
	if jitter_active:
		jitter_intensity = lerp(jitter_intensity, 1.0, delta * 5.0)
	else:
		jitter_intensity = lerp(jitter_intensity, 0.0, delta * 3.0)
	
	# Update shader
	if jitter_shader:
		jitter_shader.set_shader_parameter("intensity", jitter_intensity)
		jitter_shader.set_shader_parameter("time", Time.get_time_dict_from_system()["second"])

func _update_animation() -> void:
	if is_moving:
		# Simple bobbing animation
		sprite.position.y = sin(Time.get_ticks_msec() * 0.01) * 1.5
	else:
		sprite.position.y = 0.0

func _on_jitter_triggered() -> void:
	jitter_active = true
	
	# Create visual glitch effect
	if sprite and is_instance_valid(sprite):
		sprite.modulate = Color(1.2, 0.8, 0.8)
		await get_tree().create_timer(0.2).timeout
		if is_instance_valid(sprite):
			sprite.modulate = Color.WHITE
	
	# Reset after duration
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(self):
		jitter_active = false

func _on_game_over(reason: String) -> void:
	set_physics_process(false)

func _try_interact() -> void:
	# Check for nearby interactables
	var bodies = interaction_area.get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("interactable"):
			if body.has_method("interact"):
				body.interact(self)
				return
	
	# If at a task location, try to complete it
	if is_at_task:
		_complete_current_task()

func _complete_current_task() -> void:
	var result = TaskManager.complete_current_task()
	print("Task completed: ", result)
	
	# Apply deviation delta from task completion (Goldilocks scoring)
	if result.has("deviation_delta") and result["deviation_delta"] != 0:
		Blackboard.add_deviation(result["deviation_delta"], result.get("reason", "task_completion"))
	
	# Show floating text
	_show_floating_text(result.get("reason", "task_completed"), result.get("deviation_delta", 0))
	
	is_at_task = false

func _show_floating_text(reason: String, delta: float) -> void:
	var label = Label.new()
	var sign_str = "+" if delta > 0 else ""
	label.text = "%s %s%d" % [reason.replace("_", " "), sign_str, int(delta)]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Colorize: red for positive delta (suspicion gain), green for negative (reward)
	label.modulate = Color(0.9, 0.2, 0.2) if delta > 0 else Color(0.2, 0.9, 0.3)
	if delta == 0: label.modulate = Color.WHITE
	
	label.set("theme_override_font_sizes/font_size", 14)
	label.set("theme_override_colors/font_outline_color", Color.BLACK)
	label.set("theme_override_constants/outline_size", 4)
	
	add_child(label)
	label.top_level = true
	label.global_position = global_position + Vector2(-50, -40)
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0, -60), 1.5)
	tween.tween_property(label, "modulate:a", 0.0, 1.5)
	tween.finished.connect(label.queue_free)

func _on_interaction_area_entered(body: Node) -> void:
	if body.is_in_group("npc"):
		deviation_tracker._on_npc_entered_range(body)

func _on_interaction_area_exited(body: Node) -> void:
	if body.is_in_group("npc"):
		deviation_tracker._on_npc_exited_range(body)

func _on_scan_area_entered(body: Node) -> void:
	# Initial roll when entering range
	if body.is_in_group("intel_source"):
		if cpu_manager.overrides_active["passive_scan"]:
			_attempt_gather_intel(body)

func _on_scan_area_exited(_body: Node) -> void:
	pass

func _update_scan_tick(delta: float) -> void:
	if not cpu_manager.overrides_active["passive_scan"]:
		scan_tick_timer = 0.0
		return
	scan_tick_timer += delta
	if scan_tick_timer >= SCAN_TICK_INTERVAL:
		scan_tick_timer = 0.0
		for body in scan_area.get_overlapping_bodies():
			if body.is_in_group("intel_source"):
				_attempt_gather_intel(body)
				break  # One roll per tick

func _attempt_gather_intel(source: Node) -> void:
	# Roll for intel fragment
	if randf() < 0.3:  # 30% chance per scan tick
		# Get sector from source if available
		var preferred_sector = -1
		if source.has_method("get_sector"):
			preferred_sector = source.get_sector()
		elif source.has_meta("sector_id"):
			preferred_sector = source.get_meta("sector_id")
		elif "sector_id" in source:
			preferred_sector = source.sector_id
		
		# Generate fragment with preferred sector
		var fragment = MemoryPartition.generate_random_fragment("", preferred_sector)
		if MemoryPartition.add_to_short_term(fragment):
			AudioManager.play_intel_acquired()
			print("Intel acquired: ", fragment["type"], " for Sector ", fragment.get("sector", "?"))

func teleport_to(target_position: Vector2) -> void:
	global_position = target_position
	velocity = Vector2.ZERO

func _exit_tree() -> void:
	# Disconnect signals to prevent memory leaks
	if Blackboard.jitter_triggered.is_connected(_on_jitter_triggered):
		Blackboard.jitter_triggered.disconnect(_on_jitter_triggered)
	if Blackboard.game_over.is_connected(_on_game_over):
		Blackboard.game_over.disconnect(_on_game_over)
	if interaction_area and interaction_area.body_entered.is_connected(_on_interaction_area_entered):
		interaction_area.body_entered.disconnect(_on_interaction_area_entered)
	if scan_area and scan_area.body_entered.is_connected(_on_scan_area_entered):
		scan_area.body_entered.disconnect(_on_scan_area_entered)
	if scan_area and scan_area.body_exited.is_connected(_on_scan_area_exited):
		scan_area.body_exited.disconnect(_on_scan_area_exited)
