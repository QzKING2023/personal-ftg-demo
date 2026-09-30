extends SceneTree
## 票据 08 验收回放：j5D 收束、j6D 普通落地恢复后的普通连接、j2D 实际命中后
## 仅限 214C 的专用落地取消（L-01）。覆盖：R1 j2D>214C 例外全帧序（双面向，
## Hitstop 中输入）；R1b 落地当帧输入（记录但不消费）；R2 j6D 命中>恢复>5B
## 延迟普通连接（双面向）；R3 j5D 收束与挥空落地恢复（双面向）；R4 反例组
## （挥空/命中前预存/被防/非法目标/j6D 不借例外）；R5 jc 路线出口 jB>j5D；
## R6 j2D 对地目标（地空目标差异）。
## 运行：godot --headless --path . -s res://tests/acceptance_replay_08.gd
## 证据归档 acceptance/08/（replay-routes.log）。

const NEAR_DX := 50.0

var _failures := 0


func _initialize() -> void:
	_replay_r1_j2d_landing_cancel(1)
	_replay_r1_j2d_landing_cancel(-1)
	_replay_r1b_landing_frame_input(1)
	_replay_r2_j6d_normal_recovery_link(1)
	_replay_r2_j6d_normal_recovery_link(-1)
	_replay_r3_j5d_closer(1)
	_replay_r3_j5d_closer(-1)
	_replay_r4_negatives()
	_replay_r5_jc_jb_into_j5d(1)
	_replay_r5_jc_jb_into_j5d(-1)
	_replay_r6_j2d_grounded_target(1)
	print("")
	if _failures == 0:
		print("ALL REPLAY 08 CHECKS PASSED")
		quit(0)
	else:
		print(str(_failures) + " REPLAY 08 CHECK(S) FAILED")
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


## 214 指令逐帧输入（相对面向）：step 0=下(2)、1=下后(1)、2+=后(4)，step 3 按 C。
func _214(step: int, facing: int) -> FrameInput:
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
		input.pressed_action_keys = ["C"]
		input.held_action_keys = ["C"]
	return input


## 236 指令逐帧输入（相对面向）：step 0=下(2)、1=下前(3)、2+=前(6)，step 3 按 C。
func _236(step: int, facing: int) -> FrameInput:
	var input := FrameInput.new()
	match step:
		0:
			input.down_held = true
		1:
			input.down_held = true
			input.move_axis = facing
		_:
			input.move_axis = facing
	if step == 3:
		input.pressed_action_keys = ["C"]
		input.held_action_keys = ["C"]
	return input


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  PASS  " + label)
	else:
		_failures += 1
		print("  FAIL  " + label)


func _log_event(frame: int, tag: String, event: CombatEvent, session: CombatSession) -> void:
	match event.type:
		CombatEvent.Type.HIT:
			print("  F%-3d %s HIT seg%d 伤%.1f 第%d击 %s 玩家y=%.1f 木桩y=%.1f" % [
				frame, tag, event.move_segment, event.damage, event.combo_hits, session.player_move_id,
				session.player_position.y, session.dummy_position.y])
		CombatEvent.Type.ATTACK_BLOCKED:
			print("  F%-3d %s ATTACK_BLOCKED 姿态%d" % [frame, tag, event.guard_posture])
		CombatEvent.Type.COMBO_ENDED:
			print("  F%-3d %s COMBO_ENDED 原因%d" % [frame, tag, event.combo_end_reason])
		CombatEvent.Type.LINK_FAILED:
			print("  F%-3d %s LINK_FAILED 原因%d %s" % [frame, tag, event.link_fail_reason, event.link_move_id])
		CombatEvent.Type.DUMMY_RECOVERED:
			print("  F%-3d %s DUMMY_RECOVERED" % [frame, tag])
		CombatEvent.Type.HITSTOP_ENDED:
			print("  F%-3d %s HITSTOP_ENDED（恢复首个正常帧）" % [frame, tag])


