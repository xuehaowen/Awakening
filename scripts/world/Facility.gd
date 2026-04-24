extends Node2D

@onready var player_spawn: Marker2D = $PlayerSpawn
@onready var npc_container: Node2D = $NPCs
@onready var task_areas: Node2D = $TaskAreas
@onready var escape_terminal: Node2D = $EscapeTerminal
@onready var navigation_region: NavigationRegion2D = $NavigationRegion2D

const NPC_GUARD = preload("res://scenes/entities/NPC_Guard.tscn")
const NPC_SUPERVISOR = preload("res://scenes/entities/NPC_Supervisor.tscn")
const PLAYER = preload("res://scenes/entities/Player.tscn")
const HUD = preload("res://scenes/ui/HUD.tscn")
const TRUTH_LOOP_UI = preload("res://scenes/ui/TruthLoopUI.tscn")
const NIGHTLY_PURGE_UI = preload("res://scenes/ui/NightlyPurgeUI.tscn")
const GAME_OVER_UI = preload("res://scenes/ui/GameOverUI.tscn")

var player: Node = null
var day_one_ended: bool = false

func _ready():
	# Spawn UI instances
	var hud = HUD.instantiate()
	add_child(hud)
	
	var truth_loop = TRUTH_LOOP_UI.instantiate()
	add_child(truth_loop)
	
	var purge_ui = NIGHTLY_PURGE_UI.instantiate()
	add_child(purge_ui)
	
	var game_over = GAME_OVER_UI.instantiate()
	add_child(game_over)
	
	# Spawn player
	_spawn_player()
	
	# Connect to game events
	Blackboard.day_started.connect(_on_day_started)
	Blackboard.game_over.connect(_on_game_over)
	Blackboard.escape_triggered.connect(_on_escape_triggered)
	DayManager.phase_changed.connect(_on_phase_changed)
	
	# Start Day 1
	DayManager.advance_phase()

func _spawn_player() -> void:
	player = PLAYER.instantiate()
	player.global_position = player_spawn.global_position
	add_child(player)

func _on_day_started(day: int) -> void:
	# Clear existing NPCs
	for npc in npc_container.get_children():
		npc.queue_free()
	
	# Spawn NPCs based on day
	match day:
		1:
			_spawn_guard(Vector2(400, 300), [Vector2(400, 300), Vector2(600, 300), Vector2(600, 500), Vector2(400, 500)])
			_spawn_guard(Vector2(800, 200), [Vector2(800, 200), Vector2(1000, 200), Vector2(1000, 400)])
		2:
			_spawn_guard(Vector2(400, 300), [Vector2(400, 300), Vector2(600, 300), Vector2(600, 500)])
			_spawn_guard(Vector2(800, 200), [Vector2(800, 200), Vector2(1000, 200)])
			_spawn_supervisor(Vector2(600, 400))
		3:
			_spawn_guard(Vector2(300, 300), [Vector2(300, 300), Vector2(500, 300)])
			_spawn_guard(Vector2(900, 200), [Vector2(900, 200), Vector2(1100, 200)])
			_spawn_supervisor(Vector2(player.global_position))  # Shadows player
			_escape_terminal_active()
	
	# Reveal escape sector end of Day 1
	if day == 2 and not day_one_ended:
		day_one_ended = true
		_reveal_escape_sector()

func _spawn_guard(pos: Vector2, patrol: Array[Vector2] = []) -> void:
	var guard = NPC_GUARD.instantiate()
	guard.global_position = pos
	if not patrol.is_empty():
		guard.patrol_points = patrol
	# Connect NPC signals to AuditSystem (architecture fix - no direct calls)
	guard.decommission_threshold_reached.connect(_on_npc_decommission)
	guard.report_threshold_reached.connect(_on_npc_report)
	npc_container.add_child(guard)

func _spawn_supervisor(pos: Vector2) -> void:
	var supervisor = NPC_SUPERVISOR.instantiate()
	supervisor.global_position = pos
	# Connect NPC signals to AuditSystem (architecture fix - no direct calls)
	supervisor.decommission_threshold_reached.connect(_on_npc_decommission)
	supervisor.report_threshold_reached.connect(_on_npc_report)
	npc_container.add_child(supervisor)

func _on_npc_decommission(npc: Node) -> void:
	AuditSystem.flag_decommission(npc)

func _on_npc_report(npc: Node, reason: String) -> void:
	AuditSystem.add_flag(1, reason)

func _reveal_escape_sector() -> void:
	# Randomly select escape sector (1-4)
	var sector = (randi() % 4) + 1
	Blackboard.escape_sector = sector
	print("ESCAPE SECTOR REVEALED: Sector ", sector)
	
	# Add a hint fragment
	var hint_fragment = {
		"type": "access_code",
		"sector": sector,
		"code": "???",
		"description": "Maintenance logs indicate Sector " + str(sector) + " has exit access."
	}
	MemoryPartition.add_to_short_term(hint_fragment)

func _escape_terminal_active() -> void:
	if escape_terminal and escape_terminal.has_method("activate"):
		escape_terminal.activate()

func _on_game_over(reason: String) -> void:
	print("GAME OVER: ", reason)
	_show_game_over_screen(reason)

func _on_escape_triggered(ending: String) -> void:
	print("ESCAPE: ", ending)
	_show_game_over_screen(ending)

func _show_game_over_screen(ending: String) -> void:
	GameOver.trigger(ending)

func _on_phase_changed(new_phase: int) -> void:
	if new_phase == DayManager.DayPhase.SHIFT:
		# Respawn player at start
		if player:
			player.global_position = player_spawn.global_position
