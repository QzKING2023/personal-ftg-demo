extends SceneTree
## 票据 06：动作内蓄力、计划位移、active 扫掠、身体穿越与换边（M-01..M-04/I-01..I-03）。
## 逐帧输入驱动 CombatSession，验证可观察事件、位置与面向；正反例对照票据验收项。
## 运行：godot --headless --path . -s res://tests/test_charge_motion_sideswap.gd

var _failures := 0


func _initialize() -> void:
	_test_charge_commit_threshold_and_normal_tap()
	_test_charge_release_during_pause_commits_normal()
	_test_pre_start_hold_does_not_accumulate()
	_test_charge_window_has_no_cancels()
	_test_active_sweep_hits_mid_step_target()
	_test_whiff_displacement_and_trajectory_continues()
	_test_hit_displacement_clamps_to_origin_side_body()
	_test_blocked_keeps_original_side()
	_test_wall_clamp_truncates_and_keeps_side()
	_test_charge_cross_sideswap_and_next_frame_facing()
	_test_mirror_cross_facing_left()
	_test_candidate_lock_across_swap()
	_test_charged_5b_link_after_recovery()
	_test_move_table_charge_and_motion_validation()
	_test_solver_charge_edges_and_routes()
	print("")
	if _failures == 0:
		print("ALL CHARGE MOTION SIDESWAP TESTS PASSED")
		quit(0)
	else:
		print(str(_failures) + " TEST(S) FAILED")
		quit(1)


# --- 蓄力提交（I-01/I-02/I-03）---

func _test_charge_commit_threshold_and_normal_tap() -> void:
	# 点按 D：仅按下一帧按住，阈值前走普通 5D——正常出手时序、无蓄力版提交。
	var tap := CombatSession.new()
	tap.dummy_position = tap.player_position + Vector2(70, 0)
	var charged_commit := false
	var hit_frame := -1
	var hit_damage := 0.0
	for frame in range(1, 40):
		for event in tap.step(FrameInput.make(0, false, "D" if frame == 1 else "")):
			if event.type == CombatEvent.Type.CHARGE_COMMITTED and event.charged:
				charged_commit = true
			elif event.type == CombatEvent.Type.HIT:
				hit_frame = frame
				hit_damage = event.damage
		if frame == 1:
			_check(tap.player_move_id == "5D", "tap D starts the plain 5D")
	_check(hit_frame == 8, "tap 5D hits on the normal first active frame (start + 7, got %d)" % hit_frame)
	_check(_approx(hit_damage, 18.0), "tap 5D deals the plain 5D damage")
	_check(not charged_commit, "tap D never commits the charged version")
	# 按住 D 至阈值：active 边界延长 startup，达阈值自动提交 5[D]（不等待松键）。
	var hold := CombatSession.new()
	hold.dummy_position = hold.player_position + Vector2(70, 0)
	var commit_frame := -1
	var committed_age := -1
	var move_id_at_commit := ""
	hit_frame = -1
	hit_damage = 0.0
	for frame in range(1, 50):
		for event in hold.step(_d_input(frame, 1, 20)):
			if event.type == CombatEvent.Type.CHARGE_COMMITTED:
				commit_frame = frame
				committed_age = event.charge_age
				move_id_at_commit = hold.player_move_id
			elif event.type == CombatEvent.Type.HIT:
				hit_frame = frame
				hit_damage = event.damage
	_check(commit_frame == 9 and committed_age == 8,
		"holding D commits the charged version at the earliest normal frame with age = threshold (%d, %d)" % [
			commit_frame, committed_age,
		])
	_check(move_id_at_commit == "5[D]", "the charged commit switches the running move id")
	_check(hit_frame == 10 and _approx(hit_damage, 20.0), "5[D] hits after the commit frame with the charged damage (%d, %.1f)" % [hit_frame, hit_damage])
	# 蓄力版后摇更长：资源声明层面可区分（22 vs 18）。
	_check((MoveData.default_table()["5D"] as MoveData).recovery_frames \
			< (MoveData.default_table()["5[D]"] as MoveData).recovery_frames,
		"the charged resource declares a longer recovery")


