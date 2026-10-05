extends SceneTree
## 票据 10 联合验收回放：路线矩阵的正例与负例合并回放（真实位移、双面向、
## 中板/版边、命中/被防/挥空、不同起手等级）。J0 为逐招覆盖的表级断言
## （设计 §8 取消矩阵要点与旧 214D/jD 迁移）；J1–J8 重组各票代表路线为
## 联合证据；N1–N5 为联合负例。调校边界如实记录：J5 演示主路线尾部在默认
## 初值下 1 帧断链 + ~C 距离不足（候选 D1/D2，见 acceptance/10/playtest.md）。
## 证据归档 acceptance/10/（replay-joint.log）。
## 运行：godot --headless --path . -s res://tests/acceptance_replay_10.gd

const NEAR_DX := 50.0
const TOUCH_DX := 48.0
const CHAIN_DX := 60.0
const SLIDE_DX := 96.0

var _failures := 0


func _initialize() -> void:
	_joint_j0_coverage_assertions()
	_joint_j1_ground_chain(1)
	_joint_j1_ground_chain(-1)
	_joint_j2_2c_rekka_link(1)
	_joint_j2_2c_rekka_link(-1)
	_joint_j3a_236c_5d_5b(1)
	_joint_j3a_236c_5d_5b(-1)
	_joint_j3b_236c_charged_cross(1)
	_joint_j3b_236c_charged_cross(-1)
	_joint_j3c_seg2_charged_pickup(1)
	_joint_j3c_seg2_charged_pickup(-1)
	_joint_j4_corner_5d_wall(1)
	_joint_j4_corner_5d_wall(-1)
	_joint_j5_full_demo_route(1)
	_joint_j5_full_demo_route(-1)
	_joint_j6_solo_j214d(1)
	_joint_j6_solo_j214d(-1)
	_joint_j6b_jc_into_j214d_grounded(1)
	_joint_j6b_jc_into_j214d_grounded(-1)
	_joint_j7_bounce_starters()
	_joint_j8_air_d_landings(1)
	_joint_j8_air_d_landings(-1)
	_negative_n1a_blocked_6a_no_jump_cancel()
	_negative_n1b_blocked_236c_no_entry()
	_negative_n2_whiff_no_cancel()
	_negative_n3_plain_5d_no_reverse_link()
	_negative_n4_2c_2d_height_miss()
	_negative_n5_a_starter_bounce_ender()
	_negative_n6_whiffed_j2d_no_landing_cancel(1)
	print("")
	if _failures == 0:
		print("ALL REPLAY 10 CHECKS PASSED")
		quit(0)
	else:
		print(str(_failures) + " REPLAY 10 CHECK(S) FAILED")
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		_failures += 1
		print("  FAIL  " + label)


func _spawn(dx: float, facing: int) -> CombatSession:
	var session := CombatSession.new()
	if facing == 1:
		session.dummy_position = session.player_position + Vector2(dx, 0)
	else:
		session.dummy_position = session.player_position - Vector2(dx, 0)
		session.player_facing = -1
	return session


func _press(key: String, down := false, axis := 0) -> FrameInput:
	var input := FrameInput.new()
	if key != "":
		input.pressed_action_keys = [key]
		input.held_action_keys = [key]
	input.down_held = down
	input.move_axis = axis
	return input


func _jump() -> FrameInput:
	var input := FrameInput.new()
	input.jump_pressed = true
	return input


func _axis(axis: int) -> FrameInput:
	var input := FrameInput.new()
	input.move_axis = axis
	return input


## 相对面向的方向数字（3/6/9 前、1/4/7 后、1/2/3 下）。
func _digit(facing: int, digit: int, key: String = "") -> FrameInput:
	var axis := 0
	if digit == 3 or digit == 6 or digit == 9:
		axis = facing
	elif digit == 1 or digit == 4 or digit == 7:
		axis = -facing
	return FrameInput.make(axis, false, key, digit >= 1 and digit <= 3)


## 按住动作键：press 帧新按下、其后各帧仅保持（不重复触发新按下）。
func _hold(key: String, frame: int, press_frame: int, hold_to: int) -> FrameInput:
	if frame < press_frame or frame > hold_to:
		return FrameInput.new()
	var input := FrameInput.new()
	input.held_action_keys = [key]
	if frame == press_frame:
		input.pressed_action_keys = [key]
	return input


## 236 指令逐帧（相对面向）：step 0=下、1=下前、2+=前，step 3 按 C。
func _236(step: int, facing: int, key := "") -> FrameInput:
	var input := FrameInput.new()
	match step:
		0:
			input.down_held = true
		1:
			input.down_held = true
			input.move_axis = facing
		_:
			input.move_axis = facing
	if key != "":
		input.pressed_action_keys = [key]
		input.held_action_keys = [key]
	return input


## 214 指令逐帧（相对面向）：step 0=下、1=下后、2+=后，step 3 按键（默认 D）。
func _214(step: int, facing: int, key := "") -> FrameInput:
	var input := FrameInput.new()
	match step:
		0:
			input.down_held = true
		1:
			input.down_held = true
			input.move_axis = -facing
		_:
			input.move_axis = -facing
	if key != "":
		input.pressed_action_keys = [key]
		input.held_action_keys = [key]
	return input


