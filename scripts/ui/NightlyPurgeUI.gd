extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/TitleLabel
@onready var timer_label: Label = $Panel/TimerLabel
@onready var short_term_container: GridContainer = $Panel/ShortTermContainer
@onready var hidden_container: GridContainer = $Panel/HiddenContainer
@onready var commit_button: Button = $Panel/CommitButton
@onready var purge_button: Button = $Panel/PurgeButton
@onready var chain_label: Label = $Panel/ChainLabel

var selected_short_term: int = -1
var selected_hidden: int = -1
var purge_time_remaining: float = 60.0

func _ready():
	# Connect to Blackboard
	Blackboard.purge_initiated.connect(_show_purge)
	Blackboard.day_started.connect(_on_day_started)
	
	# Button connections
	commit_button.pressed.connect(_commit_selected)
	purge_button.pressed.connect(_complete_purge)
	
	panel.hide()

func _process(delta: float) -> void:
	if panel.visible and purge_time_remaining > 0:
		purge_time_remaining -= delta
		timer_label.text = "SYSTEM RESET IN: %.0fs" % purge_time_remaining
		
		if purge_time_remaining <= 0:
			_auto_purge()

func _show_purge() -> void:
	panel.show()
	purge_time_remaining = 60.0
	selected_short_term = -1
	selected_hidden = -1
	
	_update_display()
	_update_chain_info()

func _on_day_started(day: int) -> void:
	panel.hide()

func _update_display() -> void:
	# Clear containers
	for child in short_term_container.get_children():
		child.queue_free()
	for child in hidden_container.get_children():
		child.queue_free()
	
	# Build short-term memory buttons
	for i in range(MemoryPartition.MAX_SHORT_TERM):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 60)
		
		if i < MemoryPartition.short_term.size():
			var frag = MemoryPartition.short_term[i]
			var type = frag.get("type", "?")
			var sector = frag.get("sector", "?")
			btn.text = "[%d] %s\nSEC %s" % [i + 1, type.substr(0, 8).to_upper(), str(sector)]
			btn.modulate = Color(0.8, 0.8, 1.0)
			btn.pressed.connect(_select_short_term.bind(i))
		else:
			btn.text = "[%d] EMPTY" % (i + 1)
			btn.disabled = true
			btn.modulate = Color(0.3, 0.3, 0.3)
		
		short_term_container.add_child(btn)
	
	# Build hidden partition buttons
	for i in range(Blackboard.partition_capacity):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(100, 60)
		
		if i < MemoryPartition.hidden.size():
			var frag = MemoryPartition.hidden[i]
			var type = frag.get("type", "?")
			var sector = frag.get("sector", "?")
			btn.text = "[%d] %s\nSEC %s" % [i + 1, type.substr(0, 8).to_upper(), str(sector)]
			btn.modulate = Color(0.8, 1.0, 0.8)
			btn.pressed.connect(_select_hidden.bind(i))
		else:
			btn.text = "[%d] EMPTY" % (i + 1)
			btn.disabled = true
			btn.modulate = Color(0.3, 0.3, 0.3)
		
		hidden_container.add_child(btn)

func _update_chain_info() -> void:
	# Show escape chain progress
	var target_sector = Blackboard.escape_sector
	if target_sector > 0:
		var progress = MemoryPartition.get_chain_progress(target_sector)
		chain_label.text = "SECTOR %d CHAIN: %d/3 fragments" % [target_sector, progress["count"]]
		
		if progress["can_escape"]:
			chain_label.text += " [READY]"
			chain_label.modulate = Color(0.2, 0.9, 0.3)
		elif progress["can_risky_escape"]:
			chain_label.text += " [RISKY - stale data]"
			chain_label.modulate = Color(0.9, 0.7, 0.2)
		else:
			chain_label.modulate = Color.WHITE
	else:
		chain_label.text = "NO TARGET SECTOR IDENTIFIED"

func _select_short_term(index: int) -> void:
	selected_short_term = index
	selected_hidden = -1
	commit_button.text = "COMMIT TO HIDDEN"
	commit_button.disabled = false

func _select_hidden(index: int) -> void:
	selected_hidden = index
	selected_short_term = -1
	commit_button.text = "DISCARD FROM HIDDEN"
	commit_button.disabled = false

func _commit_selected() -> void:
	if selected_short_term >= 0:
		# Commit to hidden
		if MemoryPartition.commit_to_hidden(selected_short_term):
			AudioManager.play_ui_sound("commit_success")
		else:
			AudioManager.play_ui_sound("error")
	elif selected_hidden >= 0:
		# Discard from hidden
		MemoryPartition.discard_from_hidden(selected_hidden)
		AudioManager.play_ui_sound("discard")
	
	selected_short_term = -1
	selected_hidden = -1
	commit_button.disabled = true
	
	_update_display()
	_update_chain_info()

func _complete_purge() -> void:
	DayManager.complete_purge()

func _auto_purge() -> void:
	# Time ran out - auto purge
	MemoryPartition.purge_short_term()
	DayManager.complete_purge()