func _test_charge_release_during_pause_commits_normal() -> void:
	# 阈值前松开：延长中的 startup 以普通版提交——出手比正常晚（延长计入），
	# 但身份/伤害仍是 5D。
	var run := CombatSession.new()
	run.dummy_position = run.player_position + Vector2(70, 0)
	var commit_frame := -1
	var committed_charged := true
	var hit_damage := 0.0
	var hit_frame := -1
	for frame in range(1, 40):
		for event in run.step(_d_input(frame, 1, 8)):
			if event.type == CombatEvent.Type.CHARGE_COMMITTED:
				commit_frame = frame
				committed_charged = event.charged
			elif event.type == CombatEvent.Type.HIT:
				hit_frame = frame
				hit_damage = event.damage
	_check(commit_frame == 9 and not committed_charged, "releasing during the extended startup commits the plain version (%d, %s)" % [
		commit_frame, str(committed_charged),
	])
	_check(hit_frame == 10 and _approx(hit_damage, 18.0),
		"the delayed plain commit still deals plain 5D damage (%d, %.1f)" % [hit_frame, hit_damage])


func _test_pre_start_hold_does_not_accumulate() -> void:
	# 启动前按住不积攒（I-01 拒绝例）：无新按下的长期按住不产生任何 D 起手；
	# 之后的真按下从动作启动重新计龄。
	var run := CombatSession.new()
	run.dummy_position = run.player_position + Vector2(70, 0)
	var move_started := false
	for frame in range(1, 31):
		var input := FrameInput.new()
		if frame <= 20:
			var held: Array[String] = ["D"]
			input.held_action_keys = held
		elif frame == 21:
			input = FrameInput.make(0, false, "D")
			var held: Array[String] = ["D"]
			input.held_action_keys = held
		run.step(input)
		if run.player_move_id != "":
			move_started = true
			_check(frame == 21, "the D request only starts on a fresh press (%d)" % frame)
			break
	_check(move_started, "long-held D without a fresh press never starts the move")
	var commit_frame := -1
	for frame in range(22, 50):
		for event in run.step(_d_input(frame, 0, 40)):
			if event.type == CombatEvent.Type.CHARGE_COMMITTED:
				commit_frame = frame
	_check(commit_frame == 29, "charge age counts from the real move start, not the pre-start hold (%d)" % commit_frame)


func _test_charge_window_has_no_cancels() -> void:
	# 蓄力提交不改变取消资格（I-02）：延长 startup 期间无接触、无取消目标开放。
	var session := CombatSession.new()
	session.dummy_position = session.player_position + Vector2(70, 0)
	var saw_cancel_targets := false
	for frame in range(1, 30):
		session.step(_d_input(frame, 1, 20))
		saw_cancel_targets = saw_cancel_targets or not (session.debug_snapshot()["cancel_targets"] as Array).is_empty()
	_check(not saw_cancel_targets, "the uncommitted charge window never opens cancel targets")


# --- 计划位移（M-01/M-03）---

func _test_active_sweep_hits_mid_step_target() -> void:
	# M-03：active 帧使用起点到计划姿态的扫掠覆盖——起点命中框与木桩不重叠、
	# 计划步长跨入身体时该帧即命中（若无扫掠则要等到下一帧的完整姿态）。
	var run := CombatSession.new()
	run.dummy_position = run.player_position + Vector2(120, 0)
	var hit_frame := -1
	for frame in range(1, 30):
		for event in run.step(FrameInput.make(0, false, "D" if frame == 1 else "")):
			if event.type == CombatEvent.Type.HIT:
				hit_frame = frame
	_check(hit_frame == 8, "the swept active frame connects a mid-step target the start pose misses (%d)" % hit_frame)