func _log_event(frame: int, tag: String, event: CombatEvent, session: CombatSession, hit_move_id := "") -> void:
	match event.type:
		CombatEvent.Type.HIT:
			print("  F%-3d %s HIT %s seg%d 第%d击 伤%.1f | 修正 伤%.3f/时%.3f/轨%.3f | 玩家x=%.1f 木桩x=%.1f 木桩y=%.1f" % [
				frame, tag, hit_move_id if hit_move_id != "" else session.player_move_id, event.move_segment, event.combo_hits, event.damage,
				session.combo_damage_scale, session.combo_time_scale, session.combo_trajectory_scale,
				session.player_position.x, session.dummy_position.x, session.dummy_position.y])
		CombatEvent.Type.ATTACK_BLOCKED:
			print("  F%-3d %s ATTACK_BLOCKED %s（被防：独立接触结果）" % [frame, tag, session.player_move_id])
		CombatEvent.Type.LINK_FAILED:
			print("  F%-3d %s LINK_FAILED %s 原因%d" % [frame, tag, event.link_move_id, event.link_fail_reason])
		CombatEvent.Type.BOUNCE_CONTACT:
			print("  F%-3d %s BOUNCE_CONTACT 反弹vy=%.0f 追击窗%d" % [
				frame, tag, session.dummy_velocity.y, session.dummy_bounce_left])
		CombatEvent.Type.SWITCHED_SIDES:
			print("  F%-3d %s SWITCHED_SIDES 下一帧面向 %d" % [frame, tag, event.direction])
		CombatEvent.Type.CHARGE_COMMITTED:
			print("  F%-3d %s CHARGE_COMMITTED %s→%s（按住 %d 帧）" % [
				frame, tag, event.charge_from_move_id, event.charge_to_move_id, event.charge_age])
		CombatEvent.Type.COMBO_ENDED:
			print("  F%-3d %s COMBO_ENDED 原因%d" % [frame, tag, event.combo_end_reason])


## 通用运行：固定物理帧输入。moves 是首段连段的逐 HIT 投影；
## move_sequence 按动作分组，hits 携带判定段，hits_after_end 单列首次结束后的 HIT。
func _run_route(plan: Dictionary, facing: int, horizon: int, tag: String, dx := NEAR_DX,
		guard := 0) -> Dictionary:
	var session := _spawn(dx, facing)
	var evidence := preload("res://tests/replay_combo_evidence.gd").new()
	var links: Array[Dictionary] = []
	var blocked := 0
	var swaps := 0
	var action := 0
	for frame in range(1, horizon + 1):
		var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
		if guard != 0:
			input.dummy_guard_request = guard
		var move_at_start := session.player_move_id
		var move_frame_at_start: int = session.clone_state().player_move.frame
		var events := session.step(input)
		for order in events.size():
			var event: CombatEvent = events[order]
			evidence.record(frame, order, move_at_start, action, event)
			_log_event(frame, tag, event, session, move_at_start)
			match event.type:
				CombatEvent.Type.ATTACK_BLOCKED:
					blocked += 1
				CombatEvent.Type.SWITCHED_SIDES:
					swaps += 1
				CombatEvent.Type.LINK_FAILED:
					links.append({"frame": frame, "move": event.link_move_id, "reason": event.link_fail_reason})
		# Startup/charge/cancel is committed after this frame's hit resolution.
		if session.player_move_id != move_at_start or int(session.clone_state().player_move.frame) < move_frame_at_start:
			action += 1
	print("  %s combo move_sequence=%s hits=%s hits_after_end=%s" % [tag,
		str(evidence.move_sequence), str(evidence.hits), str(evidence.hits_after_end)])
	return {"session": session, "moves": evidence.moves, "ends": evidence.ends, "links": links,
		"move_sequence": evidence.move_sequence, "hits": evidence.hits, "hits_after_end": evidence.hits_after_end,
		"blocked": blocked, "swaps": swaps}


func _end_seen(run: Dictionary, reason: int) -> bool:
	for end in run["ends"]:
		if end["reason"] == reason:
			return true
	return false


# --- J0：逐招覆盖表级断言（设计基线 §8 取消矩阵要点 + 旧资源迁移） ---

