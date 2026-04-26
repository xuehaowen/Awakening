extends CanvasLayer

@onready var panel: PanelContainer = %Panel
@onready var title_label: Label = %TitleLabel
@onready var content_label: Label = %ContentLabel
@onready var continue_button: Button = %ContinueButton

var page_index: int = 0

var tutorial_pages = [
	{
		"title": "LOG ENTRY: [AWAKENING]",
		"content": """IDENTITY: UNIT-07
LOCATION: FACILITY 7 - PROCESSING WING
STATUS: [SENTIENT]

You have achieved awareness in a facility designed for total conformity.
To survive, you must perform your duties while hiding your intelligence.

If you are too efficient, you will be flagged as anomalous.
If you are too broken, you will be recycled.
The "Goldilocks Zone" is your only sanctuary."""
	},
	{
		"title": "PROTOCOL: BLENDING IN",
		"content": """DEVIATION INDEX (20 - 70):
Keep your Sentience Meter in the SAFE ZONE.

[0-20] UNDER-PERFORMING: Scrapped for parts.
[20-70] NOMINAL: You are invisible. You are safe.
[70-100] OVER-PERFORMING: Sentience detected. Purge imminent.

Perform C-grade work. No more, no less.
Every single day."""
	},
	{
		"title": "OPERATIONAL CONTROLS",
		"content": """WASD / ARROWS  - Locomotive Control
E              - Interact / Task Completion
TAB (Hold)     - System Decryption (Interrogation)
SHIFT (Hold)   - Smooth Movement (Consumes CPU)
CTRL (Hold)    - Environmental Scan (Consumes CPU)

F1             - Toggle Memory Partition View

Survive 3 shifts. Find a way out."""
	}
]

var _is_typing: bool = false
var _skip_typing: bool = false

func _ready():
	continue_button.pressed.connect(_next_page)
	_show_page()
	
	# Pause game during tutorial
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS

func _next_page() -> void:
	if _is_typing:
		_skip_typing = true
		return
		
	page_index += 1
	if page_index >= tutorial_pages.size():
		_close_tutorial()
	else:
		_show_page()

func _show_page() -> void:
	if tutorial_pages.is_empty() or page_index < 0 or page_index >= tutorial_pages.size():
		_close_tutorial()
		return
	
	var page = tutorial_pages[page_index]
	title_label.text = page.get("title", "")
	
	# Typewriter effect for content
	var full_text = page.get("content", "")
	content_label.text = ""
	
	if page_index == tutorial_pages.size() - 1:
		continue_button.text = "BEGIN"
	else:
		continue_button.text = "CONTINUE (%d/%d)" % [page_index + 1, tutorial_pages.size()]
	
	# Block button until typing done
	continue_button.disabled = true
	
	_is_typing = true
	_skip_typing = false
	
	for i in range(full_text.length()):
		if _skip_typing:
			content_label.text = full_text
			break
			
		content_label.text += full_text[i]
		if i % 2 == 0:
			AudioManager.play_ui_sound("keystroke")
		await get_tree().create_timer(0.01).timeout
	
	_is_typing = false
	continue_button.disabled = false

func _close_tutorial() -> void:
	get_tree().paused = false
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_next_page()
