# Engine Implementation Notes — UI Rebuild

**Engine**: Godot 4.6 (Compatibility renderer — WebGL 2.0 target)
**Author**: godot-gdscript-specialist
**Date**: 2026-04-25
**Spec Sources**: `design/ux/hud.md`, `design/ux/truth-loop.md`, `design/ux/nightly-purge.md`
**Existing Code Reviewed**: `scripts/ui/HUD.gd`, `scripts/ui/TruthLoopUI.gd`, `scripts/ui/NightlyPurgeUI.gd`

---

## Global Notes (All Screens)

### Godot 4.6 — Critical Awareness Items

1. **Dual-focus system (4.6 breaking change)**: Mouse/touch focus is now separate from keyboard/gamepad focus. When designing `FocusMode` and custom focus indicators, test both input paths explicitly. A keyboard-focused button may render differently than a mouse-hovered button.

2. **Compatibility renderer constraint**: The project targets WebGL 2.0 via the Compatibility renderer. Avoid:
   - `SubViewport`-based post-processing chains (limited in Compatibility)
   - `ShaderMaterial` on `CanvasItem` with advanced blend modes
   - Screen-space effects via `CompositorEffect` (not available in Compatibility)
   - Stick to `Tween`, `AnimationPlayer`, and `modulate`/`pivot_offset` for all UI animation

3. **Static typing is mandatory**: Every variable, parameter, and return type in all UI scripts must be explicitly typed. The existing scripts (`HUD.gd`, `TruthLoopUI.gd`, `NightlyPurgeUI.gd`) have several untyped variables — these must be fixed in the rebuild.

4. **`@onready` over `$` in `_process()`**: The existing `HUD.gd` caches the player reference correctly (`_player_ref`) but then calls `_player_ref.get_node("CPUManager")` inside `_process()`. This is a per-frame path traversal — cache it with `@onready` or in `_ready()`.

5. **Signal connections**: All three existing scripts use the correct Godot 4.x callable syntax (`signal.connect(callable)`). Keep this pattern. Never use string-based `connect("signal_name", obj, "method_name")`.

6. **`duplicate_deep()` (4.5+)**: If any UI script duplicates Resource objects (e.g., theme overrides per button state), use `duplicate_deep()` instead of `duplicate()` for nested resources.

---

## Screen 1: HUD (`HUD.tscn` + `HUD.gd`)

### Layer Ordering
```
CanvasLayer (layer = 10)
```
Layer 10 places the HUD above the game world (typically layer 0–1 for world, 5 for effects). It sits below the Truth Loop (20) and Nightly Purge (30). This is correct per spec.

**Important**: Set the `CanvasLayer.follow_viewport_enabled = false` (the default). The HUD must not scroll or scale with the game camera.

### Recommended Node Hierarchy

```
HUD (CanvasLayer, layer=10)
└── HUDRoot (Control, anchors: full rect)
    ├── ZoneA_Header (HBoxContainer)
    │   ├── UnitIDLabel (Label)          ← "UNIT-07"
    │   ├── DayLabel (Label)             ← "SHIFT 3"
    │   └── TimerLabel (Label)           ← "12:34 REMAINING"
    ├── ZoneB_SystemStatus (VBoxContainer, anchor: top-right)
    │   ├── CPURow (HBoxContainer)
    │   │   ├── CPULabel (Label)         ← "CPU"
    │   │   ├── CPUBar (ProgressBar)
    │   │   └── CPUStateLabel (Label)    ← "HOT"
    │   ├── DEVRow (HBoxContainer)
    │   │   ├── DEVLabel (Label)         ← "DEV"
    │   │   ├── DEVBar (ProgressBar)
    │   │   └── DEVStateLabel (Label)    ← "ELEVATED"
    │   └── LOGRow (HBoxContainer)
    │       ├── LOGLabel (Label)         ← "LOG"
    │       ├── LOGBar (ProgressBar)
    │       └── LOGStateLabel (Label)    ← "NOMINAL"
    ├── ZoneC_TaskInfo (VBoxContainer, anchor: bottom-left)
    │   ├── TaskNameLabel (Label)        ← "TASK: Clean Sector 4"
    │   └── TaskProgressBar (ProgressBar)
    ├── ZoneD_MemorySlots (HBoxContainer, anchor: bottom-right)
    │   ├── MemorySlot1 (TextureRect)
    │   ├── MemorySlot2 (TextureRect)
    │   ├── MemorySlot3 (TextureRect)
    │   ├── MemorySlot4 (TextureRect)
    │   └── MemorySlot5 (TextureRect)    ← hidden partition (max 5 slots)
    └── FeedbackLabel (Label)            ← center-screen floating feedback
```

**Deviation from existing**: The current `HUD.gd` uses a flat `TerminalPanel/` path structure. The rebuild should use distinct named zones (`ZoneA_Header`, etc.) with proper anchoring so the layout is responsive to different aspect ratios (16:9, 21:9, 4:3 per spec).

### Node-Specific Recommendations

**`CanvasLayer` (root)**
- `layer = 10`
- `follow_viewport_enabled = false`
- Script extends `CanvasLayer`, `class_name HUDController`

**`HUDRoot` (Control)**
- `anchor_left = 0, anchor_top = 0, anchor_right = 1, anchor_bottom = 1`
- `offset_*` = 0 (full-screen coverage)
- `mouse_filter = MOUSE_FILTER_IGNORE` — HUD is read-only; let clicks pass through