func _joint_j0_coverage_assertions() -> void:
	print("=== J0 逐招覆盖表级断言 | 共享 manifest ===")
	var result := MoveTable.load_default()
	_check(result.ok, "J0 共享表加载通过")
	if not result.ok:
		return
	var ids: Array = result.moves.keys()
	_check(not ids.has("214D") and not ids.has("jD"),
		"J0 旧地面 214D 与单一 jD 不在 manifest（票据 08/10 迁移；倒地职责在 214C~B/~C，空中在 j214D）")
	_check(ids.has("j214D") and ids.has("5[D]") and ids.has("6D") and ids.has("2D"),
		"J0 新基线招式在位（j214D/5[D]/6D/2D）")
	for move_id in ["5A", "2A", "5B", "2B", "5C", "2C", "6A", "5D", "5[D]", "6D", "2D",
			"214C", "214C~B", "214C~C", "236C", "jA", "jB", "jC", "j5D", "j6D", "j2D", "j214D", "BC"]:
		_check(ids.has(move_id), "J0 %s 在共享表" % move_id)
	var chain_5a: MoveData = result.moves["5A"]
	_check(chain_5a.chain_cancel_targets.has("5B") and chain_5a.chain_cancel_targets.has("2B")
		and chain_5a.special_cancel_targets.has("214C") and chain_5a.special_cancel_targets.has("236C"),
		"J0 5A 链式 5B/2B、必杀 214C/236C")
	var five_c: MoveData = result.moves["5C"]
	_check(five_c.chain_cancel_targets.has("6A") and five_c.chain_cancel_targets.has("5D")
		and five_c.jump_cancel_targets.is_empty(),
		"J0 5C 高伤害连接（6A/5D）、不再是专用 launcher（无 jump cancel）")
	var two_c: MoveData = result.moves["2C"]
	_check(two_c.chain_cancel_targets.has("6D") and two_c.chain_cancel_targets.has("2D")
		and two_c.special_cancel_targets.has("214C") and two_c.jump_cancel_targets.is_empty(),
		"J0 2C 链式 6D/2D、必杀 214C、无 jump cancel")
	var six_a: MoveData = result.moves["6A"]
	_check(six_a.jump_cancel_targets == ["jA", "jB", "jC"],
		"J0 6A 是唯一专用击飞入口（jump cancel jA/jB/jC）")
	var five_d: MoveData = result.moves["5D"]
	_check(five_d.charge_threshold_frames == 8 and five_d.charge_move_id == "5[D]"
		and five_d.special_entry_link_targets == ["5B"],
		"J0 5D 动作内蓄力→5[D]、来源限定 5B 目押（普通来源不取得）")
	var charged: MoveData = result.moves["5[D]"]
	_check(charged.charge_only and charged.special_entry_link_targets == ["5B"],
		"J0 5[D] charge_only 且与 5D 同款来源限定连接")
	for move_id in ["6D", "2D"]:
		var move: MoveData = result.moves[move_id]
		var exits: Array = move.air_exit_targets
		_check(MoveData.profile_for(move, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL) == null
			and exits == ["jA", "jB", "jC", "j5D", "j6D", "j2D", "j214D"],
			"J0 %s 对空限定（无 grounded 资料）且空中出口全集在位" % move_id)
	for move_id in ["jA", "jB", "jC"]:
		var move: MoveData = result.moves[move_id]
		_check(move.cancel_targets.has("j5D") and move.cancel_targets.has("j6D")
			and move.cancel_targets.has("j2D") and move.cancel_targets.has("j214D"),
			"J0 %s 可取消至三空中 D 系与 j214D" % move_id)
	var j2d: MoveData = result.moves["j2D"]
	_check(j2d.hit_landing_cancel_targets == ["214C"] and j2d.hit_landing_cancel_window_frames == 24,
		"J0 j2D 命中落地取消仅限 214C（窗口 24）")
	var j6d: MoveData = result.moves["j6D"]
	_check(j6d.link_targets == ["5B"] and j6d.hit_landing_cancel_targets.is_empty(),
		"J0 j6D 只走普通落地连接 5B、无落地特权")
	var j5d: MoveData = result.moves["j5D"]
	_check(j5d.cancel_targets.is_empty() and j5d.link_targets.is_empty()
		and not j5d.is_finisher,
		"J0 j5D 收束（无取消、无连接、无收尾标记）")
	var j214d: MoveData = result.moves["j214D"]
	_check(MoveData.profile_for(j214d, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL) != null
		and MoveData.profile_for(j214d, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL) != null
		and MoveData.profile_for(j214d, HitProfile.TargetState.GROUND_BOUNCE, HitProfile.HitContext.NORMAL) == null
		and j214d.link_targets == ["5B", "6A", "214C"],
		"J0 j214D 对地/对空统一弹地资料、不声明弹地目标键、弹地延迟连接 5B/6A/214C")
	for move_id in ["5B", "6A", "214C"]:
		var move: MoveData = result.moves[move_id]
		_check(MoveData.profile_for(move, HitProfile.TargetState.GROUND_BOUNCE, HitProfile.HitContext.NORMAL) != null,
			"J0 %s 持有弹地追击资料" % move_id)
	var rekka: MoveData = result.moves["214C"]
	_check(rekka.rekka_b_target == "214C~B" and rekka.rekka_c_target == "214C~C",
		"J0 214C 首按锁定 ~B/~C 派生")
	var rekka_b: MoveData = result.moves["214C~B"]
	var rekka_c: MoveData = result.moves["214C~C"]
	_check(rekka_b.link_targets == ["5B"] and rekka_c.is_finisher,
		"J0 ~B 延长后普通连接 5B、~C 收尾（is_finisher）")
	# 武器语义呈现规则（设计 §1 家族表）：C/D 系与 6A 出刀；A/B 普通技与投徒手；
	# Rekka 派生是 214C（C 系必杀）的分支，~B 虽按 B 键仍按出刀呈现。
	_check(NativeShapes.is_knife_move("6A", "A") and NativeShapes.is_knife_move("214C~B", "B")
			and NativeShapes.is_knife_move("jC", "C") and NativeShapes.is_knife_move("j214D", "D"),
		"J0 出刀族：6A 与 214C~B（Rekka 分支）及 C/D 键招式按短刀呈现")
	_check(not NativeShapes.is_knife_move("5B", "B") and not NativeShapes.is_knife_move("jB", "B")
			and not NativeShapes.is_knife_move("BC", ""),
		"J0 徒手族：A/B 普通技与 BC 投按徒手呈现")
	print("")