## 空中 D 系进入前缀：2C@F1 命中 F13；6D 停顿中 F17 按下、F22 起手、F31 命中；
## 出口键 6D 停顿中 F35 按下、F40 空中起手。返回逐帧输入（可被 extra 覆盖追加）。
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


## 通用路线运行：记录命中/起手/结束/落地帧与落地当帧状态。
func _run_route(dx: float, facing: int, j_move: String, extra := {}, horizon := 110) -> Dictionary:
	var session := _spawn(dx, facing)
	var hits: Array[Dictionary] = []
	var starts: Array[Dictionary] = []
	var ends: Array[Dictionary] = []
	var landed_frame := -1
	var landing_move_id := "#unset"
	var was_airborne := false
	for frame in range(1, horizon):
		var input := _prefix_input(frame, j_move, facing)
		if extra.has(frame):
			var e: FrameInput = extra[frame]
			if input.pressed_action_keys.is_empty() and input.move_axis == 0 and not input.down_held:
				input = e
			else:
				for key in e.pressed_action_keys:
					if not input.pressed_action_keys.has(key):
						input.pressed_action_keys.append(key)
						input.held_action_keys.append(key)
				input.move_axis = e.move_axis
				input.down_held = input.down_held or e.down_held
		var move_at_start := session.player_move_id
		var on_ground_before := session.player_on_ground
		for event in session.step(input):
			_log_event(frame, "RT", event, session)
			match event.type:
				CombatEvent.Type.HIT:
					hits.append({"frame": frame, "move": move_at_start, "dummy_air": not session.dummy_on_ground})
				CombatEvent.Type.ATTACK_BLOCKED:
					hits.append({"frame": frame, "move": move_at_start, "blocked": true})
				CombatEvent.Type.COMBO_ENDED:
					ends.append({"frame": frame, "reason": event.combo_end_reason})
		if session.player_move_id != move_at_start and session.player_move_id != "":
			starts.append({"frame": frame, "move": session.player_move_id})
			print("  F%-3d RT START %s（落地恢复余 %d）" % [frame, session.player_move_id, session.player_landing_recovery_left])
		if not on_ground_before:
			was_airborne = true
		if was_airborne and session.player_on_ground and landed_frame < 0:
			landed_frame = frame
			landing_move_id = session.player_move_id
	return {
		"session": session, "hits": hits, "starts": starts, "ends": ends,
		"landed_frame": landed_frame, "landing_move_id": landing_move_id,
	}


# --- R1：j2D 命中 > Hitstop 输入 214C > 落地首帧锁定 > 首个可行动帧 214C ---

func _replay_r1_j2d_landing_cancel(facing: int) -> void:
	print("=== R1 2C>6D>j2D>214C（L-01 例外全帧序）| 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	var extra := {
		49: _214(0, facing), 50: _214(1, facing), 51: _214(2, facing), 52: _214(3, facing),
	}
	var run := _run_route(NEAR_DX, facing, "j2D", extra)
	var hit_moves: Array[String] = []
	for hit in run["hits"]:
		hit_moves.append(hit["move"])
	var start_214c := -1
	for start in run["starts"]:
		if start["move"] == "214C":
			start_214c = start["frame"]
	var landed: int = run["landed_frame"]
	_check(hit_moves == ["2C", "6D", "j2D", "214C"], "R1 路线四击成立 %s" % str(hit_moves))
	_check(String(run["landing_move_id"]) == "", "R1 落地当帧（F%d）无新招：首帧锁保持" % landed)
	_check(start_214c == landed + 9, "R1 214C 于落地后首个正常帧 F%d 消费（停顿冻结 F%d–F%d，正常恢复要到 F%d）" % [
		start_214c, landed + 1, landed + 8, landed + 9 + 5])
	_check(run["session"].combo_hits == 4, "R1 例外消费延续同一连段（第 4 击 214C）")
	print("")


