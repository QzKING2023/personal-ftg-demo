extends SceneTree
## 票据 04 验收回放：Rekka 首段、派生锁定、地空命中资料与被防派生安全性。
## 记录固定起始间距、左右面向、逐帧事件与双方位置——供 acceptance/04/ 证据归档。
## 运行：godot --headless --path . -s res://tests/acceptance_replay_04.gd

const NEAR_DX := 60.0
const TOUCH_DX := 48.0


func _initialize() -> void:
	_replay_canonical_route(1)
	_replay_canonical_route(-1)
	_replay_ground_knockdowns(1)
	_replay_ground_knockdowns(-1)
	_replay_spike_route(1)
	_replay_spike_route(-1)
	_replay_same_frame_bc(1)
	_replay_same_frame_bc(-1)
	_replay_blocked_derivation(1)
	_replay_blocked_derivation(-1)
	_replay_whiff_negative(1)
	_replay_late_key_negative(1)
	_replay_window_expiry_throw(1)
	_replay_safety(NEAR_DX, 1, "214C~B", "蹲防")
	_replay_safety(NEAR_DX, -1, "214C~B", "蹲防")
	_replay_safety(NEAR_DX, 1, "214C~C", "站防")
	quit(0)


## 正例（目标路线）：2C > 214C(空中命中) > 214C~B(延长浮空) > 5B(普通连接)。
## 时间轴（贴身 48 px）：2C F1=F4、接触 F12；停顿中 F15–F17 喂 214、F18 按 C、
## 214C F1=F22、接触 F30（低浮空目标）；F32 按 B、~B F1=F39、接触 F43+（延长）、
## 停顿 F47–F54、触地转地面硬直；F70 缓存 B、~B 收招 F74、5B F1=F74、命中 F80。
func _replay_canonical_route(facing: int) -> void:
	var session := _spawn(TOUCH_DX, facing)
	print("=== 正例路线 2C>214C>214C~B(空中)>5B(目押) | 面向 %d | 起始间距 %.0f px ===" % [facing, TOUCH_DX])
	for frame in range(1, 95):
		var digit := 5
		var key := ""
		if frame == 1:
			digit = 2
			key = "C"
		elif frame in [15, 16, 17]:
			digit = [2, 1, 4][frame - 15]
		elif frame == 19:
			key = "C"
		elif frame == 32:
			key = "B"
		elif frame == 70:
			key = "B"
		var events := session.step(_relative(session, digit, key))
		_log_contact(frame, events, session)
	print("结果：连段 %d hit · 总伤害 %.1f · HP %.1f · starter=%s 修正 伤%.3f/时%.3f/轨%.3f" % [
		session.combo_hits, session.combo_total_damage, session.dummy_hp,
		_starter_text(session.combo_starter_grade), session.combo_damage_scale,
		session.combo_time_scale, session.combo_trajectory_scale])
	print("      玩家x=%.1f 木桩x=%.1f 木桩状态=%s" % [
		session.player_position.x, session.dummy_position.x, _dummy_state_text(session)])
	print("")


## 正例：裸 214C 命中地面目标后 ~B 直接普通倒地、~C 直接收尾（两条分支对照）。
func _replay_ground_knockdowns(facing: int) -> void:
	for branch in ["B", "C"]:
		var session := _spawn(NEAR_DX, facing)
		print("=== 正例 地面倒地 214C>~%s | 面向 %d | 起始间距 %.0f px ===" % [branch, facing, NEAR_DX])
		for frame in range(1, 56):
			var digit := 5
			var key := ""
			if frame == 1:
				digit = 2
			elif frame == 2:
				digit = 1
			elif frame == 3:
				digit = 4
			elif frame == 4:
				key = "C"
			elif frame == 16:
				key = branch
			var events := session.step(_relative(session, digit, key))
			_log_contact(frame, events, session)
		print("结果：木桩状态=%s（预期普通倒地）连段=%d" % [_dummy_state_text(session), session.combo_hits])
		print("")