func _test_whiff_displacement_and_trajectory_continues() -> void:
	# 挥空：5D 全程 72px 突进照常走完（挥空后轨迹继续），分布在 4 个 active 帧，
	# startup/recovery 不移动。木桩在左——面向与动作方向为 -1，位移取负号。
	var run := CombatSession.new()
	run.dummy_position = Vector2(60.0, GameParams.ground_stand_y())
	var start_x := run.player_position.x
	var startup_drift := 0.0
	for frame in range(1, 40):
		run.step(FrameInput.make(0, false, "D" if frame == 1 else ""))
		if frame == 7:
			startup_drift = run.player_position.x - start_x
	_check(_approx(startup_drift, 0.0), "startup frames do not move the player (%.1f)" % startup_drift)
	_check(_approx(run.player_position.x - start_x, -72.0, 0.01), "the whiffed 5D completes its full declared displacement (%.1f)" % (run.player_position.x - start_x))
	# 5[D] 挥空全程 120px。
	var charged := CombatSession.new()
	charged.dummy_position = Vector2(60.0, GameParams.ground_stand_y())
	start_x = charged.player_position.x
	for frame in range(1, 60):
		charged.step(_d_input(frame, 1, 20))
	_check(_approx(charged.player_position.x - start_x, -120.0, 0.01), "the whiffed 5[D] completes 120 px (%.1f)" % (charged.player_position.x - start_x))


func _test_hit_displacement_clamps_to_origin_side_body() -> void:
	# 命中但轨迹不足以到达另一侧合法位置（普通 5D 72px 捞起前置浮空）：
	# 终点与木桩重叠时截在原侧身体边界（M-02：不补足距离、不瞬移），无换边。
	var session := _float_pickup_session(70, 1)
	var swap_events := 0
	for frame in range(1, 60):
		for event in session.step(_entry_script_input(frame, 16, false)):
			if event.type == CombatEvent.Type.SWITCHED_SIDES:
				swap_events += 1
	var dx_after := session.player_position.x - session.dummy_position.x
	_check(dx_after <= -GameParams.BODY_SIZE.x + 0.01 and dx_after > -GameParams.BODY_SIZE.x - 4.0,
		"insufficient trajectory keeps the player on the origin side at the body boundary (%.1f)" % dx_after)
	_check(swap_events == 0 and session.player_facing == 1, "no sideswap without a legal far-side endpoint")


func _test_blocked_keeps_original_side() -> void:
	# 被防：位移不得越过目标到另一侧（M-02 拒绝例）——截在原侧身体边界，
	# 无 SWITCHED_SIDES。
	var run := CombatSession.new()
	run.dummy_position = run.player_position + Vector2(70, 0)
	var blocked := false
	var swapped := false
	for frame in range(1, 40):
		var input := FrameInput.make(0, false, "D" if frame == 1 else "")
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		for event in run.step(input):
			if event.type == CombatEvent.Type.ATTACK_BLOCKED:
				blocked = true
			elif event.type == CombatEvent.Type.SWITCHED_SIDES:
				swapped = true
	_check(blocked, "the standing guard blocks the 5D")
	_check(_approx(run.player_position.x - run.dummy_position.x, -GameParams.BODY_SIZE.x, 0.01),
		"a blocked D is clamped to the origin-side body boundary (%.1f)" % (run.player_position.x - run.dummy_position.x))
	_check(not swapped and run.player_facing == 1, "a blocked D never swaps sides")


