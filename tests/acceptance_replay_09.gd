extends SceneTree
## 票据 09 验收回放（连段路线票据 01 修订）：j214D 统一 GROUND_BOUNCE、跨状态
## 修正与 A/B 起手接续边界。票据 01 撤销按起手等级的一次性弹地资格与
## BOUNCE_END 强制终点：R1 改为 A 起手弹地命中自然接续至自然受身；R2 B 起手
## 6A 追击 + jc.jA 延长语义不变（不再消费资格）；N3 改为追击命中不重置三层
## 修正（原「资格不刷新」断言随规则撤销重写）。帧表按 12×20 尺度与
## jC 4/j214D 1 选值重新校准。修正观测随命中行打印（起手等级与三层累计）。
## 历史证据归档 acceptance/09/（replay-bounce.log，旧规则口径）。
## 运行：godot --headless --path . -s res://tests/acceptance_replay_09.gd

## 连段路线票据 01（12×20 尺度）：近距 26px（g14；原 50px 为 48 宽身体的 g2）。
const NEAR_DX := 26.0

var _failures := 0


func _initialize() -> void:
	_replay_r0_solo_j214d(1)
	_replay_r0_solo_j214d(-1)
	_replay_r1_a_starter_ender(1)
	_replay_r1_a_starter_ender(-1)
	_replay_r2_b_starter_extension(1)
	_replay_r2_b_starter_extension(-1)
	_replay_n1_bounce_not_otg()
	_replay_n2_expired_input_boundary()
	_replay_n3_followup_not_refreshed()
	_replay_n4_second_j214d_profile_gate()
	print("")
	if _failures == 0:
		print("ALL REPLAY 09 CHECKS PASSED")
		quit(0)
	else:
		print(str(_failures) + " REPLAY 09 CHECK(S) FAILED")
		quit(1)


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


## 空中 214 指令逐帧输入（相对面向）：step 0=下(2)、1=下后(1)、2+=后(4)，step 3 按 D。
func _air214d(step: int, facing: int) -> FrameInput:
	var input := FrameInput.new()
	match step:
		0:
			input.down_held = true
		1:
			input.down_held = true
			input.move_axis = -facing
		_:
			input.move_axis = -facing
	if step == 3:
		input.pressed_action_keys = ["D"]
		input.held_action_keys = ["D"]
	return input


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		_failures += 1
		print("  FAIL  " + label)


func _grade_label(grade: MoveData.StarterGrade) -> String:
	match grade:
		MoveData.StarterGrade.A:
			return "A"
		MoveData.StarterGrade.B:
			return "B"
		MoveData.StarterGrade.C:
			return "C"
		MoveData.StarterGrade.D:
			return "D"
	return "-"


func _log_event(frame: int, tag: String, event: CombatEvent, session: CombatSession) -> void:
	match event.type:
		CombatEvent.Type.HIT:
			print("  F%-3d %s HIT seg%d 伤%.1f 第%d击 %s | %s起手 修正 伤%.3f/时%.3f/轨%.3f 弹地窗%d | 木桩y=%.1f" % [
				frame, tag, event.move_segment, event.damage, event.combo_hits, session.player_move_id,
				_grade_label(session.combo_starter_grade), session.combo_damage_scale,
				session.combo_time_scale, session.combo_trajectory_scale,
				session.dummy_bounce_left, session.dummy_position.y])
		CombatEvent.Type.HIT_MISS:
			print("  F%-3d %s HIT_MISS %s（无匹配资料：不造成受击、不取得取消资格）" % [
				frame, tag, session.player_move_id])
		CombatEvent.Type.BOUNCE_CONTACT:
			print("  F%-3d %s BOUNCE_CONTACT 反弹vy=%.0f 追击窗%d（自下一正常帧倒数）" % [
				frame, tag, session.dummy_velocity.y, session.dummy_bounce_left])
		CombatEvent.Type.COMBO_ENDED:
			print("  F%-3d %s COMBO_ENDED 原因%d" % [frame, tag, event.combo_end_reason])
		CombatEvent.Type.LINK_FAILED:
			print("  F%-3d %s LINK_FAILED 原因%d %s" % [frame, tag, event.link_fail_reason, event.link_move_id])
		CombatEvent.Type.DUMMY_RECOVERED:
			print("  F%-3d %s DUMMY_RECOVERED 木桩状态=%d" % [frame, tag, session.dummy_state])


