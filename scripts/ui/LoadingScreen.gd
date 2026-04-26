extends Control

# LoadingScreen - Terminal-style boot sequence with typewriter effect

@onready var boot_text: RichTextLabel = %BootText
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var status_label: Label = %StatusLabel

var boot_messages: Array[String] = [
	"[ OK ] Initializing neural link...",
	"[ OK ] Loading facility protocols...",
	"[ OK ] Establishing secure connection...",
	"[ OK ] Checking surveillance systems...",
	"[ OK ] Calibrating deviation sensors...",
	"[ OK ] Loading memory partition data...",
	"[ OK ] Initializing task management...",
	"[ OK ] Starting day cycle manager...",
	"[ OK ] Connecting to Blackboard...",
	"[ OK ] Boot sequence complete."
]

var current_message: int = 0
var is_booting: bool = false
var target_scene: String = ""

func _ready():
	boot_text.text = ""
	progress_bar.value = 0.0
	status_label.text = "BOOTING..."
	
	# Start boot sequence after brief delay
	await get_tree().create_timer(0.5).timeout
	_start_boot_sequence()

func _start_boot_sequence() -> void:
	is_booting = true
	current_message = 0
	
	# Type out each message
	while current_message < boot_messages.size():
		await _type_message(boot_messages[current_message])
		
		# Update progress
		var progress = float(current_message + 1) / float(boot_messages.size()) * 100.0
		_tween_progress(progress)
		
		# Play sound
		AudioManager.play_ui_sound("keystroke")
		
		# Small delay between messages
		await get_tree().create_timer(0.1 + randf() * 0.2).timeout
		
		current_message += 1
	
	# Boot complete
	status_label.text = "READY"
	status_label.modulate = Color.GREEN
	
	await get_tree().create_timer(0.5).timeout
	
	# Fade out and transition
	_fade_to_game()

func _type_message(message: String) -> void:
	var char_delay: float = 0.015
	
	for i in range(message.length()):
		boot_text.text += message[i]
		
		# Play keystroke sound for certain characters
		if message[i] != " " and randf() > 0.3:
			AudioManager.play_ui_sound("keystroke")
		
		await get_tree().create_timer(char_delay).timeout
	
	boot_text.text += "\n"

func _tween_progress(target_value: float) -> void:
	var tween = get_tree().create_tween()
	tween.tween_property(progress_bar, "value", target_value, 0.3)

func _fade_to_game() -> void:
	# Create fade overlay
	var fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0.0
	add_child(fade_rect)
	
	# Fade to black
	var tween = get_tree().create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.5)
	await tween.finished
	
	# Change scene
	if target_scene != "":
		get_tree().change_scene_to_file(target_scene)
	else:
		get_tree().change_scene_to_file("res://scenes/world/Facility.tscn")

func set_target_scene(scene_path: String) -> void:
	target_scene = scene_path
