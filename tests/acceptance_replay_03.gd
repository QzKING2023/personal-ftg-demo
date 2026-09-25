extends SceneTree
## 票据 03 验收回放：确定性木桩防御、被防取消与反击安全场景。
## 记录固定起始间距、左右面向、逐帧事件与双方位置——供 acceptance/03/ 证据归档。
## 运行：godot --headless --path . -s res://tests/acceptance_replay_03.gd

const NEAR_DX := 60.0
const MID_DX := 100.0


func _initialize() -> void:
	_replay_blocked_chain(1)
	_replay_blocked_chain(-1)
	_replay_blocked_special(1)
	_replay_blocked_special(-1)
	_replay_blocked_leak_hit(1)
	_replay_blocked_leak_hit(-1)
	_replay_whiff_cancel_negative(1)
	_replay_blocked_jump_cancel_negative(1)
	_replay_counter_safety(NEAR_DX, 1, "近距", ["5A", "5D"])
	_replay_counter_safety(NEAR_DX, -1, "近距", ["5A", "5D"])
	_replay_counter_safety(MID_DX, 1, "中板", ["5D"])
	_replay_counter_safety_wall(1)
	_replay_counter_safety_wall(-1)
	quit(0)


## 正例：5A 被站防后链式取消 5B（再被防）；随后释放防御，第三记 5A 正常命中
## （命中/被防两分支同日志可对照）。B 在接触帧按下，组合等待被停顿吸收。
func _replay_blocked_chain(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	print("=== 被防链式取消 5A>5B | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	for frame in range(1, 64):
		var key := ""
		if frame == 1 or frame == 32 or frame == 58:
			key = "A"
		elif frame == 6:
			key = "B"
		# 第三段：F45 起释放防御（NONE），验证被防硬直内姿态冻结、硬直结束后落地。
		var guard := CombatSession.GuardPosture.STANDING if frame <= 44 else CombatSession.GuardPosture.NONE
		var input := FrameInput.make(0, false, key)
		input.dummy_guard_request = guard
		var events := session.step(input)
		_log_contact(frame, events, session)
	print("结果：连段 %d hit · 总伤害 %.1f · HP %.1f" % [session.combo_hits, session.combo_total_damage, session.dummy_hp])
	print("")


## 正例：5A 被站防后必杀取消 236C（停顿中喂 236 并按 C，恢复首个正常帧起手，
## 再被站防）。236C 是 SPECIAL 层方向派生，接触年龄 2 ≤ 必杀窗口 5。
func _replay_blocked_special(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	print("=== 被防必杀取消 5A>236C | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	for frame in range(1, 40):
		var digit := 5
		var key := ""
		if frame == 1:
			key = "A"
		elif frame == 7:
			digit = 2
		elif frame == 8:
			digit = 3
		elif frame == 9:
			digit = 6
		elif frame == 13:
			key = "C"
		var input := _relative(session, digit, key)
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		var events := session.step(input)
		_log_contact(frame, events, session)
	print("")


## 正例（混合起点）：5A 被站防后链式取消 2B——low 从站防漏出，2B 命中并
## 开启全新连段（B 起手），证明被防取消可以转入命中且修正重新起算。
func _replay_blocked_leak_hit(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	print("=== 被防转命中 5A>2B（low 漏站防） | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	for frame in range(1, 46):
		var key := ""
		var down := false
		if frame == 1:
			key = "A"
		elif frame == 6:
			key = "B"
			down = true
		var input := FrameInput.make(0, false, key, down)
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		var events := session.step(input)
		_log_contact(frame, events, session)
	_check_leak_outcome(session)
	print("")


func _check_leak_outcome(session: CombatSession) -> void:
	## 脚本级核对：2B 混入命中后 starter 应为 B（A 的被防不锁起手）。
	print("结果：starter=%s 连段=%d hit 修正 伤%.3f/时%.3f/轨%.3f" % [
		_starter_text(session.combo_starter_grade), session.combo_hits,
		session.combo_damage_scale, session.combo_time_scale, session.combo_trajectory_scale])


## 负例：木桩在判定外（200 px）时挥空——窗口内按 B 不产生任何取消或接触，
## 缓存过期作废；木桩防御请求照常成立（空闲地面木桩可站防），但无接触可言。
func _replay_whiff_cancel_negative(facing: int) -> void:
	var session := _spawn(200.0, facing)
	print("=== 负例：挥空取消 | 面向 %d | 起始间距 200 px ===" % facing)
	var any_contact := false
	for frame in range(1, 40):
		var key := ""
		if frame == 1:
			key = "A"
		elif frame == 6:
			key = "B"
		var input := FrameInput.make(0, false, key)
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		var events := session.step(input)
		for event in events:
			any_contact = any_contact or event.type in [CombatEvent.Type.HIT, CombatEvent.Type.ATTACK_BLOCKED, CombatEvent.Type.HIT_MISS]
			if event.type == CombatEvent.Type.DUMMY_GUARD_REJECTED:
				print("F%-3d DUMMY_GUARD_REJECTED %s" % [frame, CombatEvent.DummyGuardRejectReason.keys()[event.guard_reject_reason]])
		if frame in [6, 12, 20, 30]:
			print("F%-3d 输入[%s] 招式%s 木桩防%d | 玩家(%.1f) 木桩(%.1f)" % [
				frame, key, session.player_move_id, session.dummy_guard,
				session.player_position.x, session.dummy_position.x])
	print("结果：任何接触事件=%s（预期 false）；F30 玩家招式=%s（预期空，B 从未起手）" % [str(any_contact), session.player_move_id])
	print("")


## 负例：6A 被站防后按 Space——被防不开放 jump cancel；6A 走完整恢复，
## 玩家全程未起跳准备。
func _replay_blocked_jump_cancel_negative(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	print("=== 负例：被防不开 jump cancel（6A 被站防后 Space） | 面向 %d ===" % facing)
	for frame in range(1, 46):
		var jump := false
		var forward := false
		if frame == 1:
			forward = true
		elif frame == 7:
			jump = true
		var input := FrameInput.make(session.player_facing if forward else 0, false, "A" if forward else "")
		input.jump_pressed = jump
		input.up_held = jump
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		var events := session.step(input)
		_log_contact(frame, events, session)
		if session.player_prejump_left > 0:
			print("F%-3d 意外的起跳准备 prejump=%d" % [frame, session.player_prejump_left])
	print("结果：prejump 全程为 0；玩家招式=%s 空闲=%s" % [
		session.player_move_id, str(session.player_phase == CombatSession.PlayerPhase.NEUTRAL)])
	print("")


## 安全性场景（R-02 口径）：木桩站防玩家招式后，在被防硬直结束后的首个输入帧
## 请求固定反击 5A；分别观察攻击方（玩家）不防御与尝试防御两种行为。
## 分类：确反＝反击命中时攻击方仍处招式阶段；已恢复未防＝命中时攻击方已空闲；
## 被防＝攻击方及时恢复并挡住；距离不足＝反击判定窗口无接触。
func _replay_counter_safety(dx: float, facing: int, label: String, attacker_moves: Array) -> void:
	for attacker_move in attacker_moves:
		for behavior in ["不防御", "尝试防御"]:
			var session := _spawn(dx, facing)
			var attacker_total := _total_frames(attacker_move) + GameParams.HITSTOP_FRAMES
			print("=== 反击安全 | %s %.0f px | 面向 %d | 被防招式 %s（含停顿至 F%d 恢复）| 玩家%s ===" % [
				label, dx, facing, attacker_move, attacker_total, behavior])
			var verdict := ""
			## 攻击方首个可行动帧 = 招式总长 + 被防停顿 + 1（5A→F28、5D→F38）。
			var attacker_free := attacker_total + 1
			var counter_sent := false
			for frame in range(1, 70):
				var key := ""
				if frame == 1:
					key = "A" if attacker_move == "5A" else "D"
				var axis := 0
				if behavior == "尝试防御" and frame >= 20:
					axis = -facing
				var input := FrameInput.make(axis, false, key)
				input.dummy_guard_request = CombatSession.GuardPosture.STANDING
				if frame >= 15 and not counter_sent:
					input.dummy_move_request = "5A"
					if session.dummy_move_id == "5A":
						counter_sent = true
				var events := session.step(input)
				for event in events:
					match event.type:
						CombatEvent.Type.ATTACK_BLOCKED:
							print("F%-3d ATTACK_BLOCKED %s 被防硬直%d" % [frame, _guard_text(event.guard_posture), session.dummy_blockstun_left])
						CombatEvent.Type.PLAYER_HIT:
							verdict = "确反（攻击方 F%d 前尚不能行动）" % attacker_free if frame < attacker_free 								else "已恢复未防（攻击方 F%d 起可行动但未挡）" % attacker_free
							print("F%-3d PLAYER_HIT 反击命中 → %s" % [frame, verdict])
						CombatEvent.Type.BLOCKED:
							verdict = "被防（攻击方及时恢复并挡住反击）"
							print("F%-3d BLOCKED 反击被玩家挡下 → %s" % [frame, verdict])
				if frame == 69 and verdict == "":
					verdict = "反击未在观测窗口内命中（距离或时序不足）"
			print("结论：%s | 间距 %.1f→%.1f" % [verdict, dx, absf(session.dummy_position.x - session.player_position.x)])
			print("")


## 版边场景：木桩贴右墙（推退被墙截断），观察间距变化与结论是否改变。
func _replay_counter_safety_wall(facing: int) -> void:
	var session := CombatSession.new()
	if facing == 1:
		session.dummy_position = Vector2(GameParams.stage_right_limit(), GameParams.ground_stand_y())
		session.player_position = session.dummy_position - Vector2(NEAR_DX, 0)
	else:
		session.dummy_position = Vector2(GameParams.stage_left_limit(), GameParams.ground_stand_y())
		session.player_position = session.dummy_position + Vector2(NEAR_DX, 0)
	session.player_facing = facing
	print("=== 反击安全 | 版边 | 面向 %d | 木桩贴墙，玩家距墙 %.0f px ===" % [facing, NEAR_DX])
	var verdict := ""
	## 5D 总长 29 + 停顿 8 → 攻击方 F38 起可行动。
	var attacker_free := _total_frames("5D") + GameParams.HITSTOP_FRAMES + 1
	var counter_sent := false
	for frame in range(1, 70):
		var key := "D" if frame == 1 else ""
		var input := FrameInput.make(0, false, key)
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING
		if frame >= 15 and not counter_sent:
			input.dummy_move_request = "5A"
			if session.dummy_move_id == "5A":
				counter_sent = true
		var events := session.step(input)
		for event in events:
			match event.type:
				CombatEvent.Type.ATTACK_BLOCKED:
					print("F%-3d ATTACK_BLOCKED %s | 木桩x=%.1f（墙限 %.1f）" % [
						frame, _guard_text(event.guard_posture), session.dummy_position.x, GameParams.stage_right_limit()])
				CombatEvent.Type.PLAYER_HIT:
					verdict = "确反（攻击方 F%d 前尚不能行动）" % attacker_free if frame < attacker_free else "已恢复未防"
					print("F%-3d PLAYER_HIT → %s" % [frame, verdict])
				CombatEvent.Type.BLOCKED:
					verdict = "被防"
					print("F%-3d BLOCKED 反击被挡" % frame)
		if frame == 69 and verdict == "":
			verdict = "反击未在观测窗口内命中"
	print("结论：%s | 版边木桩位移被墙截断（贴墙 %.1f）" % [verdict, session.dummy_position.x])
	print("")


# --- 辅助 ---

func _spawn(dx: float, facing: int) -> CombatSession:
	var session := CombatSession.new()
	if facing == 1:
		session.dummy_position = session.player_position + Vector2(dx, 0)
	else:
		session.dummy_position = session.player_position - Vector2(dx, 0)
		session.player_facing = -1
	return session


func _total_frames(move_id: String) -> int:
	var result := MoveTable.load_default()
	var move := result.moves[move_id] as MoveData
	return move.startup_frames + move.active_frames + move.recovery_frames


func _relative(session: CombatSession, digit: int, key: String) -> FrameInput:
	var axis := 0
	if digit == 3 or digit == 6 or digit == 9:
		axis = session.player_facing
	elif digit == 1 or digit == 4 or digit == 7:
		axis = -session.player_facing
	var down := digit >= 1 and digit <= 3
	return FrameInput.make(axis, false, key, down)


func _log_contact(frame: int, events: Array[CombatEvent], session: CombatSession) -> void:
	for event in events:
		match event.type:
			CombatEvent.Type.ATTACK_BLOCKED:
				print("F%-3d ATTACK_BLOCKED 姿态%s | 停顿剩余%d 被防硬直%d | 玩家(%.1f) 木桩(%.1f) 招式%s" % [
					frame, _guard_text(event.guard_posture), session.debug_snapshot()["hitstop_left"],
					session.dummy_blockstun_left, session.player_position.x, session.dummy_position.x,
					session.player_move_id])
			CombatEvent.Type.HIT:
				print("F%-3d HIT 第%d击 伤%.1f starter%s | 修正 伤%.3f/时%.3f/轨%.3f | HP %.1f" % [
					frame, event.combo_hits, event.damage, _starter_text(session.combo_starter_grade),
					session.combo_damage_scale, session.combo_time_scale, session.combo_trajectory_scale,
					session.dummy_hp])
			CombatEvent.Type.HITSTOP_STARTED:
				print("F%-3d HITSTOP_STARTED" % frame)
			CombatEvent.Type.HITSTOP_ENDED:
				print("F%-3d HITSTOP_ENDED 被防硬直%d" % [frame, session.dummy_blockstun_left])
			CombatEvent.Type.DUMMY_RECOVERED:
				print("F%-3d DUMMY_RECOVERED" % frame)
			CombatEvent.Type.COMBO_ENDED:
				print("F%-3d COMBO_ENDED %s" % [frame, CombatEvent.ComboEndReason.keys()[event.combo_end_reason]])


func _guard_text(posture: int) -> String:
	match posture:
		CombatSession.GuardPosture.STANDING:
			return "站防"
		CombatSession.GuardPosture.CROUCH:
			return "蹲防"
		CombatSession.GuardPosture.AIR:
			return "空防"
	return "无"


func _starter_text(grade: MoveData.StarterGrade) -> String:
	match grade:
		MoveData.StarterGrade.A:
			return "A"
		MoveData.StarterGrade.B:
			return "B"
		MoveData.StarterGrade.C:
			return "C"
		MoveData.StarterGrade.D:
			return "D"
	return "未锁定"