## 正例：2C > 214C > ~C 空中向下击落——SPIKE_FALL 坠落后触地同帧转普通倒地。
func _replay_spike_route(facing: int) -> void:
	var session := _spawn(TOUCH_DX, facing)
	print("=== 正例 向下击落 2C>214C>~C(空中) | 面向 %d | 起始间距 %.0f px ===" % [facing, TOUCH_DX])
	for frame in range(1, 75):
		var digit := 5
		var key := ""
		if frame == 1:
			digit = 2
			key = "C"
		elif frame in [15, 16, 17]:
			digit = [2, 1, 4][frame - 15]
		elif frame == 19:
			key = "C"
		elif frame == 32:
			key = "C"
		var events := session.step(_relative(session, digit, key))
		_log_contact(frame, events, session)
		if session.dummy_state == CombatSession.DummyState.SPIKE_FALL and frame % 1 == 0:
			if not events.any(func(e: CombatEvent) -> bool: return e.type == CombatEvent.Type.SPIKE_LANDED):
				print("F%-3d SPIKE_FALL 木桩y=%.1f vy=%.0f（向下坠落中）" % [
					frame, session.dummy_position.y, session.dummy_velocity.y])
	print("结果：木桩状态=%s（预期普通倒地）" % _dummy_state_text(session))
	print("")