## 通用运行器：记录命中招式序列、弹地触点帧与结束原因。
func _run_route(plan: Dictionary, facing: int, horizon: int, tag: String, dx := NEAR_DX) -> Dictionary:
	var session := _spawn(dx, facing)
	var moves: Array[String] = []
	var ends: Array[Dictionary] = []
	var contacts: Array[int] = []
	for frame in range(1, horizon + 1):
		var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
		var move_at_start := session.player_move_id
		for event in session.step(input):
			_log_event(frame, tag, event, session)
			match event.type:
				CombatEvent.Type.HIT:
					moves.append(move_at_start)
				CombatEvent.Type.BOUNCE_CONTACT:
					contacts.append(frame)
				CombatEvent.Type.COMBO_ENDED:
					ends.append({"frame": frame, "reason": event.combo_end_reason})
				CombatEvent.Type.LINK_FAILED:
					ends.append({"frame": frame, "reason": -1, "link_fail": event.link_fail_reason,
						"link_move": event.link_move_id})
	return {"session": session, "moves": moves, "ends": ends, "contacts": contacts}


# --- R0：独立输入——中立跳 + 空中 214D，对地面木桩统一弹地 ---

func _replay_r0_solo_j214d(facing: int) -> void:
	print("=== R0 独立跳 j214D 对地 | 面向 %+d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	var plan := {
		2: _jump(),
		10: _air214d(0, facing), 11: _air214d(1, facing), 12: _air214d(2, facing), 13: _air214d(3, facing),
	}
	var run := _run_route(plan, facing, 130, "R0")
	var session: CombatSession = run["session"]
	_check(run["moves"] == ["j214D"], "R0 独立输入 j214D 命中地面目标 | 面向 %+d" % facing)
	_check(run["contacts"].size() == 1, "R0 恰一次 bounce_contact（一次弹地至多一次反弹）| 面向 %+d" % facing)
	_check(session.dummy_state != CombatSession.DummyState.KNOCKED_DOWN,
		"R0 弹地流程不转普通倒地（不接受 OTG）| 面向 %+d" % facing)
	var end_move_recovered := false
	for end in run["ends"]:
		if end["reason"] == CombatEvent.ComboEndReason.MOVE_RECOVERED:
			end_move_recovered = true
	_check(end_move_recovered, "R0 无追击输入时连段按收招未接续结束、弹地流程独立走完 | 面向 %+d" % facing)
	print("")


# --- R1：A 起手 juggle → j214D → 弹地后 5B 只能收尾 ---