func _test_wall_clamp_truncates_and_keeps_side() -> void:
	# 版边截断（票据正例：版边普通 5D）：位移被墙截断、可观察墙截断标记，
	# 不换边、不出界。
	var run := CombatSession.new()
	var wall := GameParams.stage_right_limit()
	run.player_position = Vector2(wall - 60.0, GameParams.ground_stand_y())
	run.dummy_position = Vector2(wall, GameParams.ground_stand_y())
	run.player_facing = 1
	var hit := false
	var swapped := false
	var wall_clamped := false
	for frame in range(1, 40):
		for event in run.step(FrameInput.make(0, false, "D" if frame == 1 else "")):
			if event.type == CombatEvent.Type.HIT:
				hit = true
			elif event.type == CombatEvent.Type.SWITCHED_SIDES:
				swapped = true
		wall_clamped = wall_clamped or bool(run.debug_snapshot()["motion_wall_clamped"])
	_check(hit, "the corner 5D still connects its hit")
	_check(wall_clamped, "the wall truncation is observable")
	_check(run.player_position.x <= wall + 0.01, "the player never leaves the stage")
	_check(not swapped and run.player_facing == 1, "a wall-clamped D keeps the original side")


# --- 命中穿越换边（M-02/M-04）---

func _test_charge_cross_sideswap_and_next_frame_facing() -> void:
	# 中板 236C > 5[D] 穿越（票据正例）：浮空捞起命中 + 120px 突进真实跨过
	# 木桩——命中当帧完成攻击与位移，下一帧使用新面向；当招 hitbox 仍朝锁定
	# 方向；木桩按原攻击方向击退。
	var session := _float_pickup_session(50, 1)
	var swap_frame := -1
	var charge_frame := -1
	var hit_direction := 0
	var attack_rect_locked := false
	for frame in range(1, 90):
		for event in session.step(_entry_script_input(frame, 16, true)):
			if event.type == CombatEvent.Type.CHARGE_COMMITTED and event.charged:
				charge_frame = frame
			elif event.type == CombatEvent.Type.SWITCHED_SIDES:
				swap_frame = frame
			elif event.type == CombatEvent.Type.HIT and session.player_move_id == "5[D]":
				hit_direction = event.direction
		if swap_frame > 0 and session.player_move_id == "5[D]":
			attack_rect_locked = session.player_attack_rect().position.x > session.player_position.x
	_check(charge_frame == 30, "the special-entry D commits the charged version (%d)" % charge_frame)
	_check(swap_frame > 0, "the charged cross records SWITCHED_SIDES (%d)" % swap_frame)
	_check(session.player_position.x > session.dummy_position.x, "the player physically passed the dummy")
	_check(session.player_facing == -1, "the facing follows the real lateral relation after the swap")
	_check(hit_direction == 1, "the hit used the locked attack direction")
	_check(attack_rect_locked, "the running 5[D] hitbox keeps the locked direction after the swap")


func _test_mirror_cross_facing_left() -> void:
	# 左面向镜像：同一相对脚本在左侧同样换边（票据：双面向回放）。
	var session := _float_pickup_session(50, -1)
	var swap_frame := -1
	for frame in range(1, 90):
		for event in session.step(_entry_script_input(frame, 16, true, -1)):
			if event.type == CombatEvent.Type.SWITCHED_SIDES:
				swap_frame = frame
	_check(swap_frame > 0, "mirror run also swaps sides (%d)" % swap_frame)
	_check(session.player_facing == 1 and session.player_position.x < session.dummy_position.x,
		"the mirror swap leaves the player left of the dummy facing right")


func _test_candidate_lock_across_swap() -> void:
	# 换边后的镜像继续输入（M-04 允许例）：换边后开始的新 236 候选按新面向
	# 折算——新面向的前向完成 236C。
	var session := _float_pickup_session(50, 1)
	var swapped := false
	var frame := 0
	while frame < 90 and not swapped:
		frame += 1
		for event in session.step(_entry_script_input(frame, 16, true)):
			if event.type == CombatEvent.Type.SWITCHED_SIDES:
				swapped = true
	_check(swapped, "the cross happened (frame %d)" % frame)
	# 等待 5[D] 收招回中立，再按新面向（-1，前向=世界左）搓 236 + C。
	while frame < 120 and session.player_move_id != "":
		frame += 1
		session.step(FrameInput.new())
	while frame < 120 and session.dummy_state == CombatSession.DummyState.GROUND_HITSTUN:
		frame += 1
		session.step(FrameInput.new())
	for offset in range(0, 10):
		frame += 1
		var down := offset == 0 or offset == 1
		var axis := -1 if offset == 1 or offset == 2 else 0
		var key := "C" if offset == 3 else ""
		session.step(FrameInput.make(axis, false, key, down))
	_check(session.player_move_id == "236C", "a fresh 236 after the swap folds with the new facing")