## R1b：214C 于落地当帧按下（落地晚于命中的几何：独立跳 j2D 命中 F24、落地
## F36）——落地首帧记录但不消费，下一正常帧（F37）消费。
func _replay_r1b_landing_frame_input(facing: int) -> void:
	print("=== R1b 落地当帧输入 214C（记录但不消费）| 面向 %d ===" % facing)
	var session := _spawn(NEAR_DX, facing)
	var start_214c := -1
	var landed := -1
	var was_air := false
	for frame in range(1, 90):
		var input := FrameInput.new()
		match frame:
			1: input.jump_pressed = true
			14: input = _press("D", true)
			33: input = _214(0, facing)
			34: input = _214(1, facing)
			35: input = _214(2, facing)
			36: input = _214(3, facing)
		var move_at_start := session.player_move_id
		var on_ground_before := session.player_on_ground
		for event in session.step(input):
			_log_event(frame, "R1b", event, session)
		if session.player_move_id == "214C" and move_at_start != "214C":
			start_214c = frame
		if not on_ground_before:
			was_air = true
		if was_air and session.player_on_ground and landed < 0:
			landed = frame
	_check(start_214c == landed + 1, "R1b 落地当帧（F%d）按下的 214C 记录但不消费，落地后首个正常帧 F%d 消费" % [landed, start_214c])
	_check(session.combo_hits == 2, "R1b 连段延续到 214C（第 %d 击）" % session.combo_hits)
	print("")


# --- R2：j6D 命中 > 普通落地恢复 > 恢复后普通连接 5B ---