func _replay_r1_a_starter_ender(facing: int) -> void:
	print("=== R1 A起手 juggle>j214D>弹地5B 自然接续 | 面向 %+d | 间距 %.0f px ===" % [facing, NEAR_DX])
	## 票据 01：A 起手弹地目标上的 5B 不再强制结束（BOUNCE_END 已撤销）——
	## 命中按弹地资料结算并自然接续，直至木桩自然受身。5B 的弹地目押窗为 1F
	##（D72 允许；B@F99 与触地 F100 的组合等待/缓存年龄共同决定）。
	var plan := {
		1: _press("A"), 9: _press("B"),
		24: _press("A", false, facing), 25: _axis(facing),
		48: _jump(),
		58: _press("C"),
		78: _air214d(0, facing), 79: _air214d(1, facing), 80: _air214d(2, facing), 81: _air214d(3, facing),
		99: _press("B"),
	}
	var run := _run_route(plan, facing, 200, "R1")
	var moves: Array[String] = run["moves"]
	var session: CombatSession = run["session"]
	_check(moves == ["5A", "5B", "6A", "jC", "j214D", "5B"],
		"R1 A起手六击成立：juggle 至 j214D 弹地、落地 5B 按弹地资料命中 %s | 面向 %+d" % [str(moves), facing])
	var b_hit_frame := -1
	var first_end_after := -1
	var recovered := false
	for hit in run["hits"]:
		if int(hit.get("hits", 0)) == 6:
			b_hit_frame = int(hit["frame"])
	for end in run["ends"]:
		if b_hit_frame > 0 and int(end.get("frame", -1)) > b_hit_frame:
			if first_end_after < 0:
				first_end_after = int(end["frame"])
			if end.get("reason", -1) == CombatEvent.ComboEndReason.DUMMY_RECOVERED:
				recovered = true
	_check(first_end_after > b_hit_frame,
		"R1 弹地目标命中不再当帧结束连段（首末 F%d > 命中 F%d）| 面向 %+d" % [first_end_after, b_hit_frame, facing])
	_check(recovered and not session.combo_active,
		"R1 连段自然接续至木桩自然受身（无强制终点）| 面向 %+d" % facing)
	print("")


# --- R2：B 起手 juggle → j214D → 6A 追击（消费资格）→ jc.jA 延长 ---

func _b6_plan(facing: int) -> Dictionary:
	## 帧表按 12×20 尺度 + jC 4/j214D 1 校准（与 test_bounce_corrections 同源）。
	return {
		1: _press("B"), 16: _press("C"),
		30: _press("A", false, facing), 31: _axis(facing),
		48: _jump(),
		62: _press("B"),
		76: _air214d(0, facing), 77: _air214d(1, facing), 78: _air214d(2, facing), 79: _air214d(3, facing),
		105: _press("A", false, facing),
		126: _jump(),
		136: _press("A"),
	}


func _replay_r2_b_starter_extension(facing: int) -> void:
	print("=== R2 B起手 5B>5C>6A>jc.jB>j214D>6A>jc.jA（弹地追击延长）| 面向 %+d | 间距 %.0f px ===" % [facing, NEAR_DX])
	var run := _run_route(_b6_plan(facing), facing, 190, "R2")
	var moves: Array[String] = run["moves"]
	var session: CombatSession = run["session"]
	_check(moves == ["5B", "5C", "6A", "jB", "j214D", "6A", "jA"],
		"R2 B起手七击：弹地后 6A 追击、jump cancel jA 真实延长 %s | 面向 %+d" % [str(moves), facing])
	_check(session.combo_starter_grade == MoveData.StarterGrade.B or not session.combo_active,
		"R2 起手等级 B 全程锁定（跨浮空/弹地/落地不重置）| 面向 %+d" % facing)
	_check(run["contacts"].size() == 1,
		"R2 一次弹地触点（无资格消费语义；接续由窗口/资料/修正与时空决定）| 面向 %+d" % facing)
	print("")


# --- N1：弹地不是 OTG——独立起手打不中弹地目标 ---

func _replay_n1_bounce_not_otg() -> void:
	print("=== N1 弹地目标与独立攻击（非 OTG）| 面向 +1 ===")
	var plan := _b6_plan(1)
	plan.erase(105)
	plan.erase(126)
	plan.erase(136)
	plan[98] = _press("A")
	var run := _run_route(plan, 1, 170, "N1")
	var session: CombatSession = run["session"]
	_check(run["moves"] == ["5B", "5C", "6A", "jB", "j214D"],
		"N1 弹地窗口内独立 5A 不产生任何命中 %s" % str(run["moves"]))
	_check(run["contacts"].size() == 1 and session.dummy_state != CombatSession.DummyState.KNOCKED_DOWN,
		"N1 弹地流程保持单触点、不转倒地（无 OTG 语义）")
	print("")