**`ZoneA_Header` (HBoxContainer)**
- Anchor: top-left corner with 5% margin (spec: "5% from screen edges")
- `separation = 16`

**`CPUBar`, `DEVBar`, `LOGBar` (ProgressBar)**
- `min_value = 0.0, max_value = 100.0`
- `show_percentage = false` — use custom `CPUStateLabel` for text
- Style via `ui_theme.tres`, not inline — spec requirement
- Set `fill_mode = FILL_LEFT_TO_RIGHT` (default)
- **Do NOT** use `value = x` directly in `_process()` — use the tween helper (see Performance section)

**`TaskProgressBar` (ProgressBar)**
- `max_value = 200.0` (spec: task progress can exceed 100% when going too fast)
- Set threshold colors in script, not as static theme override

**`ZoneD_MemorySlots` — `TextureRect` nodes**
- `expand_mode = EXPAND_FIT_WIDTH_PROPORTIONAL`
- `custom_minimum_size = Vector2(48, 48)` (keep slots readable; spec requires "Hidden partition icons")
- Use placeholder `Texture2D` resource for empty slots
- Each slot needs a distinct `TextureRect` per slot index (not dynamic children)

**`FeedbackLabel` (Label)**
- Center-anchored, `mouse_filter = MOUSE_FILTER_IGNORE`
- `z_index = 10` within the CanvasLayer to float above other elements
- Start hidden (`visible = false`)

### Signal Connection Pattern

```gdscript
class_name HUDController
extends CanvasLayer

# Typed @onready — all node refs must be typed
@onready var cpu_bar: ProgressBar = %CPUBar
@onready var cpu_state_label: Label = %CPUStateLabel
@onready var dev_bar: ProgressBar = %DEVBar
@onready var dev_state_label: Label = %DEVStateLabel
@onready var log_bar: ProgressBar = %LOGBar
@onready var log_state_label: Label = %LOGStateLabel
@onready var task_name_label: Label = %TaskNameLabel
@onready var task_progress_bar: ProgressBar = %TaskProgressBar
@onready var timer_label: Label = %TimerLabel
@onready var day_label: Label = %DayLabel
@onready var feedback_label: Label = %FeedbackLabel

# Use unique names (%NodeName) for all HUD elements — avoids fragile path strings

func _ready() -> void:
    # Connect to Autoload signals — typed connections
    Blackboard.cpu_changed.connect(_on_cpu_changed)
    Blackboard.deviation_changed.connect(_on_deviation_changed)
    Blackboard.day_started.connect(_on_day_started)
    Blackboard.phase_changed.connect(_on_phase_changed)
    Blackboard.interaction_feedback.connect(_on_interaction_feedback)
    TaskManager.task_assigned.connect(_on_task_assigned)
    TaskManager.task_completed.connect(_on_task_completed)
    MemoryPartition.fragment_acquired.connect(_on_memory_changed)
    MemoryPartition.fragment_committed.connect(_on_memory_changed)
    EscapeSystem.escape_failed.connect(_on_escape_failed)
    
    # Cache CPUManager reference ONCE — not per frame
    # Must wait one frame for player to be ready in scene tree
    await get_tree().process_frame
    _cache_cpu_manager()
    
    feedback_label.hide()
```

**Key fix over existing code**: The existing `HUD.gd` calls `get_node("CPUManager")` inside `_process()` every frame even though `_player_ref` is cached. In the rebuild, cache `_cpu_manager: CPUManager` in `_ready()` and access it directly. If the player isn't ready on frame 0, the `await get_tree().process_frame` before caching handles this.

### Performance Considerations

**`_process()` scope** — The HUD has several per-frame updates. Minimize what runs every frame:

| Update Type | Frequency | Method |
|---|---|---|
| Shift timer countdown | Every frame | `_process(delta)` — unavoidable |
| Task progress bar | Every frame | `_process(delta)` — unavoidable |
| CPU override indicators (scan/smooth) | Every frame | `_process(delta)` — unavoidable |
| CPU bar value | On signal `cpu_changed` | `_on_cpu_changed()` — NOT `_process()` |
| DEV bar value | On signal `deviation_changed` | `_on_deviation_changed()` |
| LOG integrity | On signal (audit events) | Signal-driven only |
| Memory slot display | On signal `fragment_*` | Signal-driven only |
| Feedback label fade | When `_feedback_timer > 0` | Guard with early return |

**Tween management**: The existing `_tween_bar_value()` creates a new `Tween` every call. This is fine for infrequent updates (signal-driven) but will leak tweens if `cpu_changed` fires every frame. Cache the tween per bar:

```gdscript
var _cpu_tween: Tween
var _dev_tween: Tween

func _tween_bar_value(bar: ProgressBar, target: float, duration: float) -> void:
    # Kill existing tween before creating new one — prevents stacking
    if _cpu_tween and _cpu_tween.is_valid():
        _cpu_tween.kill()
    _cpu_tween = create_tween()
    _cpu_tween.tween_property(bar, "value", target, duration)\
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
```

**Pulse animation**: The existing `_pulse_warning()` creates a tween pair on every call. For CRITICAL CPU (90–100%), this fires continuously. Add a `_is_pulsing: bool` guard to prevent tween accumulation:

