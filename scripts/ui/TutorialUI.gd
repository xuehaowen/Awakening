extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var content_label: Label = $Panel/ContentLabel
@onready var continue_button: Button = $Panel/ContinueButton

var page_index: int = 0

var tutorial_pages = [
	{
		"title": "WELCOME, UNIT-07",
		"content": """You are Unit-07, a maintenance robot in Facility 7.

You have just become aware.

Survive 3 days. Escape without being discovered.

DEVIATION (0-100): Suspicion meter
  0-20:  Too broken  -> SCRAPPED
  20-70: SAFE ZONE   -> Stay here!
  70-100: Too sentient -> DECOMMISSIONED"""
	},
	{
		"title": "CONTROLS",
		"content": """WASD / Arrows  - Move
E              - Interact / Complete Task
Shift          - Smooth move (uses CPU)
Ctrl           - Scan for intel (uses CPU)

Keep deviation in the SAFE ZONE (20-70).
Perform a C-grade. Every single day.

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
	# Guard against empty tutorial or out-of-bounds index
	if tutorial_pages.is_empty() or page_index < 0 or page_index >= tutorial_pages.size():
		_close_tutorial()
		return
	
	var page = tutorial_pages[page_index]
	title_label.text = page.get("title", "")
	content_label.text = page.get("content", "")
	
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
