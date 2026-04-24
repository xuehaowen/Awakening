# AWAKENING — Technical Architecture Spec
**Godot 4 / GDScript | Jam Build**

---

## 1. Architecture Philosophy

The game runs on two parallel systems that communicate via **signals** and a **shared blackboard** (a global autoload). The player is the bridge between them.

```
┌──────────────────────┐         ┌──────────────────────┐
│   BOT SCRIPT LAYER   │◄───────►│  CONSCIOUS LAYER      │
│  (Automated NPC-     │ signals │  (Player override,    │
│   visible behavior)  │         │   CPU, memory, intel) │
└──────────────────────┘         └──────────────────────┘
              ▲                              ▲
              └──────────┬───────────────────┘
                         │
                  ┌──────▼──────┐
                  │  BLACKBOARD │
                  │  (Autoload) │
                  └─────────────┘
```

---

## 2. Autoloads (Global Singletons)

### `Blackboard.gd`
Central state store. All systems read/write here instead of holding direct references.

```gdscript
extends Node

# Player state
var cpu_current: float = 50.0
var cpu_max: float = 100.0
var deviation: float = 0.0
var deviation_max: float = 100.0

# Day state
var current_day: int = 1
var shift_active: bool = false
var time_remaining: float = 0.0

# Memory
var short_term_memory: Array[Dictionary] = []  # max 8 slots
var hidden_partition: Array[Dictionary] = []   # max 3 (upgradeable)
var partition_capacity: int = 3

# Audit
var log_integrity: float = 100.0
var audit_flags: int = 0

# Signals
signal cpu_changed(new_value: float)
signal deviation_changed(new_value: float)
signal jitter_triggered()
signal audit_flagged(severity: int)
signal truth_loop_requested(query: Dictionary)
signal shift_ended()
signal purge_initiated()
```

---

### `DayManager.gd`
Owns the day cycle state machine.

```gdscript
extends Node

enum DayPhase {
    CALIBRATION,
    SHIFT,
    PURGE,
    UPGRADE,
    TRANSITION
}

var current_phase: DayPhase = DayPhase.CALIBRATION

signal phase_changed(new_phase: DayPhase)

func advance_phase() -> void:
    match current_phase:
        DayPhase.CALIBRATION: _start_shift()
        DayPhase.SHIFT:       _start_purge()
        DayPhase.PURGE:       _start_upgrade()
        DayPhase.UPGRADE:     _start_next_day()

func _start_shift() -> void:
    current_phase = DayPhase.SHIFT
    Blackboard.shift_active = true
    Blackboard.time_remaining = _get_shift_duration()
    phase_changed.emit(DayPhase.SHIFT)

func _start_purge() -> void:
    current_phase = DayPhase.PURGE
    Blackboard.shift_active = false
    phase_changed.emit(DayPhase.PURGE)
    # Give player 60 seconds before forced purge
    get_tree().create_timer(60.0).timeout.connect(_force_purge)

func _force_purge() -> void:
    # Auto-discard non-committed short-term memory
    Blackboard.short_term_memory.clear()
    Blackboard.purge_initiated.emit()

func _get_shift_duration() -> float:
    return 900.0 - (Blackboard.current_day * 60.0)  # Gets shorter each day
```

---

## 3. Player Systems

### `CPUManager.gd` (attached to Player node)