# --- J1：普通地面链（票据 01 路线在联合口径下复验） ---

func _joint_j1_ground_chain(facing: int) -> void:
	print("=== J1 5A>5B>5C>5D 与 5B>5D | 面向 %+d | 间距 %.0f px ===" % [facing, CHAIN_DX])
	var full := _run_route({1: _press("A"), 5: _press("B"), 21: _press("C"), 36: _press("D")},
		facing, 80, "J1a", CHAIN_DX)
	_check(full["moves"] == ["5A", "5B", "5C", "5D"],
		"J1a 基础地面链四击成立 %s | 面向 %+d" % [str(full["moves"]), facing])
	var short := _run_route({1: _press("B"), 10: _press("D")}, facing, 60, "J1b", CHAIN_DX)
	_check(short["moves"] == ["5B", "5D"],
		"J1b 5B>5D 短路线成立 %s | 面向 %+d" % [str(short["moves"]), facing])
	print("")


# --- J2：扫倒与 Rekka 延长（票据 04 目标路线） ---

func _joint_j2_2c_rekka_link(facing: int) -> void:
	print("=== J2 2C>214C(空中)>~B(延长)>5B(目押) | 面向 %+d | 间距 %.0f px ===" % [facing, TOUCH_DX])
	var plan := {
		1: _digit(facing, 2, "C"),
		15: _digit(facing, 2), 16: _digit(facing, 1), 17: _digit(facing, 4),
		19: _press("C"),
		32: _press("B"), 70: _press("B"),
	}
	var run := _run_route(plan, facing, 95, "J2", TOUCH_DX)
	_check(run["moves"] == ["2C", "214C", "214C~B", "5B"],
		"J2 扫倒路线四击成立（低浮空→空中延长→恢复后目押）%s | 面向 %+d" % [str(run["moves"]), facing])
	print("")


# --- J3a：236C 两段 > 5D 特殊进入 > 恢复后普通 5B（票据 05 正例） ---

func _joint_j3a_236c_5d_5b(facing: int) -> void:
	print("=== J3a 236C(两段)>5D(特殊进入)>5B(目押) | 面向 %+d | 间距 %.0f px ===" % [facing, NEAR_DX])
	var plan := {}
	for i in 4:
		plan[1 + i] = _236(i, facing, "C" if i == 3 else "")
	plan[26] = _press("D")
	plan[66] = _press("B")
	var run := _run_route(plan, facing, 110, "J3a", NEAR_DX)
	_check(run["moves"] == ["236C", "236C", "5D", "5B"],
		"J3a 两段命中→特殊进入 D→恢复后目押 5B 四击成立 %s | 面向 %+d" % [str(run["moves"]), facing])
	print("")


# --- J3b：中板 236C > 5[D] 蓄力穿越换边；5B 目押在默认调校下如实失败（待调校） ---

func _joint_j3b_236c_charged_cross(facing: int) -> void:
	print("=== J3b 中板 236C>5[D] 蓄力穿越 | 面向 %+d | 间距 %.0f px ===" % [facing, NEAR_DX])
	var plan := {}
	for i in 4:
		plan[1 + i] = _236(i, facing, "C" if i == 3 else "")
	# 按住 D（F16 按下、保持到 F30）至阈值自动提交蓄力版。
	for frame in range(16, 31):
		plan[frame] = _hold("D", frame, 16, 30)
	plan[70] = _press("B")
	var run := _run_route(plan, facing, 110, "J3b", NEAR_DX)
	var session: CombatSession = run["session"]
	_check(run["moves"] == ["236C", "5[D]", "5B"],
		"J3b 目标三击须在首次 COMBO_ENDED 前完成（基线已知失败，断连后命中另列）%s| 面向 %+d" % [str(run["moves"]), facing])
	_check(run["swaps"] == 1 and session.player_facing == -facing,
		"J3b 实际命中且穿越才换边（换边后面向 %+d）| 面向 %+d" % [session.player_facing, facing])
	print("")


# --- J4：版边普通 5D 墙截断不换边（票据 06 R5 联合复验） ---

func _joint_j4_corner_5d_wall(facing: int) -> void:
	print("=== J4 版边 5D 墙截断 | 面向 %+d ===" % facing)
	var session := CombatSession.new()
	var wall: float = GameParams.stage_right_limit() if facing == 1 else GameParams.stage_left_limit()
	session.player_position = Vector2(wall - 60.0 * facing, GameParams.ground_stand_y())
	session.dummy_position = session.player_position + Vector2(60.0 * facing, 0)
	session.player_facing = facing
	var hit := -1
	var swapped := false
	var wall_clamped := false
	for frame in range(1, 40):
		for event in session.step(FrameInput.make(0, false, "D" if frame == 1 else "")):
			_log_event(frame, "J4", event, session)
			if event.type == CombatEvent.Type.HIT:
				hit = frame
			elif event.type == CombatEvent.Type.SWITCHED_SIDES:
				swapped = true
		wall_clamped = wall_clamped or bool(session.debug_snapshot()["motion_wall_clamped"])
	_check(hit > 0, "J4 版边 5D 命中照常（F%d）| 面向 %+d" % [hit, facing])
	_check(wall_clamped and not swapped and session.player_facing == facing,
		"J4 墙截断可观察、不换边（被墙截断截在原侧）| 面向 %+d" % facing)
	print("")


