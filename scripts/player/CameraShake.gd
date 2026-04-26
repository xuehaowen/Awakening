extends Camera2D

# CameraShake - Trauma-based camera shake system
# Based on classic game dev pattern: trauma decays, shake = trauma^2

@export var max_offset: Vector2 = Vector2(20, 15)
@export var max_rotation: float = 5.0
@export var trauma_decay: float = 1.5  # How fast trauma fades
@export var noise_speed: float = 10.0

var trauma: float = 0.0  # 0.0 to 1.0
var noise: FastNoiseLite
var time: float = 0.0

func _ready():
	# Setup noise for smooth random shake
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.5
	
	# Connect to game events
	Blackboard.deviation_changed.connect(_on_deviation_changed)
	Blackboard.game_over.connect(_on_game_over)
	TaskManager.task_completed.connect(_on_task_completed)

func _process(delta):
	if trauma > 0:
		# Decay trauma over time
		trauma = max(trauma - trauma_decay * delta, 0.0)
		
		# Calculate shake intensity (trauma squared for non-linear falloff)
		var shake = trauma * trauma
		
		# Advance noise time
		time += delta * noise_speed
		
		# Apply offset using noise
		offset.x = noise.get_noise_1d(time) * max_offset.x * shake
		offset.y = noise.get_noise_1d(time + 1000) * max_offset.y * shake
		rotation_degrees = noise.get_noise_1d(time + 2000) * max_rotation * shake
	else:
		# Reset when no trauma
		offset = Vector2.ZERO
		rotation_degrees = 0.0

func add_trauma(amount: float) -> void:
	"""Add trauma (0.0 to 1.0 scale)"""
	trauma = min(trauma + amount, 1.0)

func shake(intensity: float, duration: float = 0.5) -> void:
	"""One-shot shake with specified intensity and duration"""
	add_trauma(intensity)
	
	# If duration specified, we could use a timer, but for now
	# we let natural decay handle it

func _on_deviation_changed(new_deviation: float, source: String) -> void:
	# Small shake when entering danger zones
	if new_deviation > 70:
		add_trauma(0.1)  # Light shake on suspicion rise
	elif new_deviation > 85:
		add_trauma(0.2)  # Medium shake near critical

func _on_game_over(reason: String, message: String) -> void:
	# Big shake on game over
	add_trauma(0.8)

func _on_task_completed(task: Dictionary, result: Dictionary) -> void:
	# Shake based on task result
	var reason = result.get("reason", "")
	match reason:
		"TOO_FAST", "TOO_SLOW":
			add_trauma(0.3)  # Bad performance = noticeable shake
		"FAST", "SLOW":
			add_trauma(0.15)  # Warning zone = light shake
		_:
			add_trauma(0.05)  # Safe = tiny celebratory shake