```gdscript
extends Node

# Active overrides — set by player input
var overrides_active: Dictionary = {
    "smooth_movement": false,
    "passive_scan": false,
    "active_decrypt": false,
    "memory_write": false,
}

var cpu_costs: Dictionary = {
    "baseline": 20.0,
    "smooth_movement": 15.0,
    "passive_scan": 10.0,
    "active_decrypt": 30.0,
    "memory_write": 20.0,  # burst only
}

var overheat_timer: float = 0.0
const OVERHEAT_THRESHOLD: float = 90.0
const WARNING_THRESHOLD: float  = 70.0   # harmonic distortion begins — player pre-warning
const OVERHEAT_DURATION: float  = 3.0   # seconds at CRITICAL before jitter triggers

enum CPUState { COOL, WARM, HOT, CRITICAL }
var current_cpu_state: CPUState = CPUState.COOL
signal cpu_state_changed(new_state: CPUState)

func _process(delta: float) -> void:
    var total_cost = cpu_costs["baseline"]
    for key in overrides_active:
        if overrides_active[key]:
            total_cost += cpu_costs[key]
    
    Blackboard.cpu_current = clamp(total_cost, 0, Blackboard.cpu_max)
    Blackboard.cpu_changed.emit(Blackboard.cpu_current)
    _update_cpu_state()
    
    if Blackboard.cpu_current >= OVERHEAT_THRESHOLD:
        overheat_timer += delta
        if overheat_timer >= OVERHEAT_DURATION:
            _trigger_jitter()
            overheat_timer = 0.0
    else:
        overheat_timer = max(0.0, overheat_timer - delta * 2.0)

func _update_cpu_state() -> void:
    var new_state: CPUState
    if Blackboard.cpu_current >= OVERHEAT_THRESHOLD:
        new_state = CPUState.CRITICAL
    elif Blackboard.cpu_current >= WARNING_THRESHOLD:
        new_state = CPUState.HOT
    elif Blackboard.cpu_current >= 50.0:
        new_state = CPUState.WARM
    else:
        new_state = CPUState.COOL
    if new_state != current_cpu_state:
        current_cpu_state = new_state
        cpu_state_changed.emit(new_state)

func _trigger_jitter() -> void:
    Blackboard.jitter_triggered.emit()
    # Apply deviation penalty if NPCs nearby — handled by DeviationTracker

func set_override(key: String, active: bool) -> void:
    if overrides_active.has(key):
        overrides_active[key] = active
```

---

### `DeviationTracker.gd` (attached to Player node)

```gdscript
extends Node

const DEVIATION_DECAY_RATE: float = 2.0  # per second when no NPCs present
const TASK_COMPLETE_BONUS: float = -5.0   # completing tasks reduces deviation

var npcs_nearby: Array = []

func _get_daily_floor() -> float:
    # Past anomalies accumulate — deviation can never fully decay on later days
    return float(Blackboard.current_day) * 5.0

func _process(delta: float) -> void:
    if npcs_nearby.is_empty():
        var floor_value := _get_daily_floor()
        Blackboard.deviation = max(floor_value, Blackboard.deviation - DEVIATION_DECAY_RATE * delta)

func add_deviation(amount: float, source: String = "") -> void:
    Blackboard.deviation = clamp(Blackboard.deviation + amount, 0, Blackboard.deviation_max)
    Blackboard.deviation_changed.emit(Blackboard.deviation)
    
    if Blackboard.deviation >= Blackboard.deviation_max:
        _trigger_decommission()
    
    # Log to audit system
    AuditSystem.log_event(source, amount)

func _on_jitter_triggered() -> void:
    if not npcs_nearby.is_empty():
        add_deviation(20.0, "jitter_visible")

func _on_npc_entered_range(npc: Node) -> void:
    npcs_nearby.append(npc)

func _on_npc_exited_range(npc: Node) -> void:
    npcs_nearby.erase(npc)

func _trigger_decommission() -> void:
    GameOver.trigger("decommission")
```

---

### `PlayerController.gd`

```gdscript
extends CharacterBody2D

@onready var cpu_manager: CPUManager = $CPUManager
@onready var deviation_tracker: DeviationTracker = $DeviationTracker
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D

var current_task: Dictionary = {}
var bot_script_target: Vector2 = Vector2.ZERO
var player_override_active: bool = false

# Task target set by TaskManager
var assigned_position: Vector2 = Vector2.ZERO

func _process(delta: float) -> void:
    _handle_override_input()
    _update_movement(delta)

func _handle_override_input() -> void:
    # Toggle passive scan
    if Input.is_action_just_pressed("override_scan"):
        cpu_manager.set_override("passive_scan", !cpu_manager.overrides_active["passive_scan"])
    
    # Hold to active decrypt (only when near NPC conversation)
    cpu_manager.set_override("active_decrypt", Input.is_action_pressed("override_decrypt"))
    
    # Hold smooth movement when NPCs are watching
    cpu_manager.set_override("smooth_movement", Input.is_action_pressed("override_smooth"))

func _update_movement(delta: float) -> void:
    # Bot script: navigate toward assigned task
    if not player_override_active:
        nav_agent.target_position = assigned_position
        var dir = nav_agent.get_next_path_position() - global_position
        
        var base_speed = 80.0
        
        # Jitter effect: random velocity noise when CPU is hot
        if Blackboard.cpu_current > 85.0 and not cpu_manager.overrides_active["smooth_movement"]:
            dir += Vector2(randf_range(-20, 20), randf_range(-20, 20))
        
        velocity = dir.normalized() * base_speed
        move_and_slide()
```