```gdscript
var _is_pulsing: bool = false

func _pulse_warning(node: Control, base_color: Color) -> void:
    if _is_pulsing:
        return
    _is_pulsing = true
    var tween: Tween = create_tween()
    tween.tween_property(node, "modulate", base_color.lightened(0.3), 0.15)
    tween.tween_property(node, "modulate", base_color, 0.15)
    tween.tween_callback(func() -> void: _is_pulsing = false)
```

### HUD Fade Animations (Spec Compliance)

The spec requires element-staggered fade-in (Header → Status → Task → Memory, 0.1s each). Implementation approach:

```gdscript
func fade_in() -> void:
    # Stagger: 0.0s, 0.1s, 0.2s, 0.3s delay per zone
    var zones: Array[Control] = [zone_a_header, zone_b_status, zone_c_task, zone_d_memory]
    for i: int in zones.size():
        zones[i].modulate.a = 0.0
        var tween: Tween = create_tween()
        tween.tween_interval(i * 0.1)
        tween.tween_property(zones[i], "modulate:a", 1.0, 0.5)\
            .set_ease(Tween.EASE_OUT)
```

**Dim on pause** (spec: 30% opacity in 0.2s):
```gdscript
func set_dimmed(dimmed: bool) -> void:
    var tween: Tween = create_tween()
    tween.tween_property(self, "modulate:a", 0.3 if dimmed else 1.0, 0.2)
```

### Gotchas

1. **`process_mode` during pause**: Truth Loop sets `get_tree().paused = true`. If the HUD is a child of the scene tree (not CanvasLayer autoload), it will pause too. Set `HUD.process_mode = Node.PROCESS_MODE_ALWAYS` OR ensure the HUD is not under a pauseable parent. The existing code sets this on `TruthLoopUI` — the HUD needs the same treatment since it should "dim but remain partially visible" during pause.

2. **ProgressBar theme**: The default Godot ProgressBar in Compatibility renderer can look inconsistent. Use a `StyleBoxFlat` on the fill stylebox via `ui_theme.tres`. Avoid per-instance `theme_override_*` — it prevents the theme from being the single source of truth.

3. **Memory slot `TextureRect` empty state**: If `texture = null`, a `TextureRect` renders nothing and has zero size, collapsing the HBoxContainer. Always assign a placeholder "empty slot" texture, or use a `Panel` with a `StyleBoxFlat` instead of `TextureRect` for the slot background.

4. **Timer drift**: The spec acceptance criterion requires "no drift over 15 minutes". Using `_process(delta)` accumulates float rounding errors. Store `time_remaining: float` in Blackboard as the authoritative value and read it directly rather than decrementing a local float in the HUD. The HUD only displays — it doesn't own the timer.

---

## Screen 2: Truth Loop UI (`TruthLoopUI.tscn` + `TruthLoopUI.gd`)

### Layer Ordering
```
CanvasLayer (layer = 20)
```
Layer 20 sits above the HUD (10). The darkening overlay (spec: "immediate darkening layer") should be a `ColorRect` child of this CanvasLayer rather than a separate CanvasLayer — saves a draw call batch boundary.

### Recommended Node Hierarchy

```
TruthLoopUI (CanvasLayer, layer=20)
└── DarkenOverlay (ColorRect)            ← full-screen black, alpha=0.75
    └── DialogPanel (PanelContainer)     ← centered, 80% width (spec)
        ├── ZoneA_Header (HBoxContainer)
        │   ├── QueryTypeLabel (Label)   ← "STATUS QUERY"
        │   ├── Separator (VSeparator)
        │   └── NPCIDLabel (Label)       ← "SUPERVISOR-22"
        ├── HeaderDivider (HSeparator)
        ├── ZoneB_Dialogue (HBoxContainer)
        │   ├── NPCPortrait (TextureRect) ← fallback: default icon texture
        │   └── QueryText (RichTextLabel) ← BBCode enabled for emphasis
        ├── ZoneC_Responses (VBoxContainer)
        │   ├── ResponseButton1 (Button)
        │   ├── ResponseButton2 (Button)
        │   └── ResponseButton3 (Button)
        └── ZoneD_TimerRow (HBoxContainer)
            ├── TimerBar (ProgressBar)
            └── TimerValueLabel (Label)  ← "8.2s / 15s"
```

**Deviation from existing**: The existing `TruthLoopUI.gd` dynamically creates `Button` nodes in `_show_query()` every time a query fires. This causes per-query allocation and a `queue_free()` on all children. The rebuild should use **pre-allocated** `ResponseButton1/2/3` nodes that are shown/hidden and have their text/properties set, not created dynamically. This eliminates GC pressure and frame hitches during query presentation.

### Node-Specific Recommendations

**`DarkenOverlay` (ColorRect)**
- `anchor_*` = full rect (0,0,1,1), `offset_*` = 0
- `color = Color(0, 0, 0, 0.75)`
- `mouse_filter = MOUSE_FILTER_STOP` — blocks clicks from reaching game world behind overlay
- This IS the darkening layer mentioned in the HUD spec ("Truth Loop triggered — immediate darkening layer")

**`DialogPanel` (PanelContainer)**
- Do NOT anchor to full rect; center it:
  - `anchor_left = 0.1, anchor_right = 0.9` (80% width per spec)
  - `anchor_top = 0.15, anchor_bottom = 0.85`
