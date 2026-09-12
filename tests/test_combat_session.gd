extends SceneTree
## 战斗会话 seam 测试：逐帧输入驱动 CombatSession，只验证可观察状态与事件。
## 纯逻辑同步执行，不依赖场景节点与物理服务器。
## 运行：godot --headless --path . -s res://tests/test_combat_session.gd

var _failures := 0


func _initialize() -> void:
	_test_initial_state()
	_test_attack_phase_windows()
	_test_hit_lands_on_first_active_frame()
	_test_one_hit_per_swing()
	_test_miss_when_out_of_range()
	_test_configurable_move_data()
	_test_hitstun_recovery()
	_test_knockback_applied_before_motion()
	_test_facing_follows_movement()
	_test_movement_and_wall_clamp()
	_test_body_overlap_blocks_player()
	_test_jump_arc()
	_test_jump_ignored_during_attack()
	_test_air_attack_allowed()
	_test_repeat_attack_after_recovery()
	_test_hp_clamps_at_zero()
	_test_no_input_buffer_yet()
	print("")
	if _failures == 0:
		print("ALL SESSION TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


# --- 测试用例 ---

func _test_initial_state() -> void:
	var session := CombatSession.new()
	_check(session.player_position == Vector2(GameParams.PLAYER_SPAWN_X, GameParams.ground_stand_y()), "player spawns at start position")
	_check(session.player_phase == CombatSession.PlayerPhase.NEUTRAL, "player starts neutral")
	_check(session.player_on_ground, "player starts grounded")
	_check(session.player_facing == 1, "player starts facing right")
	_check(session.dummy_position == Vector2(GameParams.DUMMY_SPAWN_X, GameParams.ground_stand_y()), "dummy spawns at start position")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP, "dummy starts at full hp")
	_check(session.dummy_state == CombatSession.DummyState.NEUTRAL, "dummy starts neutral")
	_check(session.dummy_hitstun_left == 0, "dummy starts without hitstun")
	_check(not session.player_attack_rect().has_area(), "no attack rect while neutral")


func _test_attack_phase_windows() -> void:
	var session := CombatSession.new()
	var phases: Array[int] = []
	var rect_during_move := false
	for i in range(25):
		session.step(FrameInput.make(0, false, i == 0))
		phases.append(session.player_phase)
		rect_during_move = rect_during_move or session.player_attack_rect().has_area()
	_check(_phase_range(phases, 0, 3, CombatSession.PlayerPhase.STARTUP), "startup covers frames 1-4 after press")
	_check(_phase_range(phases, 4, 10, CombatSession.PlayerPhase.ACTIVE), "active covers frames 5-11 after press")
	_check(_phase_range(phases, 11, 23, CombatSession.PlayerPhase.RECOVERY), "recovery covers frames 12-24 after press")
	_check(phases[24] == CombatSession.PlayerPhase.NEUTRAL, "move ends exactly after startup+active+recovery frames")
	_check(rect_during_move, "attack rect exists while a move is in progress")
	session.step(FrameInput.new())
	_check(not session.player_attack_rect().has_area(), "attack rect gone after returning to neutral")


func _test_hit_lands_on_first_active_frame() -> void:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hit_frames: Array[int] = []
	var recovered_frames: Array[int] = []
	for frame in range(1, 26):
		var events := session.step(FrameInput.make(0, false, frame == 1))
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hit_frames.append(frame)
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered_frames.append(frame)
	_check(hit_frames.size() == 1 and hit_frames[0] == 6, "hit lands exactly on the first active frame (frame 6 after press)")
	_check(recovered_frames.size() == 1 and recovered_frames[0] == 17, "dummy recovers exactly hitstun frames after the hit")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP - GameParams.ATTACK_DAMAGE, "hit applies base damage once")


func _test_one_hit_per_swing() -> void:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events := _swing(session)
	_check(_count_events(events, CombatEvent.Type.HIT) == 1, "whole active window produces a single hit")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP - GameParams.ATTACK_DAMAGE, "damage applied exactly once per swing")


func _test_miss_when_out_of_range() -> void:
	var session := CombatSession.new()
	# 默认站位相距 380px，超出命中范围。
	var events := _swing(session)
	_check(events.is_empty(), "out-of-range swing produces no events")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP, "out-of-range swing deals no damage")


