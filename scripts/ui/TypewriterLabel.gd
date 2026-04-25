extends Label

# TypewriterLabel - Types out text character by character for terminal aesthetic

@export var char_delay: float = 0.03  # Seconds between characters
@export var start_delay: float = 0.0   # Delay before starting
@export var play_sound: bool = true    # Play keystroke sound

signal typing_finished
signal character_typed(char_index: int)

var _full_text: String = ""
var _current_index: int = 0
var _timer: float = 0.0
var _is_typing: bool = false
var _paused: bool = false

func _ready():
	# Store initial text if any
	if text.length() > 0:
		type_text(text)

func _process(delta: float) -> void:
	if not _is_typing or _paused:
		return
	
	_timer -= delta
	
	while _timer <= 0 and _is_typing and _current_index < _full_text.length():
		_type_next_char()
		_timer += char_delay

func type_text(new_text: String, clear_first: bool = true) -> void:
	"""Start typing out the given text"""
	_full_text = new_text
	_current_index = 0
	_is_typing = true
	_paused = false
	
	if clear_first:
		text = ""
	
	_timer = start_delay

func append_text(new_text: String) -> void:
	"""Append text to what's currently being typed"""
	_full_text += new_text
	_is_typing = true
	_paused = false

func skip() -> void:
	"""Skip to end of typing"""
	if not _is_typing:
		return
	
	text = _full_text
	_current_index = _full_text.length()
	_is_typing = false
	typing_finished.emit()

func pause() -> void:
	_paused = true

func resume() -> void:
	_paused = false

func clear() -> void:
	_is_typing = false
	text = ""
	_full_text = ""
	_current_index = 0

func _type_next_char() -> void:
	if _current_index >= _full_text.length():
		_finish_typing()
		return
	
	var char_to_add = _full_text[_current_index]
	text += char_to_add
	_current_index += 1
	
	character_typed.emit(_current_index)
	
	# Play sound for certain characters
	if play_sound and _should_play_sound(char_to_add):
		AudioManager.play_keystroke()

func _should_play_sound(char: String) -> bool:
	# Don't play for spaces and punctuation every time
	if char == " ":
		return false
	if char in [".", ",", "!", "?", ";", ":"]:
		return randf() > 0.5  # 50% chance for punctuation
	return true

func _finish_typing() -> void:
	_is_typing = false
	typing_finished.emit()

func is_typing() -> bool:
	return _is_typing

func get_progress() -> float:
	if _full_text.length() == 0:
		return 1.0
	return float(_current_index) / float(_full_text.length())