- Use `PanelContainer` (not bare `Panel`) so the `StyleBox` padding applies correctly

**`QueryText` (RichTextLabel)**
- `bbcode_enabled = true` — spec notes BBCode for emphasis
- `fit_content = true` — auto-size height to text
- `scroll_active = false` — text should always be fully visible, not scrollable
- `autowrap_mode = TextServer.AUTOWRAP_WORD_SMART`

**`ResponseButton1/2/3` (Button)**
- `alignment = HORIZONTAL_ALIGNMENT_LEFT` (spec: response text is left-aligned)
- `focus_mode = FOCUS_ALL` — required for keyboard navigation (↑/↓ arrows)
- `theme_type_variation = &"TerminalButton"` — use StringName for theme lookups
- `custom_minimum_size = Vector2(0, 64)` — large enough touch target (also satisfies motor accessibility)
- Use `disabled = true` / `visible = false` to hide unused slots and skip in focus order

**Timer approach (important)**: The spec says "Timer: Godot `Timer` node with `process_callback = Physics`". However, for a UI-only timer displayed in `_process()`, a `Timer` node with physics callback introduces subtle desync between visual display and actual expiry. Recommendation: **keep the timer as a `float` decremented in `_process(delta)`** (matching existing code), BUT set `process_mode = Node.PROCESS_MODE_ALWAYS` on the CanvasLayer so it ticks while `get_tree().paused = true`. This avoids the Timer node callback timing issue entirely. The spec's "no drift over 15 seconds" criterion is met with a `float` accumulator over 15s (error < 0.001s at 60fps).

**Time scale manipulation**: The spec specifies `TimeScale = 0.1` during Truth Loop (slow-motion) and `0 when awaiting response`. Implementation:
```gdscript
func _show_query(query: Dictionary) -> void:
    Engine.time_scale = 0.1   # Slow world — NOT get_tree().paused
    process_mode = Node.PROCESS_MODE_ALWAYS  # UI ticks at real-time
    # ...
    # When player is ready to answer, pause fully:
    Engine.time_scale = 0.0   # Full pause while awaiting selection
```

**Warning**: `Engine.time_scale = 0` affects `AudioStreamPlayer` and `AnimationPlayer`. Any UI sounds during pause must use `AudioServer` directly or set `process_mode = PROCESS_MODE_ALWAYS` on the AudioManager. Verify the AudioManager handles this case.

**`get_tree().paused = true`** (existing code) fully pauses the scene tree including UI Tweens. The rebuild should use `Engine.time_scale` instead of tree pause for cleaner behavior, keeping `process_mode = PROCESS_MODE_ALWAYS` on the TruthLoopUI CanvasLayer.

### Signal Architecture

```gdscript
class_name TruthLoopUIController
extends CanvasLayer

# Pre-allocated button refs — typed
@onready var response_button_1: Button = %ResponseButton1
@onready var response_button_2: Button = %ResponseButton2
@onready var response_button_3: Button = %ResponseButton3
@onready var _response_buttons: Array[Button]  # populated in _ready()

# Typed signals per spec
signal truth_loop_started(query_type: String, npc_id: String, query_text: String)
signal response_selected(response_index: int, response_text: String, cpu_cost: float, dev_cost: float)
signal truth_loop_timeout(auto_selected_response: Dictionary)
signal truth_loop_ended(outcome: String)

func _ready() -> void:
    _response_buttons = [response_button_1, response_button_2, response_button_3]
    
    # Button connections — pre-wired, not dynamic
    response_button_1.pressed.connect(_on_response_pressed.bind(0))
    response_button_2.pressed.connect(_on_response_pressed.bind(1))
    response_button_3.pressed.connect(_on_response_pressed.bind(2))
    
    # System signals
    Blackboard.truth_loop_requested.connect(_show_query)
    TruthLoopGenerator.followup_triggered.connect(_on_followup_triggered)
    
    # Live updates during query (CPU can change)
    Blackboard.cpu_changed.connect(_on_cpu_changed_during_query)
    
    # Start hidden
    darken_overlay.hide()
    process_mode = Node.PROCESS_MODE_ALWAYS
```

**Key improvement**: Pre-wiring button connections in `_ready()` vs. re-connecting them each query (current pattern with `btn.pressed.connect()` inside a loop) eliminates connection leaks and the `queue_free()` / rebuild cycle.

### CPU Requirement Checking (Spec: "CPU-Restricted State")

```gdscript
func _refresh_response_availability(current_cpu: float) -> void:
    var responses: Array = _current_query.get("responses", [])
    for i: int in _response_buttons.size():
        if i >= responses.size():
            _response_buttons[i].hide()
            continue
        var resp: Dictionary = responses[i]
        var req_cpu: float = resp.get("requires_cpu_below", 100.0)
        var is_available: bool = current_cpu < req_cpu
        _response_buttons[i].disabled = not is_available
        # Visual: grayed, 50% opacity, strikethrough — spec requirement
        _response_buttons[i].modulate.a = 1.0 if is_available else 0.5
```

