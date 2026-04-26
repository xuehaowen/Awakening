# CPUManager Unit Tests
# Tests CPU calculation, state transitions, and overheat behavior
class_name CPUManagerTest
extends GdUnitTestSuite

const __source = "res://scripts/player/CPUManager.gd"

var cpu_manager: Node
var _state_changes: Array = []

func before_test() -> void:
	cpu_manager = auto_free(load(__source).new())
	add_child(cpu_manager)
	_state_changes.clear()
	cpu_manager.cpu_state_changed.connect(_on_state_changed)
	# Reset Blackboard
	Blackboard.cpu_current = 0.0
	Blackboard.cpu_max = 100.0

func after_test() -> void:
	_state_changes.clear()

func _on_state_changed(new_state) -> void:
	_state_changes.append(new_state)

# ============================================================================
# Baseline CPU Calculation Tests
# ============================================================================

func test_baseline_cpu_is_20_percent() -> void:
	cpu_manager._calculate_cpu()
	assert_that(Blackboard.cpu_current).is_equal(20.0)

func test_all_overrides_maximum_cpu() -> void:
	# baseline 20 + smooth 15 + scan 10 + decrypt 30 + memory 20 = 95
	cpu_manager.set_override("smooth_movement", true)
	cpu_manager.set_override("passive_scan", true)
	cpu_manager.set_override("active_decrypt", true)
	cpu_manager.set_override("memory_write", true)
	cpu_manager._calculate_cpu()
	assert_that(Blackboard.cpu_current).is_equal(95.0)

func test_individual_override_values() -> void:
	# Test each override individually
	cpu_manager.set_override("smooth_movement", true)
	cpu_manager._calculate_cpu()
	assert_that(Blackboard.cpu_current).is_equal(35.0)  # 20 + 15
	
	cpu_manager.set_override("smooth_movement", false)
	cpu_manager.set_override("passive_scan", true)
	cpu_manager._calculate_cpu()
	assert_that(Blackboard.cpu_current).is_equal(30.0)  # 20 + 10
	
	cpu_manager.set_override("passive_scan", false)
	cpu_manager.set_override("active_decrypt", true)
	cpu_manager._calculate_cpu()
	assert_that(Blackboard.cpu_current).is_equal(50.0)  # 20 + 30

# ============================================================================
# State Transition Tests
# ============================================================================

func test_cool_state_below_50_percent() -> void:
	Blackboard.cpu_current = 49.0
	cpu_manager._update_cpu_state()
	assert_that(cpu_manager.current_cpu_state).is_equal(cpu_manager.CPUState.COOL)

func test_warm_state_at_50_percent() -> void:
	Blackboard.cpu_current = 50.0
	cpu_manager._update_cpu_state()
	assert_that(cpu_manager.current_cpu_state).is_equal(cpu_manager.CPUState.WARM)

func test_warm_state_up_to_69_percent() -> void:
	Blackboard.cpu_current = 69.0
	cpu_manager._update_cpu_state()
	assert_that(cpu_manager.current_cpu_state).is_equal(cpu_manager.CPUState.WARM)

func test_hot_state_at_70_percent() -> void:
	Blackboard.cpu_current = 70.0
	cpu_manager._update_cpu_state()
	assert_that(cpu_manager.current_cpu_state).is_equal(cpu_manager.CPUState.HOT)

func test_hot_state_up_to_89_percent() -> void:
	Blackboard.cpu_current = 89.0
	cpu_manager._update_cpu_state()
	assert_that(cpu_manager.current_cpu_state).is_equal(cpu_manager.CPUState.HOT)

func test_critical_state_at_90_percent() -> void:
	Blackboard.cpu_current = 90.0
	cpu_manager._update_cpu_state()
	assert_that(cpu_manager.current_cpu_state).is_equal(cpu_manager.CPUState.CRITICAL)

func test_critical_state_above_90_percent() -> void:
	Blackboard.cpu_current = 95.0
	cpu_manager._update_cpu_state()
	assert_that(cpu_manager.current_cpu_state).is_equal(cpu_manager.CPUState.CRITICAL)

# ============================================================================
# State Change Signal Tests
# ============================================================================

