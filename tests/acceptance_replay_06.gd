extends SceneTree
## 票据 06 验收回放：动作内蓄力、计划位移、active 扫掠、身体穿越与换边。
## 保留真实位移/击退的逐帧证据（不钉位）：grounded/airborne 236C、前置浮空/
## slide 两种捞起时机、中板蓄力穿越、版边普通 5D 墙截断、挥空轨迹继续、
## 双面向提前搓招与手动 665B/665C。证据归档 acceptance/06/。
## 运行：godot --headless --path . -s res://tests/acceptance_replay_06.gd

const NEAR_DX := 50.0
const SLIDE_DX := 93.0

var _failures := 0


func _initialize() -> void:
	_replay_r1_mid_charge_cross(1)
	_replay_r1_mid_charge_cross(-1)
	_replay_r2_locked_candidate_and_mirror_input(1)
	_replay_r2_locked_candidate_and_mirror_input(-1)
	_replay_r3_airborne_236c_pickup(1)
	_replay_r3_airborne_236c_pickup(-1)
	_replay_r4_slide_pickup_charged(1)
	_replay_r5_corner_5d_wall_clamp(1)
	_replay_r5_corner_5d_wall_clamp(-1)
	_replay_r6_whiff_trajectory_continues(1)
	_replay_r7_blocked_keeps_side(1)
	_replay_r8_manual_dash_5b5c(1)
	_replay_r8_manual_dash_5b5c(-1)
	print("")
	if _failures == 0:
		print("ALL REPLAY 06 CHECKS PASSED")
		quit(0)
	else:
		print(str(_failures) + " REPLAY 06 CHECK(S) FAILED")
		quit(1)


func _spawn(dx: float, facing: int) -> CombatSession:
	var session := CombatSession.new()
	if facing == 1:
		session.dummy_position = session.player_position + Vector2(dx, 0)
	else:
		session.dummy_position = session.player_position - Vector2(dx, 0)
		session.player_facing = -1
	return session


func _hold_d(frame: int, press_frame: int, hold_to: int) -> FrameInput:
	var input := FrameInput.new()
	if frame == press_frame or (frame > press_frame and frame <= hold_to):
		var held: Array[String] = ["D"]
		input.held_action_keys = held
	if frame == press_frame:
		var pressed: Array[String] = ["D"]
		input.pressed_action_keys = pressed
	return input


func _feed_236c(session: CombatSession, frame: int, key: String, facing: int) -> FrameInput:
	var axis := 0
	var down := false
	var rel := frame % 4
	if rel == 1:
		down = true
	elif rel == 2:
		down = true
		axis = facing
	elif rel == 3:
		axis = facing
	return FrameInput.make(axis, false, key, down)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		_failures += 1
		print("  FAIL  " + label)


func _log_event(frame: int, tag: String, event: CombatEvent, session: CombatSession) -> void:
	match event.type:
		CombatEvent.Type.HIT:
			print("  F%-3d %s HIT seg%d 伤%.1f 第%d击 方向%d 玩家x=%.1f 木桩x=%.1f" % [
				frame, tag, event.move_segment, event.damage, event.combo_hits, event.direction,
				session.player_position.x, session.dummy_position.x])
		CombatEvent.Type.CHARGE_COMMITTED:
			print("  F%-3d %s CHARGE_COMMITTED %s→%s 按住%d帧 %s" % [
				frame, tag, event.charge_from_move_id, event.charge_to_move_id, event.charge_age,
				"蓄力版" if event.charged else "普通版"])
		CombatEvent.Type.SWITCHED_SIDES:
			print("  F%-3d %s SWITCHED_SIDES 新面向%d 玩家x=%.1f 木桩x=%.1f（下一帧生效）" % [
				frame, tag, event.direction, session.player_position.x, session.dummy_position.x])
		CombatEvent.Type.ATTACK_BLOCKED:
			print("  F%-3d %s ATTACK_BLOCKED 姿态%d 玩家x=%.1f 木桩x=%.1f" % [
				frame, tag, event.guard_posture, session.player_position.x, session.dummy_position.x])
		CombatEvent.Type.LINK_FAILED:
			print("  F%-3d %s LINK_FAILED 原因%d 招式%s" % [frame, tag, event.link_fail_reason, event.link_move_id])
		CombatEvent.Type.SLIDE_STARTED:
			print("  F%-3d %s SLIDE_STARTED 滑行剩%d 木桩x=%.1f" % [frame, tag, session.dummy_slide_left, session.dummy_position.x])


