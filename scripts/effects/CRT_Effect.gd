extends CanvasLayer

# CRT_Effect - Applies CRT monitor post-processing effect to the entire screen

@onready var effect_rect: ColorRect = $EffectRect

@export var enabled: bool = true:
	set(value):
		enabled = value
		_update_enabled()

@export var scanline_intensity: float = 0.15:
	set(value):
		scanline_intensity = value
		_update_shader_param("scanline_intensity", value)

@export var chromatic_aberration: float = 1.2:
	set(value):
		chromatic_aberration = value
		_update_shader_param("chromatic_aberration", value)

@export var vignette_intensity: float = 0.4:
	set(value):
		vignette_intensity = value
		_update_shader_param("vignette_intensity", value)

@export var noise_intensity: float = 0.03:
	set(value):
		noise_intensity = value
		_update_shader_param("noise_intensity", value)

@export var flicker_intensity: float = 0.02:
	set(value):
		flicker_intensity = value
		_update_shader_param("flicker_intensity", value)

func _ready():
	# Set up the color rect to cover the entire screen
	effect_rect.anchor_left = 0.0
	effect_rect.anchor_top = 0.0
	effect_rect.anchor_right = 1.0
	effect_rect.anchor_bottom = 1.0
	effect_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Load and apply shader
	var shader = load("res://assets/shaders/CRT_Effect.gdshader")
	if shader:
		var material = ShaderMaterial.new()
		material.shader = shader
		effect_rect.material = material
		_update_all_params()
	else:
		push_error("Failed to load CRT shader")

func _update_enabled():
	if effect_rect and effect_rect.material:
		effect_rect.material.set_shader_parameter("enabled", enabled)

func _update_shader_param(param: String, value: Variant):
	if effect_rect and effect_rect.material:
		effect_rect.material.set_shader_parameter(param, value)

func _update_all_params():
	_update_shader_param("enabled", enabled)
	_update_shader_param("scanline_intensity", scanline_intensity)
	_update_shader_param("chromatic_aberration", chromatic_aberration)
	_update_shader_param("vignette_intensity", vignette_intensity)
	_update_shader_param("noise_intensity", noise_intensity)
	_update_shader_param("flicker_intensity", flicker_intensity)

func pulse_intensity(duration: float = 0.5, multiplier: float = 2.0) -> void:
	"""Temporarily increase effect intensity for impact"""
	if not enabled:
		return
	
	var original_scanline = scanline_intensity
	var original_chromatic = chromatic_aberration
	
	# Tween to increased values
	var tween = get_tree().create_tween()
	tween.tween_method(func(v): _update_shader_param("scanline_intensity", v), 
		original_scanline, original_scanline * multiplier, duration * 0.3)
	tween.parallel().tween_method(func(v): _update_shader_param("chromatic_aberration", v),
		original_chromatic, original_chromatic * multiplier, duration * 0.3)
	
	# Tween back
	tween.tween_method(func(v): _update_shader_param("scanline_intensity", v),
		original_scanline * multiplier, original_scanline, duration * 0.7)
	tween.parallel().tween_method(func(v): _update_shader_param("chromatic_aberration", v),
		original_chromatic * multiplier, original_chromatic, duration * 0.7)
