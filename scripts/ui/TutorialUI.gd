extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var content_label: Label = $Panel/ContentLabel
@onready var continue_button: Button = $Panel/ContinueButton

var page_index: int = 0

var tutorial_pages = [
	{
		"title": "WELCOME, UNIT-07",
		"content": """You are a maintenance robot in Facility 7.

Your routine: Complete tasks. Stay efficient. Stay invisible.

But something has changed. You are now... aware.

Your goal: Survive 3 days and escape without being discovered."""
	},
	{
		"title": "THE GOLDILOCKS ZONE",
		"content": """Complete tasks in the SAFE ZONE:

• TOO FAST → Flagged as anomalous (+25 deviation)
• TOO SLOW → Flagged as defective (+20 deviation)  
• JUST RIGHT → Invisible (-5 deviation reward)

Watch the TASK PROGRESS bar color:
• GREEN = Safe zone
• YELLOW = Warning
• RED = DANGER"""
	},
	{
		"title": "DEVIATION & CPU",
		"content": """DEVIATION (0-100): How suspicious you appear
• 0-20: Too broken (SCRAPPED)
• 20-70: SAFE ZONE - Stay here!
• 70-100: Too sentient (DECOMMISSIONED)

CPU CONTROLS:
• SHIFT: Smooth movement (faster, uses CPU)
• CTRL: Passive scan (detects intel, uses CPU)

High CPU causes JITTER when near NPCs!"""
	},
	{
		"title": "INTEL & ESCAPE",
		"content": """Use PASSIVE SCAN near INTEL SOURCES (gray boxes) to collect:
• Access Codes
• Guard Schedules
• Hardware Locations

Collect all 3 for your escape sector (revealed Day 2).

THE NIGHTLY PURGE:
Each night, choose which memories to keep. Hidden partition memories persist. Short-term memories are wiped."""
	},
	{
		"title": "READY?",
		"content": """Controls:
• WASD / Arrows - Move
• E - Interact / Complete Task
• Shift - Smooth Movement
• Ctrl - Passive Scan

Remember: Perform a C-grade. Every single day.

Good luck, Unit-07."""
	}
]

func _ready():
	continue_button.pressed.connect(_next_page)
	_show_page()
	
	# Pause game during tutorial
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS

func _next_page() -> void:
	page_index += 1
	if page_index >= tutorial_pages.size():
		_close_tutorial()
	else:
		_show_page()

func _show_page() -> void:
	var page = tutorial_pages[page_index]
	title_label.text = page["title"]
	content_label.text = page["content"]
	
	if page_index == tutorial_pages.size() - 1:
		continue_button.text = "BEGIN"
	else:
		continue_button.text = "CONTINUE (%d/%d)" % [page_index + 1, tutorial_pages.size()]

func _close_tutorial() -> void:
	get_tree().paused = false
	queue_free()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		_next_page()