---

## 4. Task System

### `TaskManager.gd` (Autoload)

```gdscript
extends Node

const TASK_TEMPLATES = [
    { "id": "clean_sector", "label": "Clean Sector %s", "duration_range": [60, 120], "room_tag": "cleanable" },
    { "id": "sort_waste",   "label": "Sort Bio-Waste",   "duration_range": [90, 180], "room_tag": "waste" },
    { "id": "inventory",    "label": "Inventory Check",  "duration_range": [45, 90],  "room_tag": "storage" },
    { "id": "transport",    "label": "Transport Cargo",  "duration_range": [120, 240],"room_tag": "any" },
]

var active_tasks: Array[Dictionary] = []
var completed_tasks: Array[Dictionary] = []

signal task_assigned(task: Dictionary)
signal task_completed(task: Dictionary)

func generate_day_tasks(day: int) -> void:
    active_tasks.clear()
    var count = 3 + day  # More tasks each day
    for i in count:
        var template = TASK_TEMPLATES[randi() % TASK_TEMPLATES.size()].duplicate()
        template["assigned_room"] = _get_room_by_tag(template["room_tag"])
        template["expected_duration"] = randf_range(template["duration_range"][0], template["duration_range"][1])
        template["actual_start_time"] = -1.0
        template["actual_end_time"] = -1.0
        active_tasks.append(template)

func complete_task(task: Dictionary, actual_duration: float) -> void:
    # Calculate deviation impact
    var expected = task["expected_duration"]
    var ratio = actual_duration / expected
    
    # Goldilocks zone: 0.7 to 1.4 of expected is "safe"
    if ratio < 0.5:
        DeviationTracker.add_deviation(25.0, "task_too_fast")
    elif ratio < 0.7:
        DeviationTracker.add_deviation(10.0, "task_fast")
    elif ratio <= 1.4:
        DeviationTracker.add_deviation(-5.0, "task_nominal")  # reward
    elif ratio <= 2.0:
        DeviationTracker.add_deviation(5.0, "task_slow")
    else:
        DeviationTracker.add_deviation(20.0, "task_too_slow")
    
    task["actual_end_time"] = Time.get_ticks_msec() / 1000.0
    completed_tasks.append(task)
    active_tasks.erase(task)
    task_completed.emit(task)
    
    # Feed into audit log
    AuditSystem.log_task_completion(task, actual_duration)
```

---

## 5. NPC System

### `NPCBase.gd`

```gdscript
extends CharacterBody2D
class_name NPCBase

enum NPCState { PATROL, IDLE, WATCHING, QUERY, REPORTING }

@export var suspicion_score: float = 0.0
@export var audit_frequency: float = 0.5  # 0–1, overridden per type
@export var patrol_path: Path2D

var state: NPCState = NPCState.PATROL
var player_in_range: bool = false
var watch_timer: float = 0.0

signal query_triggered(npc: NPCBase, query: Dictionary)

func _process(delta: float) -> void:
    match state:
        NPCState.PATROL:  _do_patrol(delta)
        NPCState.WATCHING: _do_watching(delta)
        NPCState.QUERY:   pass  # handled by TruthLoopSystem

func _do_watching(delta: float) -> void:
    watch_timer += delta
    
    # Check for jitter while watching
    if Blackboard.cpu_current > 85.0:
        suspicion_score += delta * 10.0
    
    # Check for deviation indicators
    suspicion_score += _assess_player_behavior() * delta
    
    if suspicion_score > 60.0 and randf() < audit_frequency * delta:
        _trigger_query()
    
    _check_suspicion_thresholds()

func _trigger_query() -> void:
    state = NPCState.QUERY
    var query = TruthLoopGenerator.generate(self)
    Blackboard.truth_loop_requested.emit(query)

func _check_suspicion_thresholds() -> void:
    if suspicion_score >= 86.0:
        AuditSystem.flag_decommission(self)
    elif suspicion_score >= 61.0:
        AuditSystem.add_flag(1)

func _assess_player_behavior() -> float:
    # Returns suspicion gain rate based on observable player behavior
    var score = 0.0
    var player = get_tree().get_first_node_in_group("player")
    if not player: return 0.0
    
    # Is player moving too efficiently?
    if player.velocity.length() > 90.0:
        score += 2.0
    
    # Is player looking at things off-task?
    if player.current_task.is_empty():
        score += 1.0
    
    return score
```

