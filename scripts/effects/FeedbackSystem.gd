extends Node2D

# FeedbackSystem - Centralized visual feedback (particles, flashes, floating text)
# Spawn at player position or screen center for HUD feedback

# FloatingText is created programmatically — no external scene required

var active_particles: Array[GPUParticles2D] = []

func _ready():
	# Connect to game events
	TaskManager.task_completed.connect(_on_task_completed)
	MemoryPartition.fragment_acquired.connect(_on_fragment_acquired)
	Blackboard.deviation_changed.connect(_on_deviation_changed)
	Blackboard.jitter_triggered.connect(_on_jitter_triggered)

func spawn_particles(type: String, spawn_pos: Vector2) -> void:
	"""Spawn particle effect at world position"""
	match type:
		"task_complete_safe":
			_spawn_burst_particles(spawn_pos, Color(0.2, 0.9, 0.3), 15, 0.8)
		"task_complete_warning":
			_spawn_burst_particles(spawn_pos, Color(0.9, 0.8, 0.2), 12, 0.6)
		"task_complete_danger":
			_spawn_burst_particles(spawn_pos, Color(0.9, 0.2, 0.2), 20, 1.0)
		"intel_acquired":
			_spawn_pulse_particles(spawn_pos, Color(0.2, 0.8, 0.9), 10, 0.5)
		"danger_warning":
			_spawn_burst_particles(spawn_pos, Color(0.9, 0.3, 0.1), 25, 1.2)
		"jitter_spark":
			_spawn_spark_particles(spawn_pos, Color(0.9, 0.7, 0.2), 6)
		"electric_sparks":
			_spawn_spark_particles(spawn_pos, Color(0.8, 0.9, 1.0), 12)
		"dust_motes":
			_spawn_dust_particles(spawn_pos, Color(0.7, 0.7, 0.6), 20)
		"glitch_fragments":
			_spawn_glitch_particles(spawn_pos, Color(0.9, 0.2, 0.9), 15)

func _spawn_burst_particles(pos: Vector2, color: Color, amount: int, lifetime: float) -> void:
	var particles = GPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = amount
	particles.lifetime = lifetime
	
	# Create process material
	var p_material = ParticleProcessMaterial.new()
	p_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p_material.emission_sphere_radius = 10.0
	p_material.particle_flag_align_y = true
	p_material.spread = 180.0
	p_material.initial_velocity_min = 50.0
	p_material.initial_velocity_max = 100.0
	p_material.scale_min = 2.0
	p_material.scale_max = 4.0
	p_material.color = color
	p_material.gravity = Vector3.ZERO
	p_material.damping_min = 50.0
	p_material.damping_max = 100.0
	
	particles.process_material = p_material
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
	
	var p_material = ParticleProcessMaterial.new()
	p_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	p_material.emission_ring_inner_radius = 5.0
	p_material.emission_ring_radius = 15.0
	p_material.spread = 10.0
	p_material.initial_velocity_min = 30.0
	p_material.initial_velocity_max = 60.0
	p_material.scale_min = 3.0
	p_material.scale_max = 5.0
	p_material.color = color
	p_material.gravity = Vector3.ZERO
	
	particles.process_material = p_material
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

func _spawn_spark_particles(pos: Vector2, color: Color, amount: int) -> void:
	"""Spawn electric spark particles - fast, jagged, short-lived"""
	var particles = GPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = amount
	particles.lifetime = 0.3
	particles.preprocess = 0.05
	
	var p_material = ParticleProcessMaterial.new()
	p_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	p_material.spread = 180.0
	p_material.initial_velocity_min = 100.0
	p_material.initial_velocity_max = 250.0
	p_material.scale_min = 1.0
	p_material.scale_max = 3.0
	p_material.color = color
	p_material.gravity = Vector2(0, 200)
	
	particles.process_material = p_material
	particles.texture = _create_spark_texture()
	
	add_child(particles)
	active_particles.append(particles)
	
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(particles):
		particles.queue_free()
	active_particles.erase(particles)

func _spawn_dust_particles(pos: Vector2, color: Color, amount: int) -> void:
	"""Spawn floating dust motes - slow, ambient, long-lived"""
	var particles = GPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.0
	particles.amount = amount
	particles.lifetime = 3.0
	
	var p_material = ParticleProcessMaterial.new()
	p_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p_material.emission_box_extents = Vector3(50, 50, 0)
	p_material.spread = 180.0
	p_material.initial_velocity_min = 5.0
	p_material.initial_velocity_max = 20.0
	p_material.scale_min = 1.0
	p_material.scale_max = 4.0
	p_material.color = color
	p_material.color.a = 0.4
	p_material.gravity = Vector2(0, -10)
	
	particles.process_material = p_material
	particles.texture = _create_dust_texture()
	
	add_child(particles)
	active_particles.append(particles)
	
	await get_tree().create_timer(3.5).timeout
	if is_instance_valid(particles):
		particles.queue_free()
	active_particles.erase(particles)