# --- 蓄力版来源限定 5B（票据 05/06 联合）---

func _test_charged_5b_link_after_recovery() -> void:
	# 236C > 5[D]（蓄力、命中、穿越）→ D 完全恢复后普通连接 5B：来源限定边
	# 由蓄力版资源声明（special_entry_link_targets），恢复后才可消费；默认调校
	# 下剩余硬直不足以让 5B 判定落地（组合等待 + startup 消耗窗口），注入更长
	# untech 的表单独验证完整三击正例。
	var session := _float_pickup_session(50, 1)
	var link_started := false
	for frame in range(1, 130):
		var input := _entry_script_input(frame, 16, true)
		if frame == 59:
			var pressed: Array[String] = ["B"]
			input.pressed_action_keys.append_array(pressed)
			input.held_action_keys.append_array(pressed)
		session.step(input)
		if frame == 64:
			link_started = session.player_move_id == "5B" and session.combo_active
	_check(link_started, "the charged 5[D] opens the source-limited 5B link on full recovery")
	# 注入表：5[D] 空中 untech 32 → 44，剩余硬直覆盖 5B 前摇。
	var table := MoveData.default_table()
	var charged_move := table["5[D]"] as MoveData
	var airborne := charged_move.profile_for(charged_move, HitProfile.TargetState.AIRBORNE, HitProfile.HitContext.NORMAL)
	airborne.air_untech_frames = 44
	var injected := CombatSession.new(table)
	injected.dummy_position = injected.player_position + Vector2(50, 0)
	var combo_hits_at_5b := 0
	for frame in range(1, 130):
		var input := _entry_script_input(frame, 16, true)
		if frame == 59:
			var pressed: Array[String] = ["B"]
			input.pressed_action_keys.append_array(pressed)
			input.held_action_keys.append_array(pressed)
		for event in injected.step(input):
			if event.type == CombatEvent.Type.HIT and injected.player_move_id == "5B":
				combo_hits_at_5b = event.combo_hits
	_check(combo_hits_at_5b == 3, "with enough remaining stun the linked 5B lands as the third hit (%d)" % combo_hits_at_5b)


# --- Solver（票据 06：蓄力边变体与路线）---

func _test_solver_charge_edges_and_routes() -> void:
	# Solver 验证蓄力输入（按下后按住至阈值提交）：目标声明蓄力的接缝另生成
	# 蓄力变体边（to=5[D]、标注蓄力、按住帧编排），静态钉位下 timing-valid；
	# 真实穿越/墙边/双面向仍属 replay-required（SCOPE_TEXT 已声明）。
	var opts := ComboSolver.SolverOptions.new()
	opts.facings = [1]
	var report := ComboSolver.solve(opts)
	_check(not report.refused, "solver accepts the table containing the charged move")
	var entry_valid := false
	var chain_valid := false
	var link_honest := false
	for edge in report.edges:
		if edge.to_id != "5[D]" or not edge.charged:
			continue
		if edge.valid and edge.kind == ComboSolver.EdgeKind.SPECIAL_ENTRY and edge.from_id == "236C":
			entry_valid = true
		if edge.valid and edge.kind == ComboSolver.EdgeKind.CHAIN_CANCEL:
			chain_valid = true
		if not edge.valid and edge.kind == ComboSolver.EdgeKind.NORMAL_LINK 				and String(edge.reason).contains("目押超时"):
			link_honest = true
	_check(entry_valid, "solver verifies the charged special-entry edge 236C → 5[D]")
	_check(chain_valid, "solver verifies a charged chain-cancel edge into 5[D]")
	_check(link_honest, "solver honestly reports the charged link edge as timing-expired")
	var charged_route := false
	for route in report.routes:
		if route.move_ids.has("5[D]") and route.timing_valid:
			charged_route = true
	_check(charged_route, "solver reports timing-valid routes through 5[D]")
	var charged_solo_start := false
	for route in report.routes:
		if route.move_ids.size() > 0 and route.move_ids[0] == "5[D]":
			charged_solo_start = true
	_check(not charged_solo_start, "the charged move never enumerates as a single-key route start")