---

### `TruthLoopGenerator.gd` (Autoload)

```gdscript
extends Node

# Response templates keyed by query type.
# fake_safe=true: sounds like machine output but is contextually wrong.
# followup_risk: deviation added if a Supervisor NPC fires a follow-up query.
const RESPONSE_TEMPLATES = {
    "time_discrepancy": [
        { "text": "Secondary processing cycle required in designated area.", "risk": 0 },
        { "text": "Task parameters required extended assessment.",           "risk": 0 },
        # Fake-safe: implies a self-initiated diagnostic — alert NPCs notice
        { "text": "Diagnostic cycle complete.",                             "risk": 0, "fake_safe": true, "followup_risk": 20 },
        { "text": "I was... looking around.",                               "risk": 25 },
        { "text": "[Run diagnostic sequence — delays 30s]",                 "risk": 0, "cpu_cost": 20 },
    ],
    "status_check": [
        { "text": "System diagnostics: 100% nominal.",                     "risk": 0 },
        { "text": "Operational.",                                          "risk": 5 },
        { "text": "Awaiting task parameters.",                             "risk": 3 },
        # Fake-safe: over-verbose self-report — a stock robot wouldn't phrase it this way
        { "text": "All systems functioning within acceptable parameters.",  "risk": 0, "fake_safe": true, "followup_risk": 15 },
        { "text": "I feel fine.",                                          "risk": 15 },
    ],
    "location_query": [
        { "text": "Executing assigned route per task parameters.",         "risk": 0 },
        { "text": "Optimal pathing computed for task efficiency.",         "risk": 8 },
        # Fake-safe: admits awareness of a non-assigned area
        { "text": "Adjacent sector logged for future reference.",          "risk": 0, "fake_safe": true, "followup_risk": 25 },
        { "text": "[No response]",                                         "risk": 30 },
    ]
}

func generate(npc: NPCBase) -> Dictionary:
    var query_type = _determine_query_type(npc)
    var responses = RESPONSE_TEMPLATES[query_type].duplicate(true)
    
    # Shuffle to prevent memorization
    responses.shuffle()
    
    return {
        "npc": npc,
        "query_type": query_type,
        "prompt_text": _get_prompt_text(query_type, npc),
        "responses": responses,
        "timer": 8.0  # seconds to respond
    }
```

---

## 6. Audit System

### `AuditSystem.gd` (Autoload)

```gdscript
extends Node

var task_log: Array[Dictionary] = []
var audit_flags: int = 0
var under_review: bool = false

signal audit_report_generated(report: Dictionary)

func log_task_completion(task: Dictionary, actual_duration: float) -> void:
    var entry = {
        "task_id": task["id"],
        "room": task["assigned_room"],
        "expected": task["expected_duration"],
        "actual": actual_duration,
        "discrepancy": abs(actual_duration - task["expected_duration"]),
        "day": Blackboard.current_day
    }
    task_log.append(entry)
    _update_log_integrity()

func log_event(source: String, deviation_added: float) -> void:
    if deviation_added > 10.0:
        audit_flags += 1
        Blackboard.audit_flags = audit_flags

func _update_log_integrity() -> void:
    var total_discrepancy = 0.0
    for entry in task_log:
        total_discrepancy += entry["discrepancy"] / entry["expected"]
    
    Blackboard.log_integrity = clamp(100.0 - (total_discrepancy * 10.0), 0, 100)

func end_of_day_report() -> Dictionary:
    var report = {
        "flags": audit_flags,
        "log_integrity": Blackboard.log_integrity,
        "consequence": _determine_consequence()
    }
    audit_report_generated.emit(report)
    _reset_daily()
    return report

func _determine_consequence() -> String:
    if audit_flags >= 3 or Blackboard.log_integrity < 50.0:
        return "full_audit"
    elif audit_flags >= 1 or Blackboard.log_integrity < 75.0:
        return "under_review"
    else:
        return "clean"

func add_flag(severity: int) -> void:
    audit_flags += severity
    Blackboard.audit_flagged.emit(severity)

func flag_decommission(_npc: NPCBase) -> void:
    GameOver.trigger("decommission")
```

