extends SceneTree
## 票据 08 单元测试：j5D 收束、j6D 普通落地恢复后的普通连接、j2D 实际命中后
## 仅限 214C 的专用落地取消（L-01：Hitstop 可缓存、落地首帧锁定、首个可行动帧
## 消费并清除资格）、挥空/被防/命中前预存反例、最后空中帧先结算命中再落地、
## active 落地截断与既有出口接线。
## 运行：godot --headless --path . -s res://tests/test_air_d_landing.gd

## 连段路线票据 01（12×20 尺度）：近距校准 14px（g2，与原 50px@48宽身体同边缘距）。
const NEAR_DX := 14.0

var _failures := 0


func _initialize() -> void:
	_test_air_d_entries_in_shared_table()
	_test_j2d_hit_landing_cancel_route()
	_test_j2d_last_air_frame_hit_settles_before_landing()
	_test_j2d_whiff_no_landing_cancel()
	_test_j2d_prehit_input_no_autofire()
	_test_j2d_blocked_no_qualification()
	_test_j2d_qualification_bound_to_combo()
	_test_j6d_hit_normal_recovery_then_link()
	_test_j6d_no_j2d_exception()
	_test_j5d_closer_ends_route()
	_test_j5d_whiff_bears_landing_recovery()
	_test_jb_cancel_into_j6d()
	_test_j5d_j6d_grounded_targets()
	print("")
	if _failures == 0:
		print("ALL AIR D LANDING TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


func _spawn(dx: float, facing := 1) -> CombatSession:
	var session := CombatSession.new()
	if facing == 1:
		session.dummy_position = session.player_position + Vector2(dx, 0)
	else:
		session.dummy_position = session.player_position - Vector2(dx, 0)
		session.player_facing = -1
	return session


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS  " + message)
	else:
		_failures += 1
		print("FAIL  " + message)


func _input(key: String, down := false, axis := 0) -> FrameInput:
	var input := FrameInput.new()
	if key != "":
		input.pressed_action_keys = [key]
		input.held_action_keys = [key]
	input.down_held = down
	input.move_axis = axis
	return input


func _214_frame_input(step: int, facing: int) -> FrameInput:
	## step 0=下(2)，1=下后(1)，2/3=后(4)，step 3 同时按下 C。
	## 连段路线票据 01（12×20 尺度）：6D 的 88px 计划位移在薄身下合法穿越
	## 木桩并换边，后续 214 按换边后的面向折算——世界方向取 +facing。
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


# --- 表项与接线：三招入表、jD 退场、出口边 ---

func _test_air_d_entries_in_shared_table() -> void:
	var result := MoveTable.load_default()
	_check(result.ok, "shared manifest loads with the air D series present")
	if not result.ok:
		return
	var moves := result.moves
	for entry in [["j5D", 6, 4, 16, 16], ["j6D", 7, 4, 18, 17], ["j2D", 8, 4, 20, 18]]:
		var move := moves.get(entry[0]) as MoveData
		_check(move != null, "%s exists in the shared table" % entry[0])
		if move == null:
			continue
		_check(move.stance == MoveData.Stance.AIR and move.action_key == "D" and move.starter_grade == MoveData.StarterGrade.D,
			"%s is an air D move with starter grade D" % entry[0])
		_check(move.startup_frames == entry[1] and move.active_frames == entry[2] \
			and move.recovery_frames == entry[3] and move.base_damage == entry[4],
			"%s frame data matches the tuning table (%d/%d/%d, dmg %d)" % [entry[0], entry[1], entry[2], entry[3], entry[4]])
		_check(move.has_motion(), "%s declares planned motion" % entry[0])
		_check(move.block_freeze_frames >= 0 and move.block_stun_frames >= 0 and move.block_pushback_px_s >= 0,
			"%s declares blockable result fields" % entry[0])
	_check(not moves.has("jD"), "legacy jD is removed from the shared table")
	var j5d := moves["j5D"] as MoveData
	var j6d := moves["j6D"] as MoveData
	var j2d := moves["j2D"] as MoveData
	_check(j5d.motion_x_px > 0.0 and is_equal_approx(j5d.motion_y_px, 0.0), "j5D sweeps horizontally (motion 74/0)")
	_check(j6d.motion_x_px > 0.0 and j6d.motion_y_px > 0.0, "j6D dives diagonally down (motion 68/26)")
	_check(is_equal_approx(j2d.motion_x_px, 0.0) and j2d.motion_y_px > 0.0, "j2D drops vertically (motion 0/70)")
	_check(j2d.hit_landing_cancel_targets == ["214C"] and j2d.hit_landing_cancel_window_frames > 0,
		"j2D alone declares the 214C hit-landing cancel with a window")
	_check(j5d.hit_landing_cancel_targets.is_empty() and j6d.hit_landing_cancel_targets.is_empty(),
		"j5D/j6D declare no hit-landing cancel")
	_check(j6d.link_targets == ["5B"], "j6D declares the post-recovery normal link to 5B")
	_check(j5d.link_targets.is_empty() and j2d.link_targets.is_empty(), "j5D/j2D declare no normal links")
	for pair in [["jA", moves["jA"] as MoveData], ["jB", moves["jB"] as MoveData], ["jC", moves["jC"] as MoveData]]:
		var move: MoveData = pair[1]
		for target in ["j5D", "j6D", "j2D"]:
			_check(move.cancel_targets.has(target), "%s cancels into %s on hit confirm" % [pair[0], target])
		_check(not move.cancel_targets.has("jD"), "%s no longer references legacy jD" % pair[0])
	for source in ["6D", "2D"]:
		var move := moves[source] as MoveData
		for target in ["j5D", "j6D", "j2D"]:
			_check(move.air_exit_targets.has(target), "%s air exit opens into %s" % [source, target])


# --- 正例 1：2C > 6D > j2D 命中 > Hitstop 输入 214C > 落地首帧锁 > 首个可行动帧 214C ---

func _run_air_d_route(dx: float, facing: int, j_move: String, extra_inputs := {}, horizon := 110) -> Dictionary:
	## 复用票据 07 的锚点（连段路线票据 04 C6 后整体前移 3F）：2C@F1（下+C）
	## 命中 F10（原 F13）；6D 于停顿中 F17 按下、F19 起手、F28 命中（12px 离地）；
	## 出口键于 6D 停顿中 F35 按下（j2D 按住下、j6D 前方向、j5D 无方向）、
	## F37 空中起手。extra_inputs: frame -> FrameInput 覆盖追加。
	var session := _spawn(dx, facing)
	var hits: Array[Dictionary] = []
	var starts: Array[Dictionary] = []
	var ends: Array[Dictionary] = []
	var landed_frame := -1
	var landing_move_id := "#unset"
	var hitstop_ends: Array[int] = []
	var was_airborne := false
	for frame in range(1, horizon):
		var input := FrameInput.new()
		match frame:
			1:
				input = _input("C", true)
			17:
				input = _input("D", false, facing)
			35:
				match j_move:
					"j2D":
						input = _input("D", true)
					"j6D":
						input = _input("D", false, facing)
					_:
						input = _input("D")
		if extra_inputs.has(frame):
			var extra: FrameInput = extra_inputs[frame]
			if input.pressed_action_keys.is_empty() and input.move_axis == 0 and not input.down_held:
				input = extra
			else:
				for key in extra.pressed_action_keys:
					if not input.pressed_action_keys.has(key):
						input.pressed_action_keys.append(key)
						input.held_action_keys.append(key)
				input.move_axis = extra.move_axis
				input.down_held = input.down_held or extra.down_held
		var move_at_start := session.player_move_id
		var on_ground_before := session.player_on_ground
		for event in session.step(input):
			match event.type:
				CombatEvent.Type.HIT:
					hits.append({"frame": frame, "move": move_at_start})
				CombatEvent.Type.ATTACK_BLOCKED:
					hits.append({"frame": frame, "move": move_at_start, "blocked": true})
				CombatEvent.Type.COMBO_ENDED:
					ends.append({"frame": frame, "reason": event.combo_end_reason})
				CombatEvent.Type.HITSTOP_ENDED:
					hitstop_ends.append(frame)
		if move_at_start != session.player_move_id and session.player_move_id != "":
			starts.append({
				"frame": frame, "move": session.player_move_id,
				"recovery_left": int(session.debug_snapshot()["landing_recovery_left"]),
			})
		if not on_ground_before:
			was_airborne = true
		if was_airborne and session.player_on_ground and landed_frame < 0:
			landed_frame = frame
			landing_move_id = session.player_move_id
	return {
		"session": session, "hits": hits, "starts": starts, "ends": ends,
		"landed_frame": landed_frame, "landing_move_id": landing_move_id,
		"hitstop_ends": hitstop_ends,
	}


func _test_j2d_hit_landing_cancel_route() -> void:
	for facing in [1, -1]:
		## 214C 于 j2D 命中停顿中喂入（F49–F52 四帧：2、1、4、4+C）。
		var extra := {
			49: _214_frame_input(0, facing),
			50: _214_frame_input(1, facing),
			51: _214_frame_input(2, facing),
			52: _214_frame_input(3, facing),
		}
		var run := _run_air_d_route(NEAR_DX, facing, "j2D", extra)
		var session: CombatSession = run["session"]
		var hit_moves: Array[String] = []
		for hit in run["hits"]:
			hit_moves.append(hit["move"])
		_check(hit_moves == ["2C", "6D", "j2D", "214C"],
			"j2D hit-landing cancel route reads 2C > 6D > j2D > 214C (facing %d): %s" % [facing, str(hit_moves)])
		var start_214c := -1
		var recovery_left_at_start := -1
		for start in run["starts"]:
			if start["move"] == "214C":
				start_214c = start["frame"]
				recovery_left_at_start = int(start["recovery_left"])
		var landed: int = run["landed_frame"]
		_check(start_214c > 0 and landed > 0, "214C starts and the attacker lands (facing %d, land F%d, 214C F%d)" % [facing, landed, start_214c])
		## 落地首帧锁：落地当帧无任何新招（j2D 已截断、214C 未起）。
		_check(String(run["landing_move_id"]) == "", "landing first frame stays locked: no move starts on the landing frame (facing %d)" % facing)
		## 例外消费帧：落地事件后的首个到达消费阶段的正常帧（停顿冻结帧不消费）。
		var hitstop_ends: Array[int] = run["hitstop_ends"]
		var first_resume_after_landing := landed + 1
		for ended_at in hitstop_ends:
			if ended_at > landed:
				first_resume_after_landing = ended_at
				break
		_check(start_214c == first_resume_after_landing,
			"214C starts on the first actionable frame after the landing lock, skipping the rest of the air landing recovery (facing %d: land F%d, consume F%d, expected F%d)" % [facing, landed, start_214c, first_resume_after_landing])
		_check(recovery_left_at_start > 0,
			"the exception fires while the normal air-move landing recovery is still running (facing %d: recovery left %d at the 214C start)" % [facing, recovery_left_at_start])
		_check(session.combo_hits == 4, "the cancel keeps one unbroken combo of four hits (facing %d)" % facing)
		var ended_before_cancel := false
		for end in run["ends"]:
			if end["frame"] < start_214c:
				ended_before_cancel = true
		_check(not ended_before_cancel, "no combo end fires between the j2D hit and the 214C start (facing %d)" % facing)
		_check(not bool(session.debug_snapshot()["hit_landing_cancel_open"]),
			"the one-shot qualification is cleared after consumption (facing %d)" % facing)


# --- 正例 2：最后空中物理帧先结算命中，再进入落地恢复 ---

func _test_j2d_last_air_frame_hit_settles_before_landing() -> void:
	var run := _run_air_d_route(NEAR_DX, 1, "j2D", {
		49: _214_frame_input(0, 1), 50: _214_frame_input(1, 1),
		51: _214_frame_input(2, 1), 52: _214_frame_input(3, 1),
	})
	var j2d_hit := -1
	var blocked_or_hit := false
	for hit in run["hits"]:
		if hit["move"] == "j2D":
			j2d_hit = hit["frame"]
			blocked_or_hit = not hit.get("blocked", false)
	var landed: int = run["landed_frame"]
	_check(j2d_hit > 0 and blocked_or_hit, "j2D registers a real hit on its last air frame (hit F%d)" % j2d_hit)
	_check(j2d_hit == landed, "the hit and the landing share the frame: hit detection settles before motion lands (hit F%d, land F%d)" % [j2d_hit, landed])
	var j2d_hit_count := 0
	for hit in run["hits"]:
		if hit["move"] == "j2D":
			j2d_hit_count += 1
	_check(j2d_hit_count == 1, "the truncated active window yields exactly one j2D contact")
	_check(String(run["session"].debug_snapshot()["move_id"]) in ["", "214C"],
		"j2D is cleared on landing: remaining active does not extend past the landing frame")


# --- 反例 1：j2D 挥空 → 普通落地恢复，不取得资格 ---

func _test_j2d_whiff_no_landing_cancel() -> void:
	var session := _spawn(NEAR_DX, 1)
	var start_214c := -1
	var ended: Array[Dictionary] = []
	var landed_frame := -1
	var was_airborne := false
	for frame in range(1, 110):
		var input := FrameInput.new()
		match frame:
			1:
				input = _input("C", true)
			17:
				input = _input("D", false, 1)
			35:
				input = _input("D", true)
			49:
				input = _214_frame_input(0, 1)
			50:
				input = _214_frame_input(1, 1)
			51:
				input = _214_frame_input(2, 1)
			52:
				input = _214_frame_input(3, 1)
		var move_at_start := session.player_move_id
		var on_ground_before := session.player_on_ground
		for event in session.step(input):
			if event.type == CombatEvent.Type.COMBO_ENDED:
				ended.append({"frame": frame, "reason": event.combo_end_reason})
		if session.player_move_id == "214C" and move_at_start != "214C":
			start_214c = frame
		if not on_ground_before:
			was_airborne = true
		if was_airborne and session.player_on_ground and landed_frame < 0:
			landed_frame = frame
		## 6D 命中后把木桩移出 j2D 判定范围：j2D 挥空落地。
		if frame == 40:
			session.dummy_position += Vector2(260, 0)
	var j2d := (MoveTable.load_default().moves["j2D"] as MoveData)
	var normal_first_actionable := landed_frame + GameParams.PLAYER_LANDING_RECOVERY_BASE_FRAMES \
		+ GameParams.PLAYER_AIR_ATTACK_LANDING_PENALTY_FRAMES + j2d.extra_landing_recovery_frames
	_check(start_214c < 0 or start_214c >= normal_first_actionable,
		"whiffed j2D never lands-cancel into 214C before the normal recovery end (214C F%d, land F%d, earliest legal F%d)" % [start_214c, landed_frame, normal_first_actionable])
	_check(landed_frame > 0, "the attacker still lands after the whiff (F%d)" % landed_frame)
	var recovered_end := ended.filter(func(end): return end["reason"] == CombatEvent.ComboEndReason.MOVE_RECOVERED)
	_check(not recovered_end.is_empty() and int(recovered_end[0]["frame"]) == landed_frame,
		"the whiffed route ends on the landing frame as move-recovered (ends %s, land F%d)" % [str(ended), landed_frame])
	_check(not bool(session.debug_snapshot()["hit_landing_cancel_open"]), "no qualification is granted on a whiff")


# --- 反例 2：命中前预存 214C 不自动补发 ---

func _test_j2d_prehit_input_no_autofire() -> void:
	## 214C 于 j2D 前摇期（F41–F44）喂入——早于命中，资格尚未授予。
	var run := _run_air_d_route(NEAR_DX, 1, "j2D", {
		41: _214_frame_input(0, 1), 42: _214_frame_input(1, 1),
		43: _214_frame_input(2, 1), 44: _214_frame_input(3, 1),
	})
	var hit_moves: Array[String] = []
	for hit in run["hits"]:
		hit_moves.append(hit["move"])
	var started: Array[String] = []
	for start in run["starts"]:
		started.append(start["move"])
	_check(hit_moves.has("j2D"), "j2D still hits after the pre-hit input (hits %s)" % str(hit_moves))
	_check(not started.has("214C"), "a 214C pressed before the j2D hit never auto-fires through the exception")
	var recovered := false
	for end in run["ends"]:
		if end["reason"] == CombatEvent.ComboEndReason.MOVE_RECOVERED:
			recovered = true
	_check(recovered, "the route ends unrecovered-without-consumption instead of inheriting the exception (ends %s)" % str(run["ends"]))


# --- 反例 3：被防 j2D 不取得资格 ---

func _test_j2d_blocked_no_qualification() -> void:
	## 独立跳后空中 j2D 打站防木桩：BLOCKED 接触不授予资格。
	var session := _spawn(NEAR_DX, 1)
	var blocked := false
	var started: Array[String] = []
	var landed_frame := -1
	var was_airborne := false
	for frame in range(1, 90):
		var input := FrameInput.new()
		match frame:
			1:
				input.jump_pressed = true
			14:
				input = _input("D", true)
			24:
				input = _214_frame_input(0, 1)
			25:
				input = _214_frame_input(1, 1)
			26:
				input = _214_frame_input(2, 1)
			27:
				input = _214_frame_input(3, 1)
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		var move_at_start := session.player_move_id
		var on_ground_before := session.player_on_ground
		for event in session.step(input):
			if event.type == CombatEvent.Type.ATTACK_BLOCKED:
				blocked = true
		if session.player_move_id != move_at_start and session.player_move_id != "":
			started.append(session.player_move_id)
		if not on_ground_before:
			was_airborne = true
		if was_airborne and session.player_on_ground and landed_frame < 0:
			landed_frame = frame
	_check(started.has("j2D") and blocked, "the air j2D is started and gets blocked by the standing guard (started %s)" % str(started))
	_check(not started.has("214C"), "blocked j2D grants no landing cancel to 214C")
	_check(session.combo_hits == 0, "no combo or hit-confirm opens from the blocked contact")
	_check(landed_frame > 0, "the attacker lands normally after the block (F%d)" % landed_frame)


# --- 反例 4：资格绑定连段——连段结束资格清除 ---

func _test_j2d_qualification_bound_to_combo() -> void:
	## j2D 命中后立刻把木桩剩余受身计时压到 1：连段在落地前结束，资格随之清除。
	var session := _spawn(NEAR_DX, 1)
	var start_214c := -1
	var dummy_recovered_end := -1
	for frame in range(1, 110):
		var input := FrameInput.new()
		match frame:
			1:
				input = _input("C", true)
			17:
				input = _input("D", false, 1)
			35:
				input = _input("D", true)
			49:
				input = _214_frame_input(0, 1)
			50:
				input = _214_frame_input(1, 1)
			51:
				input = _214_frame_input(2, 1)
			52:
				input = _214_frame_input(3, 1)
		var move_at_start := session.player_move_id
		for event in session.step(input):
			if event.type == CombatEvent.Type.COMBO_ENDED and event.combo_end_reason == CombatEvent.ComboEndReason.DUMMY_RECOVERED:
				dummy_recovered_end = frame
		if session.player_move_id == "214C" and move_at_start != "214C":
			start_214c = frame
		if frame == 48:
			session.dummy_hitstun_left = 1
	_check(dummy_recovered_end > 0, "the dummy recovers before the landing cancel could fire (F%d)" % dummy_recovered_end)
	_check(start_214c < 0 or start_214c > dummy_recovered_end,
		"the qualification dies with the combo: no 214C consumption while the combo is alive (214C F%d, dummy recovered F%d)" % [start_214c, dummy_recovered_end])


# --- 正例 3：j6D 命中 → 普通落地恢复 → 恢复后普通连接 5B ---

func _test_j6d_hit_normal_recovery_then_link() -> void:
	for facing in [1, -1]:
		## 5B 于落地恢复中按下（B 组合等待 3 帧恰好落在首个可行动帧前解除；
		## 连段路线票据 04 C6 后落地 F53/可行动 F57，按帧自 57 前移至 54）。
		var extra := {54: _input("B")}
		var run := _run_air_d_route(NEAR_DX, facing, "j6D", extra)
		var session: CombatSession = run["session"]
		var hit_moves: Array[String] = []
		for hit in run["hits"]:
			hit_moves.append(hit["move"])
		_check(hit_moves == ["2C", "6D", "j6D", "5B"],
			"j6D route reads 2C > 6D > j6D, then 5B after the normal landing recovery (facing %d): %s" % [facing, str(hit_moves)])
		var start_5b := -1
		for start in run["starts"]:
			if start["move"] == "5B":
				start_5b = start["frame"]
		var landed: int = run["landed_frame"]
		var normal_actionable := landed + GameParams.PLAYER_LANDING_RECOVERY_BASE_FRAMES \
			+ GameParams.PLAYER_AIR_ATTACK_LANDING_PENALTY_FRAMES
		_check(start_5b == normal_actionable,
			"5B is consumed exactly at the first actionable frame after the full normal recovery (facing %d: land F%d, 5B F%d, expected F%d)" % [facing, landed, start_5b, normal_actionable])
		_check(session.combo_hits == 4, "the link continues the same combo (facing %d)" % facing)
		var early_end := false
		for end in run["ends"]:
			if end["frame"] < start_5b:
				early_end = true
		_check(not early_end, "no combo end before the deferred link resolves (facing %d, ends %s)" % [facing, str(run["ends"])])


# --- 反例 5：j6D 不共享 j2D 例外 ---

func _test_j6d_no_j2d_exception() -> void:
	var run := _run_air_d_route(NEAR_DX, 1, "j6D", {
		49: _214_frame_input(0, 1), 50: _214_frame_input(1, 1),
		51: _214_frame_input(2, 1), 52: _214_frame_input(3, 1),
	})
	var started: Array[String] = []
	for start in run["starts"]:
		started.append(start["move"])
	var landed: int = run["landed_frame"]
	_check(not started.has("214C"), "j6D never picks up the j2D landing exception (started %s)" % str(started))
	_check(landed > 0, "j6D attacker lands (F%d)" % landed)


# --- j5D 收束：命中后路线结束、无出口 ---

func _test_j5d_closer_ends_route() -> void:
	var run := _run_air_d_route(NEAR_DX, 1, "j5D")
	var session: CombatSession = run["session"]
	var hit_moves: Array[String] = []
	for hit in run["hits"]:
		hit_moves.append(hit["move"])
	_check(hit_moves == ["2C", "6D", "j5D"], "j5D closes the route: 2C > 6D > j5D with no follow-up (hits %s)" % str(hit_moves))
	var started: Array[String] = []
	for start in run["starts"]:
		started.append(start["move"])
	_check(not started.has("214C") and not started.has("5B"), "j5D grants no cancel, link, or landing privilege (started %s)" % str(started))
	var ended := false
	for end in run["ends"]:
		if end["reason"] in [CombatEvent.ComboEndReason.MOVE_RECOVERED, CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED]:
			ended = true
	_check(ended and session.combo_hits == 3, "the combo ends with three hits (ends %s)" % str(run["ends"]))


# --- j5D 挥空也承担空技落地恢复 ---

func _test_j5d_whiff_bears_landing_recovery() -> void:
	var session := _spawn(NEAR_DX, 1)
	var landed_frame := -1
	var was_airborne := false
	var recovery_seen := -1
	var ends: Array[int] = []
	for frame in range(1, 110):
		var input := FrameInput.new()
		match frame:
			1:
				input = _input("C", true)
			17:
				input = _input("D", false, 1)
			35:
				input = _input("D")
		var on_ground_before := session.player_on_ground
		for event in session.step(input):
			if event.type == CombatEvent.Type.COMBO_ENDED:
				ends.append(frame)
		if not on_ground_before:
			was_airborne = true
		if was_airborne and session.player_on_ground and landed_frame < 0:
			landed_frame = frame
			recovery_seen = int(session.debug_snapshot()["landing_recovery_left"])
		if frame == 40:
			session.dummy_position += Vector2(260, 0)
	_check(landed_frame > 0 and recovery_seen > 0,
		"whiffed j5D still lands into the air-move landing recovery (land F%d, recovery %d)" % [landed_frame, recovery_seen])
	_check(ends.has(landed_frame), "the in-combo whiff ends the combo on the landing frame (ends %s, land F%d)" % [str(ends), landed_frame])


# --- 既有出口接线：jB 命中确认取消进入 j6D（jA/jB/jC → 空中 D 系）---

func _test_jb_cancel_into_j6d() -> void:
	## 复用票据 07 R1 前缀：5A@F1、B@F9、C@F24、6A@F38、Space@F56、jB@F68 命中 F75；
	## jB 停顿中 F79 按前+D → j6D 空中取消起手。
	var session := _spawn(NEAR_DX, 1)
	var hit_moves: Array[String] = []
	for frame in range(1, 130):
		var input := FrameInput.new()
		match frame:
			1:
				input = _input("A")
			9:
				input = _input("B")
			24:
				input = _input("C")
			38:
				input = _input("A")
				input.move_axis = 1
			39:
				input.move_axis = 1
			56:
				input.jump_pressed = true
			68:
				input = _input("B")
			79:
				input = _input("D", false, 1)
		var move_at_start := session.player_move_id
		for event in session.step(input):
			if event.type == CombatEvent.Type.HIT:
				hit_moves.append(move_at_start)
	_check(hit_moves == ["5A", "5B", "5C", "6A", "jB", "j6D"],
		"jB cancels on hit-confirm into the air D series (j6D): %s" % str(hit_moves))
	_check(session.combo_hits == 6, "the jc route with the air D follow-up stays one combo")


# --- 地空目标：j5D/j6D 的 grounded 资料命中站立木桩 ---

func _test_j5d_j6d_grounded_targets() -> void:
	## 连段路线票据 01（12×20 尺度）：站立木桩顶部 400→460，对地接触只剩跳跃
	## 下降末段——j5D 于 F35（active 落在最后空中帧）、j6D 于 F33（斜下速降扫掠）。
	for entry in [["j5D", 35, false], ["j6D", 33, true]]:
		var move_id: String = entry[0]
		var press_frame: int = entry[1]
		var forward: bool = entry[2]
		var session := _spawn(NEAR_DX, 1)
		var hit_moves: Array[String] = []
		var state_at_hit := -1
		for frame in range(1, 60):
			var input := FrameInput.new()
			if frame == 1:
				input.jump_pressed = true
			elif frame == press_frame:
				input = _input("D", false, 1 if forward else 0)
			var move_at_start := session.player_move_id
			for event in session.step(input):
				if event.type == CombatEvent.Type.HIT:
					hit_moves.append(move_at_start)
					state_at_hit = session.dummy_state
		_check(hit_moves == [move_id], "%s hits a standing grounded dummy with its grounded profile (hits %s)" % [move_id, str(hit_moves)])
		_check(state_at_hit == CombatSession.DummyState.GROUND_HITSTUN,
			"%s grounded hit applies ground hitstun (state %d)" % [move_id, state_at_hit])