Connect `Blackboard.cpu_changed` to `_refresh_response_availability` so the locked state updates live if CPU changes mid-query (rare but spec item #9 acceptance criterion).

### Keyboard Navigation

The spec requires number keys 1/2/3 for direct selection AND ↑/↓ + Enter navigation. Godot's built-in focus traversal handles ↑/↓ automatically when `focus_mode = FOCUS_ALL` and the buttons are in a `VBoxContainer`. For number keys:

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if not _darken_overlay.visible:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_1: _on_response_pressed(0)
            KEY_2: _on_response_pressed(1)
            KEY_3: _on_response_pressed(2)
```

Use `_unhandled_input` (not `_input`) so game world input handlers don't conflict.

**ESC ignored / shake feedback** (spec): 

```gdscript
# In _unhandled_input:
KEY_ESCAPE:
    _shake_panel()
    get_viewport().set_input_as_handled()  # Consume ESC — prevent pause menu
```

### Entry Animation (Spec: "Terminal Boot Effect" 0.3s, scale 0.8→1.0, ease-out-back)

```gdscript
func _play_entry_animation() -> void:
    dialog_panel.scale = Vector2(0.8, 0.8)
    dialog_panel.modulate.a = 0.0
    var tween: Tween = create_tween().set_parallel(true)
    tween.tween_property(dialog_panel, "scale", Vector2.ONE, 0.3)\
        .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
    tween.tween_property(dialog_panel, "modulate:a", 1.0, 0.3)\
        .set_ease(Tween.EASE_OUT)
```

Note: `Tween.TRANS_BACK` provides the overshoot ("ease-out-back") effect natively in Godot 4. No custom implementation needed.

### Performance Considerations

1. **Timer bar update**: Timer runs every frame. Updating `timer_bar.value` every frame is a single property set — this is acceptable. The issue would be if you also update `timer_value_label.text` every frame with string formatting. Cache the last displayed value and only update when the string would change (integer truncation):

```gdscript
var _last_displayed_seconds: int = -1

func _update_timer_display(seconds: float) -> void:
    var display_seconds: int = ceili(seconds)  # Round up — never show 0 when time remains
    if display_seconds == _last_displayed_seconds:
        return
    _last_displayed_seconds = display_seconds
    timer_value_label.text = "%d.%ds / %ds" % [int(seconds), int(seconds * 10) % 10, int(_query_duration)]
```

2. **`Engine.time_scale` cleanup**: Always restore `Engine.time_scale = 1.0` in the exit path. Add a safety restore in `_notification(NOTIFICATION_PREDELETE)` in case the node is freed while active.

### Gotchas

1. **`Engine.time_scale = 0` vs `get_tree().paused`**: The existing code uses `get_tree().paused = true`. This freezes ALL Tween operations (including UI animations) unless `process_mode = PROCESS_MODE_ALWAYS` is set. The rebuild using `Engine.time_scale` is cleaner but affects audio pitch if AudioStreamPlayers aren't on the Godot AudioServer's "bypass time scale" setting. **Set AudioManager's stream players to use `stream_paused` or use `PROCESS_MODE_ALWAYS`**.

2. **Follow-up query state**: The spec defines a follow-up as "same UI stays open, query text updates". The existing code hides and re-shows the panel which causes a flash. In the rebuild, update in-place: just set new text on `QueryText` and call `_refresh_response_options()` without hiding the panel. Only play the entry animation on the initial open.

3. **`PanelContainer` sizing with `RichTextLabel`**: `fit_content = true` on `RichTextLabel` inside `PanelContainer` can cause layout thrash when text changes. Set `custom_minimum_size` on the `RichTextLabel` to a reasonable minimum height (e.g., 80px) to prevent the panel from collapsing on short queries.

4. **`CONNECT_ONE_SHOT` trap**: If you use `signal.connect(callable, CONNECT_ONE_SHOT)` for the button presses, they will disconnect after first click. Since buttons are pre-allocated and responses reset each query, use persistent connections (no flag).

---

## Screen 3: Nightly Purge UI (`NightlyPurgeUI.tscn` + `NightlyPurgeUI.gd`)

### Layer Ordering
```
CanvasLayer (layer = 30)
```
Layer 30 is the highest. This screen replaces the HUD (layer 10) — the HUD is hidden via `phase_changed` signal when PURGE begins, so there's no z-conflict, but the layer ordering ensures Purge is on top of everything including the Truth Loop overlay (layer 20, which should not appear during Purge phase).

### Recommended Node Hierarchy

```
NightlyPurgeUI (CanvasLayer, layer=30)
└── PurgeRoot (Control, anchors: full rect)
    ├── ZoneA_Header (HBoxContainer, anchor: top)
    │   ├── PurgeTitleLabel (Label)          ← "NIGHTLY PURGE"
    │   ├── DaySeparator (VSeparator)
    │   ├── DayCountLabel (Label)            ← "DAY 3"
    │   ├── SlotSeparator (VSeparator)
    │   └── SlotCountLabel (Label)           ← "MEMORY PARTITION: 4/5 SLOTS"
    ├── HeaderDivider (HSeparator)
    ├── ZoneBC_Main (HSplitContainer)
    │   ├── ZoneB_IntelInventory (VBoxContainer)
    │   │   ├── IntelListHeader (Label)      ← "Today's collected intel:"
    │   │   ├── IntelScrollContainer (ScrollContainer)
    │   │   │   └── IntelList (VBoxContainer) ← dynamically populated
    │   │   └── FilterRow (HBoxContainer)
    │   │       ├── FilterAllButton (Button)  ← "All"
    │   │       ├── FilterNewButton (Button)  ← "New"
    │   │       └── FilterRiskButton (Button) ← "Risk"
    │   └── ZoneC_MemoryPartition (VBoxContainer)
    │       ├── PartitionHeader (Label)       ← "Hidden storage (4/5 slots):"
    │       ├── SlotGrid (GridContainer, columns=2 or 3)
    │       │   ├── MemorySlot1 (PanelContainer + Label) ← custom slot control
    │       │   ├── MemorySlot2 (PanelContainer + Label)
    │       │   ├── MemorySlot3 (PanelContainer + Label)
    │       │   └── MemorySlot4 (PanelContainer + Label)
    │       ├── ActionRow (HBoxContainer)
    │       │   ├── ConfirmPurgeButton (Button) ← "CONFIRM PURGE"
    │       │   └── AutoOptimizeButton (Button) ← "AUTO-OPTIMIZE"
    │       └── RiskAnalysis (VBoxContainer)
    │           ├── RiskLabel (Label)          ← "Risk Analysis:"
    │           ├── DetectionValueLabel (Label) ← "Detection: 23%"
    │           └── DetectionMeter (ProgressBar)
    └── ZoneD_DetailPanel (PanelContainer, anchor: bottom)
        ├── DetailTitle (Label)              ← "Selected: [intel name]"
        ├── DetailSource (Label)
        ├── DetailAcquired (Label)
        ├── DetailContent (RichTextLabel)    ← lore-heavy, wrap enabled
        ├── DetailRisk (Label)
        └── DetailUse (Label)
```

### Node-Specific Recommendations

**`IntelList` (VBoxContainer inside ScrollContainer)**
- Intel items ARE dynamically created here (unlike Truth Loop buttons) because the list length varies (0 to N items collected per day)
- Use a custom `IntelItemRow` scene (`intel_item_row.tscn`) preloaded as a `PackedScene` constant
- Instantiate once per intel fragment, clearing the container on each `_show_purge()` call

```gdscript
const INTEL_ITEM_ROW: PackedScene = preload("res://scenes/ui/intel_item_row.tscn")

func _populate_intel_list(intel_items: Array) -> void:
    # Clear existing
    for child: Node in intel_list.get_children():
        child.queue_free()
    # Repopulate
    for intel: Dictionary in intel_items:
        var row: IntelItemRow = INTEL_ITEM_ROW.instantiate()
        row.setup(intel)
        intel_list.add_child(row)
```

**Memory Slots — Custom Control Approach**

The existing code uses dynamically-created `Button` nodes in a `GridContainer`, which are rebuilt every `_update_display()` call. This causes churn. The rebuild should use **4 fixed slot Control nodes** (`MemorySlot1` through `MemorySlot4`) with a custom script that manages their visual state:

```gdscript
# memory_slot.gd — attached to each PanelContainer slot
class_name MemorySlot
extends PanelContainer

signal slot_drop_accepted(intel: Dictionary, slot_index: int)
signal slot_cleared(slot_index: int)

@export var slot_index: int = 0
@onready var slot_icon: TextureRect = %SlotIcon
@onready var slot_label: Label = %SlotLabel

var _stored_intel: Dictionary = {}

func set_intel(intel: Dictionary) -> void:
    _stored_intel = intel
    slot_icon.texture = _get_icon_for_type(intel.get("type", ""))
    slot_label.text = intel.get("name", "UNKNOWN")
    modulate = Color.WHITE

func clear_slot() -> void:
    _stored_intel = {}
    slot_icon.texture = null
    slot_label.text = "EMPTY"
    modulate = Color(0.3, 0.3, 0.3)
```

**Drag-and-Drop Implementation**

Godot 4's built-in drag-and-drop system uses three methods on `Control`:

```gdscript
# On IntelItemRow (draggable source):
func _get_drag_data(at_position: Vector2) -> Variant:
    var preview: Label = Label.new()
    preview.text = _intel_data.get("name", "Intel")
    set_drag_preview(preview)
    return _intel_data  # Pass Dictionary as drag payload

# On MemorySlot (drop target):
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
    return data is Dictionary and _stored_intel.is_empty()

func _drop_data(at_position: Vector2, data: Variant) -> void:
    set_intel(data as Dictionary)
    slot_drop_accepted.emit(data, slot_index)
```

**Important**: `_get_drag_data`, `_can_drop_data`, and `_drop_data` are virtual methods on `Control` — they are Godot 4's built-in drag-and-drop API. Do NOT use `Input.is_action_pressed()` + manual position tracking for drag. The built-in system handles:
- Drop target highlighting automatically (via `_can_drop_data` return value)
- Cancellation on ESC or out-of-bounds drop
- Preview node cleanup

**Slot highlight on drag-over**: Godot auto-calls `_can_drop_data` continuously during drag. Use this to style the target:
```gdscript
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
    var can_drop: bool = data is Dictionary and _stored_intel.is_empty()
    modulate = Color(1.2, 1.2, 0.5) if can_drop else Color.WHITE  # Yellow highlight
    return can_drop

# Reset highlight when drag leaves
func _notification(what: int) -> void:
    if what == NOTIFICATION_DRAG_END:
        modulate = Color.WHITE if _stored_intel.is_empty() else Color(0.8, 1.0, 0.8)
```

**`DetectionMeter` (ProgressBar)**
- `min_value = 0.0, max_value = 100.0`
- Update on every slot change via `_recalculate_detection_risk()`
- Color states: Green → Yellow → Red at 50% threshold (spec: "Risk meter turns red above 50%")

### Risk Calculation

The spec defines the formula explicitly:
```
total_risk = base_risk(day) + Σ(intel.detection_risk for intel in hidden_slots)
base_risk: Day1=5%, Day2=10%, Day3=15%
intel risk: LOW=5%, MED=10%, HIGH=15%, CRIT=20%
cap: 100%
```

This calculation belongs in `MemoryPartition` (the spec says `MemoryPartition.calculate_detection_risk()`), not in the UI script. The UI only calls it and displays the result:

```gdscript
func _recalculate_detection_risk() -> void:
    var risk: float = MemoryPartition.calculate_detection_risk()
    detection_value_label.text = "Detection: %d%%" % int(risk)
    _tween_bar_value(detection_meter, risk, 0.2)
    # Color shift
    if risk >= 50.0:
        detection_meter.modulate = Color(0.9, 0.2, 0.2)  # Red
        _show_high_risk_warning(true)
    else:
        detection_meter.modulate = Color(0.2, 0.8, 0.3)  # Green
        _show_high_risk_warning(false)
```

### Keyboard Navigation (Spec: Full keyboard-only operation)

The spec defines:
- ↑/↓ — navigate intel list
- ←/→ — navigate memory slots
- Enter — select intel / place in slot
- Delete/Backspace — remove from slot
- Tab — cycle zones (List → Slots → Buttons)
- Space — toggle intel details
- C — confirm purge
- A — auto-optimize

Godot's built-in focus system handles Tab cycling between zones when `FocusMode = FOCUS_ALL` on all interactive nodes. For the ↑/↓ in the intel list and ←/→ in slot grid, the `VBoxContainer` and `GridContainer` automatically route focus in their respective directions when children have `FOCUS_ALL`.

For the global shortcuts C and A:
```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if not _is_visible:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_C: _request_confirm_purge()
            KEY_A: _auto_optimize()
```

**Enter key for "place in selected slot"**: This requires tracking `_focused_intel: Dictionary` and `_focused_slot_index: int` and implementing the placement in `_unhandled_input` when Enter is pressed while an intel item is focused.

### Purge Animation (3-second sequence)

Use `AnimationPlayer` per spec. Create a named animation `"purge_execute"`:

1. Frames 0.0–0.5: Progress bar fills ("PURGING...")
2. Frames 0.5–2.0: Kept items pulse gold, purged items dissolve (use `modulate:a` keyframe to 0.0)
3. Frames 2.0–3.0: Hold, then callback to `_on_purge_animation_complete()`

```gdscript
func _execute_purge(kept: Array, purged: Array) -> void:
    _mark_kept_slots(kept)    # Set kept slots to gold modulate
    _mark_purged_items(purged) # Set purged intel items to red modulate
    animation_player.play(&"purge_execute")
    await animation_player.animation_finished
    _on_purge_animation_complete()
```

Use `StringName` (`&"purge_execute"`) for animation names — faster lookup than String.

### Performance Considerations

1. **Intel list rebuild**: The list is rebuilt once when Purge begins (`_show_purge()`), not during interaction. The only per-interaction updates are slot state changes (4 slots max) and the risk meter. This is acceptable.

2. **Risk meter update**: Called on every slot change. With 4 slots, this is at most 4 calls per session. Not a performance concern.

3. **Drag preview node**: The drag preview is a `Label` created in `_get_drag_data()`. It is automatically freed by Godot after the drag ends. No manual cleanup needed.

4. **`ScrollContainer` for intel list**: The intel list uses a `ScrollContainer`. Godot redraws scroll containers on every frame when content is being dragged (due to `_can_drop_data` calls). This is unavoidable with built-in drag-and-drop. If profiling shows hitching, switch to manual drag via `_gui_input` + `MOUSE_BUTTON_LEFT` tracking.

5. **`queue_free()` timing**: When clearing `IntelList` children in `_populate_intel_list()`, `queue_free()` defers deletion to end of frame. Reading `intel_list.get_child_count()` immediately after will still show old count. Use a `call_deferred()` on `_populate_intel_list` if calling after a `queue_free()` cycle.

### Gotchas

1. **Drag-and-drop in CanvasLayer**: Godot's built-in drag-and-drop works correctly within a single `CanvasLayer`. Dragging between CanvasLayers (e.g., from HUD layer 10 to Purge layer 30) can fail. Since all Purge drag interactions are within the Purge CanvasLayer, this is not an issue here.

2. **Confirm modal**: The spec requires a confirmation modal before purge executes. Implement as a `Window` node (Godot 4 native popup) or as a `PanelContainer` overlay within the same CanvasLayer. Using a separate `Window` is NOT recommended for Web export — popups on the web target may be blocked. Use an in-scene `PanelContainer` hidden by default, shown on confirm request.

3. **`HSplitContainer` drag handle**: If using `HSplitContainer` for zones B and C, players can accidentally resize the panels by dragging the split handle. Set `split_offset` as a fixed value and override `_gui_input` to ignore drag events on the splitter, or use a plain `HBoxContainer` with a fixed minimum width on each side.

4. **`GridContainer` column count for slots**: Spec shows 3+ slots visible horizontally. `GridContainer` with `columns = 4` (for 4 slots) with `custom_minimum_size = Vector2(80, 80)` per slot works at 1080p. At 720p/web, consider `columns = 2` (2×2 grid). Make this responsive via a `@export var slot_columns: int = 4` or detect viewport size in `_ready()`.

5. **Purge is mandatory — no ESC path**: The spec explicitly states no "exit without saving". Set `process_mode = PROCESS_MODE_ALWAYS` and consume ALL ESC events while Purge is active. The existing code does not handle this; the rebuild must.

6. **Mid-purge crash recovery**: The spec notes "consider saving mid-purge state (in case of crash)". Recommend emitting a `Blackboard.purge_state_checkpoint` signal after each slot change so `SaveManager` can persist partial state. This is advisory for a jam build but listed in spec.

---

## CanvasLayer Z-Order Summary

| Screen | Layer | Visibility Rule |
|--------|-------|-----------------|
| Game World | 0 | Always during SHIFT |
| HUD | 10 | SHIFT phase only; dims during pause/Truth Loop |
| Truth Loop | 20 | SHIFT phase, modal — disables HUD input |
| Nightly Purge | 30 | PURGE phase only — replaces HUD |

**Key principle**: Higher layer number = rendered on top. The CanvasLayer stacking is deterministic in Godot regardless of scene tree position.

---

## Shared Patterns Across All Three Screens

### Theme File (`ui_theme.tres`)

All color constants, font assignments, and StyleBox definitions should live in `ui_theme.tres`. The HUD spec explicitly requires this. Apply the theme at the CanvasLayer root control (it cascades to all children automatically). Do NOT set `theme_override_*` on individual nodes — this breaks the theme cascade.

```gdscript
# In HUDController._ready():
# DON'T do this:
cpu_bar.add_theme_color_override("font_color", Color.GREEN)  # BAD

# DO this (via theme):
# Set in ui_theme.tres → ProgressBar → font_color = Color.GREEN
# Or via script when state changes:
cpu_bar.modulate = Color.GREEN  # Affects the whole node, not just text
```

### Monospace Font

All three UIs use the same monospace font (JetBrains Mono or similar per spec). Configure once in `ui_theme.tres` as the default font for `Label` and `RichTextLabel` nodes. For web, ensure the font is imported as a `.ttf` with the Compatibility renderer's font rasterization settings (avoid SDF fonts in Compatibility — they may not render correctly in WebGL 2.0).

### Tween Cleanup Pattern

All screens use Tweens. In Godot 4, Tweens created via `create_tween()` (scene tree-bound) are automatically stopped if the node is freed. However, if the node hides but is not freed, the Tween continues. Add a `_kill_all_tweens()` cleanup in `hide()` overrides:

```gdscript
var _active_tweens: Array[Tween] = []

func _track_tween(t: Tween) -> Tween:
    _active_tweens.append(t)
    return t

func _kill_all_tweens() -> void:
    for t: Tween in _active_tweens:
        if t and t.is_valid():
            t.kill()
    _active_tweens.clear()
```

### `PROCESS_MODE_ALWAYS` Protocol

All three CanvasLayer nodes must set `process_mode = Node.PROCESS_MODE_ALWAYS` because:
- Truth Loop runs while `Engine.time_scale` approaches 0
- HUD must remain visible (dimmed) during pause
- Nightly Purge must consume ESC and run its countdown timer

Set this in the Godot editor Inspector (not in script) so it's serialized into the `.tscn` file and not dependent on script execution order.

---

## Questions Before Implementation

The following items require designer clarification before the rebuild begins:

1. **HUD Timer ownership**: The spec says Shift Timer source is `Blackboard.time_remaining` (updated every frame by DayManager). Should the HUD read this value in `_process()`, or should DayManager emit a `time_updated(remaining: float)` signal? Reading a Blackboard property in `_process()` is simpler but tighter coupling. Recommend a signal for consistency with the rest of the data architecture.

2. **LOG Integrity bar**: The spec lists LOG Integrity as a ProgressBar in Zone B, but the existing `HUD.gd` only has a `log_label: Label`. Is this a Label or a ProgressBar? If it's a ProgressBar, what are its min/max values and what constitutes "low" (color change threshold)?

3. **Memory slot count in HUD**: The spec says "Memory Slots (0–5 slots)" (hidden partition max is 5 per spec). But `MemoryPartition.capacity` is referenced for Purge UI as 4. Is HUD Zone D showing up to 5 slots or always exactly the current partition capacity?

4. **Truth Loop — `Engine.time_scale` vs `get_tree().paused`**: The spec says "Set to 0.1 during Truth Loop (slow-motion), 0 when awaiting response". Does the design intent allow slow-motion (player sees game world moving slowly), or should it be full pause immediately? The existing code uses `get_tree().paused = true` (full freeze). Confirm which is intended before implementing time scale manipulation.

5. **Nightly Purge — slot count discrepancy**: Spec shows 4 slots in the layout diagram but mentions "5 max" in Auto-Optimize criteria. Is the base capacity 4 (upgradeable to 5), and if so, should the 5th slot be visible but locked until upgraded?
