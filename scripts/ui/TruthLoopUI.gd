extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var prompt_label: Label = $Panel/PromptLabel
@onready var responses_container: VBoxContainer = $Panel/ResponsesContainer
@onready var timer_bar: ProgressBar = $Panel/TimerBar
@onready var decrypt_hint: Label = $Panel/DecryptHint

var current_query: Dictionary = {}
var response_timer: float = 0.0
var decrypt_active: bool = false
var selected_index: int = -1
var is_transitioning: bool = false  # Prevents race conditions between coroutines

func _ready():
	# Connect to Blackboard
	Blackboard.truth_loop_requested.connect(_show_query)
	
	# Connect to TruthLoopGenerator signals
	TruthLoopGenerator.context_mismatch_triggered.connect(_on_context_mismatch)
	TruthLoopGenerator.followup_triggered.connect(_on_followup_triggered)
	
	# Hide initially
	panel.hide()
	set_process_input(true)

func _process(delta: float) -> void:
	if not panel.visible:
		return
	
	# Update timer
	if response_timer > 0:
		response_timer -= delta
		timer_bar.value = (response_timer / current_query.get("timer", 8.0)) * 100
		
		if response_timer <= 0:
			_timeout_silence()
	
	# Check for decrypt input
	if Input.is_action_pressed("override_decrypt"):
		if not decrypt_active:
			decrypt_active = true
			_decrypt_scan()
	else:
		if decrypt_active:
			decrypt_active = false
			_decrypt_scan()  # Restore button colors and remove [ANOMALY DETECTED]

func _input(event: InputEvent) -> void:
	if not panel.visible:
		return
	
	# Number keys for response selection
	for i in range(4):
		if event.is_action_pressed("ui_" + str(i + 1)) or \
		   (event is InputEventKey and event.pressed and event.keycode == KEY_1 + i):
			_select_response(i)
			return

func _show_query(query: Dictionary) -> void:
	current_query = query
	response_timer = query.get("timer", 8.0)
	selected_index = -1
	decrypt_active = false
	
	# Show panel
	panel.show()
	
	# Pause the game (but keep UI processing)
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_input(true)
	
	# Set prompt with typewriter effect
	var prompt_text = "> " + query.get("prompt_text", "QUERY?")
	if prompt_label.has_method("type_text"):
		prompt_label.type_text(prompt_text)
	else:
		prompt_label.text = prompt_text
	
	# Clear and rebuild responses
	for child in responses_container.get_children():
		child.queue_free()
	
	var responses = query.get("responses", [])
	for i in range(responses.size()):
		var btn = Button.new()
		var text = responses[i].get("text", "Option " + str(i + 1))
		btn.text = "[%d] %s" % [i + 1, text]
		btn.pressed.connect(_select_response.bind(i))
		
		# Style as terminal button
		btn.theme_type_variation = "TerminalButton"
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		
		responses_container.add_child(btn)
	
	# Show decrypt hint
	decrypt_hint.text = "[Hold SHIFT to analyze responses]"
	decrypt_hint.modulate = Color(0.5, 0.5, 0.5)
	
	# Reset timer bar
	timer_bar.value = 100

func _decrypt_scan() -> void:
	# Highlight fake-safe responses when decrypt is active
	var fake_index = TruthLoopGenerator.get_fake_safe_index()
	var buttons = responses_container.get_children()
	var responses = current_query.get("responses", [])
	
	for i in range(buttons.size()):
		if i >= responses.size():
			continue
		
		var original_text = "[%d] %s" % [i + 1, responses[i].get("text", "Option")]
		
		if i == fake_index and decrypt_active:
			buttons[i].modulate = Color(0.8, 0.2, 0.2)
			buttons[i].text = original_text + " [ANOMALY DETECTED]"
		else:
			buttons[i].modulate = Color.WHITE
			buttons[i].text = original_text

func _select_response(index: int) -> void:
	if index < 0 or index >= current_query.get("responses", []).size():
		return
	if is_transitioning:
		return  # Prevent double-clicks during transition
	
	is_transitioning = true
	selected_index = index
	var response = TruthLoopGenerator.select_response(index, decrypt_active)
	
	# If a follow-up is being triggered, don't complete yet — wait for followup_triggered
	# The followup_triggered signal handler will show the next query or close
	if not TruthLoopGenerator.followup_mode:
		# No follow-up: close panel and complete
		get_tree().paused = false
		panel.hide()
		is_transitioning = false
		var risk = response.get("risk", 0) if response else 0
		Blackboard.truth_loop_completed.emit(risk)
	else:
		# Follow-up pending: emit completion but keep panel open for context mismatch display
		# context_mismatch handler will hide panel, then followup_triggered will reopen
		var risk = response.get("risk", 0) if response else 0
		Blackboard.truth_loop_completed.emit(risk)
		# is_transitioning remains true until followup completes or context mismatch cleanup

func _timeout_silence() -> void:
	if is_transitioning:
		return
	
	is_transitioning = true
	TruthLoopGenerator.timeout_silence()
	
	# Unpause
	get_tree().paused = false
	panel.hide()
	is_transitioning = false
	
	Blackboard.truth_loop_completed.emit(30)

func _on_context_mismatch(_npc_type: String, _reason: String) -> void:
	# Show feedback label with CONTEXT_MISMATCH warning
	prompt_label.text += "\n\n[CONTEXT_MISMATCH] Response incongruent with unit operational parameters."
	prompt_label.modulate = Color(0.9, 0.3, 0.3)
	
	# Disable all response buttons to prevent double-submit
	for btn in responses_container.get_children():
		btn.disabled = true
	
	# Keep panel visible briefly to show the feedback
	await get_tree().create_timer(1.5).timeout
	
	# Only hide if we're not about to show a follow-up
	# followup_triggered will handle showing the next query
	if not TruthLoopGenerator.followup_mode:
		panel.hide()
		get_tree().paused = false
		is_transitioning = false
	prompt_label.modulate = Color.WHITE

func _on_followup_triggered(npc: Node) -> void:
	# Supervisor fires a follow-up query after catching a fake-safe response
	# Give a brief pause before re-interrogating
	await get_tree().create_timer(0.5).timeout
	is_transitioning = false  # Reset for the new query
	var followup_query = TruthLoopGenerator.generate(npc, "status_check")
	_show_query(followup_query)
