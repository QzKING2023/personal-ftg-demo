extends SceneTree
## 连段路线票据 04：原版边两轮普通 D 后 2C 实际倒地与保位（R3-B/C）。
## 覆盖父规格 C6（仅 2C 前摇 9N→6N，D120/D122 与阶段 B 冻结参考 v1）、
## 两轮普通 D 固定路线准确 10/9 动作/HIT、每轮 D 完整恢复后 5B、零换边、
## 2C 低浮空自然触地转普通倒地（首 END=实际倒地、KNOCKDOWN、非 FINISHER）、
## 首次倒地原墙 0–12px 与玩家场内侧、保证域有限扫描、同表三收尾条件
## （2C / 214C~B / 214C~C 按深度）、关键键窗口、真实窗外/规则负例、
## 2C 攻防与接续影响、D-loop 有限重复与保存恢复一致性。
## 运行：godot --headless --path . -s res://tests/test_corner_two_d_finish.gd
## 窗口/联合按 D122 只记录；有限采样不称连续域穷尽。

const ROUTE_HORIZON := 210

## 阶段 B 冻结参考 v1（frozen-inputs.json）：B/C 各一套跨距离共用，左右同帧号。
const B_ANCHORS := {"b1": 1, "c1": 12, "m1": 29, "d1": 45, "b2": 74, "c2": 79, "m2": 100, "d2": 117, "b3": 143, "e3": 149}
const C_ANCHORS := {"c1": 1, "m1": 15, "d1": 31, "b2": 61, "c2": 71, "m2": 89, "d2": 105, "b3": 132, "e3": 143}

const R3_SEQ_B := ["5B", "5C", "236C", "5D", "5B", "5C", "236C", "5D", "5B", "2C"]
const R3_SEQ_C := ["5C", "236C", "5D", "5B", "5C", "236C", "5D", "5B", "2C"]
const EXPECT_HITS_B := [10, 27, 42, 58, 83, 99, 114, 130, 153, 167]
const EXPECT_HITS_C := [12, 27, 43, 70, 87, 102, 118, 141, 156]
const EXPECT_KNOCK_B := 181
const EXPECT_KNOCK_C := 171

## 代表点 g9.3/r6.7 单组平移窗口（阶段 B windows.json，−14…+18F，其余输入固定；
## m 移动整个 4F 方向块；成功以完整准确路线与空间终点判定）。
const EXPECT_WINDOWS := {
	"B": {"c1": [5, 18], "m1": [22, 36], "d1": [37, 54], "b2": [73, 75], "c2": [78, 80], "m2": [94, 106], "d2": [109, 124], "b3": [142, 145], "e3": [148, 150]},
	"C": {"m1": [7, 22], "d1": [22, 39], "b2": [55, 65], "c2": [65, 77], "m2": [82, 95], "d2": [97, 113], "b3": [130, 136], "e3": [136, 148]},
}

## 保证域有限扫描点位（阶段 B domain.json 同构）：9×7 网格 + 32 个非整数点 +
## 代表点 (9.3, 6.7)；有限采样非连续域穷尽（D76/D85 补验安排保留）。
const DOMAIN_G := [0.0, 0.001, 1.0, 2.0, 4.0, 9.0, 13.0, 17.999, 18.0]
const DOMAIN_R := [0.0, 0.001, 4.0, 6.0, 8.0, 11.999, 12.0]
const DOMAIN_EXTRA := [
	[7.137, 3.719], [14.274, 7.438], [3.411, 11.157], [10.548, 2.876], [17.685, 6.595],
	[6.822, 10.314], [13.959, 2.033], [3.096, 5.752], [10.233, 9.471], [17.37, 1.19],
	[6.507, 4.909], [13.644, 8.628], [2.781, 0.347], [9.918, 4.066], [17.055, 7.785],
	[6.192, 11.504], [13.329, 3.223], [2.466, 6.942], [9.603, 10.661], [16.74, 2.38],
	[5.877, 6.099], [13.014, 9.818], [2.151, 1.537], [9.288, 5.256], [16.425, 8.975],
	[5.562, 0.694], [12.699, 4.413], [1.836, 8.132], [8.973, 11.851], [16.11, 3.57],
	[5.247, 7.289], [12.384, 11.008],
]

var _failures := 0