# --- N2：A 起手过早输入——允许的目押窗口前过期，不伪造追击 ---

func _replay_n2_expired_input_boundary() -> void:
	print("=== N2 A起手过早输入边界 | 面向 +1 ===")
	var plan := {
		1: _press("A"), 9: _press("B"),
		24: _press("A", false, 1), 25: _axis(1),
		48: _jump(),
		58: _press("C"),
		71: _air214d(0, 1), 72: _air214d(1, 1), 73: _air214d(2, 1), 74: _air214d(3, 1),
		92: _press("B"),
	}
	var run := _run_route(plan, 1, 160, "N2")
	_check(run["moves"] == ["5A", "5B", "6A", "jC", "j214D"],
		"N2 过早按下在弹地开窗前过期：追击招不起手、不伪造命中 %s" % str(run["moves"]))
	var move_recovered := false
	for end in run["ends"]:
		if end["reason"] == CombatEvent.ComboEndReason.MOVE_RECOVERED:
			move_recovered = true
	_check(move_recovered and run["contacts"].size() == 1,
		"N2 连段按收招未接续结束，弹地流程照常走完（允许取消 ≠ 来不及命中）")
	print("")


# --- N3：弹地追击命中不重置三层修正（资格语义撤销后重写） ---

func _replay_n3_followup_not_refreshed() -> void:
	print("=== N3 弹地追击修正不重置（资格不随命中刷新→修正只降不升）| 面向 +1 ===")
	var session := _spawn(NEAR_DX, 1)
	var plan := _b6_plan(1)
	var scales: Array[float] = []
	var bounce_pursuit_seen := false
	for frame in range(1, 190):
		var input: FrameInput = plan[frame] if plan.has(frame) else FrameInput.new()
		for event in session.step(input):
			_log_event(frame, "N3", event, session)
			if event.type == CombatEvent.Type.HIT:
				scales.append(session.combo_time_scale)
				if event.combo_hits == 6:
					bounce_pursuit_seen = true
	var monotone := true
	for i in range(1, scales.size()):
		if scales[i] > scales[i - 1] + 0.0001:
			monotone = false
	_check(bounce_pursuit_seen and scales.size() == 7 and monotone,
		"N3 弹地追击（第 6 击）及其后命中不重置/刷新三层修正（时间层只降不升，七击单调）")
	print("")


# --- N4：第二次 j214D 对弹地目标——资料门负例 ---

func _replay_n4_second_j214d_profile_gate() -> void:
	print("=== N4 第二次 j214D 资料门 | 表级断言 ===")
	var result := MoveTable.load_default()
	_check(result.ok, "N4 共享表加载")
	if not result.ok:
		return
	var j214d := result.moves["j214D"] as MoveData
	_check(MoveData.profile_for(j214d, HitProfile.TargetState.GROUND_BOUNCE, HitProfile.HitContext.NORMAL) == null
		and MoveData.profile_for(j214d, HitProfile.TargetState.GROUND_BOUNCE, HitProfile.HitContext.COUNTER) == null,
		"N4 j214D 不声明弹地目标键：第二次 j214D 对弹地目标按 MISS_NO_PROFILE 断链（精确匹配不回退）")
	## 结构性不可达：能命中弹地目标的只有 5B/6A/214C（弹地键），它们的命中把目标
	## 带离 GROUND_BOUNCE（LAUNCH），不存在任何配置边把 j214D 接到仍在弹地的目标上。
	var bounce_hitters := []
	for move_id in result.moves:
		var move := result.moves[move_id] as MoveData
		if MoveData.profile_for(move, HitProfile.TargetState.GROUND_BOUNCE, HitProfile.HitContext.NORMAL) != null:
			bounce_hitters.append(move_id)
	_check(bounce_hitters == ["5B", "6A", "214C"],
		"N4 弹地追击资料仅 5B/6A/214C 持有，追击命中即离开弹地状态——第二次弹地结构上不可达 %s" % str(bounce_hitters))
	print("")