# --- 资源与校验（MoveTable）---

func _test_move_table_charge_and_motion_validation() -> void:
	# motion 两轴成对。
	var one_axis := _valid_strike("D0", "D")
	one_axis.motion_x_px = 72.0
	_check(_rejects([one_axis]), "a single-axis motion declaration is rejected")
	# 普通投不位移、不蓄力。
	var motion_throw := _valid_throw()
	motion_throw.motion_x_px = 10.0
	motion_throw.motion_y_px = 0.0
	_check(_rejects([motion_throw]), "a throw cannot declare planned motion")
	var charge_throw := _valid_throw()
	charge_throw.charge_threshold_frames = 8
	charge_throw.charge_move_id = "X"
	_check(_rejects([charge_throw]), "a throw cannot declare in-action charge")
	# 蓄力阈值 0。
	var zero_threshold := _valid_strike("D0", "D")
	zero_threshold.charge_threshold_frames = 0
	zero_threshold.charge_move_id = "DC"
	_check(_rejects([zero_threshold]), "a zero charge threshold is rejected")
	# 蓄力目标缺失 / 未声明 charge_only / 孤儿蓄力版 / 出现在接续目标中。
	var missing_target := _valid_strike("D0", "D")
	missing_target.charge_threshold_frames = 8
	missing_target.charge_move_id = "NOPE"
	missing_target.motion_x_px = 72.0
	missing_target.motion_y_px = 0.0
	_check(_rejects([missing_target]), "a charge target outside the table is rejected")
	var not_only := _valid_strike("D0", "D")
	not_only.charge_threshold_frames = 8
	not_only.charge_move_id = "D1"
	_check(_rejects([not_only, _valid_strike("D1", "D")]), "a charge target without charge_only is rejected")
	var orphan := _valid_strike("DC2", "D")
	orphan.charge_only = true
	_check(_rejects([orphan]), "an unreferenced charge_only move is rejected")
	var in_targets := _valid_strike("D0", "D")
	in_targets.charge_threshold_frames = 8
	in_targets.charge_move_id = "DC3"
	in_targets.chain_cancel_targets = ["DC3"]
	in_targets.chain_cancel_window_frames = 3
	var charged_entry := _valid_strike("DC3", "D")
	charged_entry.charge_only = true
	_check(_rejects([in_targets, charged_entry]), "a charge_only move in a continuation target list is rejected")
	# 蓄力版不能又声明自己的蓄力（不链式）。
	var chained := _valid_strike("DC4", "D")
	chained.charge_only = true
	chained.charge_threshold_frames = 4
	chained.charge_move_id = "DC5"
	_check(_rejects([chained]), "a charged move cannot declare its own charge")
	# 合法对照：普通版 + 蓄力版成对。
	var ok_base := _valid_strike("D6", "D")
	ok_base.charge_threshold_frames = 8
	ok_base.charge_move_id = "DC6"
	ok_base.motion_x_px = 72.0
	ok_base.motion_y_px = 0.0
	var ok_charged := _valid_strike("DC6", "D")
	ok_charged.charge_only = true
	ok_charged.motion_x_px = 120.0
	ok_charged.motion_y_px = 0.0
	_check(MoveTable.validate([ok_base, ok_charged]).is_empty(), "a valid charge pair passes")


# --- 输入与场景助手 ---