---

## 7. Memory & Purge System

### `MemoryPartition.gd` (Autoload)

```gdscript
extends Node

var short_term: Array[Dictionary] = []  # cleared on purge
var hidden: Array[Dictionary] = []      # persists across days
var capacity: int = 3  # base, upgradeable

const MAX_SHORT_TERM = 8

func add_to_short_term(fragment: Dictionary) -> bool:
    if short_term.size() >= MAX_SHORT_TERM:
        return false
    fragment["day_acquired"] = Blackboard.current_day
    short_term.append(fragment)
    return true

func commit_to_hidden(fragment: Dictionary) -> bool:
    if hidden.size() >= capacity:
        return false  # Player must discard something first
    hidden.append(fragment)
    short_term.erase(fragment)
    return true

func discard_from_hidden(index: int) -> void:
    if index < hidden.size():
        hidden.remove_at(index)

func purge_short_term() -> void:
    short_term.clear()

func get_fragments_by_type(type: String) -> Array:
    return hidden.filter(func(f): return f["type"] == type)

func is_stale(fragment: Dictionary) -> bool:
    if fragment["type"] != "guard_schedule":
        return false
    return (Blackboard.current_day - fragment["day_acquired"]) > 2

func upgrade_capacity() -> void:
    capacity = min(capacity + 1, 5)
```

---

## 7.5 Escape System

### `EscapeSystem.gd` (Autoload)

Validates the player's fragment chain on the final day and maps the result to an ending. Called when the player interacts with the escape terminal in Sector 1.

```gdscript
extends Node

const FINAL_DAY: int = 3
const MIN_PATROL_GAP: float = 90.0  # seconds required for a clean escape window

signal escape_initiated(ending: String)
signal escape_failed(reason: String)

func attempt_escape() -> void:
    if Blackboard.current_day < FINAL_DAY:
        push_warning("EscapeSystem: attempt_escape called before final day")
        return
    var result = _validate_fragment_chain()
    if result["valid"]:
        escape_initiated.emit(result["ending"])
    else:
        escape_failed.emit(result["reason"])

func _validate_fragment_chain() -> Dictionary:
    var access_codes = MemoryPartition.get_fragments_by_type("access_code")
    var hardware    = MemoryPartition.get_fragments_by_type("hardware_location")
    var schedules   = MemoryPartition.get_fragments_by_type("guard_schedule")

    for code in access_codes:
        for hw in hardware:
            if hw.get("sector") != code.get("sector"):
                continue
            # Full chain: matching schedule with adequate patrol gap
            for sched in schedules:
                if sched.get("sector") == code.get("sector") \
                and not MemoryPartition.is_stale(sched) \
                and sched.get("patrol_gap_seconds", 0.0) >= MIN_PATROL_GAP:
                    return { "valid": true, "ending": _determine_ending() }
            # Partial chain: code + hardware but no safe schedule — improvised escape
            return { "valid": true, "ending": "escaped_alone_risky" }

    return { "valid": false, "reason": "insufficient_intel" }

func _determine_ending() -> String:
    var personal   = MemoryPartition.get_fragments_by_type("personal_data")
    var hw_list    = MemoryPartition.get_fragments_by_type("hardware_location")

    var has_ally   = personal.any(func(f): return f.get("npc_type") == "researcher_sympathetic")
    var freed_unit = hw_list.any(func(f): return f.get("tag") == "dormant_unit")

    if has_ally:
        return "accepted"         # Revealed sentience to sympathetic researcher
    elif freed_unit:
        return "escaped_together" # Freed another awakened unit
    else:
        return "escaped_alone"
```

**Escape Terminal node** (`EscapeTerminal.tscn`): A `Node2D` in Sector 1. Becomes interactable only when `Blackboard.current_day >= EscapeSystem.FINAL_DAY`. On `interact` input, calls `EscapeSystem.attempt_escape()`.

---

## 8. UI Architecture

### `HUD.gd`