func _initialize() -> void:
	_test_c6_resources()
	_test_r3_reference()
	_test_r3_domain_sweep()
	_test_r3_windows()
	_test_r3_negatives()
	_test_r3_tails()
	_test_r3_tail_boxes()
	_test_r3_save_restore()
	_test_two_c_effects()
	_test_d_loop_repetition()
	_test_solver_route_report()
	print("")
	if _failures == 0:
		print("ALL CORNER TWO-D FINISH TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		_failures += 1
		print("FAIL  " + label)


func _approx(a: float, b: float, tolerance := 0.01) -> bool:
	return absf(a - b) <= tolerance


# --- 布置与输入构造（固定帧计划；未列帧中立）---

## g 为双方身体横向边缘间距，r 为目标身体边缘到其身后指定原墙的距离（连续
## [0,12]px，含端点）；玩家从场内侧起手，指定墙整条路线不变。
func _place(g: float, r: float, facing: int, moves = null) -> CombatSession:
	var session := CombatSession.new(moves) if moves != null else CombatSession.new()
	var wall := GameParams.stage_right_limit() if facing == 1 else GameParams.stage_left_limit()
	var dummy_x := wall - r * facing
	var player_x := dummy_x - facing * (GameParams.BODY_SIZE.x + g)
	session.player_position = Vector2(player_x, GameParams.ground_stand_y())
	session.dummy_position = Vector2(dummy_x, GameParams.ground_stand_y())
	session.player_facing = facing
	return session


func _hold(key: String, axis := 0) -> FrameInput:
	var input := FrameInput.new()
	input.held_action_keys = [key]
	input.move_axis = axis
	return input


func _press(key: String, axis := 0, down := false) -> FrameInput:
	var input := FrameInput.new()
	input.pressed_action_keys = [key]
	input.held_action_keys = [key]
	input.move_axis = axis
	input.down_held = down
	return input


func _direction(axis: int, down := false) -> FrameInput:
	var input := FrameInput.new()
	input.move_axis = axis
	input.down_held = down
	return input


func _neutral() -> FrameInput:
	return FrameInput.new()


func _guard_input(posture: int) -> FrameInput:
	var input := FrameInput.new()
	input.dummy_guard_request = posture
	return input


## 236C 方向块（末键 t）：t−3 下、t−2 下前、t−1 前、t 前+C，t+1 全松。
func _add_236(plan: Dictionary, t: int, facing: int) -> void:
	plan[t - 3] = _direction(0, true)
	plan[t - 2] = _direction(facing, true)
	plan[t - 1] = _direction(facing)
	plan[t] = _press("C", facing)
	plan[t + 1] = _neutral()


## 214C 方向块（末键 t）：t−3 下、t−2 下后、t−1 后、t 后+C，t+1 全松。
func _add_214(plan: Dictionary, t: int, facing: int) -> void:
	plan[t - 3] = _direction(0, true)
	plan[t - 2] = _direction(-facing, true)
	plan[t - 1] = _direction(-facing)
	plan[t] = _press("C", -facing)
	plan[t + 1] = _neutral()


func _r3_anchors(kind: String) -> Dictionary:
	return B_ANCHORS.duplicate() if kind == "B" else C_ANCHORS.duplicate()


## 两轮固定参考计划。rounds=1 只到 b2（一轮 D 后 5B）；tail 决定末段：
## "2c" 冻结 e3 下+C，"none" 无末段（尾段另接）。
func _r3_plan(kind: String, facing: int, shifts := {}, rounds := 2, tail := "2c") -> Dictionary:
	var a := _r3_anchors(kind)
	for key in shifts:
		a[key] = int(a[key]) + int(shifts[key])
	var plan := {}
	if kind == "B":
		plan[int(a["b1"])] = _press("B")
	plan[int(a["c1"])] = _press("C")
	_add_236(plan, int(a["m1"]), facing)
	plan[int(a["d1"])] = _press("D")
	plan[int(a["b2"])] = _press("B")
	if rounds >= 2:
		plan[int(a["c2"])] = _press("C")
		_add_236(plan, int(a["m2"]), facing)
		plan[int(a["d2"])] = _press("D")
		plan[int(a["b3"])] = _press("B")
		if tail == "2c":
			plan[int(a["e3"])] = _press("C", 0, true)
	return plan


## 旧表对照（阶段 C6 落表前生产 9N）：内存深拷贝仅改 2C 前摇。
func _nine_n_table() -> Dictionary:
	var moves := MoveData.default_table()
	var two_c: MoveData = (moves["2C"] as MoveData).duplicate()
	two_c.startup_frames = 9
	moves["2C"] = two_c
	return moves


# --- 回放执行与观察 ---

## 逐帧喂入固定计划；首 END 前后命中分账、换边、低浮空触地、首次实际普通
## 倒地帧末（含该帧运动/墙限/身体分离）、原墙距与玩家侧别、两轮 5D 段恢复。
func _run_route_on(session: CombatSession, plan: Dictionary, facing: int, start_frame: int, horizon: int, guard := 0) -> Dictionary:
	var res := {"hits": [], "hit_moves": [], "post_hits": [], "swaps": 0,
		"first_end_frame": -1, "first_end_reason": -1, "low_float_frame": -1,
		"knock_frame": -1, "knock_wall": -1.0, "field_side": false,
		"recovered_frame": -1, "d_recoveries": [], "frames": [], "dummy_states": []}
	var ended := false
	for frame in range(start_frame, horizon + 1):
		var before_move: String = session.player_move_id
		var input: FrameInput = plan.get(frame, _neutral())
		if guard != 0:
			input.dummy_guard_request = guard
		for event in session.step(input):
			match event.type:
				CombatEvent.Type.HIT:
					if ended:
						res["post_hits"].append([frame, before_move])
					else:
						res["hits"].append(frame)
						res["hit_moves"].append(before_move)
				CombatEvent.Type.COMBO_ENDED:
					if int(res["first_end_frame"]) == -1:
						res["first_end_frame"] = frame
						res["first_end_reason"] = event.combo_end_reason
					ended = true
				CombatEvent.Type.LOW_FLOAT_LANDED:
					res["low_float_frame"] = frame
				CombatEvent.Type.DUMMY_RECOVERED:
					if int(res["recovered_frame"]) == -1:
						res["recovered_frame"] = frame
				CombatEvent.Type.SWITCHED_SIDES:
					res["swaps"] = int(res["swaps"]) + 1
		res["frames"].append(session.clone_state())
		res["dummy_states"].append(int(session.dummy_state))
		if int(res["knock_frame"]) == -1 and session.dummy_state == CombatSession.DummyState.KNOCKED_DOWN:
			res["knock_frame"] = frame
			var wall: float = GameParams.stage_right_limit() if facing == 1 else GameParams.stage_left_limit()
			res["knock_wall"] = (wall - session.dummy_position.x) * facing
			res["field_side"] = (session.dummy_position.x - session.player_position.x) * facing > 0.0
	# 两轮 5D：各自完整恢复（首个 NEUTRAL 帧）及后继 5B 的命中限定连接。
	var spans: Array = []
	var span_start := -1
	for i in range(res["frames"].size()):
		var mid: String = res["frames"][i].player_move.move_id
		if mid == "5D" and span_start == -1:
			span_start = i + 1
		elif mid != "5D" and span_start != -1:
			spans.append([span_start, i])
			span_start = -1
	if span_start != -1:
		spans.append([span_start, res["frames"].size()])
	for span in spans:
		# 完整恢复后的后继 5B（命中限定连接）：同帧「恢复→缓存消费」时无中立
		# 空档，退出帧记为离开 5D 的首帧；via_link 承载「完整恢复后才连接」合同。
		var b_start := -1
		var via := false
		for i in range(span[1], res["frames"].size()):
			var st = res["frames"][i]
			if st.player_move.move_id == "5B":
				b_start = i + 1
				via = bool(st.player_move.via_link)
				break
		res["d_recoveries"].append({"start": span[0], "last": span[1], "exit": span[1] + 1, "b_start": b_start, "via_link": via})
	return res


func _run_route(plan: Dictionary, facing: int, g: float, r: float, moves = null, horizon := ROUTE_HORIZON, guard := 0) -> Dictionary:
	return _run_route_on(_place(g, r, facing, moves), plan, facing, 1, horizon, guard)


## R3 完整功能合同：准确序列/计数、首 END 边界=实际倒地（KNOCKDOWN、低浮空
## 同帧）、零换边、原墙 0–12px、玩家场内侧、两轮 5D 完整恢复后 5B 连接、
## 末击后无新命中拼段。2C/~B 非 FINISHER 语义由资源断言与 KNOCKDOWN 原因承载。
func _route_ok(kind: String, res: Dictionary) -> bool:
	var seq: Array = R3_SEQ_B if kind == "B" else R3_SEQ_C
	var want := 10 if kind == "B" else 9
	if res["hit_moves"] != seq or (res["hits"] as Array).size() != want:
		return false
	if int(res["swaps"]) != 0 or not (res["post_hits"] as Array).is_empty():
		return false
	if int(res["knock_frame"]) <= 0 or int(res["first_end_frame"]) != int(res["knock_frame"]):
		return false
	if int(res["first_end_reason"]) != CombatEvent.ComboEndReason.KNOCKDOWN:
		return false
	if int(res["low_float_frame"]) != int(res["knock_frame"]):
		return false
	if float(res["knock_wall"]) < -0.000001 or float(res["knock_wall"]) > 12.000001:
		return false
	if not bool(res["field_side"]):
		return false
	var recoveries: Array = res["d_recoveries"]
	if recoveries.size() != 2:
		return false
	for rec in recoveries:
		if int(rec["exit"]) <= 0 or int(rec["b_start"]) <= 0 or not bool(rec["via_link"]):
			return false
	return true


# --- 1. C6 资源与数值表（唯一新增正式参数）---

func _test_c6_resources() -> void:
	var table := MoveData.default_table()
	var two_c := table["2C"] as MoveData
	_check(two_c.startup_frames == 6, "C6：2C 前摇 9N→6N（当前 %d）" % two_c.startup_frames)
	_check(two_c.active_frames == 3 and two_c.recovery_frames == 18 and two_c.base_damage == 14,
		"2C active 3N/recovery 18N/伤害 14 不随 C6 改写")
	_check(two_c.is_finisher == false, "2C 保持非 FINISHER（不加标记凑终点）")
	var normal := MoveData.profile_for(two_c, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	var counter := MoveData.profile_for(two_c, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.COUNTER)
	_check(normal != null and normal.reaction == HitProfile.Reaction.LOW_FLOAT_SWEEP
		and normal.air_untech_frames == 20 and _approx(normal.horizontal_speed_px_s, 140.0)
		and _approx(normal.upward_speed_px_s, 120.0) and normal.knockdown_frames == 30,
		"2C 对地 NORMAL 低浮空资料保持（20N/140/120/倒地30N）")
	_check(counter != null and counter.air_untech_frames == 26,
		"2C 对地 COUNTER 不可受身 26N 保持")
	_check(two_c.chain_cancel_targets == ["6D", "2D"] and two_c.special_cancel_targets == ["214C"]
		and two_c.special_cancel_window_frames == 5,
		"2C 链式 6D/2D 与必杀 214C 出口保持")
	_check(two_c.requires_crouch, "2C 保持蹲姿识别（下+C）")
	var b5 := table["5B"] as MoveData
	var b5_gnd := MoveData.profile_for(b5, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	_check(b5_gnd != null and b5_gnd.ground_stun_frames == 14, "5B 对地普通硬直 14N 保持（不合并 Q19）")
	var rekka := table["214C"] as MoveData
	var rekka_gnd := MoveData.profile_for(rekka, HitProfile.TargetState.GROUNDED, HitProfile.HitContext.NORMAL)
	_check(rekka.startup_frames == 8 and rekka_gnd != null and rekka_gnd.ground_stun_frames == 14,
		"214C 前摇 8N/对地普通硬直 14N 保持（不合并 V1/P18/V3b/V4）")
	var finisher_ids: Array[String] = []
	for move_id in table:
		if (table[move_id] as MoveData).is_finisher:
			finisher_ids.append(move_id)
	_check(finisher_ids == ["214C~C"], "全表仅 214C~C 为 FINISHER（2C/~B 均非，实际 %s）" % str(finisher_ids))


# --- 2. 冻结参考路线（代表点 g9.3/r6.7，双面向）---

func _test_r3_reference() -> void:
	for kind in ["B", "C"]:
		var expected_hits: Array = EXPECT_HITS_B if kind == "B" else EXPECT_HITS_C
		var expect_knock := EXPECT_KNOCK_B if kind == "B" else EXPECT_KNOCK_C
		for facing in [1, -1]:
			var res := _run_route(_r3_plan(kind, facing), facing, 9.3, 6.7)
			_check(res["hits"] == expected_hits,
				"R3-%s facing=%+d 冻结参考准确命中帧 10/9 HIT（实际 %s）" % [kind, facing, str(res["hits"])])
			_check(res["hit_moves"] == (R3_SEQ_B if kind == "B" else R3_SEQ_C),
				"R3-%s facing=%+d 准确动作序列（实际 %s）" % [kind, facing, str(res["hit_moves"])])
			_check(_route_ok(kind, res),
				"R3-%s facing=%+d 完整合同：两轮 D 完整恢复后 B、零换边、首END=实际倒地 KNOCKDOWN、原墙0–12px、场内侧" % [kind, facing])
			_check(int(res["knock_frame"]) == expect_knock and _approx(float(res["knock_wall"]), 0.0, 0.001),
				"R3-%s facing=%+d 首次实际普通倒地 F%d、原墙 0px（实际 F%d、%.3fpx）" % [kind, facing, expect_knock, int(res["knock_frame"]), float(res["knock_wall"])])
			var recoveries: Array = res["d_recoveries"]
			_check(recoveries.size() == 2 and int(recoveries[0]["b_start"]) > 0 and int(recoveries[1]["b_start"]) > 0
				and bool(recoveries[0]["via_link"]) and bool(recoveries[1]["via_link"]),
				"R3-%s facing=%+d 两轮 5D 均完整恢复后 5B 命中限定连接（D 段 %s）" % [kind, facing, str(recoveries)])


# --- 3. 保证域有限扫描（同一套跨距离共用参考；不逐站位重锚）---

func _test_r3_domain_sweep() -> void:
	var points: Array = []
	for g in DOMAIN_G:
		for r in DOMAIN_R:
			points.append([g, r])
	points.append_array(DOMAIN_EXTRA)
	points.append([9.3, 6.7])
	var fails: Array[String] = []
	for kind in ["B", "C"]:
		for facing in [1, -1]:
			var plan := _r3_plan(kind, facing)
			for point in points:
				var res := _run_route(plan, facing, point[0], point[1])
				if not _route_ok(kind, res):
					fails.append("R3-%s/f%+d/g%s/r%s（击 %d/换边 %d/倒地 F%d/墙 %.2f）" % [kind, facing, str(point[0]), str(point[1]), (res["hits"] as Array).size(), int(res["swaps"]), int(res["knock_frame"]), float(res["knock_wall"])])
	_check(fails.is_empty(), "保证域 96 站位×B/C×双面向=384 全过（首个失败：%s）" % (fails[0] if not fails.is_empty() else "无"))
	# 触墙阈值邻点（阶段 B 右墙 B/g0 首触墙 r≈2.12784 两侧；有限邻点采样）。
	var boundary_ok := true
	for kind in ["B", "C"]:
		for facing in [1, -1]:
			for g in [0.0, 9.0, 18.0]:
				for r in [2.1278, 2.1279]:
					if not _route_ok(kind, _run_route(_r3_plan(kind, facing), facing, g, r)):
						boundary_ok = false
	_check(boundary_ok, "触墙阈值邻点（r=2.1278/2.1279×g{0,9,18}×双面向）路线不受首触墙帧变化影响")
	print("  域扫描覆盖：9×7 网格 + 32 非整数点 + 代表点 = 96 站位×4 = 384；步长与非整数样点为有限采样，非连续域穷尽")


# --- 4. 关键键窗口（单组平移，其余输入固定；D122 记录项不设门槛）---

func _test_r3_windows() -> void:
	for kind in ["B", "C"]:
		var expected: Dictionary = EXPECT_WINDOWS[kind]
		var first_key := "c1" if kind == "B" else "m1"
		for key in expected:
			var anchor := int(_r3_anchors(kind)[key])
			var lo_expected: int = expected[key][0]
			var hi_expected: int = expected[key][1]
			for facing in [1, -1]:
				var window: Array[int] = []
				for delta in range(-14, 19):
					var shifted := anchor + delta
					if shifted <= 1:
						continue
					var res := _run_route(_r3_plan(kind, facing, {key: delta}), facing, 9.3, 6.7)
					if _route_ok(kind, res):
						window.append(shifted)
				var contiguous := true
				for i in range(1, window.size()):
					if window[i] != window[i - 1] + 1:
						contiguous = false
				_check(not window.is_empty() and contiguous and window[0] == lo_expected and window[window.size() - 1] == hi_expected,
					"R3-%s facing=%+d 关键键 %s 成功闭区间 [%d,%d]（实际 [%s]，锚 %d）" % [kind, facing, key, lo_expected, hi_expected, (str(window[0]) + "…" + str(window[window.size() - 1])) if not window.is_empty() else "空", anchor])
		# 锚本身在窗内（参考可冻结）。
		for key in expected:
			var anchor := int(_r3_anchors(kind)[key])
			_check(anchor >= expected[key][0] and anchor <= expected[key][1],
				"R3-%s 冻结锚 %s=%d 落在记录窗口 [%d,%d] 内" % [kind, key, anchor, expected[key][0], expected[key][1]])
	print("  窗口记录：代表点单组 −14…+18F 平移扫描，双面向同帧号；无 D112 完整按下/松开维度或 D113 256 组")


# --- 5. 负例（旧 9N 对照、真实窗外、规则与 OTG/结束后新命中）---

func _test_r3_negatives() -> void:
	# 旧 9N 表对照：同输入下 B 首END F167 仅 9 HIT、2C F170 为新命中；
	# C 首END F157 仅 8 HIT、2C F159 为新命中（阶段 B 生产对照，正式版独立复验）。
	var nine := _nine_n_table()
	for kind in ["B", "C"]:
		var want_hits := 9 if kind == "B" else 8
		var want_end := 167 if kind == "B" else 157
		var want_post := 170 if kind == "B" else 159
		var res := _run_route(_r3_plan(kind, 1), 1, 9.3, 6.7, nine)
		_check((res["hits"] as Array).size() == want_hits and int(res["first_end_frame"]) == want_end,
			"9N 旧表对照 R3-%s：首END F%d 仅 %d HIT（实际 F%d、%d HIT）" % [kind, want_end, want_hits, int(res["first_end_frame"]), (res["hits"] as Array).size()])
		var post_2c := false
		for entry in res["post_hits"]:
			if entry[1] == "2C" and entry[0] == want_post:
				post_2c = true
		_check(post_2c and not _route_ok(kind, res),
			"9N 旧表对照 R3-%s：2C F%d 是首END后新命中、后续倒地不拼入首段（post %s）" % [kind, want_post, str(res["post_hits"])])
	# 真实窗外一步（阶段 B 越窗例，facing=+1 代表）：
	var out_cases := [
		["B", {"b2": -2}, 97, "B b2=72：5B 命中但后继 5C 晚于首END F97"],
		["B", {"b2": 2}, -1, "B b2=76：原段仅 4 HIT"],
		["B", {"e3": -2}, -1, "B e3=147：覆盖末次 5B/改招，原段 8 HIT"],
		["B", {"e3": 2}, 167, "B e3=151：2C F168 晚于首END F167"],
		["C", {"e3": -8}, -1, "C e3=135：原段 7 HIT"],
		["C", {"e3": 6}, 157, "C e3=149：2C F158 晚于首END F157"],
	]
	for case in out_cases:
		var kind: String = case[0]
		var res := _run_route(_r3_plan(kind, 1, case[1]), 1, 9.3, 6.7)
		var ok_boundary := not _route_ok(kind, res)
		if int(case[2]) > 0:
			ok_boundary = ok_boundary and int(res["first_end_frame"]) == int(case[2])
		_check(ok_boundary, "%s（实际：击 %d/首END F%d）" % [case[3], (res["hits"] as Array).size(), int(res["first_end_frame"])])
	# 窗口端点相邻帧真实失败（c2/b3 与 C 侧 b2/b3 边界）。
	var edge_cases := [
		["B", "c2", 77], ["B", "c2", 81], ["B", "b3", 141], ["B", "b3", 146],
		["C", "b2", 54], ["C", "b2", 66], ["C", "b3", 129], ["C", "b3", 137],
	]
	for edge in edge_cases:
		var kind: String = edge[0]
		var key: String = edge[1]
		var frame_wanted: int = edge[2]
		var delta := frame_wanted - int(_r3_anchors(kind)[key])
		var res := _run_route(_r3_plan(kind, 1, {key: delta}), 1, 9.3, 6.7)
		_check(not _route_ok(kind, res), "R3-%s %s=%d（窗端相邻帧）真实失败（击 %d/首END F%d）" % [kind, key, frame_wanted, (res["hits"] as Array).size(), int(res["first_end_frame"])])
	# 规则负例。
	var mis_charge := _r3_plan("B", 1)
	mis_charge[45] = _press("D")
	for frame in range(46, 46 + 17):
		mis_charge[frame] = _hold("D")
	var charged := _run_route(mis_charge, 1, 9.3, 6.7)
	_check((charged["hit_moves"] as Array).has("5[D]") and not _route_ok("B", charged),
		"误蓄力 D 提交 5[D]，不构成两轮普通 D 样本（序列 %s）" % str(charged["hit_moves"]))
	var no_cancel := _r3_plan("B", 1)
	no_cancel.erase(117)
	var seg2 := _run_route(no_cancel, 1, 9.3, 6.7)
	_check((seg2["hit_moves"] as Array).count("5D") == 1 and not _route_ok("B", seg2),
		"236C 第二段未取消（无 D 消费）：缺第二轮 5D、样本失败（击 %d/序列 %s）" % [(seg2["hit_moves"] as Array).size(), str(seg2["hit_moves"])])
	var one_round := _r3_plan("B", 1, {}, 1, "2c")
	one_round[149] = _press("C", 0, true)
	var short_route := _run_route(one_round, 1, 9.3, 6.7)
	_check(not _route_ok("B", short_route), "删中间一轮不构成两轮样本（击 %d）" % (short_route["hit_moves"] as Array).size())
	var no_down := _r3_plan("B", 1)
	no_down[149] = _press("C")
	var standing_c := _run_route(no_down, 1, 9.3, 6.7)
	_check(not (standing_c["hit_moves"] as Array).has("2C") and (standing_c["hit_moves"] as Array).size() > 0,
		"末段未输入下方向出 5C 而非 2C（序列尾 %s）" % str((standing_c["hit_moves"] as Array).back()))
	# 被防：无命中专用资格（全程蹲防挡下全部段位，首击被防整段无 HIT、无倒地；
	# 站防漏低段由 2C 影响组单独覆盖）。
	var blocked := _run_route(_r3_plan("B", 1), 1, 9.3, 6.7, null, ROUTE_HORIZON, CombatSession.GuardPosture.CROUCH)
	_check((blocked["hits"] as Array).is_empty() and int(blocked["knock_frame"]) == -1,
		"被防不取得命中专用资格（HIT %d、倒地 F%d）" % [(blocked["hits"] as Array).size(), int(blocked["knock_frame"])])
	# 挥空：范围外 g=200 对照，首击挥空。
	var whiff := _run_route(_r3_plan("B", 1), 1, 200.0, 6.7)
	_check((whiff["hits"] as Array).is_empty() and not _route_ok("B", whiff), "范围外挥空无命中（域外对照 g=200，HIT %d）" % (whiff["hits"] as Array).size())
	# 恢复前强行出招：D 恢复前缓存过期（b2=60 早于第一轮 D 恢复）。
	var early := _run_route(_r3_plan("B", 1, {"b2": -14}), 1, 9.3, 6.7)
	_check(not _route_ok("B", early), "D 恢复前过早 5B（b2=60）不构成样本（击 %d/序列 %s）" % [(early["hits"] as Array).size(), str(early["hit_moves"])])
	# OTG 与结束后新命中：完整两轮倒地后 F200 按 B——倒地期间（KNOCKED_DOWN
	# 逐帧状态）无 HIT，木桩起身后命中另列（不并入首段、不冒充 OTG 追击）。
	var post_plan := _r3_plan("B", 1)
	post_plan[200] = _press("B")
	var post := _run_route(post_plan, 1, 9.3, 6.7, null, 235)
	var otg_or_premature := false
	var states: Array = post["dummy_states"]
	for entry in post["post_hits"]:
		if int(states[int(entry[0]) - 1]) == CombatSession.DummyState.KNOCKED_DOWN:
			otg_or_premature = true
	var post_clean: Dictionary = (post as Dictionary).duplicate()
	post_clean["post_hits"] = []
	_check(_route_ok("B", post_clean) and not otg_or_premature,
		"倒地后按 B：KNOCKED_DOWN 期间无 HIT，起身后命中在首段之外另账（post %s、首次起身 F%d）" % [str(post["post_hits"]), int(post["recovered_frame"])])
	# 浅层 OTG 负例：直接 5B>2C 命中停顿使 2C 收招至 F52；F53 按 B（判定
	# F60–64）与 KNOCKED_DOWN（F42–F64）重叠、无 HIT，F65 起身后无补击。
	var otg_plan := {1: _press("B"), 12: _press("C", 0, true), 53: _press("B")}
	var otg := _run_route(otg_plan, 1, 9.3, 6.7, null, 95)
	var otg_states: Array = otg["dummy_states"]
	var otg_overlap := false
	var otg_hit := false
	var second_5b_started := false
	for i in range(otg["frames"].size()):
		var frame := i + 1
		var st = otg["frames"][i]
		if frame >= 54 and st.player_move.move_id == "5B":
			second_5b_started = true
		if second_5b_started and st.player_move.move_id == "5B" and int(otg_states[i]) == CombatSession.DummyState.KNOCKED_DOWN:
			otg_overlap = true
	for entry in otg["post_hits"]:
		if int(otg_states[int(entry[0]) - 1]) == CombatSession.DummyState.KNOCKED_DOWN:
			otg_hit = true
	_check(otg_overlap and not otg_hit,
		"浅层 2C 倒地后 5B 与 KNOCKED_DOWN 重叠期间无 HIT（重叠 %s、倒地期间命中 %s）" % [str(otg_overlap), str(otg_hit)])


# --- 6. 同表三收尾条件（固定点：准确计数、实际倒地/保位、正确/错误形态）---

func _tail_expected(kind: String, depth: int) -> Array:
	# depth: 0=直接5B、1=一轮 D 后 5B、2=两轮 D 后 5B。返回前缀动作序列。
	var prefix_b := {
		0: ["5B"],
		1: ["5B", "5C", "236C", "5D", "5B"],
		2: ["5B", "5C", "236C", "5D", "5B", "5C", "236C", "5D", "5B"],
	}
	var prefix_c := {
		1: ["5C", "236C", "5D", "5B"],
		2: ["5C", "236C", "5D", "5B", "5C", "236C", "5D", "5B"],
	}
	if kind == "B":
		return prefix_b[depth]
	return prefix_c[depth]


func _tail_ok(kind: String, depth: int, tail: String, res: Dictionary) -> bool:
	var tail_move := "2C" if tail == "2c" else ("214C~B" if tail == "~B" else "214C~C")
	var seq: Array = _tail_expected(kind, depth)
	if tail != "2c":
		seq = seq.duplicate()
		seq.append("214C")
	seq = seq.duplicate()
	seq.append(tail_move)
	if res["hit_moves"] != seq:
		return false
	if int(res["swaps"]) != 0 or not (res["post_hits"] as Array).is_empty():
		return false
	if int(res["knock_frame"]) <= 0 or int(res["first_end_frame"]) != int(res["knock_frame"]):
		return false
	if int(res["first_end_reason"]) != CombatEvent.ComboEndReason.KNOCKDOWN:
		return false
	if float(res["knock_wall"]) < -0.000001 or float(res["knock_wall"]) > 12.000001:
		return false
	if not bool(res["field_side"]):
		return false
	return true


func _tail_plan(kind: String, facing: int, depth: int, tail: String, submit: int, derive := -1) -> Dictionary:
	var plan := {}
	if depth == 0:
		plan[1] = _press("B")
	else:
		var a := _r3_anchors(kind)
		var rounds := 1 if depth == 1 else 2
		plan = _r3_plan(kind, facing, {}, rounds, "none")
		if depth == 1:
			pass  # _r3_plan rounds=1 已含 b2（末次 5B）
	if tail == "2c":
		plan[submit] = _press("C", 0, true)
	else:
		_add_214(plan, submit, facing)
		plan[derive] = _press("B" if tail == "~B" else "C")
	return plan


func _test_r3_tails() -> void:
	# 直接 5B（浅层）：三尾全成立，零换边、首次倒地原墙 0px、玩家场内侧。
	var direct_2c := _run_route(_tail_plan("B", 1, 0, "2c", 12), 1, 9.3, 6.7, null, 80)
	_check(_tail_ok("B", 0, "2c", direct_2c) and direct_2c["hits"] == [10, 25] and int(direct_2c["knock_frame"]) == 42,
		"直接 5B>2C：2 HIT F[10,25]、倒地 F42（实际 %s/F%d）" % [str(direct_2c["hits"]), int(direct_2c["knock_frame"])])
	var direct_tb := _run_route(_tail_plan("B", 1, 0, "~B", 12, 28), 1, 9.3, 6.7, null, 80)
	_check(_tail_ok("B", 0, "~B", direct_tb) and int(direct_tb["knock_frame"]) == 43,
		"直接 5B>214C~B：3 HIT、倒地 F43（实际 %d HIT/F%d）" % [(direct_tb["hits"] as Array).size(), int(direct_tb["knock_frame"])])
	var direct_tc := _run_route(_tail_plan("B", 1, 0, "~C", 12, 28), 1, 9.3, 6.7, null, 80)
	_check(_tail_ok("B", 0, "~C", direct_tc) and int(direct_tc["knock_frame"]) == 45,
		"直接 5B>214C~C：3 HIT、倒地 F45（实际 %d HIT/F%d）" % [(direct_tc["hits"] as Array).size(), int(direct_tc["knock_frame"])])
	# 一轮 D 后 5B：2C 与 ~B 成立；~C 正确形态下派生晚于首 END。
	var one_b_2c := _run_route(_tail_plan("B", 1, 1, "2c", 84), 1, 9.3, 6.7, null, 140)
	_check(_tail_ok("B", 1, "2c", one_b_2c) and int(one_b_2c["knock_frame"]) == 113,
		"B 一轮>2C@84：6 HIT、倒地 F113（实际 %d HIT/F%d）" % [(one_b_2c["hits"] as Array).size(), int(one_b_2c["knock_frame"])])
	var one_b_tb := _run_route(_tail_plan("B", 1, 1, "~B", 79, 104), 1, 9.3, 6.7, null, 140)
	_check(_tail_ok("B", 1, "~B", one_b_tb) and int(one_b_tb["knock_frame"]) == 115,
		"B 一轮>214C~B@79/104：7 HIT、倒地 F115（实际 %d HIT/F%d）" % [(one_b_tb["hits"] as Array).size(), int(one_b_tb["knock_frame"])])
	var one_b_tc := _run_route(_tail_plan("B", 1, 1, "~C", 79, 97), 1, 9.3, 6.7, null, 140)
	_check((one_b_tc["hits"] as Array).size() == 6 and int(one_b_tc["first_end_frame"]) == 115
		and not (one_b_tc["hit_moves"] as Array).has("214C~C"),
		"B 一轮>214C~C@79/97 正确形态：原段 6 HIT、首END F115；早派生未锁分支，~C 未在首段成立（实际 %d HIT/END F%d/序列尾 %s/post %s）" % [(one_b_tc["hits"] as Array).size(), int(one_b_tc["first_end_frame"]), str((one_b_tc["hit_moves"] as Array).back()), str(one_b_tc["post_hits"])])
	var one_c_2c := _run_route(_tail_plan("C", 1, 1, "2c", 72), 1, 9.3, 6.7, null, 130)
	_check(_tail_ok("C", 1, "2c", one_c_2c) and int(one_c_2c["knock_frame"]) == 101,
		"C 一轮>2C@72：5 HIT、倒地 F101（实际 %d HIT/F%d）" % [(one_c_2c["hits"] as Array).size(), int(one_c_2c["knock_frame"])])
	var one_c_tb := _run_route(_tail_plan("C", 1, 1, "~B", 71, 93), 1, 9.3, 6.7, null, 130)
	_check(_tail_ok("C", 1, "~B", one_c_tb) and int(one_c_tb["knock_frame"]) == 103,
		"C 一轮>214C~B@71/93：6 HIT、倒地 F103（实际 %d HIT/F%d）" % [(one_c_tb["hits"] as Array).size(), int(one_c_tb["knock_frame"])])
	var one_c_tc := _run_route(_tail_plan("C", 1, 1, "~C", 71, 89), 1, 9.3, 6.7, null, 130)
	_check(int(one_c_tc["first_end_frame"]) == 104 and not (one_c_tc["post_hits"] as Array).is_empty(),
		"C 一轮>214C~C@71/89 正确形态：~C F105 晚于首END F104（实际 END F%d/post %s）" % [int(one_c_tc["first_end_frame"]), str(one_c_tc["post_hits"])])
	# 两轮 D 后 5B：2C 为冻结必保参考；C 侧另存在条件 142。
	var two_b_2c := _run_route(_tail_plan("B", 1, 2, "2c", 149), 1, 9.3, 6.7)
	_check(_tail_ok("B", 2, "2c", two_b_2c) and int(two_b_2c["knock_frame"]) == 181,
		"B 两轮>2C@149（冻结参考）：10 HIT、倒地 F181（实际 %d HIT/F%d）" % [(two_b_2c["hits"] as Array).size(), int(two_b_2c["knock_frame"])])
	for submit in [142, 143]:
		var two_c_2c := _run_route(_tail_plan("C", 1, 2, "2c", submit), 1, 9.3, 6.7)
		_check(_tail_ok("C", 2, "2c", two_c_2c) and int(two_c_2c["knock_frame"]) == 171,
			"C 两轮>2C@%d：9 HIT、倒地 F171（实际 %d HIT/F%d）" % [submit, (two_c_2c["hits"] as Array).size(), int(two_c_2c["knock_frame"])])
	# 错误形态：未识别 214 方向直接出 5C，不能单独证明 Rekka 不可接。
	var wrong_form := {}
	wrong_form[1] = _press("B")
	wrong_form[12] = _press("C", 1)
	var wrong := _run_route(wrong_form, 1, 9.3, 6.7, null, 80)
	_check((wrong["hit_moves"] as Array).has("5C") and not (wrong["hit_moves"] as Array).has("214C"),
		"未识别 214 出 5C 的错误形态另列（序列 %s）" % str(wrong["hit_moves"]))


# --- 7. 两轮深处 Rekka 搜索盒（0/609 只描述该盒，不证明任意时序无解）---

func _tail_box(kind: String, facing: int, depth: int, tail: String, g := 9.3, r := 6.7) -> Dictionary:
	var a := _r3_anchors(kind)
	var cut_frame := int(a["b2"]) if depth == 1 else int(a["b3"])
	var prefix := _r3_plan(kind, facing, {}, 1 if depth == 1 else 2, "none")
	var session := _place(g, r, facing)
	for frame in range(1, cut_frame + 1):
		session.step(prefix.get(frame, _neutral()))
	var state := session.clone_state()
	var successes := 0
	var trials := 0
	var rekka_connected := 0
	for submit in range(cut_frame + 4, cut_frame + 25):
		for derive in range(submit + 4, submit + 33):
			trials += 1
			var restored := CombatSession.new()
			if not restored.restore_state(state):
				return {"error": "restore refused"}
			var tail_plan := {}
			_add_214(tail_plan, submit, facing)
			tail_plan[derive] = _press("B" if tail == "~B" else "C")
			var res := _run_route_on(restored, tail_plan, facing, cut_frame + 1, cut_frame + 150)
			if _tail_ok(kind, depth, tail, res):
				successes += 1
			if (res["hit_moves"] as Array).has("214C"):
				rekka_connected += 1
	return {"successes": successes, "trials": trials, "rekka_connected": rekka_connected}


func _test_r3_tail_boxes() -> void:
	# 搜索盒：末次 5B 后 +4…+24F 提交、提交后 +4…+32F 派生 = 21×29=609。
	# 两轮深处 ~B/~C 全盒 0 成功（B 首缝 5B→214C 断；C 214C 可接、派生断）。
	for kind in ["B", "C"]:
		for facing in [1, -1]:
			for tail in ["~B", "~C"]:
				var box := _tail_box(kind, facing, 2, tail)
				_check(box.get("error", "") == "" and int(box["successes"]) == 0 and int(box["trials"]) == 609,
					"R3-%s facing=%+d 两轮 %s 搜索盒 0/609（实际 %s/%s）" % [kind, facing, tail, str(box.get("successes")), str(box.get("trials"))])
				if kind == "C":
					_check(int(box.get("rekka_connected", 0)) > 0,
						"R3-C facing=%+d 两轮 %s：214C 本身可接、断在派生（214C 命中格 %s）" % [facing, tail, str(box.get("rekka_connected"))])
				else:
					_check(int(box.get("rekka_connected", 0)) == 0,
						"R3-B facing=%+d 两轮 %s：5B→214C 首缝断（214C 命中格 %s）" % [facing, tail, str(box.get("rekka_connected"))])
	# 一轮 ~C 盒同样 0/609（正确形态失败例已在上文固定点保存）。
	for kind in ["B", "C"]:
		var box := _tail_box(kind, 1, 1, "~C")
		_check(int(box["successes"]) == 0 and int(box["trials"]) == 609,
			"R3-%s 一轮 ~C 搜索盒 0/609（实际 %s/%s）" % [kind, str(box.get("successes")), str(box.get("trials"))])
	print("  搜索盒：代表点 g9.3/r6.7，末次B后 +4…+24 提交、+4…+32 派生；0/609 只限此盒与代表点，不声称任意时序无解")


# --- 8. 保存恢复逐切点续跑（D 恢复/等待/消费、Hitstop、2C 启动/低浮空/倒地）---

func _test_r3_save_restore() -> void:
	var facing := 1
	var plan := _r3_plan("B", facing)
	var baseline_session := _place(9.3, 6.7, facing)
	var baseline_events: Array = []
	for frame in range(1, ROUTE_HORIZON + 1):
		for event in baseline_session.step(plan.get(frame, _neutral())):
			baseline_events.append([frame, event.type, event.combo_hits, event.direction, event.combo_end_reason, event.link_fail_reason, event.damage])
	var cuts := [45, 50, 55, 74, 76, 90, 100, 110, 120, 130, 143, 145, 153, 160, 167, 175, 181, 190]
	var mismatch := ""
	for cut in cuts:
		var session := _place(9.3, 6.7, facing)
		var events: Array = []
		for frame in range(1, cut):
			for event in session.step(plan.get(frame, _neutral())):
				events.append([frame, event.type, event.combo_hits, event.direction, event.combo_end_reason, event.link_fail_reason, event.damage])
		var state := session.clone_state()
		var restored := CombatSession.new()
		if not restored.restore_state(state):
			mismatch = "cut %d restore_state 拒绝" % cut
			break
		for frame in range(cut, ROUTE_HORIZON + 1):
			for event in restored.step(plan.get(frame, _neutral())):
				events.append([frame, event.type, event.combo_hits, event.direction, event.combo_end_reason, event.link_fail_reason, event.damage])
		if events != baseline_events or not _approx(restored.player_position.x, baseline_session.player_position.x, 0.001) or not _approx(restored.dummy_position.x, baseline_session.dummy_position.x, 0.001):
			mismatch = "cut %d 事件流/终态不等价" % cut
			break
	_check(mismatch == "", "R3-B 逐切点保存续跑与不中断回放逐事件等价（%s）" % mismatch)


# --- 9. 2C 攻防/接续影响（C6 整招加快的正式对照）---

func _test_two_c_effects() -> void:
	# 中立 2C（下+C F1，组合等待后 F4 启动）：命中 F10、低浮空、触地 F28 同帧
	# KNOCKED_DOWN；无后续输入时取消窗先关（END F27 CANCEL_WINDOW_CLOSED），
	# 实际倒地与 END 分列记录。
	var neutral_plan := {1: _press("C", 0, true)}
	var neutral := _run_route(neutral_plan, 1, 2.0, 50.0, null, 60)
	_check((neutral["hits"] as Array).size() == 1 and (neutral["hits"] as Array)[0] == 10,
		"中立 2C 命中 F10（9N 时 F13）（实际 %s）" % str(neutral["hits"]))
	_check(int(neutral["knock_frame"]) == 28 and int(neutral["low_float_frame"]) == 28,
		"中立 2C 低浮空触地 F28 同帧转普通倒地（实际倒地 F%d/触地 F%d）" % [int(neutral["knock_frame"]), int(neutral["low_float_frame"])])
	_check(int(neutral["first_end_frame"]) == 27 and int(neutral["first_end_reason"]) == CombatEvent.ComboEndReason.CANCEL_WINDOW_CLOSED,
		"中立单发 2C 无后续输入：首END F27 取消窗关闭，倒地不计入已结束连段（实际 F%d/原因 %d）" % [int(neutral["first_end_frame"]), int(neutral["first_end_reason"])])
	# 挥空：恢复提前 3F（最后一招帧 F29、F30 起可行动；9N 时 F33/F34）。
	var whiff := _run_route(neutral_plan, 1, 200.0, 50.0, null, 60)
	var first_idle := -1
	var last_move := -1
	for i in range(whiff["frames"].size()):
		var st = whiff["frames"][i]
		if st.player_move.move_id == "2C":
			last_move = i + 1
		elif last_move > 0 and first_idle == -1 and st.player.phase == CombatSession.PlayerPhase.NEUTRAL:
			first_idle = i + 1
	_check(last_move == 29 and first_idle == 30, "挥空 2C 最后一招帧 F29、F30 起可行动（9N 时 F33/F34）（实际 %d/%d）" % [last_move, first_idle])
	# 站防漏低段：站防被 2C 命中（低段）；蹲防挡下。
	var standing := _run_route(neutral_plan, 1, 2.0, 50.0, null, 60, CombatSession.GuardPosture.STANDING)
	_check((standing["hits"] as Array).size() == 1, "站防漏低段：2C 命中站防木桩（HIT %d）" % (standing["hits"] as Array).size())
	var crouch := _run_route(neutral_plan, 1, 2.0, 50.0, null, 60, CombatSession.GuardPosture.CROUCH)
	_check((crouch["hits"] as Array).is_empty(), "蹲防挡下 2C（HIT %d）" % (crouch["hits"] as Array).size())
	# Counter：木桩 5C 启动中被 2C 命中为 Counter（应用计时按 C 起手修正，不回写资料）。
	var counter_hits := 0
	var counter_session := _place(2.0, 50.0, 1)
	for frame in range(1, 60):
		var input := FrameInput.new()
		if frame == 1:
			input.down_held = true
			input.pressed_action_keys = ["C"]
			input.held_action_keys = ["C"]
		if frame == 8:
			input.dummy_move_request = "5C"
		for event in counter_session.step(input):
			if event.type == CombatEvent.Type.HIT and event.is_counter:
				counter_hits += 1
	_check(counter_hits == 1, "2C 命中启动中的木桩 5C 记为 Counter（实际 %d）" % counter_hits)
	# 接续窗：2C 命中后 6D 提交 F5–19、214C 提交 F5–17 成立（9N 时 F8–22/F8–20）。
	for pair in [["6D", [5, 19]], ["214C", [5, 17]]]:
		var follow: String = pair[0]
		var window: Array[int] = []
		for submit in range(5, 42):
			var plan := {1: _press("C", 0, true)}
			if follow == "6D":
				plan[submit] = _press("D", 1)
			else:
				_add_214(plan, submit, 1)
			var res := _run_route(plan, 1, 2.0, 50.0, null, 80)
			var hit_moves: Array = res["hit_moves"]
			if hit_moves.has(follow):
				window.append(submit)
		_check(not window.is_empty() and window[0] == pair[1][0] and window[window.size() - 1] == pair[1][1],
			"2C→%s 成立提交窗 F%d–%d（实际 [%d…%d]）" % [follow, pair[1][0], pair[1][1], window[0] if not window.is_empty() else -1, window[window.size() - 1] if not window.is_empty() else -1])
	# 同首段不追加命中：2D/重复 2C/直接 5B 提交后首段仍只有 2C 一击。
	for extra in [["D", true], ["C", true], ["B", false]]:
		var plan := {1: _press("C", 0, true), 12: _press(extra[0], 0, bool(extra[1]))}
		var res := _run_route(plan, 1, 2.0, 50.0, null, 90)
		_check((res["hits"] as Array).size() == 1,
			"2C 后同帧位 %s 不在首段追加命中（HIT %d）" % [extra[0], (res["hits"] as Array).size()])


# --- 10. D-loop 有限重复（自然首断点取证；不设隐藏次数上限）---

## 固定复制第二轮节拍（B：b→b+5→b+26→b+43，间隔 69；C：b→b+10→b+28→b+44，
## 间隔 71），round3_shift 只平移第三轮起整块；tail 补末次 5B+2C。
func _loop_plan(kind: String, rounds: int, facing := 1, tail := true, round3_shift := 0) -> Dictionary:
	var plan := {}
	var next_b := 0
	if kind == "B":
		plan[1] = _press("B")
		plan[12] = _press("C")
		_add_236(plan, 29, facing)
		plan[45] = _press("D")
		var b := 74
		for round_idx in range(2, rounds + 1):
			if round_idx >= 3:
				b += round3_shift
			plan[b] = _press("B")
			plan[b + 5] = _press("C")
			_add_236(plan, b + 26, facing)
			plan[b + 43] = _press("D")
			b += 69
		next_b = b
		if tail:
			plan[next_b] = _press("B")
			plan[next_b + 6] = _press("C", 0, true)
	else:
		plan[1] = _press("C")
		_add_236(plan, 15, facing)
		plan[31] = _press("D")
		var b := 61
		for round_idx in range(2, rounds + 1):
			if round_idx >= 3:
				b += round3_shift
			plan[b] = _press("B")
			plan[b + 10] = _press("C")
			_add_236(plan, b + 28, facing)
			plan[b + 44] = _press("D")
			b += 71
		next_b = b
		if tail:
			plan[next_b] = _press("B")
			plan[next_b + 11] = _press("C", 0, true)
	return {"plan": plan, "tail_b": next_b, "tail_e": next_b + (6 if kind == "B" else 11)}


func _test_d_loop_repetition() -> void:
	# 固定复制第二轮节拍：1/2 轮完整成立；≥3 轮固定节拍断开、命中另账
	#（未穷举第三轮节拍，不证明禁止合法第三轮，更不证明无无限）。
	for kind in ["B", "C"]:
		for rounds in [1, 2, 3, 4]:
			var built := _loop_plan(kind, rounds)
			var horizon: int = 210 + 80 * int(rounds)
			var res := _run_route(built["plan"], 1, 9.3, 6.7, null, horizon)
			if rounds <= 2:
				_check(_route_ok(kind, res) if rounds == 2 else not _route_ok(kind, res),
					"R3-%s 固定节拍 %d 轮：%s（击 %d）" % [kind, rounds, "两轮完整成立" if rounds == 2 else "一轮非完整样本构型", (res["hits"] as Array).size()])
			else:
				var hit_count := (res["hits"] as Array).size()
				_check(not _route_ok(kind, res) and hit_count < (10 if kind == "B" else 9),
					"R3-%s 固定节拍 %d 轮自然断开：首段击数 %d、尾段命中另账（首END F%d/post %d）" % [kind, rounds, hit_count, int(res["first_end_frame"]), (res["post_hits"] as Array).size()])
	# 第三轮时移小扫描（−40…+10）：是否存在合法第三轮（固定前缀，B 侧代表）。
	var third_found := -999
	for delta in range(-40, 11):
		var built := _loop_plan("B", 3, 1, true, delta)
		var res := _run_route(built["plan"], 1, 9.3, 6.7, null, 420)
		if _route_ok("B", res):
			third_found = delta
			break
	_check(third_found == -999,
		"第三轮 5B 时移 −40…+10 未发现合法三轮全链（有限扫描，不声称任意节拍无解；扫描首命中 %d）" % third_found)
	print("  D-loop：固定节拍 1–4 轮 + 第三轮时移小扫描；两轮是样本构型非次数上限，≥3 轮固定节拍自然断开如实记录")


# --- 11. Solver 精确路线查询（共享表语义一致）---

func _test_solver_route_report() -> void:
	var ids: Array[String] = ["5B", "2C"]
	var report := ComboSolver.route_report(ids)
	var route: ComboSolver.SolverRoute = null
	if not report.refused and not report.routes.is_empty():
		route = report.routes[0]
	_check(route != null and route.timing_valid and (route.hit_frames as Array).size() == 2,
		"Solver 精确查询 5B>2C 时序成立（C6 后 2C 命中帧 %s）" % (str(route.hit_frames) if route != null else "null"))
	var full: Array[String] = []
	for move_id in R3_SEQ_B:
		full.append(str(move_id))
	var full_report := ComboSolver.route_report(full)
	print("  Solver R3-B 全序列查询：refused=%s routes=%d（钉位探针口径，钉位≠版边几何）" % [str(full_report.refused), full_report.routes.size()])