## 正例：首段命中后的停顿中同帧 B+C——固定 C > B 优先级锁 ~C，不进入普通投等待。
func _replay_same_frame_bc(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	print("=== 正例 同帧 B+C 锁 ~C | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	for frame in range(1, 60):
		var input := _relative(session, 5, "")
		if frame == 1:
			input = _relative(session, 2, "")
		elif frame == 2:
			input = _relative(session, 1, "")
		elif frame == 3:
			input = _relative(session, 4, "")
		elif frame == 4:
			input = _relative(session, 5, "C")
		elif frame == 16:
			input = FrameInput.new()
			input.pressed_action_keys = ["B", "C"]
			input.held_action_keys = ["B", "C"]
		var events := session.step(input)
		_log_contact(frame, events, session)
	print("结果：招式=%s（预期 214C~C）无 THROW 事件" % session.player_move_id)
	print("")


## 正例/反例：蹲防全程——首段 mid 被防开放窗口、~B low 同样被防（只产生 BLOCKED）；
## 站防对照——~B low 漏出命中（混合起点，新连段 B 起手）。
func _replay_blocked_derivation(facing: int) -> void:
	for mode in ["蹲防", "站防"]:
		var session := _spawn(NEAR_DX, facing)
		var guard := CombatSession.GuardPosture.CROUCH if mode == "蹲防" else CombatSession.GuardPosture.STANDING
		print("=== 被防派生 %s全程 | 面向 %d | 起始间距 %.0f px ===" % [mode, facing, NEAR_DX])
		for frame in range(1, 60):
			var digit := 5
			var key := ""
			if frame == 1:
				digit = 2
			elif frame == 2:
				digit = 1
			elif frame == 3:
				digit = 4
			elif frame == 4:
				key = "C"
			elif frame == 16:
				key = "B"
			var input := _relative(session, digit, key)
			input.dummy_guard_request = guard
			var events := session.step(input)
			_log_contact(frame, events, session)
		print("结果：连段=%d hit starter=%s（蹲防预期 0 击不锁起手；站防预期 ~B 漏防开新连段）" % [
			session.combo_hits, _starter_text(session.combo_starter_grade)])
		print("")


## 反例：木桩在判定外（200 px）——首段挥空，窗口内按 B 无派生、无接触。
func _replay_whiff_negative(facing: int) -> void:
	var session := _spawn(200.0, facing)
	print("=== 反例 首段挥空无派生 | 面向 %d | 起始间距 200 px ===" % facing)
	var saw_lock := false
	var saw_contact := false
	for frame in range(1, 45):
		var digit := 5
		var key := ""
		if frame == 1:
			digit = 2
		elif frame == 2:
			digit = 1
		elif frame == 3:
			digit = 4
		elif frame == 4:
			key = "C"
		elif frame == 16:
			key = "B"
		var events := session.step(_relative(session, digit, key))
		for event in events:
			saw_contact = saw_contact or event.type in [CombatEvent.Type.HIT, CombatEvent.Type.ATTACK_BLOCKED]
			saw_lock = saw_lock or event.type == CombatEvent.Type.REKKA_BRANCH_LOCKED
	print("结果：任何接触=%s（预期 false）分支锁定=%s（预期 false）玩家招式=%s" % [
		str(saw_contact), str(saw_lock), session.player_move_id])
	print("")


## 反例：窗口内先按 B 锁 ~B，3 帧内再按 C——分支不改写、不升级为 ~C、不配对成投。
func _replay_late_key_negative(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	print("=== 反例 先B后C不改写分支 | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	for frame in range(1, 60):
		var digit := 5
		var key := ""
		if frame == 1:
			digit = 2
		elif frame == 2:
			digit = 1
		elif frame == 3:
			digit = 4
		elif frame == 4:
			key = "C"
		elif frame == 16:
			key = "B"
		elif frame == 19:
			key = "C"
		var events := session.step(_relative(session, digit, key))
		_log_contact(frame, events, session)
	print("结果：玩家招式=%s（预期 214C~B，绝不出现 214C~C）" % session.player_move_id)
	print("")


## 反例/正例：派生窗口关闭后（接触年龄 >12）B+C 沿用组合规则——招式中被状态门
## 拒绝（THROW_FAILED/STATE）；首段完全恢复后的新组合正常执行普通投。
func _replay_window_expiry_throw(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	print("=== 窗口外 B+C 组合规则 | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	for frame in range(1, 75):
		var input := _relative(session, 5, "")
		if frame == 1:
			input = _relative(session, 2, "")
		elif frame == 2:
			input = _relative(session, 1, "")
		elif frame == 3:
			input = _relative(session, 4, "")
		elif frame == 4:
			input = _relative(session, 5, "C")
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING if frame <= 20 else 0
		if frame == 36 or frame == 48:
			input = FrameInput.new()
			input.pressed_action_keys = ["B", "C"]
			input.held_action_keys = ["B", "C"]
		var events := session.step(input)
		_log_contact(frame, events, session)
	print("结果：首段恢复后 B+C 正常起手普通投（THROW_HIT 见日志）" )
	print("")


## 被防派生安全性（R-02 口径，TUNING_INITIAL 观测）：木桩按能挡住派生属性的
## 姿态防住 ~B/~C，在被防硬直结束后的首个输入帧请求固定反击 5A；分别观察
## 攻击方不防御与尝试防御。结论绑定当前初值与近距站位，最终手感 replay-required。
func _replay_safety(dx: float, facing: int, derived_id: String, guard_label: String) -> void:
	var guard := CombatSession.GuardPosture.STANDING if guard_label == "站防" else CombatSession.GuardPosture.CROUCH
	var total := _total_frames(derived_id) + GameParams.HITSTOP_FRAMES
	for behavior in ["不防御", "尝试防御"]:
		var session := _spawn(dx, facing)
		print("=== 被防派生安全 | %s 被%s挡下 %.0f px | 面向 %d | 派生 F24 起手、F%d 起可行动 | 攻击方%s ===" % [
			derived_id, guard_label, dx, facing, 24 + total, behavior])
		var verdict := ""
		## 派生招式 F1 = 首段停顿恢复帧（60 px 时间轴为 F24）；total 已含派生自身
		## 接触停顿 8——首个可行动帧 = F24 + total。
		var attacker_free := 24 + total
		var counter_sent := false
		for frame in range(1, 90):
			var digit := 5
			var key := ""
			if frame == 1:
				digit = 2
			elif frame == 2:
				digit = 1
			elif frame == 3:
				digit = 4
			elif frame == 4:
				key = "C"
			elif frame == 16:
				key = derived_id.right(1)
			var input := _relative(session, digit, key)
			input.dummy_guard_request = guard
			if behavior == "尝试防御" and frame > 40:
				input.move_axis = -session.player_facing
			if frame >= 40 and not counter_sent:
				input.dummy_move_request = "5A"
				if session.dummy_move_id == "5A":
					counter_sent = true
			var events := session.step(input)
			for event in events:
				match event.type:
					CombatEvent.Type.ATTACK_BLOCKED:
						print("F%-3d ATTACK_BLOCKED %s 被防硬直%d" % [frame, _guard_text(event.guard_posture), session.dummy_blockstun_left])
					CombatEvent.Type.PLAYER_HIT:
						verdict = "确反（攻击方 F%d 前尚不能行动）" % attacker_free if frame < attacker_free \
							else "已恢复未防（攻击方 F%d 起可行动但未挡）" % attacker_free
						print("F%-3d PLAYER_HIT 反击命中 → %s" % [frame, verdict])
					CombatEvent.Type.BLOCKED:
						verdict = "被防（攻击方及时恢复并挡住反击）"
						print("F%-3d BLOCKED 反击被攻击方挡下 → %s" % [frame, verdict])
					CombatEvent.Type.REKKA_BRANCH_LOCKED:
						print("F%-3d REKKA_BRANCH_LOCKED ~%s" % [frame, event.rekka_branch])
			if frame == 89 and verdict == "":
				verdict = "反击未在观测窗口内命中（距离或时序不足）"
		print("结论：%s | 间距 %.1f→%.1f | 绑定 TUNING_INITIAL，最终安全性 replay-required" % [
			verdict, dx, absf(session.dummy_position.x - session.player_position.x)])
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
			CombatEvent.Type.HIT:
				print("F%-3d HIT 第%d击 伤%.1f starter%s | 修正 伤%.3f/时%.3f/轨%.3f | HP %.1f | %s" % [
					frame, event.combo_hits, event.damage, _starter_text(session.combo_starter_grade),
					session.combo_damage_scale, session.combo_time_scale, session.combo_trajectory_scale,
					session.dummy_hp, _dummy_state_text(session)])
			CombatEvent.Type.ATTACK_BLOCKED:
				print("F%-3d ATTACK_BLOCKED 姿态%s | 停顿剩余%s 被防硬直%d" % [
					frame, _guard_text(event.guard_posture),
					str(session.debug_snapshot()["hitstop_left"]), session.dummy_blockstun_left])
			CombatEvent.Type.REKKA_BRANCH_LOCKED:
				print("F%-3d REKKA_BRANCH_LOCKED ~%s → %s" % [frame, event.rekka_branch, event.rekka_move_id])
			CombatEvent.Type.SPIKE_LANDED:
				print("F%-3d SPIKE_LANDED 向下击落触地 → 普通倒地（计时 %d）" % [frame, session.dummy_knockdown_left])
			CombatEvent.Type.LOW_FLOAT_LANDED:
				print("F%-3d LOW_FLOAT_LANDED 低浮空触地 → 普通倒地" % frame)
			CombatEvent.Type.LINK_FAILED:
				print("F%-3d LINK_FAILED %s %s" % [frame, event.link_move_id, CombatEvent.LinkFailReason.keys()[event.link_fail_reason - 1]])
			CombatEvent.Type.THROW_FAILED:
				print("F%-3d THROW_FAILED %s" % [frame, CombatEvent.ThrowFailReason.keys()[event.throw_fail_reason - 1]])
			CombatEvent.Type.THROW_HIT:
				print("F%-3d THROW_HIT 普通投成立" % frame)
			CombatEvent.Type.HITSTOP_ENDED:
				print("F%-3d HITSTOP_ENDED" % frame)
			CombatEvent.Type.COMBO_ENDED:
				print("F%-3d COMBO_ENDED %s" % [frame, CombatEvent.ComboEndReason.keys()[event.combo_end_reason]])
			CombatEvent.Type.DUMMY_RECOVERED:
				print("F%-3d DUMMY_RECOVERED" % frame)


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


func _dummy_state_text(session: CombatSession) -> String:
	match session.dummy_state:
		CombatSession.DummyState.NEUTRAL:
			return "中立"
		CombatSession.DummyState.GROUND_HITSTUN:
			return "地面受击(%d)" % session.dummy_hitstun_left
		CombatSession.DummyState.AIR_HITSTUN:
			return "浮空受击(%d)" % session.dummy_hitstun_left
		CombatSession.DummyState.AIR_RECOVERED:
			return "空中已受身"
		CombatSession.DummyState.KNOCKED_DOWN:
			return "普通倒地(%d)" % session.dummy_knockdown_left
		CombatSession.DummyState.LOW_FLOAT_SWEEP:
			return "低浮空(%d)" % session.dummy_hitstun_left
		CombatSession.DummyState.SPIKE_FALL:
			return "向下击落坠落"
	return "?"