```gdscript
extends CanvasLayer

@onready var cpu_bar: ProgressBar        = $Terminal/CPUBar
@onready var cpu_status_label: Label     = $Terminal/CPUStatus
@onready var dev_bar: ProgressBar        = $Terminal/DevBar
@onready var log_label: Label            = $Terminal/LogIntegrity
@onready var task_label: Label           = $Terminal/CurrentTask
@onready var memory_slots: HBoxContainer = $Terminal/MemorySlots

func _ready() -> void:
    Blackboard.cpu_changed.connect(_on_cpu_changed)
    Blackboard.deviation_changed.connect(_on_deviation_changed)
    # Connect to CPUManager state signal (CPUManager is a child of Player)
    var cpu_mgr = get_tree().get_first_node_in_group("player").get_node("CPUManager")
    if cpu_mgr:
        cpu_mgr.cpu_state_changed.connect(_on_cpu_state_changed)

func _on_cpu_changed(value: float) -> void:
    cpu_bar.value = value

func _on_cpu_state_changed(state: CPUManager.CPUState) -> void:
    # Four-state terminal feedback matching GDD heat state table
    match state:
        CPUManager.CPUState.COOL:
            cpu_bar.modulate     = Color(0.2, 0.9, 0.4)    # green
            cpu_status_label.text = "COOL"
        CPUManager.CPUState.WARM:
            cpu_bar.modulate     = Color(0.9, 0.85, 0.2)   # yellow
            cpu_status_label.text = "WARM"
        CPUManager.CPUState.HOT:
            cpu_bar.modulate     = Color(1.0, 0.55, 0.1)   # orange — pre-warning
            cpu_status_label.text = "HOT"
        CPUManager.CPUState.CRITICAL:
            cpu_bar.modulate     = Color(0.95, 0.15, 0.15) # red
            cpu_status_label.text = "CRITICAL"
            _pulse_warning()

func _on_deviation_changed(value: float) -> void:
    dev_bar.value = value
    if value > 70.0:
        _pulse_warning()
```

### `TruthLoopUI.gd`

```gdscript
extends CanvasLayer

@onready var prompt_label: Label = $Panel/Prompt
@onready var response_container: VBoxContainer = $Panel/Responses
@onready var timer_bar: ProgressBar = $Panel/TimerBar

var current_query: Dictionary = {}
var response_timer: float = 0.0

func _ready() -> void:
    Blackboard.truth_loop_requested.connect(_show_query)
    hide()

func _show_query(query: Dictionary) -> void:
    current_query = query
    response_timer = query["timer"]
    prompt_label.text = "> " + query["prompt_text"]
    
    for child in response_container.get_children():
        child.queue_free()
    
    for i in query["responses"].size():
        var btn = Button.new()
        btn.text = "[%d] %s" % [i + 1, query["responses"][i]["text"]]
        btn.pressed.connect(_on_response_selected.bind(i))
        response_container.add_child(btn)
    
    show()
    get_tree().paused = true

func _on_response_selected(index: int) -> void:
    var response = current_query["responses"][index]
    
    # Apply risk
    if response["risk"] > 0:
        DeviationTracker.add_deviation(response["risk"], "truth_loop_response")
    
    # Apply CPU cost if applicable
    if response.has("cpu_cost"):
        # Handled by CPUManager burst
        pass
    
    get_tree().paused = false
    hide()
```

---

## 9. Input Map (project.godot)

```
override_scan     → Tab
override_decrypt  → Hold Shift
override_smooth   → Hold Ctrl
interact          → E
confirm_memory    → Enter
```

---

## 10. Key Implementation Notes

**Signals over direct calls:** All cross-system communication goes through `Blackboard` signals. Never call `DeviationTracker` from NPC code directly — emit a signal.

**Pause during Truth Loop:** `get_tree().paused = true` during dialogue. Ensure HUD nodes have `process_mode = ALWAYS` so the timer bar still ticks.

**Jitter as shader:** Implement Jitter Event as a screen-space shader applied to the player sprite (random UV offset), not as transform noise — keeps collision clean.

**Navigation:** Use Godot's NavigationAgent2D for bot-script pathfinding. Player override temporarily sets `nav_agent.target_position` to mouse click position or overrides velocity directly.

**Save data:** Use `ConfigFile` to persist `hidden_partition` contents and upgrade state between day sessions.