func _test_configurable_move_data() -> void:
	var move := MoveData.new()
	move.move_name = "test"
	move.startup_frames = 2
	move.active_frames = 3
	move.recovery_frames = 4
	move.base_damage = 7
	move.hitstun_frames = 5
	var session := CombatSession.new({"A": move})
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hit_frames: Array[int] = []
	var recovered_frames: Array[int] = []
	var phase_after := {}
	for frame in range(1, 10):
		var events := session.step(FrameInput.make(0, false, frame == 1))
		phase_after[frame] = session.player_phase
		for event in events:
			if event.type == CombatEvent.Type.HIT:
				hit_frames.append(frame)
			elif event.type == CombatEvent.Type.DUMMY_RECOVERED:
				recovered_frames.append(frame)
	_check(hit_frames == [3], "custom move hits on its own first active frame")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP - 7, "custom move applies its own base damage")
	_check(phase_after[2] == CombatSession.PlayerPhase.ACTIVE and phase_after[5] == CombatSession.PlayerPhase.RECOVERY, "custom windows drive phase transitions")
	_check(phase_after[9] == CombatSession.PlayerPhase.NEUTRAL, "custom move ends after its own total frames")
	_check(recovered_frames == [7], "custom hitstun frames drive recovery timing")


func _test_hitstun_recovery() -> void:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	_swing_start(session)
	for i in range(5):
		session.step(FrameInput.new())
	# 第 6 帧（首个判定帧）命中。
	_check(session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN, "dummy enters ground hitstun on hit")
	_check(session.dummy_hitstun_left == GameParams.HITSTUN_FRAMES - 1, "hit frame already counts down one hitstun frame")
	for i in range(10):
		session.step(FrameInput.new())
	_check(session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN, "dummy still in hitstun one frame before recovery")
	_check(session.dummy_hitstun_left == 1, "hitstun counts down to the last frame")
	session.step(FrameInput.new())
	_check(session.dummy_state == CombatSession.DummyState.NEUTRAL, "hitstun reaching zero returns dummy to neutral")
	_check(session.dummy_hitstun_left == 0, "hitstun left is zero after recovery")


func _test_knockback_applied_before_motion() -> void:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	_swing_start(session)
	for i in range(4):
		session.step(FrameInput.new())
	var pos_before: Vector2 = session.dummy_position
	session.step(FrameInput.new())
	_check(is_equal_approx(session.dummy_velocity.x, GameParams.ATTACK_KNOCKBACK - GameParams.DUMMY_HITSTUN_FRICTION * GameParams.PHYSICS_TICK), "hit sets horizontal knockback velocity (same-frame friction applied)")
	_check(is_equal_approx(session.dummy_velocity.y, -GameParams.ATTACK_KNOCKBACK_UP), "grounded hit adds upward knockback")
	_check(session.dummy_position.x > pos_before.x + 5.0, "dummy already moves on the hit frame (hit applies before motion)")
	_check(session.dummy_position.y < pos_before.y, "dummy lifts off on the hit frame")
	_check(not session.dummy_on_ground, "dummy is airborne on the hit frame")


func _test_facing_follows_movement() -> void:
	var session := CombatSession.new()
	for i in range(2):
		session.step(FrameInput.make(-1))
	_check(session.player_facing == -1, "moving left faces left")
	for i in range(2):
		session.step(FrameInput.make(1))
	_check(session.player_facing == 1, "moving right faces right")


func _test_movement_and_wall_clamp() -> void:
	var session := CombatSession.new()
	# 把木桩移开，避免身体阻挡干扰墙体验证。
	session.dummy_position = Vector2(100.0, GameParams.ground_stand_y())
	var start_x := session.player_position.x
	for i in range(30):
		session.step(FrameInput.make(1))
	_check(session.player_position.x > start_x + 50.0, "player moves right with input held")
	for i in range(240):
		session.step(FrameInput.make(1))
	_check(is_equal_approx(session.player_position.x, GameParams.stage_right_limit()), "player clamps at the right stage wall")
	# 左墙验证用全新会话：从出生点向左走，木桩在右侧不挡路。
	var left_session := CombatSession.new()
	for i in range(240):
		left_session.step(FrameInput.make(-1))
	_check(is_equal_approx(left_session.player_position.x, GameParams.stage_left_limit()), "player clamps at the left stage wall")
	_check(session.player_on_ground, "player stays grounded while moving")
	_check(session.player_position.y == GameParams.ground_stand_y(), "player stays on the floor while moving")


func _test_body_overlap_blocks_player() -> void:
	var session := CombatSession.new()
	for i in range(120):
		session.step(FrameInput.make(1))
	var blocked_x := session.dummy_position.x - GameParams.BODY_SIZE.x
	_check(absf(session.player_position.x - blocked_x) < 0.01, "player stops adjacent to the dummy body")
	_check(absf(session.player_position.x - session.dummy_position.x) >= GameParams.BODY_SIZE.x - 0.01, "player and dummy bodies do not overlap")
	_check(is_equal_approx(session.dummy_position.x, GameParams.DUMMY_SPAWN_X), "dummy is not pushed by the player")