## R1 中板蓄力穿越（前置浮空时机）：236C 段 1 命中 grounded（低浮空）→ 按住 D
## 至阈值 → 5[D] 捞起浮空 + 120px 突进真实跨过木桩 → 下一帧面向翻转。
func _replay_r1_mid_charge_cross(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	print("=== R1 中板 236C>5[D] 蓄力穿越 | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	var charge_frame := -1
	var swap_frame := -1
	var hit_frames: Array[int] = []
	var facing_at_swap := 0
	for frame in range(1, 90):
		var input: FrameInput
		if frame <= 4:
			input = _feed_236c(session, frame, "C" if frame == 4 else "", facing)
		else:
			input = _hold_d(frame, 16, 30)
		for event in session.step(input):
			_log_event(frame, "R1", event, session)
			if event.type == CombatEvent.Type.CHARGE_COMMITTED and event.charged:
				charge_frame = frame
			elif event.type == CombatEvent.Type.SWITCHED_SIDES:
				swap_frame = frame
			elif event.type == CombatEvent.Type.HIT:
				hit_frames.append(frame)
		if frame == swap_frame:
			facing_at_swap = session.player_facing
	_check(charge_frame > 0, "R1 蓄力提交发生（F%d）" % charge_frame)
	_check(swap_frame > 0, "R1 真实穿越换边（F%d）" % swap_frame)
	_check((session.player_position.x - session.dummy_position.x) * facing > 0,
		"R1 玩家终点越过木桩（dx=%.1f）" % (session.player_position.x - session.dummy_position.x))
	_check(session.player_facing == -facing, "R1 回放结束面向翻转（%d）" % session.player_facing)
	_check(facing_at_swap == -facing, "R1 换边当帧面向已按新关系更新")
	print("  命中帧 %s · 蓄力 F%d · 换边 F%d · 终点 玩家x=%.1f 木桩x=%.1f" % [
		str(hit_frames), charge_frame, swap_frame, session.player_position.x, session.dummy_position.x])
	print("")


## R2 双面向提前搓招：换边后开始的新候选按新面向折算（R2a）；换边前已开始的
## 候选锁定首次面向——新面向前向折为 4、234 断链（R2b）。
func _replay_r2_locked_candidate_and_mirror_input(facing: int) -> void:
	print("=== R2 换边后指令解释 | 面向 %d ===" % facing)
	# 通用前段：236C 段 1 命中 → 按住 D 蓄力 → 5[D] 穿越换边；返回换边帧。
	var run_to_swap := func(session: CombatSession) -> int:
		var swap_frame := -1
		var frame := 0
		while frame < 90 and swap_frame < 0:
			frame += 1
			var input: FrameInput
			if frame <= 4:
				input = _feed_236c(session, frame, "C" if frame == 4 else "", facing)
			else:
				input = _hold_d(frame, 16, 30)
			for event in session.step(input):
				if event.type == CombatEvent.Type.SWITCHED_SIDES:
					swap_frame = frame
		return swap_frame
	# R2a：换边后（5[D] 后摇期间）先录 2、3，收招回中立后按 C——按新面向
	# 组成 236。
	var fresh := _spawn(NEAR_DX, facing)
	var swap_frame: int = run_to_swap.call(fresh)
	_check(swap_frame > 0, "R2 前段穿越换边成立（F%d）" % swap_frame)
	var frame := swap_frame
	for phase in range(1, 4):
		frame += 1
		var input := FrameInput.new()
		input.down_held = phase <= 2
		if phase >= 2:
			input.move_axis = -facing
		fresh.step(input)
	while frame < 140 and fresh.player_move_id != "":
		frame += 1
		fresh.step(FrameInput.new())
	var started := ""
	while frame < 160 and started == "":
		frame += 1
		var input := FrameInput.new()
		if frame == swap_frame + 5 or (started == "" and fresh.player_move_id == "" and frame < swap_frame + 8):
			input = FrameInput.new()
	var pressed_at := -1
	frame = swap_frame
	while frame < 170:
		frame += 1
		var input := FrameInput.new()
		if pressed_at < 0 and fresh.player_move_id == "":
			var pressed: Array[String] = ["C"]
			input.pressed_action_keys = pressed
			input.held_action_keys = pressed
			pressed_at = frame
		for event in fresh.step(input):
			_log_event(frame, "R2a", event, fresh)
		if pressed_at > 0 and frame >= pressed_at + 5 and started == "":
			started = fresh.player_move_id
	_check(started == "236C", "R2a 换边后新候选按新面向折算，236C 起手（%s）" % started)
	# R2b：换边前（5[D] 蓄力中）提前输入 2、3——候选锁定原面向；换边后按新
	# 面向前向（世界 -facing）应折为 4，不起手 236C。
	var broken := _spawn(NEAR_DX, facing)
	swap_frame = -1
	frame = 0
	var pre_phase := 0
	while frame < 90 and swap_frame < 0:
		frame += 1
		var input: FrameInput
		if frame <= 4:
			input = _feed_236c(broken, frame, "C" if frame == 4 else "", facing)
		elif frame == 17 or frame == 18:
			# 蓄力延长 startup 期间提前搓招：2、3（此时面向尚未翻转）。
			pre_phase += 1
			input = FrameInput.new()
			input.down_held = true
			if pre_phase == 2:
				input.move_axis = facing
			var held: Array[String] = ["D"]
			input.held_action_keys = held
		else:
			input = _hold_d(frame, 16, 30)
		for event in broken.step(input):
			if event.type == CombatEvent.Type.SWITCHED_SIDES:
				swap_frame = frame
	_check(swap_frame > 0, "R2b 前段穿越换边成立（F%d，提前段在 F17-18）" % swap_frame)
	_check(String(broken.debug_snapshot()["direction_sequence"]).contains("23"),
		"R2b 提前搓招的 2、3 已录入（%s）" % broken.debug_snapshot()["direction_sequence"])
	var broken_started := ""
	var bframe := swap_frame
	while bframe < 140 and broken_started == "":
		bframe += 1
		var input := FrameInput.new()
		if bframe == swap_frame + 1:
			input.move_axis = -facing
			var pk: Array[String] = ["C"]
			input.pressed_action_keys = pk
			input.held_action_keys = pk
		for event in broken.step(input):
			_log_event(bframe, "R2b", event, broken)
		if bframe >= swap_frame + 5:
			broken_started = broken.player_move_id
	_check(broken_started != "236C", "R2b 新面向前向不完成锁定候选（起手=%s）" % broken_started)
	print("")


## R3 airborne 236C：段 1 择起 grounded 目标后，段 2 命中空中目标（独立空中
## 资料：untech 30 延长浮空）→ 按住 D 蓄力 → 5[D] 照常捞起并穿越。真实路线
##（票据 05 已证时序），非显式中间状态。
func _replay_r3_airborne_236c_pickup(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	print("=== R3 airborne 236C 段2(空中资料)>5[D] | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	var seg2_hit := -1
	var seg2_airborne := false
	var pickup_hit := -1
	var swap_frame := -1
	for frame in range(1, 100):
		var input: FrameInput
		if frame <= 4:
			input = _feed_236c(session, frame, "C" if frame == 4 else "", facing)
		else:
			input = _hold_d(frame, 26, 42)
		for event in session.step(input):
			_log_event(frame, "R3", event, session)
			if event.type == CombatEvent.Type.HIT and event.move_segment == 2:
				seg2_hit = frame
				seg2_airborne = session.dummy_state == CombatSession.DummyState.AIR_HITSTUN
			elif event.type == CombatEvent.Type.HIT and session.player_move_id == "5[D]":
				pickup_hit = frame
			elif event.type == CombatEvent.Type.SWITCHED_SIDES:
				swap_frame = frame
	_check(seg2_hit > 0 and seg2_airborne, "R3 段 2 命中空中目标（F%d，airborne 延长资料）" % seg2_hit)
	_check(pickup_hit > 0, "R3 蓄力 5[D] 捞起空中目标（F%d）" % pickup_hit)
	_check(swap_frame > 0, "R3 蓄力 5[D] 对空中目标同样穿越换边（F%d）" % swap_frame)
	print("")


## R4 slide 时机捞起（蓄力版）：@93px 段 1 挥空、段 2 命中 grounded → 触地
## GROUND_SLIDE → 按住 D 至阈值 → 5[D] 以 slide 资料捞起。
func _replay_r4_slide_pickup_charged(facing: int) -> void:
	var session := _spawn(SLIDE_DX, facing)
	print("=== R4 236C(段1挥空)>段2>slide>5[D] 蓄力捞起 | 面向 %d | 起始间距 %.0f px ===" % [facing, SLIDE_DX])
	var slide_frame := -1
	var pickup_hit := -1
	var pickup_damage := 0.0
	var swap_frame := -1
	for frame in range(1, 110):
		var input: FrameInput
		if frame <= 4:
			input = _feed_236c(session, frame, "C" if frame == 4 else "", facing)
		else:
			input = _hold_d(frame, 30, 44)
		for event in session.step(input):
			_log_event(frame, "R4", event, session)
			if event.type == CombatEvent.Type.SLIDE_STARTED:
				slide_frame = frame
			elif event.type == CombatEvent.Type.HIT and session.player_move_id == "5[D]":
				pickup_hit = frame
				pickup_damage = event.damage
			elif event.type == CombatEvent.Type.SWITCHED_SIDES:
				swap_frame = frame
	_check(slide_frame > 0, "R4 段 2 击飞触地进入 GROUND_SLIDE（F%d）" % slide_frame)
	_check(pickup_hit > 0, "R4 蓄力 5[D] 以 slide 资料捞起（F%d，伤 %.1f，slide 倍率）" % [pickup_hit, pickup_damage])
	print("  蓄力捞起后 玩家x=%.1f 木桩x=%.1f 换边=%s" % [
		session.player_position.x, session.dummy_position.x, str(swap_frame > 0)])
	print("")


## R5 版边普通 5D 墙截断：贴墙侧的 5D 位移被墙截断——命中照常、不换边、
## 墙截断标记可观察。
func _replay_r5_corner_5d_wall_clamp(facing: int) -> void:
	var session := CombatSession.new()
	var wall := GameParams.stage_right_limit() if facing == 1 else GameParams.stage_left_limit()
	session.player_position = Vector2(wall - 60.0 * facing, GameParams.ground_stand_y())
	session.dummy_position = session.player_position + Vector2(60.0 * facing, 0)
	session.player_facing = facing
	print("=== R5 版边普通 5D 墙截断 | 面向 %d | 玩家x=%.1f ===" % [facing, session.player_position.x])
	var hit := -1
	var swapped := false
	var wall_clamped := false
	for frame in range(1, 40):
		for event in session.step(FrameInput.make(0, false, "D" if frame == 1 else "")):
			_log_event(frame, "R5", event, session)
			if event.type == CombatEvent.Type.HIT:
				hit = frame
			elif event.type == CombatEvent.Type.SWITCHED_SIDES:
				swapped = true
		wall_clamped = wall_clamped or bool(session.debug_snapshot()["motion_wall_clamped"])
	_check(hit > 0, "R5 版边 5D 命中照常（F%d）" % hit)
	_check(wall_clamped, "R5 墙截断可观察")
	_check(not swapped and session.player_facing == facing, "R5 墙截断不换边（面向 %d）" % session.player_facing)
	_check((session.player_position.x - wall) * facing <= 0.01, "R5 不越界（终点 %.1f / 墙 %.1f）" % [session.player_position.x, wall])
	print("")


## R6 挥空轨迹继续：无目标的 5D/5[D] 全程位移照常走完（72/120px），速度积分
## 不受影响。
func _replay_r6_whiff_trajectory_continues(facing: int) -> void:
	print("=== R6 挥空轨迹继续 | 面向 %d ===" % facing)
	var far := CombatSession.new()
	far.dummy_position = far.player_position - Vector2(200.0 * facing, 0)
	var start_x := far.player_position.x
	for frame in range(1, 40):
		far.step(FrameInput.make(0, false, "D" if frame == 1 else ""))
	_check(is_equal_approx(absf(far.player_position.x - start_x), 72.0) or absf(absf(far.player_position.x - start_x) - 72.0) < 0.01,
		"R6 挥空 5D 全程位移 72px（%.1f）" % absf(far.player_position.x - start_x))
	var charged := CombatSession.new()
	charged.dummy_position = charged.player_position - Vector2(200.0 * facing, 0)
	start_x = charged.player_position.x
	for frame in range(1, 60):
		charged.step(_hold_d(frame, 1, 20))
	_check(absf(absf(charged.player_position.x - start_x) - 120.0) < 0.01,
		"R6 挥空 5[D] 全程位移 120px（%.1f）" % absf(charged.player_position.x - start_x))
	print("")


## R7 被防不穿越：站防挡下 5D——原侧身体边界停住，无换边（镜像单元测试的
## 真实位移取证）。
func _replay_r7_blocked_keeps_side(facing: int) -> void:
	var session := _spawn(70.0, facing)
	print("=== R7 被防不穿越 | 面向 %d | 起始间距 70 px ===" % facing)
	var blocked := -1
	var swapped := false
	for frame in range(1, 40):
		var input := FrameInput.make(0, false, "D" if frame == 1 else "")
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		for event in session.step(input):
			_log_event(frame, "R7", event, session)
			if event.type == CombatEvent.Type.ATTACK_BLOCKED:
				blocked = frame
			elif event.type == CombatEvent.Type.SWITCHED_SIDES:
				swapped = true
	_check(blocked > 0, "R7 站防挡下 5D（F%d）" % blocked)
	_check(not swapped and session.player_facing == facing, "R7 被防不换边")
	_check(absf(session.player_position.x - session.dummy_position.x) >= GameParams.BODY_SIZE.x,
		"R7 被防停在原侧身体边界（dx=%.1f）" % (session.player_position.x - session.dummy_position.x))
	print("")


## R8 手动 665B/665C：66 前冲后接普通技（冲刺结束后起手），双面向；换边后
## 按新面向冲刺同样成立。
func _replay_r8_manual_dash_5b5c(facing: int) -> void:
	print("=== R8 手动 665B/665C | 面向 %d ===" % facing)
	for key in ["B", "C"]:
		var session := _spawn(90.0, facing)
		var dash_frame := -1
		var move_frame := -1
		var hit_frame := -1
		for frame in range(1, 80):
			var input := FrameInput.new()
			# 66 前冲：前、(中立)、前——方向历史三段触发；随后冲刺结束按 B/C。
			if frame == 1 or frame == 3:
				input.move_axis = facing
			elif frame == 20:
				var pressed: Array[String] = [key]
				input.pressed_action_keys = pressed
				input.held_action_keys = pressed
			for event in session.step(input):
				if event.type == CombatEvent.Type.DASH_STARTED and dash_frame < 0:
					dash_frame = frame
				elif event.type == CombatEvent.Type.HIT and hit_frame < 0:
					hit_frame = frame
			if frame > 20 and move_frame < 0 and session.player_move_id != "":
				move_frame = frame
		_check(dash_frame == 3, "R8 66 前冲触发（F%d，键 %s）" % [dash_frame, key])
		_check(move_frame > 20, "R8 冲刺结束后 5%s 起手（F%d）" % [key, move_frame])
		_check(hit_frame > 0, "R8 5%s 命中（F%d）" % [key, hit_frame])
	print("")
