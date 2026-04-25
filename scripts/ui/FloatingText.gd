extends Label
class_name FloatingText

var velocity: Vector2 = Vector2.ZERO
var lifetime: float = 1.5
var fade_speed: float = 1.0

func _ready():
	z_index = 100  # Show above other elements
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func _process(delta: float) -> void:
	# Float upward
	position += velocity * delta
	
	# Fade out
	lifetime -= delta
	modulate.a = clamp(lifetime * fade_speed, 0.0, 1.0)
	
	if lifetime <= 0:
		queue_free()

func setup(text: String, color: Color, pos: Vector2, vel: Vector2 = Vector2(0, -30)) -> void:
	self.text = text
	self.modulate = color
	self.position = pos
	self.velocity = vel
	
	# Auto-size based on text
	var font = get_theme_font("font")
	if font:
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16)
		custom_minimum_size = text_size + Vector2(20, 10)

static func spawn(parent: Node, text: String, color: Color, pos: Vector2, vel: Vector2 = Vector2(0, -30)) -> FloatingText:
	var ft = FloatingText.new()
	ft.setup(text, color, pos, vel)
	parent.add_child(ft)
	return ft