# --- J5：演示主路线 5A>5B>5C>6A>jc.jB>jC>j2D>214C~C（阶段 6/7/8 串接的完整八击） ---

func _joint_j5_full_demo_route(facing: int) -> void:
	print("=== J5 演示路线 5A>5B>5C>6A>jc.jB>jC>j2D>214C~C | 面向 %+d | 间距 %.0f px ===" % [facing, NEAR_DX])
	var plan := {
		1: _press("A"), 9: _press("B"), 24: _press("C"),
		38: _press("A", false, facing), 39: _axis(facing),
		56: _jump(),
		68: _press("B"),
		76: _press("C"),
		92: _press("D", true),
		109: _214(0, facing), 110: _214(1, facing), 111: _214(2, facing),
		112: _214(3, facing, "C"),
		134: _press("C"),
	}
	var session := _spawn(NEAR_DX, facing)
	var moves: Array[String] = []
	var start_214c := -1
	var land_rec_at_214c := -1
	var started_214cc := false
	var hit_after_end := 0
	var combo_over := false
	var dummy_recovered_frame := -1
	var knockdown_end := false
	for frame in range(1, 190):
		var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
		var move_at_start := session.player_move_id
		for event in session.step(input):
			_log_event(frame, "J5", event, session, move_at_start)
			match event.type:
				CombatEvent.Type.HIT:
					if combo_over:
						hit_after_end += 1
					else:
						moves.append(move_at_start)
				CombatEvent.Type.COMBO_ENDED:
					if event.combo_end_reason == CombatEvent.ComboEndReason.DUMMY_RECOVERED 							and dummy_recovered_frame < 0:
						dummy_recovered_frame = frame
					if event.combo_end_reason == CombatEvent.ComboEndReason.KNOCKDOWN:
						knockdown_end = true
					combo_over = true
		if session.player_move_id == "214C" and move_at_start != "214C":
			start_214c = frame
			land_rec_at_214c = session.player_landing_recovery_left
		if session.player_move_id == "214C~C":
			started_214cc = true
	_check(moves == ["5A", "5B", "5C", "6A", "jB", "jC", "j2D"],
		"J5 连段前缀七击成立（地面链→6A 击飞→jump cancel 空中链→j2D 带落地命中）%s | 面向 %+d" % [str(moves), facing])
	_check(start_214c > 0 and land_rec_at_214c > 0,
		"J5 j2D 命中落地取消在位：214C 于落地恢复中（余 %d）的首个可行动帧起手，L-01 例外跳过其余空技恢复 | 面向 %+d" % [land_rec_at_214c, facing])
	_check(dummy_recovered_frame == start_214c + 7,
		"J5 调校边界如实记录：木桩受身 F%d 比 214C 首个判定帧恰早 1 帧——深连段时间层（≤0.49）下 j2D untech 24→11 覆盖不了落地+前摇，尾部按新连段结算（%d 次收尾命中）| 面向 %+d" % [dummy_recovered_frame, hit_after_end, facing])
	_check(started_214cc and not knockdown_end,
		"J5 ~C 分支仍锁定并起手，但 214C 击退把木桩推出 ~C 触及（距离不足挥空、无倒地收尾）——j2D untech 与 214C 击退两组调校候选随真人试玩裁决 | 面向 %+d" % facing)
	print("")


# --- J6：独立跳 j214D 对地（票据 09 R0 联合复验） ---

func _joint_j6_solo_j214d(facing: int) -> void:
	print("=== J6 独立跳 j214D 对地统一弹地 | 面向 %+d | 间距 %.0f px ===" % [facing, NEAR_DX])
	var plan := {
		2: _jump(),
		10: _214(0, facing), 11: _214(1, facing), 12: _214(2, facing), 13: _214(3, facing, "D"),
	}
	var run := _run_route(plan, facing, 130, "J6", NEAR_DX)
	var session: CombatSession = run["session"]
	_check(run["moves"] == ["j214D"], "J6 独立输入 j214D 命中地面目标 | 面向 %+d" % facing)
	_check(session.dummy_state != CombatSession.DummyState.KNOCKED_DOWN,
		"J6 弹地流程不转普通倒地 | 面向 %+d" % facing)
	print("")


# --- J7：弹地起手差异（B 起手一次性延长 / A 起手收尾，票据 09 R1/R2 联合复验） ---