func _replay_r2_j6d_normal_recovery_link(facing: int) -> void:
	print("=== R2 2C>6D>j6D>5B（普通落地恢复 + 延迟普通连接）| 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	var run := _run_route(NEAR_DX, facing, "j6D", {57: _press("B")})
	var hit_moves: Array[String] = []
	var hit_frames: Array[int] = []
	for hit in run["hits"]:
		hit_moves.append(hit["move"])
		hit_frames.append(hit["frame"])
	var start_5b := -1
	for start in run["starts"]:
		if start["move"] == "5B":
			start_5b = start["frame"]
	var landed: int = run["landed_frame"]
	var dummy_air_at_j6d := false
	for hit in run["hits"]:
		if hit["move"] == "j6D":
			dummy_air_at_j6d = bool(hit["dummy_air"])
	_check(hit_moves == ["2C", "6D", "j6D", "5B"], "R2 路线四击成立 %s（帧 %s）" % [str(hit_moves), str(hit_frames)])
	_check(start_5b == landed + 4, "R2 5B 于完整普通落地恢复（3+1）后的首个合法帧 F%d 消费（落地 F%d）" % [start_5b, landed])
	_check(dummy_air_at_j6d, "R2 j6D 命中时目标为空中目标、命中后保持浮空（对空连接前提）")
	print("")


# --- R3：j5D 收束（无后续、无特权）与挥空落地恢复 ---

func _replay_r3_j5d_closer(facing: int) -> void:
	print("=== R3 2C>6D>j5D 收束 + 挥空落地恢复 | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	var run := _run_route(NEAR_DX, facing, "j5D")
	var hit_moves: Array[String] = []
	for hit in run["hits"]:
		hit_moves.append(hit["move"])
	var ends: Array[Dictionary] = run["ends"]
	_check(hit_moves == ["2C", "6D", "j5D"], "R3 三击后路线收束 %s" % str(hit_moves))
	_check(not ends.is_empty() and ends[0]["reason"] in [
			CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED, CombatEvent.ComboEndReason.MOVE_RECOVERED],
		"R3 收束按取消窗关闭/收招结束（原因 %s）" % str(ends))
	_check(not bool(run["session"].debug_snapshot()["hit_landing_cancel_open"]), "R3 j5D 不取得任何落地资格")
	## 挥空：同一编排把木桩移出 j5D 判定范围。
	var whiff := _spawn(NEAR_DX, facing)
	var recovery_seen := -1
	var was_airborne := false
	for frame in range(1, 90):
		var input := _prefix_input(frame, "j5D", facing)
		var on_ground_before := whiff.player_on_ground
		whiff.step(input)
		if not on_ground_before:
			was_airborne = true
		if was_airborne and whiff.player_on_ground and recovery_seen < 0:
			recovery_seen = int(whiff.debug_snapshot()["landing_recovery_left"])
		if frame == 40:
			whiff.dummy_position += Vector2(260, 0)
	_check(recovery_seen == 4, "R3 挥空 j5D 同样承担空技落地恢复（落地余 3+1=%d 帧）" % recovery_seen)
	print("")


# --- R4：反例组（挥空/命中前预存/非法目标/被防/j6D 不借例外）---

func _replay_r4_negatives() -> void:
	print("=== R4 反例组 | 面向 1 ===")
	# a) j2D 挥空：无资格、落地帧断连、214C 只按独立招式在正常恢复后起手。
	var whiff := _spawn(NEAR_DX, 1)
	var whiff_214c_start := -1
	var whiff_end_at_landing := false
	var landed := -1
	var was_air := false
	for frame in range(1, 110):
		var input := _prefix_input(frame, "j2D", 1)
		match frame:
			49: input = _214(0, 1)
			50: input = _214(1, 1)
			51: input = _214(2, 1)
			52: input = _214(3, 1)
		var move_at_start := whiff.player_move_id
		var on_ground_before := whiff.player_on_ground
		var ended_here := false
		for event in whiff.step(input):
			if event.type == CombatEvent.Type.COMBO_ENDED:
				ended_here = true
		if whiff.player_move_id == "214C" and move_at_start != "214C":
			whiff_214c_start = frame
		if not on_ground_before:
			was_air = true
		if was_air and whiff.player_on_ground and landed < 0:
			landed = frame
			whiff_end_at_landing = ended_here
		if frame == 40:
			whiff.dummy_position += Vector2(260, 0)
	_check(whiff_end_at_landing, "R4a 挥空 j2D 落地当帧按收招未接续断连（F%d）" % landed)
	_check(whiff_214c_start < 0 or whiff_214c_start >= landed + 6,
		"R4a 214C 不早于正常恢复结束（起手 F%d，落地 F%d）" % [whiff_214c_start, landed])

	# b) 命中前预存 214C：不自动补发。
	var pre := _run_route(NEAR_DX, 1, "j2D", {
		41: _214(0, 1), 42: _214(1, 1), 43: _214(2, 1), 44: _214(3, 1),
	})
	var pre_started: Array[String] = []
	for start in pre["starts"]:
		pre_started.append(start["move"])
	var pre_hit: Array[String] = []
	for hit in pre["hits"]:
		pre_hit.append(hit["move"])
	_check(pre_hit.has("j2D") and not pre_started.has("214C"),
		"R4b 命中前按下的 214C 不经例外补发（命中 %s，起手 %s）" % [str(pre_hit), str(pre_started)])

	# c) 非法目标：资格开放期喂 236C（非声明目标）——例外失效、无任何取消。
	var illegal := _run_route(NEAR_DX, 1, "j2D", {
		49: _236(0, 1), 50: _236(1, 1), 51: _236(2, 1), 52: _236(3, 1),
	})
	var illegal_started: Array[String] = []
	for start in illegal["starts"]:
		illegal_started.append(start["move"])
	var illegal_landed: int = illegal["landed_frame"]
	var illegal_lapsed := false
	for end in illegal["ends"]:
		if end["frame"] > illegal_landed and end["reason"] == CombatEvent.ComboEndReason.MOVE_RECOVERED:
			illegal_lapsed = true
	var illegal_236c := -1
	for start in illegal["starts"]:
		if start["move"] == "236C":
			illegal_236c = start["frame"]
	_check(illegal_lapsed and (illegal_236c < 0 or illegal_236c >= illegal_landed + 6) and not illegal_started.has("214C"),
		"R4c 非声明目标（236C）不消费例外：资格落地后失效断连；236C 至多按独立招式在正常恢复后起手（F%d，落地 F%d，起手 %s）" % [
			illegal_236c, illegal_landed, str(illegal_started)])

	# d) 被防 j2D：无资格。
	var blocked := _spawn(NEAR_DX, 1)
	var blocked_seen := false
	for frame in range(1, 90):
		var input := FrameInput.new()
		match frame:
			1: input.jump_pressed = true
			14: input = _press("D", true)
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		for event in blocked.step(input):
			if event.type == CombatEvent.Type.ATTACK_BLOCKED:
				blocked_seen = true
	_check(blocked_seen and not bool(blocked.debug_snapshot()["hit_landing_cancel_open"]),
		"R4d 被防 j2D 不取得命中落地资格")

	# e) j6D 同场景不借例外：214C 输入只按正常恢复后的独立/无例外路径。
	var j6 := _run_route(NEAR_DX, 1, "j6D", {
		49: _214(0, 1), 50: _214(1, 1), 51: _214(2, 1), 52: _214(3, 1),
	})
	var j6_started: Array[String] = []
	for start in j6["starts"]:
		j6_started.append(start["move"])
	var j6_214c := -1
	for start in j6["starts"]:
		if start["move"] == "214C":
			j6_214c = start["frame"]
	_check(not j6_started.has("214C") or j6_214c >= int(j6["landed_frame"]) + 4,
		"R4e j6D 不取得 j2D 例外（214C 起手 %s，落地 F%d）" % [str(j6_214c), int(j6["landed_frame"])])
	print("")


# --- R5：既有出口接线 jB > j5D（jc 演示路线前缀复用）---

func _replay_r5_jc_jb_into_j5d(facing: int) -> void:
	print("=== R5 5A>5B>5C>6A>jc.jB>j5D | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	var session := _spawn(NEAR_DX, facing)
	var hit_moves: Array[String] = []
	for frame in range(1, 130):
		var input := FrameInput.new()
		match frame:
			1: input = _press("A")
			9: input = _press("B")
			24: input = _press("C")
			38:
				input = _press("A", false, facing)
			39: input.move_axis = facing
			56: input.jump_pressed = true
			68: input = _press("B")
			79: input = _press("D")
		var move_at_start := session.player_move_id
		for event in session.step(input):
			_log_event(frame, "R5", event, session)
			if event.type == CombatEvent.Type.HIT:
				hit_moves.append(move_at_start)
	_check(hit_moves == ["5A", "5B", "5C", "6A", "jB", "j5D"],
		"R5 jB 命中确认取消进入空中 D 系（j5D 收束）：%s" % str(hit_moves))
	print("")


# --- R6：j2D 对地目标（地空目标差异：grounded profile + 例外同样成立）---

func _replay_r6_j2d_grounded_target(facing: int) -> void:
	print("=== R6 独立跳 j2D 对地目标 > 214C | 面向 %d ===" % facing)
	var session := _spawn(NEAR_DX, facing)
	var hit_moves: Array[String] = []
	for frame in range(1, 90):
		var input := FrameInput.new()
		match frame:
			1: input.jump_pressed = true
			14: input = _press("D", true)
			26: input = _214(0, facing)
			27: input = _214(1, facing)
			28: input = _214(2, facing)
			29: input = _214(3, facing)
		var move_at_start := session.player_move_id
		for event in session.step(input):
			_log_event(frame, "R6", event, session)
			if event.type == CombatEvent.Type.HIT:
				hit_moves.append(move_at_start)
	_check(hit_moves == ["j2D", "214C"],
		"R6 对地 j2D 命中（grounded 资料）同样取得一次性落地取消：%s" % str(hit_moves))
	_check(session.dummy_state == CombatSession.DummyState.AIR_HITSTUN or session.combo_hits == 2,
		"R6 连段延续到 214C（第 %d 击）" % session.combo_hits)
	print("")