## D 按住输入：press_frame 帧新按下并按住，持续到 hold_to（含）；其余帧为空。
## 显式构造类型化数组——属性上的字面量三元在运行期是未类型 Array。
func _d_input(frame: int, press_frame: int, hold_to: int) -> FrameInput:
	var input := FrameInput.new()
	if frame == press_frame or (frame > press_frame and frame <= hold_to):
		var held: Array[String] = ["D"]
		input.held_action_keys = held
	if frame == press_frame:
		var pressed: Array[String] = ["D"]
		input.pressed_action_keys = pressed
	return input


## 236C（面向相对 2/3/6 + C，C 为投组合成员需 +3f 等待）命中段 1 后，
## d_press_frame 帧按 D 进入特殊进入 5D；charge 为真时按住 D 至蓄力提交。
func _entry_script_input(frame: int, d_press_frame: int, charge: bool, facing := 1) -> FrameInput:
	var down := frame == 1 or frame == 2
	var axis := facing if (frame == 2 or frame == 3) else 0
	var key := "C" if frame == 4 else ""
	var input := FrameInput.make(axis, false, key, down)
	if frame == d_press_frame:
		var pressed: Array[String] = ["D"]
		input.pressed_action_keys = pressed
		input.held_action_keys = pressed
	elif charge and frame > d_press_frame and frame <= d_press_frame + 14:
		var held: Array[String] = ["D"]
		input.held_action_keys = held
	return input


## 段 1 浮空捞起场景：dx 间距、面向 facing 的木桩站位。
func _float_pickup_session(dx: float, facing: int) -> CombatSession:
	var session := CombatSession.new()
	if facing == 1:
		session.dummy_position = session.player_position + Vector2(dx, 0)
	else:
		session.dummy_position = session.player_position - Vector2(dx, 0)
		session.player_facing = -1
	return session


func _valid_strike(id: String, key: String) -> MoveData:
	var move := MoveData.new()
	move.move_id = id
	move.move_kind = MoveData.MoveKind.STRIKE
	move.stance = MoveData.Stance.GROUND
	move.action_key = key
	move.startup_frames = 5
	move.active_frames = 4
	move.recovery_frames = 12
	move.cancel_window_frames = 8
	move.priority = 1
	move.base_damage = 10
	move.attack_attribute = MoveData.AttackAttribute.MID
	move.hitbox_size = Vector2(64, 60)
	move.hitbox_gap = 4.0
	move.starter_grade = MoveData.StarterGrade.A
	move.block_freeze_frames = 8
	move.block_stun_frames = 9
	move.block_pushback_px_s = 45.0
	var normal := HitProfile.new()
	normal.target_state = HitProfile.TargetState.GROUNDED
	normal.hit_context = HitProfile.HitContext.NORMAL
	normal.reaction = HitProfile.Reaction.GROUND_HITSTUN
	normal.ground_stun_frames = 12
	normal.horizontal_speed_px_s = 160.0
	normal.upward_speed_px_s = 0.0
	move.hit_profiles = [normal]
	return move


func _valid_throw() -> MoveData:
	var move := _valid_strike("throw", "B")
	move.move_kind = MoveData.MoveKind.THROW
	move.action_key = ""
	move.hit_profiles = []
	move.startup_frames = 5
	move.active_frames = GameParams.THROW_TECH_WINDOW_AFTER_GRAB + 1
	move.throw_range = 64.0
	move.block_freeze_frames = -1
	move.block_stun_frames = -1
	move.block_pushback_px_s = -1.0
	move.starter_grade = MoveData.StarterGrade.UNSET
	move.base_damage = -1
	move.hitbox_size = Vector2.ZERO
	move.hitbox_gap = -1.0
	return move


func _rejects(move_list: Array) -> bool:
	return not MoveTable.validate(move_list).is_empty()


func _approx(value: float, expected: float, tolerance := 0.05) -> bool:
	return absf(value - expected) <= tolerance


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS  " + label)
	else:
		_failures += 1
		printerr("FAIL  " + label)