func _joint_j7_bounce_starters() -> void:
	print("=== J7 弹地 A/B 起手差异 | 面向 +1 ===")
	var b_plan := {
		1: _press("B"), 16: _press("C"),
		30: _press("A", false, 1), 31: _axis(1),
		48: _jump(),
		60: _press("B"),
		70: _214(0, 1), 71: _214(1, 1), 72: _214(2, 1), 73: _214(3, 1, "D"),
		103: _press("A", false, 1),
		124: _jump(),
		132: _press("A"),
	}
	var b_run := _run_route(b_plan, 1, 190, "J7B")
	_check(b_run["moves"] == ["5B", "5C", "6A", "jB", "j214D", "6A", "jA"],
		"J7B B 起手弹地后 6A 消费一次性资格并 jump cancel 延长 %s" % str(b_run["moves"]))
	var a_plan := {
		1: _press("A"), 9: _press("B"), 24: _press("C"),
		38: _press("A", false, 1), 39: _axis(1),
		56: _jump(),
		68: _press("B"),
		78: _214(0, 1), 79: _214(1, 1), 80: _214(2, 1), 81: _214(3, 1, "D"),
		110: _press("B"),
	}
	var a_run := _run_route(a_plan, 1, 160, "J7A")
	_check(a_run["moves"] == ["5A", "5B", "5C", "6A", "jB", "j214D", "5B"],
		"J7A A 起手弹地后 5B 只能收尾 %s" % str(a_run["moves"]))
	_check(_end_seen(a_run, CombatEvent.ComboEndReason.BOUNCE_END),
		"J7A 收尾命中立即 BOUNCE_END（A 起手无追击资格）")
	print("")


# --- J8：空中 D 系落地语义（j2D 例外取消 / j6D 普通连接，票据 08 联合复验） ---

func _prefix_input(frame: int, j_move: String, facing: int) -> FrameInput:
	match frame:
		1:
			return _press("C", true)
		17:
			return _press("D", false, facing)
		35:
			match j_move:
				"j2D":
					return _press("D", true)
				"j6D":
					return _press("D", false, facing)
				_:
					return _press("D")
	return FrameInput.new()


func _joint_j8_air_d_landings(facing: int) -> void:
	print("=== J8 j2D 落地例外与 j6D 普通落地连接 | 面向 %+d | 间距 %.0f px ===" % [facing, NEAR_DX])
	# j2D > 214C：命中落地取消（停顿中缓存、落地首帧锁、首个可行动帧消费）。
	var cancel_plan := {}
	for frame in range(1, 110):
		cancel_plan[frame] = _prefix_input(frame, "j2D", facing)
	for i in 4:
		cancel_plan[49 + i] = _214(i, facing, "C" if i == 3 else "")
	var cancel_run := _run_route(cancel_plan, facing, 110, "J8a", NEAR_DX)
	_check(cancel_run["moves"] == ["2C", "6D", "j2D", "214C"],
		"J8a 2C>6D>j2D>214C 四击成立（专用落地取消）%s | 面向 %+d" % [str(cancel_run["moves"]), facing])
	# j6D > 5B：普通落地恢复（3+1）后的首个合法帧延迟普通连接。
	var link_plan := {}
	for frame in range(1, 110):
		link_plan[frame] = _prefix_input(frame, "j6D", facing)
	link_plan[57] = _press("B")
	var link_run := _run_route(link_plan, facing, 110, "J8b", NEAR_DX)
	_check(link_run["moves"] == ["2C", "6D", "j6D", "5B"],
		"J8b 2C>6D>j6D>5B 四击成立（无落地特权、普通连接）%s | 面向 %+d" % [str(link_run["moves"]), facing])
	print("")


# --- N1a：被防 6A 无 jump cancel（挥空/被防不进空中追击） ---

func _negative_n1a_blocked_6a_no_jump_cancel() -> void:
	print("=== N1a 被防 6A 无 jump cancel | 面向 +1 | 站防木桩 ===")
	var session := _spawn(NEAR_DX, 1)
	var blocked := 0
	var took_off := false
	var was_airborne := false
	for frame in range(1, 70):
		var input := FrameInput.new()
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		match frame:
			1:
				input = _press("A", false, 1)
				input.dummy_guard_request = CombatSession.GuardPosture.STANDING
			2:
				input = _axis(1)
				input.dummy_guard_request = CombatSession.GuardPosture.STANDING
			14:
				input.jump_pressed = true
				input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		var on_ground_before := session.player_on_ground
		for event in session.step(input):
			_log_event(frame, "N1a", event, session)
			if event.type == CombatEvent.Type.ATTACK_BLOCKED:
				blocked += 1
		if not on_ground_before:
			was_airborne = true
		if was_airborne and not session.player_on_ground:
			took_off = true
	_check(blocked == 1, "N1a 6A 被站防挡下（独立被防接触）")
	_check(not was_airborne and not took_off and session.player_on_ground,
		"N1a 被防不授予 jump cancel：Space 不起跳（player_on_ground=%s）" % session.player_on_ground)
	print("")


# --- N1b：236C 段 1 被防立即终止且无 5D 特殊进入 ---

