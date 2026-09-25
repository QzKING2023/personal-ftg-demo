extends SceneTree
## 票据 05 验收回放：236C 两段判定、GROUND_SLIDE、来源限定 D 进入与 5B 目押。
## 记录固定起始间距、左右面向、逐帧事件、真实位移与三层修正——供
## acceptance/05/ 证据归档。运行：godot --headless --path . -s res://tests/acceptance_replay_05.gd

const NEAR_DX := 70.0
const SLIDE_DX := 93.0


func _initialize() -> void:
	_replay_route_b(1)
	_replay_route_b(-1)
	_replay_route_a(1)
	_replay_route_a(-1)
	_replay_early_entry(1)
	_replay_seg1_blocked(1)
	_replay_seg1_blocked(-1)
	_replay_expired_entry(1)
	_replay_slide_profile_gate(1)
	_replay_normal_5d_gap(1)
	quit(0)


func _spawn(dx: float, facing: int) -> CombatSession:
	var session := CombatSession.new()
	if facing == 1:
		session.dummy_position = session.player_position + Vector2(dx, 0)
	else:
		session.dummy_position = session.player_position - Vector2(dx, 0)
		session.player_facing = -1
	return session


func _feed_236c(session: CombatSession, frame: int, key: String) -> FrameInput:
	## 面向相对的 2/3/6 搓招：F-3 下、F-2 下+前、F-1 前，F 按键。
	var axis := 0
	var down := false
	var rel := frame % 4
	if rel == 1:
		down = true
	elif rel == 2:
		down = true
		axis = session.player_facing
	elif rel == 3:
		axis = session.player_facing
	return FrameInput.make(axis, false, key, down)


func _log(frame: int, tag: String, events: Array, session: CombatSession) -> void:
	for event in events:
		match event.type:
			CombatEvent.Type.HIT:
				print("  F%-3d %s HIT seg%d 伤%.1f 第%d击 木桩=%s 硬直%d 滑行%d 玩家x=%.1f 木桩x=%.1f" % [
					frame, tag, event.move_segment, event.damage, event.combo_hits,
					_state_text(session), session.dummy_hitstun_left, session.dummy_slide_left,
					session.player_position.x, session.dummy_position.x])
			CombatEvent.Type.HIT_MISS:
				print("  F%-3d %s HIT_MISS seg%d（无匹配资料，不回退）" % [frame, tag, event.move_segment])
			CombatEvent.Type.ATTACK_BLOCKED:
				print("  F%-3d %s BLOCKED seg%d（姿态%d 停顿%d 硬直%d 推退%.0f）" % [
					frame, tag, event.move_segment, event.guard_posture,
					event.block_freeze_frames, event.block_stun_frames, event.block_pushback_px_s])
			CombatEvent.Type.SLIDE_STARTED:
				print("  F%-3d %s SLIDE_STARTED 滑行剩%d 木桩x=%.1f" % [frame, tag, session.dummy_slide_left, session.dummy_position.x])
			CombatEvent.Type.LINK_FAILED:
				print("  F%-3d %s LINK_FAILED 原因%d 招式%s" % [frame, tag, event.link_fail_reason, event.link_move_id])
			CombatEvent.Type.COMBO_ENDED:
				print("  F%-3d %s COMBO_ENDED 原因%d" % [frame, tag, event.combo_end_reason])
			CombatEvent.Type.DUMMY_RECOVERED:
				print("  F%-3d %s DUMMY_RECOVERED" % [frame, tag])


func _state_text(session: CombatSession) -> String:
	match session.dummy_state:
		CombatSession.DummyState.NEUTRAL:
			return "中立"
		CombatSession.DummyState.GROUND_HITSTUN:
			return "地面硬直"
		CombatSession.DummyState.AIR_HITSTUN:
			return "浮空"
		CombatSession.DummyState.KNOCKED_DOWN:
			return "倒地"
		CombatSession.DummyState.LOW_FLOAT_SWEEP:
			return "低浮空"
		CombatSession.DummyState.SPIKE_FALL:
			return "击落"
		CombatSession.DummyState.LOW_FLOAT_TO_SLIDE:
			return "滑行前滞空"
		CombatSession.DummyState.GROUND_SLIDE:
			return "地面滑行"
		CombatSession.DummyState.AIR_RECOVERED:
			return "空中已受身"
	return "?"