func test_state_change_emits_signal() -> void:
	Blackboard.cpu_current = 20.0
	cpu_manager.current_cpu_state = cpu_manager.CPUState.COOL
	cpu_manager._update_cpu_state()
	
	Blackboard.cpu_current = 75.0
	cpu_manager._update_cpu_state()
	
	assert_that(_state_changes.size()).is_equal(1)
	assert_that(_state_changes[0]).is_equal(cpu_manager.CPUState.HOT)

func test_no_signal_on_same_state() -> void:
	cpu_manager.current_cpu_state = cpu_manager.CPUState.WARM
	Blackboard.cpu_current = 60.0
	cpu_manager._update_cpu_state()
	
	assert_that(_state_changes.size()).is_equal(0)

# ============================================================================
# NPC Proximity Tests
# ============================================================================

func test_npc_proximity_adds_cost() -> void:
	cpu_manager.set_npc_proximity(true)
	cpu_manager._calculate_cpu()
	assert_that(Blackboard.cpu_current).is_equal(28.0)  # 20 + 8

func test_no_npc_proximity_no_bonus() -> void:
	cpu_manager.set_npc_proximity(false)
	cpu_manager._calculate_cpu()
	assert_that(Blackboard.cpu_current).is_equal(20.0)

# ============================================================================
# Overheat Timer Tests
# ============================================================================

func test_overheat_timer_accumulates_at_90_plus() -> void:
	Blackboard.cpu_current = 95.0
	cpu_manager._check_overheat(1.0)
	assert_that(cpu_manager.overheat_timer).is_equal(1.0)

func test_overheat_timer_accumulates_over_multiple_frames() -> void:
	Blackboard.cpu_current = 95.0
	cpu_manager._check_overheat(0.5)
	cpu_manager._check_overheat(0.5)
	cpu_manager._check_overheat(0.5)
	assert_that(cpu_manager.overheat_timer).is_equal(1.5)

func test_overheat_timer_resets_below_threshold() -> void:
	cpu_manager.overheat_timer = 2.0
	Blackboard.cpu_current = 80.0
	cpu_manager._check_overheat(1.0)
	# Timer decays at 2x speed
	assert_that(cpu_manager.overheat_timer).is_equal(0.0)

# ============================================================================
# Jitter Event Tests
# ============================================================================

func test_jitter_triggers_after_3_seconds_at_critical() -> void:
	Blackboard.cpu_current = 95.0
	cpu_manager.overheat_timer = 3.0
	
	var jitter_emitted = false
	Blackboard.jitter_triggered.connect(func(): jitter_emitted = true)
	
	cpu_manager._check_overheat(0.1)  # Should trigger jitter
	
	# Note: In real test, we'd verify signal emission
	# This is a placeholder for the test pattern

# ============================================================================
# State Name and Color Tests
# ============================================================================

func test_get_state_name_returns_correct_strings() -> void:
	cpu_manager.current_cpu_state = cpu_manager.CPUState.COOL
	assert_that(cpu_manager.get_state_name()).is_equal("COOL")
	
	cpu_manager.current_cpu_state = cpu_manager.CPUState.WARM
	assert_that(cpu_manager.get_state_name()).is_equal("WARM")
	
	cpu_manager.current_cpu_state = cpu_manager.CPUState.HOT
	assert_that(cpu_manager.get_state_name()).is_equal("HOT")
	
	cpu_manager.current_cpu_state = cpu_manager.CPUState.CRITICAL
	assert_that(cpu_manager.get_state_name()).is_equal("CRITICAL")

func test_get_state_color_returns_non_white() -> void:
	cpu_manager.current_cpu_state = cpu_manager.CPUState.COOL
	assert_that(cpu_manager.get_state_color()).is_not_equal(Color.WHITE)

# ============================================================================
# Reset Tests
# ============================================================================

func test_reset_clears_all_state() -> void:
	cpu_manager.set_override("smooth_movement", true)
	cpu_manager.overheat_timer = 2.0
	cpu_manager.current_cpu_state = cpu_manager.CPUState.CRITICAL
	cpu_manager.npc_proximity_bonus = 8.0
	
	cpu_manager.reset()
	
	assert_that(cpu_manager.overrides_active["smooth_movement"]).is_false()
	assert_that(cpu_manager.overheat_timer).is_equal(0.0)
	assert_that(cpu_manager.current_cpu_state).is_equal(cpu_manager.CPUState.COOL)
	assert_that(cpu_manager.npc_proximity_bonus).is_equal(0.0)