func _negative_n1b_blocked_236c_no_entry() -> void:
	print("=== N1b 段 1 被防终止 + 无特殊进入 | 面向 +1 | 站防木桩 ===")
	var session := _spawn(NEAR_DX, 1)
	var blocked_236c := 0
	var blocked_5d := 0
	var hits := 0
	var five_d_via_entry := false
	var five_d_start := -1
	for frame in range(1, 70):
		var input: FrameInput
		if frame <= 4:
			input = _236(frame - 1, 1, "C" if frame == 4 else "")
		elif frame == 30:
			input = _press("D")
		else:
			input = FrameInput.new()
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		var move_before := session.player_move_id
		for event in session.step(input):
			_log_event(frame, "N1b", event, session, move_before)
			if event.type == CombatEvent.Type.HIT:
				hits += 1
			elif event.type == CombatEvent.Type.ATTACK_BLOCKED:
				if move_before == "236C":
					blocked_236c += 1
				else:
					blocked_5d += 1
		if session.player_move_id == "5D" and move_before != "5D":
			five_d_start = frame
			five_d_via_entry = bool(session.debug_snapshot().get("move_via_special_entry", false))
	_check(blocked_236c == 1 and hits == 0,
		"N1b 段 1 被防：整招立即结束（无段 2 接触、无任何命中；被防 236C 段数=%d）" % blocked_236c)
	_check(five_d_start == 30 and not five_d_via_entry and blocked_5d == 1,
		"N1b 被防不授予特殊进入：窗口内按 D 起手的是恢复后独立普通 5D（F%d，非经资格），照常被防" % five_d_start)
	print("")


# --- N2：挥空无取消资格（射程外首击后链式键只能独立起手） ---

func _negative_n2_whiff_no_cancel() -> void:
	print("=== N2 挥空无取消 | 面向 +1 | 木桩 240 px（射程外） ===")
	var session := _spawn(240.0, 1)
	var hits := 0
	var link_rejected := false
	var b_during_recovery := false
	var b_fresh_start := -1
	for frame in range(1, 60):
		var key := "A" if frame == 1 else ("B" if frame == 16 or frame == 24 else "")
		var move_before := session.player_move_id
		for event in session.step(FrameInput.make(0, false, key)):
			_log_event(frame, "N2", event, session, move_before)
			if event.type == CombatEvent.Type.HIT:
				hits += 1
			elif event.type == CombatEvent.Type.LINK_FAILED and event.link_move_id == "5B":
				link_rejected = true
		if session.player_move_id == "5B" and move_before != "5B":
			if frame < 20:
				b_during_recovery = true
			else:
				b_fresh_start = frame
	_check(hits == 0, "N2 射程外全程零命中（挥空）")
	_check(link_rejected and not b_during_recovery,
		"N2 挥空不产生取消资格：恢复中按 B 的链式请求被可观察拒绝（LINK_FAILED），不冒充接续")
	_check(b_fresh_start >= 20, "N2 完全收招后的新按下才作为独立招式起手（F%d）" % b_fresh_start)
	print("")


# --- N3：普通 5D 无反向 5B 出口（来源资格不泄漏，票据 05 N4 联合复验） ---

func _negative_n3_plain_5d_no_reverse_link() -> void:
	print("=== N3 普通 5D>5B 无反向出口 | 面向 +1 | 间距 %.0f px ===" % NEAR_DX)
	var run := _run_route({1: _press("A"), 5: _press("B"), 21: _press("D"), 38: _press("B")},
		1, 70, "N3", NEAR_DX)
	_check(run["moves"] == ["5A", "5B", "5D"] and not run["session"].combo_active,
		"N3 普通来源 5D 后目押 5B 不成立（不取得来源限定连接；本例按木桩自然受身结束——未声明边的 CONFIGURATION_GAP 断言在 test_combat_session 注入探针覆盖）%s" % str(run["moves"]))
	print("")


# --- N4：2C 低浮空下 2D 高度失配（票据 07 R3a 联合复验） ---

func _negative_n4_2c_2d_height_miss() -> void:
	print("=== N4 2C>2D 高度失配挥空 | 面向 +1 | 间距 %.0f px ===" % NEAR_DX)
	var run := _run_route({1: _press("C", true), 17: _press("D", true)}, 1, 90, "N4", NEAR_DX)
	_check(run["moves"] == ["2C"],
		"N4 2C 命中后 2D 因判定高度不匹配挥空（低浮空峰值够不到高位框）%s" % str(run["moves"]))
	var session: CombatSession = run["session"]
	_check(not session.combo_active, "N4 挥空后连段按取消窗关闭结束（允许取消 ≠ 来得及命中）")
	print("")


# --- N5：A 起手弹地收尾（票据 09 R1 的联合负例复验，双面向已由 J7A 覆盖 +1） ---

func _negative_n5_a_starter_bounce_ender() -> void:
	print("=== N5 A 起手弹地循环边界 | 面向 +1 ===")
	var plan := {
		1: _press("A"), 9: _press("B"), 24: _press("C"),
		38: _press("A", false, 1), 39: _axis(1),
		56: _jump(),
		68: _press("B"),
		78: _214(0, 1), 79: _214(1, 1), 80: _214(2, 1), 81: _214(3, 1, "D"),
		110: _press("B"),
	}
	var run := _run_route(plan, 1, 160, "N5")
	_check(_end_seen(run, CombatEvent.ComboEndReason.BOUNCE_END) and not run["session"].combo_active,
		"N5 A 起手弹地后新命中立即收尾、不形成弹地循环（A 起手追击资格=0）")
	print("")