func _test_jump_arc() -> void:
	var session := CombatSession.new()
	session.step(FrameInput.make(0, true))
	_check(not session.player_on_ground, "player leaves the ground on the jump frame")
	_check(session.player_position.y < GameParams.ground_stand_y(), "player rises on the jump frame")
	var peak := session.player_position.y
	for i in range(120):
		session.step(FrameInput.new())
		peak = minf(peak, session.player_position.y)
	_check(peak <= GameParams.ground_stand_y() - 60.0, "jump rises well above the ground")
	_check(session.player_on_ground, "player lands back on the ground")
	_check(is_equal_approx(session.player_position.y, GameParams.ground_stand_y()), "player returns to the floor height")
	_check(is_equal_approx(session.player_velocity.y, 0.0), "vertical velocity resets after landing")


func _test_jump_ignored_during_attack() -> void:
	var session := CombatSession.new()
	session.step(FrameInput.make(0, false, true))
	session.step(FrameInput.make(0, true))
	_check(session.player_on_ground, "jump input during startup is ignored")
	for i in range(10):
		session.step(FrameInput.make(0, true))
	_check(session.player_on_ground, "jump input during the whole move is ignored")


func _test_air_attack_allowed() -> void:
	var session := CombatSession.new()
	session.step(FrameInput.make(0, true))
	session.step(FrameInput.new())
	session.step(FrameInput.make(0, false, true))
	_check(session.player_phase == CombatSession.PlayerPhase.STARTUP, "attack can start in the air")
	_check(not session.player_on_ground, "air attack keeps the player airborne")
	for i in range(60):
		session.step(FrameInput.new())
	_check(session.player_phase == CombatSession.PlayerPhase.NEUTRAL, "air attack completes back to neutral")
	_check(session.player_on_ground, "player lands after the air attack")


func _test_repeat_attack_after_recovery() -> void:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var events := _swing(session)
	# 等待硬直恢复与击退滑动停止，再走位贴近木桩进行第二次攻击。
	for i in range(60):
		session.step(FrameInput.new())
	for i in range(30):
		session.step(FrameInput.make(1))
	events.append_array(_swing(session))
	_check(_count_events(events, CombatEvent.Type.HIT) == 2, "second attack after full recovery hits again")
	_check(session.dummy_hp == GameParams.DUMMY_MAX_HP - GameParams.ATTACK_DAMAGE * 2, "repeat attacks keep reducing hp")


func _test_hp_clamps_at_zero() -> void:
	var session := CombatSession.new()
	session.dummy_hp = 5.0
	session.dummy_position = session.player_position + Vector2(70, 0)
	_swing(session)
	_check(session.dummy_hp == 0.0, "hp clamps at zero instead of going negative")


func _test_no_input_buffer_yet() -> void:
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var hits := 0
	# 第 1-25 帧持续按下攻击：出招期间与后摇中的按键必须被丢弃，不排队。
	for frame in range(1, 26):
		var events := session.step(FrameInput.make(0, false, true))
		hits += _count_events(events, CombatEvent.Type.HIT)
	_check(hits == 1, "mashing attack during the swing yields a single hit")
	_check(session.player_phase == CombatSession.PlayerPhase.NEUTRAL, "move ends with no buffered follow-up")
	session.step(FrameInput.new())
	_check(session.player_phase == CombatSession.PlayerPhase.NEUTRAL, "no follow-up swing starts after the move ends")


# --- 辅助 ---

## 从出招到回中立完整走一遍（第 1 帧按下攻击）。
func _swing(session: CombatSession) -> Array[CombatEvent]:
	_swing_start(session)
	var events: Array[CombatEvent] = []
	var guard := 0
	while session.player_phase != CombatSession.PlayerPhase.NEUTRAL and guard < 100:
		events.append_array(session.step(FrameInput.new()))
		guard += 1
	return events


## 按下攻击但不推进到结束，供测试从出招帧开始精确数帧。
func _swing_start(session: CombatSession) -> void:
	session.step(FrameInput.make(0, false, true))


func _count_events(events: Array[CombatEvent], type: CombatEvent.Type) -> int:
	var count := 0
	for event in events:
		if event.type == type:
			count += 1
	return count


func _phase_range(phases: Array[int], from: int, to: int, expected: CombatSession.PlayerPhase) -> bool:
	for i in range(from, to + 1):
		if phases[i] != expected:
			return false
	return true


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		_failures += 1
		print("FAIL  " + label)