func _spawn_glitch_particles(pos: Vector2, color: Color, amount: int) -> void:
	"""Spawn glitch fragments - digital-looking square particles"""
	var particles = GPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = amount
	particles.lifetime = 0.5
	
	var p_material = ParticleProcessMaterial.new()
	p_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	p_material.emission_sphere_radius = 15.0
	p_material.spread = 180.0
	p_material.initial_velocity_min = 50.0
	p_material.initial_velocity_max = 150.0
	p_material.scale_min = 2.0
	p_material.scale_max = 6.0
	p_material.color = color
	p_material.gravity = Vector3.ZERO
	
	particles.process_material = p_material
	particles.texture = _create_glitch_texture()
	
	add_child(particles)
	active_particles.append(particles)
	
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(particles):
		particles.queue_free()
	active_particles.erase(particles)

func _create_spark_texture() -> Texture2D:
	# Create a lightning-bolt shape for sparks
	var image = Image.create(8, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Draw jagged line
	var points = [Vector2(4, 0), Vector2(2, 4), Vector2(6, 8), Vector2(3, 12), Vector2(5, 15)]
	for i in range(points.size() - 1):
		var start = points[i]
		var end = points[i + 1]
		var steps = int(start.distance_to(end))
		for j in range(steps):
			var t = float(j) / steps
			var x = int(lerp(start.x, end.x, t))
			var y = int(lerp(start.y, end.y, t))
			if x >= 0 and x < 8 and y >= 0 and y < 16:
				image.set_pixel(x, y, Color.WHITE)
				# Add glow around center
				if x > 0: image.set_pixel(x - 1, y, Color(1, 1, 1, 0.5))
				if x < 7: image.set_pixel(x + 1, y, Color(1, 1, 1, 0.5))
	
	return ImageTexture.create_from_image(image)

func _create_dust_texture() -> Texture2D:
	# Create soft circle for dust
	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	for x in range(8):
		for y in range(8):
			var dx = x - 3.5
			var dy = y - 3.5
			var dist = sqrt(dx * dx + dy * dy)
			if dist <= 3.0:
				var alpha = (1.0 - (dist / 3.0)) * 0.6
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
	
	return ImageTexture.create_from_image(image)

func _create_glitch_texture() -> Texture2D:
	# Create square/rectangular glitch fragments
	var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	
	# Draw a pixelated square with some randomness
	for x in range(2, 6):
		for y in range(2, 6):
			image.set_pixel(x, y, Color.WHITE)
	# Add some pixels extending for glitch look
	image.set_pixel(1, 3, Color(1, 1, 1, 0.7))
	image.set_pixel(6, 4, Color(1, 1, 1, 0.7))
	image.set_pixel(4, 1, Color(1, 1, 1, 0.5))
	image.set_pixel(3, 6, Color(1, 1, 1, 0.5))
	
	return ImageTexture.create_from_image(image)

func show_floating_text(text: String, spawn_pos: Vector2, color: Color = Color.WHITE) -> void:
	"""Show floating text at position (programmatic, no external scene)"""
	var label = Label.new()
	label.text = text
	label.modulate = color
	label.position = spawn_pos
	label.z_index = 10
	# Style
	var settings = LabelSettings.new()
	settings.font_size = 14
	settings.outline_size = 2
	settings.outline_color = Color(0, 0, 0, 0.8)
	label.label_settings = settings
	add_child(label)
	# Animate: float up and fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position", spawn_pos + Vector2(0, -40), 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9)
	await tween.finished
	if is_instance_valid(label):
		label.queue_free()

func _on_task_completed(_task: Dictionary, result: Dictionary) -> void:
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

func _on_fragment_acquired(_fragment: Dictionary) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		spawn_particles("intel_acquired", player.global_position)

func _on_deviation_changed(new_deviation: float, _source: String) -> void:
	# Flash on danger threshold
	if new_deviation > 70:
		var player = get_tree().get_first_node_in_group("player")
		if player:
			spawn_particles("danger_warning", player.global_position)

func _on_jitter_triggered() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		spawn_particles("jitter_spark", player.global_position)