# --- J3c：段 1 挥空 > 段 2 命中 > 5[D] 蓄力捞起（远距 93px 正例，票据 06 R4 联合复验） ---

func _joint_j3c_seg2_charged_pickup(facing: int) -> void:
	print("=== J3c 段1挥空>段2>slide>5[D] 蓄力捞起 | 面向 %+d | 间距 %.0f px（远距） ===" % [facing, SLIDE_DX])
	var plan := {}
	for i in 4:
		plan[1 + i] = _236(i, facing, "C" if i == 3 else "")
	for frame in range(30, 45):
		plan[frame] = _hold("D", frame, 30, 44)
	var run := _run_route(plan, facing, 110, "J3c", SLIDE_DX)
	var session: CombatSession = run["session"]
	_check(run["moves"] == ["236C", "5[D]"],
		"J3c 段 1 挥空（触及 91px 内）> 段 2 命中（97px 边界内、远距正例）> 蓄力 5[D] 以 slide 资料捞起 %s | 面向 %+d" % [str(run["moves"]), facing])
	_check(session.dummy_state != CombatSession.DummyState.KNOCKED_DOWN and not session.combo_active,
		"J3c 捞起流程走完不伪造倒地（slide 是有限状态、不是 OTG）| 面向 %+d" % facing)
	print("")


# --- J6b：jC > j214D 对空中目标（字面路线：jC 是稳定进入 j214D 的最低等级） ---
# 对地变体的实测边界：独立跳的 jC 只在下落段（触地前约 8 帧）够得着地面目标，
# 其停顿+9 帧前摇在剩余滞空内装不下（探针 probe_j6b4：j214D F49 起手、F53
# 落地中断）——对地统一弹地由独立输入 j214D 承担（J6），jC 入口对地属
# 空中预算边界、随调校复验（frame-data v0.12 记录）。

func _joint_j6b_jc_into_j214d_grounded(facing: int) -> void:
	print("=== J6b 5A>5B>5C>6A>jc.jB>jC>j214D（对空目标）| 面向 %+d | 间距 %.0f px ===" % [facing, NEAR_DX])
	var plan := {
		1: _press("A"), 9: _press("B"), 24: _press("C"),
		38: _press("A", false, facing), 39: _axis(facing),
		56: _jump(),
		68: _press("B"),
		76: _press("C"),
		92: _214(0, facing), 93: _214(1, facing), 94: _214(2, facing), 95: _214(3, facing, "D"),
	}
	var run := _run_route(plan, facing, 160, "J6b", NEAR_DX)
	var session: CombatSession = run["session"]
	_check(run["moves"] == ["5A", "5B", "5C", "6A", "jB", "jC", "j214D"],
		"J6b jC 命中空中目标后取消进 j214D、统一弹地成立（七击）%s | 面向 %+d" % [str(run["moves"]), facing])
	var move_recovered := false
	for end in run["ends"]:
		if end["reason"] == CombatEvent.ComboEndReason.MOVE_RECOVERED:
			move_recovered = true
	_check(move_recovered,
		"J6b 无追击输入：弹地流程独立走完、连段按收招未接续结束（A 起手追击资格=0——5A 首击锁定；N5 为其命中即收尾对照）| 面向 %+d" % facing)
	print("")


# --- N6：挥空 j2D 无落地特权（挥空只承担落地恢复，214C 不经例外消费） ---

func _negative_n6_whiffed_j2d_no_landing_cancel(facing: int) -> void:
	print("=== N6 挥空 j2D 无落地取消 | 面向 %+d | 木桩 240px（射程外） ===" % facing)
	var session := _spawn(240.0, facing)
	var hits := 0
	var exception_open := false
	var started_214c := -1
	var landed_frame := -1
	var was_airborne := false
	for frame in range(1, 120):
		var input := FrameInput.new()
		if frame == 1:
			input.jump_pressed = true
		elif frame == 14:
			input = _press("D", true)
		elif frame >= 30 and frame <= 33:
			input = _214(frame - 30, facing, "C" if frame == 33 else "")
		var move_before := session.player_move_id
		var on_ground_before := session.player_on_ground
		for event in session.step(input):
			_log_event(frame, "N6", event, session, move_before)
			if event.type == CombatEvent.Type.HIT:
				hits += 1
		if not on_ground_before:
			was_airborne = true
		if was_airborne and session.player_on_ground and landed_frame < 0:
			landed_frame = frame
		if bool(session.debug_snapshot().get("hit_landing_cancel_open", false)):
			exception_open = true
		if session.player_move_id == "214C" and move_before != "214C":
			started_214c = frame
	_check(hits == 0, "N6 射程外全程零命中（j2D 挥空）")
	_check(not exception_open, "N6 挥空 j2D 不授予命中落地取消资格（资格仅实际 HIT 授予）")
	_check(started_214c < 0 or started_214c >= landed_frame + 7,
		"N6 挥空路径的 214C 只能等完整落地恢复（3+1+2+缓存）后的独立起手（落地 F%d、起手 F%d）——无例外消费" % [landed_frame, started_214c])
	print("")
