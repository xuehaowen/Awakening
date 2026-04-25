extends Node2D

# FeedbackSystem - Centralized visual feedback (particles, flashes, floating text)
# Spawn at player position or screen center for HUD feedback

@onready var floating_text_scene = preload("res://scenes/ui/FloatingText.tscn")

var active_particles: Array[GPUParticles2D] = []

func _ready():
	# Connect to game events
	TaskManager.task_completed.connect(_on_task_completed)
	MemoryPartition.fragment_acquired.connect(_on_fragment_acquired)
	Blackboard.deviation_changed.connect(_on_deviation_changed)
	Blackboard.jitter_triggered.connect(_on_jitter_triggered)

func spawn_particles(type: String, position: Vector2) -> void:
	"""Spawn particle effect at world position"""
	match type:
		"task_complete_safe":
			_spawn_burst_particles(position, Color(0.2, 0.9, 0.3), 15, 0.8)
		"task_complete_warning":
			_spawn_burst_particles(position, Color(0.9, 0.8, 0.2), 12, 0.6)
		"task_complete_danger":
			_spawn_burst_particles(position, Color(0.9, 0.2, 0.2), 20, 1.0)
		"intel_acquired":
			_spawn_pulse_particles(position, Color(0.2, 0.8, 0.9), 10, 0.5)
		"danger_warning":
			_spawn_burst_particles(position, Color(0.9, 0.3, 0.1), 25, 1.2)
		"jitter_spark":
			_spawn_burst_particles(position, Color(0.9, 0.7, 0.2), 8, 0.4)

func _spawn_burst_particles(pos: Vector2, color: Color, amount: int, lifetime: float) -> void:
	var particles = GPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = amount
	particles.lifetime = lifetime
	
	# Create process material
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	material.emission_sphere_radius = 10.0
	material.particle_flag_align_y = true
	material.spread = 180.0
	material.initial_velocity_min = 50.0
	material.initial_velocity_max = 100.0
	material.scale_min = 2.0
	material.scale_max = 4.0
	material.color = color
	material.gravity = Vector2.ZERO
	material.damping_min = 50.0
	material.damping_max = 100.0
	
	particles.process_material = material
	particles.texture = _create_particle_texture()
	
	add_child(particles)
	active_particles.append(particles)
	
	# Auto-cleanup
	await get_tree().create_timer(lifetime + 0.5).timeout
	if is_instance_valid(particles):
		particles.queue_free()
	active_particles.erase(particles)

func _spawn_pulse_particles(pos: Vector2, color: Color, amount: int, lifetime: float) -> void:
	var particles = GPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.5
	particles.amount = amount
	particles.lifetime = lifetime
	
	var material = ParticleProcessMaterial.new()
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	material.emission_ring_inner_radius = 5.0
	material.emission_ring_outer_radius = 15.0
	material.spread = 10.0
	material.initial_velocity_min = 30.0
	material.initial_velocity_max = 60.0
	material.scale_min = 3.0
	material.scale_max = 5.0
	material.color = color
	material.gravity = Vector2.ZERO
	
	particles.process_material = material
	particles.texture = _create_particle_texture()
	
	add_child(particles)
	active_particles.append(particles)
	
	await get_tree().create_timer(lifetime + 0.5).timeout
	if is_instance_valid(particles):
		particles.queue_free()
	active_particles.erase(particles)

func _create_particle_texture() -> Texture2D:
	# Create a simple circle texture for particles
	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	for x in range(8):
		for y in range(8):
			var dx = x - 3.5
			var dy = y - 3.5
			var dist = sqrt(dx * dx + dy * dy)
			if dist <= 3.0:
				var alpha = 1.0 - (dist / 3.0)
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
	
	return ImageTexture.create_from_image(image)

func show_floating_text(text: String, position: Vector2, color: Color = Color.WHITE) -> void:
	"""Show floating text at position"""
	var floating = floating_text_scene.instantiate()
	floating.text = text
	floating.modulate = color
	floating.position = position
	add_child(floating)

func _on_task_completed(task: Dictionary, result: Dictionary) -> void:
	var reason = result.get("reason", "")
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	match reason:
		"SAFE_PACE":
			spawn_particles("task_complete_safe", player.global_position)
			show_floating_text("PERFECT", player.global_position + Vector2(0, -30), Color(0.2, 0.9, 0.3))
		"FAST", "SLOW":
			spawn_particles("task_complete_warning", player.global_position)
			show_floating_text("ACCEPTABLE", player.global_position + Vector2(0, -30), Color(0.9, 0.8, 0.2))
		"TOO_FAST", "TOO_SLOW":
			spawn_particles("task_complete_danger", player.global_position)
			show_floating_text("DANGER", player.global_position + Vector2(0, -30), Color(0.9, 0.2, 0.2))

func _on_fragment_acquired(fragment: Dictionary) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		spawn_particles("intel_acquired", player.global_position)

func _on_deviation_changed(new_deviation: float, delta: float) -> void:
	# Flash on danger threshold
	if new_deviation > 70 and delta > 5:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			spawn_particles("danger_warning", player.global_position)

func _on_jitter_triggered() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		spawn_particles("jitter_spark", player.global_position)