func _summary(tag: String, session: CombatSession) -> void:
	print("  结果[%s]：连段 %d hit · 总伤 %.1f · HP %.1f · starter=%d 修正 伤%.4f/时%.4f/轨%.4f · 玩家x=%.1f 木桩x=%.1f" % [
		tag, session.combo_hits, session.combo_total_damage, session.dummy_hp,
		session.combo_starter_grade, session.combo_damage_scale, session.combo_time_scale,
		session.combo_trajectory_scale, session.player_position.x, session.dummy_position.x])


## 正例 R1（前置浮空捞起 + 目押）：236C 两段命中 → 特殊进入 5D（覆盖浮空）→
## D 完全恢复后目押 5B。时间轴（@70px）：F1–F3 搓 236、F4 C → F7 起手；
## 段 1 F13 命中、段 2 F26 命中（空中延长）；D@F26（命中当帧）→ F35 消费起手 5D；
## 5D F41 命中（airborne 资料）；B@F66（组合等待过）→ F70 收招当帧消费起手 5B；
## 5B F76 命中；F95 木桩自然恢复收尾。
func _replay_route_b(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	print("=== R1 正例 236C(两段)>5D(特殊进入)>5B(目押) | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	for frame in range(1, 110):
		var key := ""
		if frame == 4:
			key = "C"
		elif frame == 26:
			key = "D"
		elif frame == 66:
			key = "B"
		var input := _feed_236c(session, frame, key) if frame <= 4 else FrameInput.new()
		if frame > 4 and key != "":
			input = FrameInput.make(0, false, key)
		var events := session.step(input)
		_log(frame, "R1", events, session)
		if frame == 36:
			var snap := session.debug_snapshot()
			print("  F36 来源资格开放=%s 经资格起手=%s" % [snap.get("special_entry_open"), snap.get("move_via_special_entry")])
	_summary("R1", session)
	print("")


## 正例 R2（slide 捞起）：@93px 段 1 挥空（段 1 触及 91px 内、段 2 触及 97px 内）
## → 段 2 命中 grounded → 击飞触地 GROUND_SLIDE → 晚按 D（窗口内）→ 5D 以
## slide 资料捞起（slide 命中倍率 0.92/0.96/0.96）。
func _replay_route_a(facing: int) -> void:
	var session := _spawn(SLIDE_DX, facing)
	print("=== R2 正例 236C(段1挥空)>段2>slide>5D(捞起) | 面向 %d | 起始间距 %.0f px ===" % [facing, SLIDE_DX])
	for frame in range(1, 90):
		var key := ""
		if frame == 4:
			key = "C"
		elif frame == 30:
			key = "D"
		var input := _feed_236c(session, frame, key) if frame <= 4 else FrameInput.new()
		if frame > 4 and key != "":
			input = FrameInput.make(0, false, key)
		var events := session.step(input)
		_log(frame, "R2", events, session)
	_summary("R2", session)
	print("")


## 正例 R3（段 1 命中当下取消）：D 在段 1 命中的停顿内按下 → 恢复首帧消费，
## 原 236C 立即结束、段 2 不执行——全程只有一次 236C 命中。
func _replay_early_entry(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	print("=== R3 正例 236C(段1命中)>D(当帧取消跳过段2) | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	for frame in range(1, 60):
		var key := ""
		if frame == 4:
			key = "C"
		elif frame == 14:
			key = "D"
		var input := _feed_236c(session, frame, key) if frame <= 4 else FrameInput.new()
		if frame > 4 and key != "":
			input = FrameInput.make(0, false, key)
		var events := session.step(input)
		_log(frame, "R3", events, session)
	_summary("R3", session)
	print("")


## 反例 N1（段 1 被防终止整招 + 不授予资格）：木桩站防挡下段 1 → 整招立即结束；
## 停顿中按 D 只在恢复后作为独立 5D 起手，且被连防姿态再次挡下——全程零命中。
func _replay_seg1_blocked(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	print("=== N1 反例 段1被防终止+无资格 | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	for frame in range(1, 55):
		var key := ""
		if frame == 4:
			key = "C"
		elif frame == 15:
			key = "D"
		var input := _feed_236c(session, frame, key) if frame <= 4 else FrameInput.new()
		if frame > 4 and key != "":
			input = FrameInput.make(0, false, key)
		input.dummy_guard_request = CombatSession.GuardPosture.STANDING if frame <= 40 else 0
		var events := session.step(input)
		_log(frame, "N1", events, session)
	_summary("N1", session)
	print("")


## 反例 N2（资格过期不补发）：连段随资格窗口关闭结束后才按 D——5D 只作为独立
## 招式起手，命中的是已恢复的木桩（全新连段首击），不取得来源限定连接。
func _replay_expired_entry(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	print("=== N2 反例 资格过期后的独立 5D | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	for frame in range(1, 90):
		var key := ""
		if frame == 4:
			key = "C"
		elif frame == 53:
			key = "D"
		var input := _feed_236c(session, frame, key) if frame <= 4 else FrameInput.new()
		if frame > 4 and key != "":
			input = FrameInput.make(0, false, key)
		var events := session.step(input)
		_log(frame, "N2", events, session)
	_summary("N2", session)
	print("")


## 反例 N3（slide 资料门）：注入去掉 5D slide 资料的表——特殊进入的 5D 命中框
## 已连接滑行目标但无 (GROUND_SLIDE, normal) 资料 → HIT_MISS，滑行照常走完。
func _replay_slide_profile_gate(facing: int) -> void:
	var table := MoveData.default_table()
	var five_d := table["5D"] as MoveData
	var kept: Array[HitProfile] = []
	for profile in five_d.hit_profiles:
		if profile.target_state != HitProfile.TargetState.GROUND_SLIDE:
			kept.append(profile)
	five_d.hit_profiles = kept
	var session := CombatSession.new(table)
	if facing == 1:
		session.dummy_position = session.player_position + Vector2(SLIDE_DX, 0)
	else:
		session.dummy_position = session.player_position - Vector2(SLIDE_DX, 0)
		session.player_facing = -1
	print("=== N3 反例 slide 无资料 → HIT_MISS（注入表） | 面向 %d | 起始间距 %.0f px ===" % [facing, SLIDE_DX])
	for frame in range(1, 80):
		var key := ""
		if frame == 4:
			key = "C"
		elif frame == 30:
			key = "D"
		var input := _feed_236c(session, frame, key) if frame <= 4 else FrameInput.new()
		if frame > 4 and key != "":
			input = FrameInput.make(0, false, key)
		var events := session.step(input)
		_log(frame, "N3", events, session)
	_summary("N3", session)
	print("")


## 反例 N4（普通来源 5D 不取得反向 5B）：5B 链式取消进 5D（普通来源）→ D 命中后
## 目押 5B → 收招当帧报 LINK_FAILED/CONFIGURATION_GAP（未声明普通连接边），
## 连段结束，5B 输入只按独立招式继续。
func _replay_normal_5d_gap(facing: int) -> void:
	var session := _spawn(NEAR_DX, facing)
	print("=== N4 反例 普通 5D>5B 无反向出口 | 面向 %d | 起始间距 %.0f px ===" % [facing, NEAR_DX])
	for frame in range(1, 70):
		var key := ""
		if frame == 1:
			key = "A"
		elif frame == 5:
			key = "B"
		elif frame == 21:
			key = "D"
		elif frame == 38:
			key = "B"
		var events := session.step(FrameInput.make(0, false, key))
		_log(frame, "N4", events, session)
	_summary("N4", session)
	print("")
